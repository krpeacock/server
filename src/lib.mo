import CertifiedCache "mo:certified-cache";
import Http "mo:certified-cache/Http";
import HashMap "mo:StableHashMap/ClassStableHashMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";

module {
  type HttpFunction = (Http.HttpRequest) -> CacheResponse;
  type RequestMap = HashMap.StableHashMap<Text, HttpFunction>;

  public type CacheResponse = {
    status_code : Nat16;
    headers : [(Text, Text)];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
  };

  public class Server(cache : CertifiedCache.CertifiedCache<Text, CacheResponse>) {
    var getRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var postRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var putRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    var deleteRequests = HashMap.StableHashMap<Text, HttpFunction>(0, Text.equal, Text.hash);

    public func registerGetRequest(url : Text, function : HttpFunction) {
      getRequests.put(url, function);
    };

    public func registerPostRequest(url : Text, function : HttpFunction) {
      postRequests.put(url, function);
    };

    public func registerPutRequest(url : Text, function : HttpFunction) {
      putRequests.put(url, function);
    };

    public func registerDeleteRequest(url : Text, function : HttpFunction) {
      deleteRequests.put(url, function);
    };

    public func http_request(request : Http.HttpRequest) : Http.HttpResponse {
      var response = cache.get(request.url);
      switch response {
        case (?cacheResponse) {
          {
            status_code = cacheResponse.status_code;
            headers = Array.append(cacheResponse.headers, [cache.certificationHeader(request.url)]);
            body = cacheResponse.body;
            streaming_strategy = cacheResponse.streaming_strategy;
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

    public func http_request_update(req : Http.HttpRequest) : Http.HttpResponse {
      // Application logic to process the request
      let response = process_request(req);

      // expiry can be null to use the default expiry
      cache.put(req.url, response, null);
      return {
        status_code = response.status_code;
        headers = Array.append(response.headers, [cache.certificationHeader(req.url)]);
        body = response.body;
        streaming_strategy = response.streaming_strategy;
        upgrade = null;
      };
    };

    public func process_request(req : Http.HttpRequest) : CacheResponse {
      Debug.print("Processing request: " # req.url);
      Debug.print("Method: " # req.method);
      switch (req.method) {
        case "GET" {
          switch (getRequests.get(req.url)) {
            case (?getFunction) {
              getFunction(req);
            };
            case null {
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

    public func get(path : Text, handler : (request : Http.HttpRequest, response : Response) -> CacheResponse) {
      registerGetRequest(
        path,
        func(request : Http.HttpRequest) : CacheResponse {
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

    public func post(path : Text, handler : (request : Http.HttpRequest, response : Response) -> CacheResponse) {
      registerPostRequest(
        path,
        func(request : Http.HttpRequest) : CacheResponse {
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

    public func put(path : Text, handler : (request : Http.HttpRequest, response : Response) -> CacheResponse) {
      registerPutRequest(
        path,
        func(request : Http.HttpRequest) : CacheResponse {
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

    public func delete(path : Text, handler : (request : Http.HttpRequest, response : Response) -> CacheResponse) {
      registerDeleteRequest(
        path,
        func(request : Http.HttpRequest) : CacheResponse {
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
};
