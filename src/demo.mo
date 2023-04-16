import CertifiedCache "mo:certified-cache";
import Text "mo:base/Text";
import Server "lib";
import Http "mo:certified-cache/Http";
import Int "mo:base/Int";
import Time "mo:base/Time";

actor {
  type CacheResponse = Server.CacheResponse;

  stable var entries : [(Text, (Blob, Nat))] = [];
  let two_days_in_nanos = 2 * 24 * 60 * 60 * 1000 * 1000 * 1000;
  var cache = CertifiedCache.fromEntries<Text, Blob>(
    entries,
    Text.equal,
    Text.hash,
    Text.encodeUtf8,
    func(b : Blob) : Blob { b },
    two_days_in_nanos + Int.abs(Time.now()),
  );

  var server = Server.Server(cache);

  server.get(
    "/",
    func(req, res) : CacheResponse {
      res.send({
        status_code = 200;
        headers = [("Content-Type", "text/html")];
        body = Text.encodeUtf8(
          "<!DOCTYPE html>" # "<html lang=\"en\">" # "<head>" # "<meta charset=\"UTF-8\">" # "<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\">" # "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">" # "<title>Motoko Server SSR</title>" # "<meta name=\"description\" content=\"This is the first live website from Kyle Peacock's server package, hosted and certified on the IC\">" # "</head>" # "<body>" # "<h1>Hello, world!</h1>" # "</body>" # "</html>"
        );
        streaming_strategy = null;
      });
    },
  );

  // Bind the server to the HTTP interface
  public query func http_request(req : Http.HttpRequest) : async Http.HttpResponse {
    server.http_request(req);
  };
  public func http_request_update(req : Http.HttpRequest) : async Http.HttpResponse {
    server.http_request_update(req);
  };

  system func preupgrade() {
    entries := cache.entries();
  };

  system func postupgrade() {
    let _ = cache.pruneAll();
  };

};
