import Server "mo:server";
import Http "mo:certified-cache/Http";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

actor {
  type Request = Server.Request;
  type Response = Server.Response;
  type ResponseClass = Server.ResponseClass;

  stable var cacheStorage : [(Http.HttpRequest, (Http.HttpResponse, Nat))] = [];

  var server = Server.Server(cacheStorage);

  stable var files = Trie.empty<Text, Blob>();
  func key(x : Text) : Trie.Key<Text> { { key = x; hash = Text.hash(x) } };

  server.post(
    "/greet",
    func(req : Request, res : ResponseClass) : Response {
      let parsedName = req.url.queryObj.get("name");
      var name = "";
      switch parsedName {
        case null { name := "World" };
        case (?n) {
          name := n;
        };
      };
      let greeting = "Hello " # name # "!";
      res.send({
        status_code = 200;
        headers = [("Content-Type", "text/plain")];
        body = Text.encodeUtf8(greeting);
        streaming_strategy = null;
        cache_strategy = #default;
      });
    },
  );

  server.get(
    "/",
    func(req, res) : Response {
      let file = Trie.get(files, key("index.html"), Text.equal);
      switch file {
        case null {
          return res.send({
            status_code = 404;
            headers = [];
            body = Text.encodeUtf8("File not found");
            streaming_strategy = null;
            cache_strategy = #noCache;
          });
        };
        case (?blob) {
          return res.send({
            status_code = 200;
            headers = [("Content-Type", "text/html")];
            body = blob;
            streaming_strategy = null;
            cache_strategy = #default;
          });
        };
      };
    },
  );

  server.get(
    "/index.js",
    func(req, res) : Response {
      let file = Trie.get(files, key("index.js"), Text.equal);
      switch file {
        case null {
          return res.send({
            status_code = 404;
            headers = [];
            body = Text.encodeUtf8("File not found");
            streaming_strategy = null;
            cache_strategy = #noCache;
          });
        };
        case (?blob) {
          return res.send({
            status_code = 200;
            headers = [("Content-Type", "text/javascript")];
            body = blob;
            streaming_strategy = null;
            cache_strategy = #default;
          });
        };
      };
    },
  );

  server.get(
    "/favicon.ico",
    func(req, res) : Response {
      let file = Trie.get(files, key("favicon.ico"), Text.equal);
      switch file {
        case null {
          return res.send({
            status_code = 404;
            headers = [];
            body = Text.encodeUtf8("File not found");
            streaming_strategy = null;
            cache_strategy = #noCache;
          });
        };
        case (?blob) {
          return res.send({
            status_code = 200;
            headers = [("Content-Type", "image/x-icon")];
            body = blob;
            streaming_strategy = null;
            cache_strategy = #default;
          });
        };
      };
    },
  );

  server.get(
    "/main.css",
    func(req, res) : Response {
      let file = Trie.get(files, key("main.css"), Text.equal);
      switch file {
        case null {
          return res.send({
            status_code = 404;
            headers = [];
            body = Text.encodeUtf8("File not found");
            streaming_strategy = null;
            cache_strategy = #noCache;
          });
        };
        case (?blob) {
          return res.send({
            status_code = 200;
            headers = [("Content-Type", "text/css")];
            body = blob;
            streaming_strategy = null;
            cache_strategy = #default;
          });
        };
      };
    },
  );

  server.get(
    "/logo2.svg",
    func(req, res) : Response {
      let file = Trie.get(files, key("logo2.svg"), Text.equal);
      switch file {
        case null {
          return res.send({
            status_code = 404;
            headers = [];
            body = Text.encodeUtf8("File not found");
            streaming_strategy = null;
            cache_strategy = #noCache;
          });
        };
        case (?blob) {
          return res.send({
            status_code = 200;
            headers = [("Content-Type", "image/svg+xml")];
            body = blob;
            streaming_strategy = null;
            cache_strategy = #default;
          });
        };
      };
    },
  );

  server.get(
    "/profile.jpeg",
    func(req, res) : Response {
      let file = Trie.get(files, key("profile.jpeg"), Text.equal);
      switch file {
        case null {
          return res.send({
            status_code = 404;
            headers = [];
            body = Text.encodeUtf8("File not found");
            streaming_strategy = null;
            cache_strategy = #noCache;
          });
        };
        case (?blob) {
          return res.send({
            status_code = 200;
            headers = [("Content-Type", "image/jpeg")];
            body = blob;
            streaming_strategy = null;
            cache_strategy = #default;
          });
        };
      };
    },
  );

  public func store(path : Text, content : Blob) {
    let (newFiles, existing) = Trie.put(
      files, // Target trie
      key(path), // Key
      Text.equal, // Equality checker
      content,
    );

    if (existing != null) {
      server.empty_cache();
    };

    files := newFiles;
  };

  /*
     * http request hooks
     */
  public query func http_request(req : Http.HttpRequest) : async Http.HttpResponse {
    server.http_request(req);
  };
  public func http_request_update(req : Http.HttpRequest) : async Http.HttpResponse {
    server.http_request_update(req);
  };

  /*
     * upgrade hooks
     */
  system func preupgrade() {
    cacheStorage := server.cache.entries();
  };

  system func postupgrade() {
    let _ = server.cache.pruneAll();
  };
};
