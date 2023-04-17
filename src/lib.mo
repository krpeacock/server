import CertifiedCache "mo:certified-cache";
import Http "mo:certified-cache/Http";
import HashMap "mo:StableHashMap/ClassStableHashMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HttpParser "http-parser";

module {
  type HttpFunction = (HttpParser.ParsedHttpRequest) -> CacheResponse;
  type RequestMap = HashMap.StableHashMap<Text, HttpFunction>;

  public type CacheResponse = {
    status_code : Nat16;
    headers : [Http.HeaderField];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
  };

  public class Server(cache : CertifiedCache.CertifiedCache<Http.HttpRequest, Http.HttpResponse>) {
    var getRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var postRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var putRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var deleteRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

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
        cache.put(request, response, null);
      };
      return response;
    };

    public func process_request(req : HttpParser.ParsedHttpRequest) : CacheResponse {
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
          };
        };
      };
    };

    public func get(path : Text, handler : (request : HttpParser.ParsedHttpRequest, response : Response) -> CacheResponse) {
      registerRequest(
        "GET",
        path,
        func(request : HttpParser.ParsedHttpRequest) : CacheResponse {
          var response = handler(
            request,
            Response(
              func(res : CacheResponse) : CacheResponse {
                res;
              }
            ),
          );
          return response;
        },
      );
    };
  };

  public type CacheResponseFunc = (response : CacheResponse) -> CacheResponse;
  public class Response(cb : (CacheResponse) -> CacheResponse) {

    public func send(response : CacheResponse) : CacheResponse {
      cb(response);
    };

    public func json(
      response : {
        status_code : Nat16;
        body : Text;
      }
    ) : CacheResponse {

      cb({
        status_code = response.status_code;
        headers = [("content-type", "application/json")];
        body = Text.encodeUtf8(response.body);
        streaming_strategy = null;
      });
    };
  };

  type HttpRequest = Http.HttpRequest;
  type HttpResponse = Http.HttpResponse;
  // Compare two requests
  public func compareRequests (req1 : HttpRequest, req2 : HttpRequest) : Bool {
    req1.url == req2.url;
  };
  // Hash a request
  public func hashRequest (req : HttpRequest) : Hash.Hash {
    Text.hash(req.url);
  };
  // Encode a request
  public func encodeRequest (req : HttpRequest) : Blob {
    Text.encodeUtf8(req.url);
  };
  // Yield a response
  public func yieldResponse (b : HttpResponse) : Blob { b.body };
};
