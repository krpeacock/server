import CertifiedCache "mo:certified-cache";
import Text "mo:base/Text";
import Server "lib";
import HashMap "mo:StableHashMap/FunctionalStableHashMap";
import Http "mo:certified-cache/Http";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Hash "mo:base/Hash";
import Blob "mo:base/Blob";

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

  stable var files = Trie.empty<Text, Blob>();
  func key(x : Text) : Trie.Key<Text> { { key = x; hash = Text.hash(x) } };

  server.get(
    "/",
    func(req, res) : CacheResponse {
      res.send({
        status_code = 200;
        headers = [("Content-Type", "text/html")];
        body = Text.encodeUtf8(
          "<!DOCTYPE html>" # "<html lang=\"en\">" # "<head>" # "<meta charset=\"UTF-8\">" # "<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\">" # "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">" # "<title>Motoko Server SSR</title>" # "<meta name=\"description\" content=\"This is the first live website from Kyle Peacock's server package, hosted and certified on the IC\">" # "<meta property=\"og:title\" content=\"Motoko Server SSR\">" # "<meta property=\"og:description\" content=\"This is the first live website from Kyle Peacock's server package, hosted and certified on the IC\">" # "<meta property=\"og:type\" content=\"website\">" # "<meta property=\"og:image\" content=\"https://q56hh-gyaaa-aaaab-qaiaq-cai.ic0.app/profile.jpeg\">" # "</head>" # "<body>" # "<h1>Hello, world!</h1>" # "<div><img src=\"/profile.jpeg\"/></div>" # "</body>" # "</html>"
        );
        streaming_strategy = null;
      });
    },
  );

  server.get(
    "/profile.jpeg",
    func(req, res) : CacheResponse {
      let file = Trie.get(files, key("/profile.jpeg"), Text.equal);
      switch file {
        case null {
          return res.send({
            status_code = 404;
            headers = [];
            body = Text.encodeUtf8("File not found");
            streaming_strategy = null;
          });
        };
        case (?blob) {
          return res.send({
            status_code = 200;
            headers = [("Content-Type", "image/jpeg")];
            body = blob;
            streaming_strategy = null;
          });
        };
      };
    },
  );

  server.get(
    "/api/hi",
    func(req, res) : CacheResponse {
      res.json({
        status_code = 200;
        body = "hi";
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

  public func store(path : Text, content : Blob) {
    let (newFiles, existing) = Trie.put(
      files, // Target trie
      key(path), // Key
      Text.equal, // Equality checker
      content,
    );

    files := newFiles;
  };

  public func invalidate_cache() {
    cache := CertifiedCache.fromEntries<Text, Blob>(
      [],
      Text.equal,
      Text.hash,
      Text.encodeUtf8,
      func(b : Blob) : Blob { b },
      two_days_in_nanos + Int.abs(Time.now()),
    );
  };

  system func preupgrade() {
    entries := cache.entries();
  };

  system func postupgrade() {
    let _ = cache.pruneAll();
  };

};
