import CertifiedCache "mo:certified-cache";
import Assets "mo:assets";
import AssetTypes "mo:assets/Types";
import Http "mo:certified-cache/Http";
import HashMap "mo:StableHashMap/ClassStableHashMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Hash "mo:base/Hash";
import HttpParser "mo:http-parser.mo";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";

module {
  // Public Types
  public type HttpRequest = Http.HttpRequest;
  public type HttpResponse = Http.HttpResponse;

  public type Request = HttpParser.ParsedHttpRequest;

  public type Response = {
    status_code : Nat16;
    headers : [Http.HeaderField];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
    cache_strategy : CacheStrategy;
  };

  public type SerializedEntries = ([(HttpRequest, (HttpResponse, Nat))], [(AssetTypes.Key, Assets.StableAsset)], [Principal]);

  public type Path = Assets.Path;
  public type Contents = Assets.Contents;

  // Public Functions

  // Compare two requests
  public func compareRequests(req1 : HttpRequest, req2 : HttpRequest) : Bool {
    req1.url == req2.url;
  };
  // Hash a request
  public func hashRequest(req : HttpRequest) : Hash.Hash {
    Text.hash(req.url);
  };
  // Encode a request
  public func encodeRequest(req : HttpRequest) : Blob {
    Text.encodeUtf8(req.url);
  };
  // Yield a response
  public func yieldResponse(b : HttpResponse) : Blob { b.body };

  // Private Types
  type HttpFunction = (Request) -> async Response;
  type RequestMap = HashMap.StableHashMap<Text, HttpFunction>;

  type CacheStrategy = {
    #default;
    #noCache;
    #expireAfter : { nanoseconds : Nat };
  };

  type BasicResponse = {
    status_code : Nat16;
    headers : [Http.HeaderField];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
  };

  public class Server({
    serializedEntries : SerializedEntries;
  }) {
    let (cacheEntries, stableAssets, cacheAuthorized) = serializedEntries;

    public var authorized = cacheAuthorized;

    let missingResponse : Response = {
      status_code = 404;
      headers = [];
      body = Blob.fromArray([]);
      streaming_strategy = null;
      cache_strategy = #noCache;
    };

    let two_days_in_nanos = 2 * 24 * 60 * 60 * 1000 * 1000 * 1000;
    let one_second_in_nanos = 1000 * 1000 * 1000;

    let filteredCacheEntries = Iter.toArray(
      Iter.filter(
        Iter.fromArray(cacheEntries),
        (
          func(entry : (HttpRequest, (HttpResponse, Nat))) : Bool {
            let (_, (_, expiry)) = entry;
            if (expiry > Int.abs(Time.now())) {
              true;
            } else {
              false;
            };
          }
        ),
      )
    );

    public var cache = CertifiedCache.fromEntries<HttpRequest, HttpResponse>(
      filteredCacheEntries,
      compareRequests,
      hashRequest,
      encodeRequest,
      yieldResponse,
      two_days_in_nanos + Int.abs(Time.now()),
    );

    // Set up asset management
    public var assets = Assets.Assets({
      serializedEntries = (stableAssets, authorized);
    });

    // #region Internals
    var getRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var postRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var putRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var deleteRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    private func process_request(req : Request) : async Response {
      switch (req.method) {
        case "GET" {
          switch (getRequests.get(req.url.path.original)) {
            case (?getFunction) {
              await getFunction(req);
            };
            case null {
              staticFallback(req);
            };
          };
        };
        case "POST" {
          switch (postRequests.get(req.url.path.original)) {
            case (?postFunction) {
              await postFunction(req);
            };
            case null {
              missingResponse;
            };
          };
        };
        case "PUT" {
          switch (putRequests.get(req.url.path.original)) {
            case (?putFunction) {
              await putFunction(req);
            };
            case null {
              missingResponse;
            };
          };
        };
        case "DELETE" {
          switch (deleteRequests.get(req.url.path.original)) {
            case (?deleteFunction) {
              await deleteFunction(req);
            };
            case null {
              missingResponse;
            };
          };
        };
        case _ {
          missingResponse;
        };
      };
    };



    private func staticFallback(req : Request) : Response {
      var b : Blob = Blob.fromArray([]);
      switch (req.body) {
        case (?body) {
          b := body.original;
        };
        case null {};
      };
      var path : Text = req.url.path.original;

      if (path == "/") {
        path := "/index.html";
      };

      let response = assets.http_request({
        method = req.method;
        url = path;
        headers = req.headers.original;
        body = b;
      });

      switch (response.streaming_strategy) {

        case (?_) {
          // TODO - implement streaming
          missingResponse;
        };
        case null {
          switch (response.status_code) {
            case 200 {
              {
                status_code = response.status_code;
                headers = response.headers;
                body = response.body;
                streaming_strategy = null;
                upgrade = null;
                // expire after 10 seconds
                cache_strategy = #expireAfter {
                  nanoseconds = Int.abs(Time.now()) + 10 * one_second_in_nanos;
                };
              };
            };
            case _ {
              missingResponse;
            };
          };

        };

      };

    };

    public func http_request_streaming_callback(token : AssetTypes.StreamingCallbackToken) : async AssetTypes.StreamingCallbackHttpResponse {
      assets.http_request_streaming_callback(token);
    };

    // Insert request handlers into maps based on method
    public func registerRequest(method : Text, url : Text, function : HttpFunction) {
      switch (method) {
        case "GET" {
          getRequests.put(url, function);
        };
        case "POST" {
          postRequests.put(url, function);
        };
        case "PUT" {
          putRequests.put(url, function);
        };
        case "DELETE" {
          deleteRequests.put(url, function);
        };
        case _ {
        };
      };
    };
    // Register a request handler that will be cached
    // GET requests are cached by default
    // POST, PUT, DELETE requests are not cached
    private func registerRequestWithHandler(method : Text, path : Text, handler : (request : Request, response : ResponseClass) -> async Response) {
      if (method == "GET") {
        registerRequest(
          method,
          path,
          func(request : Request) : async Response {
            var response = handler(
              request,
              ResponseClass(
                func(res : Response) : Response {
                  return {
                    status_code = res.status_code;
                    headers = res.headers;
                    body = res.body;
                    streaming_strategy = res.streaming_strategy;
                    cache_strategy = res.cache_strategy;
                  };
                }
              ),
            );
            return await response;
          },
        );
      } else {
        registerRequest(
          method,
          path,
          func(request : Request) : async Response {
            var response = handler(
              request,
              ResponseClass(
                func(res : BasicResponse) : Response {
                  return {
                    status_code = res.status_code;
                    headers = res.headers;
                    body = res.body;
                    streaming_strategy = res.streaming_strategy;
                    cache_strategy = #noCache;
                  };
                }
              ),
            );
            return await response;
          },
        );
      };
    };

    public func get(path : Text, handler : (request : Request, response : ResponseClass) -> async Response) {
      registerRequestWithHandler("GET", path, handler);
    };

    public func post(path : Text, handler : (request : Request, response : ResponseClass) -> async Response) {
      registerRequestWithHandler("POST", path, handler);
    };

    public func put(path : Text, handler : (request : Request, response : ResponseClass) -> async Response) {
      registerRequestWithHandler("PUT", path, handler);
    };

    public func delete(path : Text, handler : (request : Request, response : ResponseClass) -> async Response) {
      registerRequestWithHandler("DELETE", path, handler);
    };

    public func entries() : SerializedEntries {
      let serializedAssets = assets.entries();
      let (stableAssets, _) = serializedAssets;
      (cache.entries(), stableAssets, authorized);
    };

    public func isAuthorized(caller : Principal) : Bool {
      func eq(value : Principal) : Bool = value == caller;
      Array.find(authorized, eq) != null;
    };

    // #endregion

    // #region Bindings
    public func empty_cache() {
      cache := CertifiedCache.fromEntries<HttpRequest, HttpResponse>(
        [],
        compareRequests,
        hashRequest,
        encodeRequest,
        yieldResponse,
        two_days_in_nanos + Int.abs(Time.now()),
      );
    };

    public func remove_from_cache(
      {
        caller;
        path;
      } : RemoveFromCacheProps
    ) : () {
      let authorized = isAuthorized(caller);
      if (authorized == false) {
        return;
      };
      let foundInCache = Iter.filter(
        cache.keys(),
        func(key : Http.HttpRequest) : Bool {
          key.url == path;
        },
      );
      for (key in foundInCache) {
        ignore cache.remove(key);
      };
    };
    public type RemoveFromCacheProps = {
      path : Path;
      caller : Principal;
    };

    public func http_request(request : HttpRequest) : HttpResponse {
      var cachedResponse = cache.get(request);
      switch cachedResponse {
        case (?response) {
          {
            status_code = response.status_code;
            headers = joinArrays(response.headers, [cache.certificationHeader(request)]);
            body = response.body;
            streaming_strategy = response.streaming_strategy;
            upgrade = null;
          };
        };
        case null {
          return {
            status_code = 404;
            headers = [];
            body = Blob.fromArray([]);
            streaming_strategy = null;
            upgrade = ?true;
          };
        };

      };
    };

    public func http_request_update(request : HttpRequest) : async HttpResponse {
      // Application logic to process the request
      let req = HttpParser.parse(request);
      let response = await process_request(req);
      let formattedResponse = {
        status_code = response.status_code;
        headers = response.headers;
        body = response.body;
        streaming_strategy = response.streaming_strategy;
        upgrade = null;
      };

      Debug.print("cache strategy: " # debug_show response.cache_strategy);

      // expiry can be null to use the default expiry
      if (response.status_code == 200) {
        switch (response.cache_strategy) {
          case (#expireAfter expiry) {
            cache.put(request, formattedResponse, ?expiry.nanoseconds);
          };
          case (#noCache) {
            // do not cache
          };
          case (#default) {
            cache.put(request, formattedResponse, null);
          };
        };
      };
      return formattedResponse;
    };

    /**
     * Authorize a principal to update the assets
     * @param args
      * @param args.caller The principal that is authorizing the other principal
      * @param args.other The principal that is being authorized
      * @returns ()
      @ example
      ```rust
      public shared ({ caller }) func authorize(other : Principal) : async () {
        server.authorize({ caller; other });
      };
      ```
     */
    public func authorize(
      {
        caller;
        other;
      } : AuthorizeProps
    ) : () {
      authorized := joinArrays<Principal>(authorized, [other]);
      assets.authorize({ caller; other });
    };
    public type AuthorizeProps = {
      caller : Principal;
      other : Principal;
    };

    /**
     * Retrieve an asset at a provide path
     * @param path The path of the asset to retrieve
     * @returns The asset at the provided path (Blob)
      @ example
      ```rust
      public shared func retrieve(path : Path) : Contents {
        server.retrieve(path);
      };
      ```
     */
    public func retrieve(path : Path) : Contents {
      assets.retrieve(path);
    };

    /**
     * Store an asset at a provided path
     * @param args
      * @param args.key The path of the asset to store
      * @param args.content_type The content type of the asset
      * @param args.content_encoding The content encoding of the asset
      * @param args.content The content of the asset
      * @param args.sha256 The sha256 hash of the asset
      * @returns ()
      @ example
      ```rust
      public shared ({ caller }) func store(arg: StoreProps) : async () {
        server.store({
          caller;
          arg;
        });
      };
      ```
     */
    public func store({
      arg : StoreProps;
      caller : Principal;
    }) : () {
      assets.store({
        caller;
        arg;
      });
      remove_from_cache({
        caller;
        path = arg.key;
      });
    };
    public type Key = Assets.Key;
    public type StoreProps = {
      key : Key;
      content_type : Text;
      content_encoding : Text;
      content : Blob;
      sha256 : ?Blob;
    };

    // #endregion
    private func joinArrays<T>(a : [T], b : [T]) : [T] {
      let buf = Buffer.fromArray<T>(a);
      let vals = b.vals();
      for (val in vals) {
        buf.add(val);
      };
      Buffer.toArray(buf);
    };
  };

  public class ResponseClass(cb : (Response) -> Response) {

    public func send(response : Response) : Response {
      cb(response);
    };

    public func json(
      response : {
        status_code : Nat16;
        body : Text;
        cache_strategy : CacheStrategy;
      }
    ) : Response {
      cb({
        status_code = response.status_code;
        headers = [("content-type", "application/json")];
        body = Text.encodeUtf8(response.body);
        streaming_strategy = null;
        cache_strategy = response.cache_strategy;
      });
    };
  };

  // #endregion
};
