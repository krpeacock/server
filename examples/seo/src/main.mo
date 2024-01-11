import Server "../../../src/lib";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HM "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import DateTime "mo:datetime/DateTime";

shared ({ caller = creator }) actor class () {
  type Request = Server.Request;
  type Response = Server.Response;
  type HttpRequest = Server.HttpRequest;
  type HttpResponse = Server.HttpResponse;
  type ResponseClass = Server.ResponseClass;

  stable var serializedEntries : Server.SerializedEntries = ([], [], [creator]);

  var server = Server.Server({ serializedEntries });


  server.get(
    "/",
    func(req : Request, res : ResponseClass) : async Response {
      let dateStr = DateTime.now().toText();
      let ogTitle = "<meta property=\"og:title\" content=\"Dynamic SEO on ICP\" />";
      let title = "<title>" # dateStr # "</title>";
      let ogDescription = "<meta property=\"og:description\" content=\"The current time is " # dateStr # "\" />";


      res.send({
        status_code = 200;
        headers = [("Content-Type", "text/html")];
        body = Text.encodeUtf8(
          "<html><head>" # title # ogTitle # ogDescription # "</head><body><h1>The current time is " # dateStr # "</h1></body></html>"
        );
        streaming_strategy = null;
        cache_strategy = #noCache;
      });
    },
  );

  // Bind the server to the HTTP interface
  public query func http_request(req : HttpRequest) : async HttpResponse {
    server.http_request(req);
  };
  public func http_request_update(req : HttpRequest) : async HttpResponse {
    await server.http_request_update(req);
  };

  public func invalidate_cache() : async () {
    server.empty_cache();
  };

  system func preupgrade() {
    serializedEntries := server.entries();
  };

  system func postupgrade() {
    ignore server.cache.pruneAll();
  };
};
