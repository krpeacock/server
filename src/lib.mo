import CertifiedCache "mo:certified-cache";
import Assets "mo:assets";
import AssetTypes "mo:assets/Types";
import HashMap "mo:StableHashMap/ClassStableHashMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Hash "mo:base/Hash";
import HttpParser "mo:http-parser";
import HttpParserTypes "mo:http-parser/Types";
import Http "mo:http-types";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import TrieMap "mo:base/TrieMap";
import Utils "Utils";

module {
  // Public Types
  
  /**
    An incoming HTTP request. See <a href="https://mops.one/http-types/docs#type.Request">Http Type</a> documentation
    
    public type HttpRequest = {
      url : Text;
      method : Text;
      headers : [Header];
      body : Blob;
    } and {
      certificate_version : ?Nat16;
    };
    */
  public type HttpRequest = Http.Request;

  /**
    An outgoing HTTP response. See <a href="https://mops.one/http-types/docs#type.Response">Http Type</a> documentation
    
    public type HttpResponse = {
      status_code : Nat16;
      headers : [Header];
      body : Blob;
      streaming_strategy : ?StreamingStrategy;
    };

    */
  public type HttpResponse = Http.Response;

  /**
    A parsed URL.

    public type URL = {
      original: Text;
      protocol: Text ;
      port: Nat16; 
      host: {
          original: Text;
          array: [Text];
      };
      path: {
          original: Text;
          array: [Text];
      };
      queryObj: {
          original: Text;
          get: (Text) -> ?Text;
          trieMap: TrieMap.TrieMap<Text, Text>;
          keys: [Text]; 
      };
      anchor: Text; 
    };
    */
  public type URL = HttpParserTypes.URL;

  /**
    A serialized entry for the server, processed using the Utils.parsePathParams method.

    public type Request = {
      method : Text;
      url : URL;
      headers : HttpParserTypes.Headers;
      body : ?HttpParserTypes.Body;
      params : ?TrieMap.TrieMap<Text, Text>;
    };
    */
  public type Request = {
    method : Text;
    url : URL;
    headers : HttpParserTypes.Headers;
    body : ?HttpParserTypes.Body;
    params : ?TrieMap.TrieMap<Text, Text>;
  };

  /**
    A Response, along with a `cache_strategy` for the `certified-cache` module.

    public type Response = {
      status_code : Nat16;
      headers : [Header];
      body : Blob;
      streaming_strategy : ?StreamingStrategy;
      cache_strategy : CacheStrategy;
    };
    */
  public type Response = {
    status_code : Nat16;
    headers : [Http.Header];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
    cache_strategy : CacheStrategy;
  };

  /**
    A set of stable structures used to serialize to and from for upgrades. This hydrates the certified cache, assets, and authorized principals.

    public type SerializedEntries = ([(HttpRequest, (HttpResponse, Nat))], [(AssetTypes.Key, Assets.StableAsset)], [Principal]);

    @example
    ```mo
    let serializedEntries : SerializedEntries = ([], [], [controller_principals]);
    ```
    */
  public type SerializedEntries = ([(HttpRequest, (HttpResponse, Nat))], [(AssetTypes.Key, Assets.StableAsset)], [Principal]);

  /**
    A path to an asset. It's just Text.

    public type Path = Assets.Path;
    */
  public type Path = Assets.Path;

  /**
    Contents of an asset. It's just Blob.

    public type Contents = Assets.Contents;
    */
  public type Contents = Assets.Contents;

  // Public Functions

  /**
    Compare two requests. Used to initialize the cache. Default strategy just checks the URL.

    @param {HttpRequest} req1 - The first request

    @param {HttpRequest} req2 - The second request

    @returns {Bool} - Whether the requests are equal
    */
  public func compareRequests(req1 : HttpRequest, req2 : HttpRequest) : Bool {
    req1.url == req2.url;
  };
  
  /**
    Hash a request.

    @param {HttpRequest} req - The request to hash

    @returns {Hash.Hash} - The hash of the request
    */
  public func hashRequest(req : HttpRequest) : Hash.Hash {
    Text.hash(req.url);
  };
  
  /**
    Encode a request as a Blob.

    @param {HttpRequest} req - The request to encode

    @returns {Blob} - The encoded request
    */
  public func encodeRequest(req : HttpRequest) : Blob {
    Text.encodeUtf8(req.url);
  };

  /**
    Yield the response from a response.

    @param {HttpResponse} b - The response to yield

    @returns {Blob} - The response body
    */
  public func yieldResponse(b : HttpResponse) : Blob { b.body };

  // Private Types
  type HttpFunction = (Request) -> async* Response;
  type RequestMap = HashMap.StableHashMap<Text, HttpFunction>;

  type CacheStrategy = {
    #default;
    #noCache;
    #expireAfter : { nanoseconds : Nat };
  };

  type BasicResponse = {
    status_code : Nat16;
    headers : [Http.Header];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
  };

  /**
    A server that handles HTTP requests and responses. It includes a cache, assets, and authorized principals.

    Variables:

    - `authorized` {[Principal]} - The authorized principals for modifying assets
    - `cache` {CertifiedCache<HttpRequest, HttpResponse>} - The cache for the server
    - `assets` {Assets} - The assets for the server

    public class Server = {
      serializedEntries : SerializedEntries;
    };
    */
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

    /** iterates through the request handlers and finds the first one that matches the path

    @param {Text} path - The path to match

    @param {HashMap.StableHashMap<Text, HttpFunction>} map - The map of request handlers

    @returns {?(HttpFunction, Utils.PathParams)} An optional Tuple matching the pattern and path parameters
    */
    private func findMatchingPattern(path : Text, map : HashMap.StableHashMap<Text, HttpFunction>) : ?(HttpFunction, Utils.PathParams) {
      let entries = map.entries();
      for (entry in entries) {
        let (pattern, _) = entry;
        switch (Utils.parsePathParams(pattern, path)) {
          case (#ok params) {
            let function = map.get(pattern);
            switch (function) {
              case (?f) {
                return ?(f, params);
              };
              case null {
                return null;
              };
            };
          };
          case (#err _) {
            return null;
          };
        };
      };
      return null;
    };

    private func handleFunction(map : HashMap.StableHashMap<Text, HttpFunction>, req : Request, fallback : ?((Request) -> Response)) : async* Response {
      let (simplifiedBaseRoute, simplifiedFullRoute) = Utils.simplifyRoute(req.url);

      ignore do ? {
        // Check for an exact match, including query parameters
        switch (map.get(simplifiedFullRoute)) {
          case (?f) {
            return await* f(req);
          };
          case null {};
        };

        // Check for a match with the base route
        switch (map.get(simplifiedBaseRoute)) {
          case (?f) {
            return await* f(req);
          };
          case null {};
        };

        // Check for a match with a pattern
        let maybePattern = findMatchingPattern(simplifiedBaseRoute, map);
        switch (maybePattern) {
          case (?(f, params)) {
            let request = {
              method = req.method;
              url = req.url;
              headers = req.headers;
              body = req.body;
              params = ?params;
            };
            return await* f(request);
          };
          case null {};
        };

        // Check for a fallback
        switch (fallback) {
          case (?f) {
            return f(req);
          };
          case null {};
        };
      };
      missingResponse;
    };

    private func process_request(req : Request) : async* Response {
      switch (req.method) {
        case "GET" {
          let fallback = staticFallback;
          await* handleFunction(getRequests, req, ?fallback);
        };
        case "POST" {
          await* handleFunction(postRequests, req, null);
        };
        case "PUT" {
          await* handleFunction(putRequests, req, null);
        };
        case "DELETE" {
          await* handleFunction(deleteRequests, req, null);
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

    /** Handler to register for streaming callback, if you are handling multi-part requests
      
      @param {AssetTypes.StreamingCallbackToken} token - The token for the streaming callback
      
      @returns {AssetTypes.StreamingCallbackHttpResponse} - The response from the streaming callback
    */
    public func http_request_streaming_callback(token : AssetTypes.StreamingCallbackToken) : async AssetTypes.StreamingCallbackHttpResponse {
      assets.http_request_streaming_callback(token);
    };

    /**
      Register a request handler for a given method and URL.

      @param {Text} method - The HTTP method to handle

      @param {Text} url - The URL to handle

      @param {HttpFunction} function - The function to handle the request
    */
    public func registerRequest(method : Text, url : Text, function : HttpFunction) {
      let lowercaseUrl = Text.toLowercase(url);
      switch (method) {
        case "GET" {
          getRequests.put(lowercaseUrl, function);
        };
        case "POST" {
          postRequests.put(lowercaseUrl, function);
        };
        case "PUT" {
          putRequests.put(lowercaseUrl, function);
        };
        case "DELETE" {
          deleteRequests.put(lowercaseUrl, function);
        };
        case _ {};
      };
    };
    // Register a request handler that will be cached
    // GET requests are cached by default
    // POST, PUT, DELETE requests are not cached
    private func registerRequestWithHandler(method : Text, path : Text, handler : (request : Request, response : ResponseClass) -> async* Response) {
      if (method == "GET") {
        registerRequest(
          method,
          path,
          func(request : Request) : async* Response {
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
            return await* response;
          },
        );
      } else {
        registerRequest(
          method,
          path,
          func(request : Request) : async* Response {
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
            return await* response;
          },
        );
      };
    };

    /**
      Register a GET request handler for a given path or pattern.

      @param {Text} path - The URL to handle

      @param {HttpFunction} function - The function to handle the request

      @example
      ```mo
      server.get("/hello", func(request : Request, response : ResponseClass) : async* Response {
        return response.json({
          status_code = 200,
          body = "Hello, World!",
          cache_strategy = #default,
        });
      });
      ```
    */
    public func get(path : Text, handler : (request : Request, response : ResponseClass) -> async* Response) {
      registerRequestWithHandler("GET", path, handler);
    };

    /**
      Register a POST request handler for a given path or pattern.

      @param {Text} path - The URL to handle

      @param {HttpFunction} function - The function to handle the request

      @example
      ```mo
      server.post("/hello", func(request : Request, response : ResponseClass) : async* Response {
        let obj = request.url.queryObj;

        switch (obj.get("name")){
          case (?name) {
            return response.json({
              status_code = 200,
              body = "Hello, " + name + "!",
              cache_strategy = #default,
            });
          };
          case null {
            return response.json({
              status_code = 400,
              body = "Name not provided",
              cache_strategy = #noCache,
            });
          };
        };
      });
      ```
    */
    public func post(path : Text, handler : (request : Request, response : ResponseClass) -> async* Response) {
      registerRequestWithHandler("POST", path, handler);
    };

    /** 
      Register a PUT request handler for a given path or pattern.

      @param {Text} path - The URL to handle

      @param {HttpFunction} function - The function to handle the request
    */
    public func put(path : Text, handler : (request : Request, response : ResponseClass) -> async* Response) {
      registerRequestWithHandler("PUT", path, handler);
    };

    /** 
      Register a DELETE request handler for a given path or pattern.

      @param {Text} path - The URL to handle

      @param {HttpFunction} function - The function to handle the request
    */
    public func delete(path : Text, handler : (request : Request, response : ResponseClass) -> async* Response) {
      registerRequestWithHandler("DELETE", path, handler);
    };

    /**
      Serialize the server to a set of stable structures.

      @returns {SerializedEntries} - The serialized entries
    */
    public func entries() : SerializedEntries {
      let serializedAssets = assets.entries();
      let (stableAssets, _) = serializedAssets;
      (cache.entries(), stableAssets, authorized);
    };

    /**
      Check if a principal is authorized to update the assets.

      @param {Principal} caller - The principal to check

      @returns {Bool} - Whether the principal is authorized
    */
    public func isAuthorized(caller : Principal) : Bool {
      func eq(value : Principal) : Bool = value == caller;
      Array.find(authorized, eq) != null;
    };

    // #endregion

    // #region Bindings

    /**
      Empty the cache.
    */
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

    /**
      Remove a path from the cache.

      @param {Principal} caller - The principal to authorize the removal

      @param {Path} path - The path to remove
    */
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
        func(key : HttpRequest) : Bool {
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

    /**
      Binding to attach to the HTTP request handler in your actor.

      @param {HttpRequest} request - The incoming HTTP request

      @returns {HttpResponse} - The outgoing HTTP response

      @example
      ```mo
      public query func http_request(req : HttpRequest) : async HttpResponse {
        server.http_request(req);
      };
      ```
    */
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
            status_code = 426;
            headers = [];
            body = Blob.fromArray([]);
            streaming_strategy = null;
            upgrade = ?true;
          };
        };

      };
    };

    /**
      Binding to attach to the HTTP request handler in your actor.

      @param {HttpRequest} request - The incoming HTTP request

      @returns {HttpResponse} - The outgoing HTTP response

      @example
      ```mo
      public func http_request_update(req : HttpRequest) : async HttpResponse {
        await server.http_request_update(req);
      };
      ```
    */
    public func http_request_update(request : HttpRequest) : async* HttpResponse {
      // prune the cache
      ignore cache.remove(request);

      // Application logic to process the request
      let req = HttpParser.parse(request);

      // Set the params to null - we will find a matching handler if there is one during the processing
      let parsedrequest = {
        method = req.method;
        url = req.url;
        headers = req.headers;
        body = req.body;
        params = null;
      };

      let response = await* process_request(parsedrequest);

      let formattedResponse = {
        status_code = response.status_code;
        headers = response.headers;
        body = response.body;
        streaming_strategy = response.streaming_strategy;
        upgrade = null;
      };

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
