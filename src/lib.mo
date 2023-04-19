import CertifiedCache "mo:certified-cache";
import Http "mo:certified-cache/Http";
import HashMap "mo:StableHashMap/ClassStableHashMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HttpParser "http-parser";
import Int "mo:base/Int";
import Time "mo:base/Time";

module {
  type HttpFunction = (HttpParser.ParsedHttpRequest) -> Response;
  type RequestMap = HashMap.StableHashMap<Text, HttpFunction>;

  type CacheStrategy = {
    #default;
    #noCache;
    #expireAfter : { nanoseconds : Nat };
  };

  public type BasicResponse = {
    status_code : Nat16;
    headers : [Http.HeaderField];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
  };

  public type Response = {
    status_code : Nat16;
    headers : [Http.HeaderField];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
    cache_strategy : CacheStrategy;
  };

  public type Request = HttpParser.ParsedHttpRequest;

  public type HttpRequest = Http.HttpRequest;
  public type HttpResponse = Http.HttpResponse;

  public class Server(entries : [(HttpRequest, (HttpResponse, Nat))]) {

    let two_days_in_nanos = 2 * 24 * 60 * 60 * 1000 * 1000 * 1000;

    public var cache = CertifiedCache.fromEntries<HttpRequest, HttpResponse>(
      entries,
      compareRequests,
      hashRequest,
      encodeRequest,
      yieldResponse,
      two_days_in_nanos + Int.abs(Time.now()),
    );

    var getRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var postRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var putRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var deleteRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    public func http_request(request : Http.HttpRequest) : Http.HttpResponse {
      let req = HttpParser.parse(request);
      var cachedResponse = cache.get(request);
      switch cachedResponse {
        case (?response) {
          {
            status_code = response.status_code;
            headers = Array.append(response.headers, [cache.certificationHeader(request)]);
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

    public func http_request_update(request : Http.HttpRequest) : Http.HttpResponse {
      // Application logic to process the request
      let req = HttpParser.parse(request);
      let cacheResponse = process_request(req);
      let response = {
        status_code = cacheResponse.status_code;
        headers = cacheResponse.headers;
        body = cacheResponse.body;
        streaming_strategy = cacheResponse.streaming_strategy;
        upgrade = null;
      };

      // expiry can be null to use the default expiry
      if (response.status_code == 200) {
        switch (cacheResponse.cache_strategy) {
          case (#expireAfter expiry) {
            cache.put(request, response, ?expiry.nanoseconds);
          };
          case (#noCache) {
            // do not cache
          };
          case (#default) {
            cache.put(request, response, null);
          };
        };
      };
      return response;
    };

    public func process_request(req : HttpParser.ParsedHttpRequest) : Response {
      Debug.print("Processing request: " # debug_show req.url.original);
      Debug.print("Method: " # req.method);
      Debug.print("Path: " # req.url.path.original);
      switch (req.method) {
        case "GET" {
          switch (getRequests.get(req.url.path.original)) {
            case (?getFunction) {
              Debug.print("Found GET function");
              getFunction(req);
            };
            case null {
              Debug.print("No GET function found");
              {
                status_code = 404;
                headers = [];
                body = Blob.fromArray([]);
                streaming_strategy = null;
                cache_strategy = #noCache;
              };
            };

          };
        };
        case "POST" {
          switch (postRequests.get(req.url.path.original)) {
            case (?postFunction) {
              Debug.print("Found POST function");
              postFunction(req);
            };
            case null {
              Debug.print("No POST function found");
              {
                status_code = 404;
                headers = [];
                body = Blob.fromArray([]);
                streaming_strategy = null;
                cache_strategy = #noCache;
              };
            };

          };
        };

        case "PUT" {
          switch (putRequests.get(req.url.path.original)) {
            case (?putFunction) {
              Debug.print("Found PUT function");
              putFunction(req);
            };
            case null {
              Debug.print("No PUT function found");
              {
                status_code = 404;
                headers = [];
                body = Blob.fromArray([]);
                streaming_strategy = null;
                cache_strategy = #noCache;
              };
            };

          };
        };

        case "DELETE" {
          switch (deleteRequests.get(req.url.path.original)) {
            case (?deleteFunction) {
              Debug.print("Found DELETE function");
              deleteFunction(req);
            };
            case null {
              Debug.print("No DELETE function found");
              {
                status_code = 404;
                headers = [];
                body = Blob.fromArray([]);
                streaming_strategy = null;
                cache_strategy = #noCache;
              };
            };

          };
        };

        case _ {
          {
            status_code = 404;
            headers = [];
            body = Blob.fromArray([]);
            streaming_strategy = null;
            cache_strategy = #noCache;
          };
        };
      };
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
          Debug.print("Unknown method: " # method);
        };
      };
    };
    // Register a request handler that will be cached
    // GET requests are cached by default
    // POST, PUT, DELETE requests are not cached
    private func registerRequestWithHandler(method : Text, path : Text, handler : (request : Request, response : ResponseClass) -> Response) {
      if (method == "GET") {
        registerRequest(
          method,
          path,
          func(request : Request) : Response {
            var response = handler(
              request,
              ResponseClass(
                func(res : BasicResponse) : Response {
                  return {
                    status_code = res.status_code;
                    headers = res.headers;
                    body = res.body;
                    streaming_strategy = res.streaming_strategy;
                    cache_strategy = #default;
                  };
                },
                ? #default,
              ),
            );
            return response;
          },
        );
      } else {
        registerRequest(
          method,
          path,
          func(request : Request) : Response {
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
                },
                ?#noCache,
              ),
            );
            return response;
          },
        );
      };
    };

    public func get(path : Text, handler : (request : Request, response : ResponseClass) -> Response) {
      registerRequestWithHandler("GET", path, handler);
    };

    public func post(path : Text, handler : (request : Request, response : ResponseClass) -> Response) {
      registerRequestWithHandler("POST", path, handler);
    };

    public func put(path : Text, handler : (request : Request, response : ResponseClass) -> Response) {
      registerRequestWithHandler("PUT", path, handler);
    };

    public func delete(path : Text, handler : (request : HttpParser.ParsedHttpRequest, response : ResponseClass) -> Response) {
      registerRequestWithHandler("DELETE", path, handler);
    };

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
  };

  public type ResponseFunc = (response : Response) -> Response;
  
  public class ResponseClass(cb : (Response) -> Response, overrideCacheStrategy : ?CacheStrategy) {

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
      let cache_strategy = switch (overrideCacheStrategy) {
        case (?cacheStrategy) {
          cacheStrategy;
        };
        case null {
          response.cache_strategy;
        };
      };
      cb({
        status_code = response.status_code;
        headers = [("content-type", "application/json")];
        body = Text.encodeUtf8(response.body);
        streaming_strategy = null;
        cache_strategy = cache_strategy;
      });
    };
  };

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
};
