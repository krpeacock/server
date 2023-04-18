import Server "../../src/lib";
import Blob "mo:base/Blob";
import CertifiedCache "mo:certified-cache";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HM "mo:base/HashMap";
import HashMap "mo:StableHashMap/FunctionalStableHashMap";
import Http "mo:certified-cache/Http";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import serdeJson "mo:serde/JSON";
import Option "mo:base-0.7.3/Option";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";

actor {
  type Response = Server.Response;
  type HttpRequest = Http.HttpRequest;
  type HttpResponse = Http.HttpResponse;

  stable var cacheStorage : [(HttpRequest, (HttpResponse, Nat))] = [];

  var server = Server.Server(cacheStorage);

  stable var files = Trie.empty<Text, Blob>();
  func key(x : Text) : Trie.Key<Text> { { key = x; hash = Text.hash(x) } };

  let template = (
    "<!DOCTYPE html>" #
    "<html lang=\"en\">" #
    "<head>" #
    "<meta charset=\"UTF-8\">" #
    "<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\">" #
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">" #
    "<title>Motoko Server SSR</title>" #
    "<meta name=\"description\" content=\"This is the first live website from Kyle Peacock's server package, hosted and certified on the IC\">" #
    "<meta property=\"og:title\" content=\"Motoko Server SSR\">" #
    "<meta property=\"og:description\" content=\"This is the first live website from Kyle Peacock's server package, hosted and certified on the IC\">" #
    "<meta property=\"og:type\" content=\"website\">" #
    "<meta property=\"og:image\" content=\"https://q56hh-gyaaa-aaaab-qaiaq-cai.ic0.app/profile.jpeg\">" #
    "</head>" #
    "<body>" #
    "<h1>Hello, world!</h1>" #
    "<div><img src=\"/profile.jpeg\"/></div>" #
    "</body>" #
    "</html>"
  );

  server.get(
    "/",
    func(req, res) : Response {
      res.send({
        status_code = 200;
        headers = [("Content-Type", "text/html")];
        body = Text.encodeUtf8(
          template
        );
        streaming_strategy = null;
        cache_strategy = #default;
      });
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

  // Cached endpoint
  server.get(
    "/hi",
    func(req, res) : Response {
      Debug.print("hi");
      res.json({
        status_code = 200;
        body = "hi";
        cache_strategy = #default;
      });
    },
  );

  // Dynamic endpoint
  server.get(
    "/queryParam",
    func(req, res) : Response {
      let obj = req.url.queryObj;
      let keys = Iter.fromArray(obj.keys);

      var body = "{";

      // insert timestamp
      body := body # "\"timestamp\": \"" # Int.toText(Time.now()) # "\", ";

      for (key in keys) {
        let value = obj.get(key);
        switch value {
          case null {};
          case (?value) {
            body := body # "\"" # key # "\": \"" # value # "\", ";
          };
        };
      };
      // trim the last comma
      body := Text.trimEnd(body, #text ", ");

      body := body # "}";

      res.json({
        status_code = 200;
        body = body;
        cache_strategy = #noCache;
      });
    },
  );
  type Cat = {
    name : Text;
    age : Nat;
  };
  var cats = HM.HashMap<Text, Cat>(0, Text.equal, Text.hash);

  server.get(
    "/cats",
    func(req, res) : Response {
      let catEntries = cats.entries();

      var catJson = "{ ";
      for (entry in catEntries) {
        let (id, cat) = entry;
        catJson := catJson # "\"" # id # "\": { \"name\": \"" # cat.name # "\", \"age\": " # Nat.toText(cat.age) # " }, ";
      };
      catJson := Text.trimEnd(catJson, #text ", ");
      catJson := catJson # " }";

      res.json({
        status_code = 200;
        body = catJson;
        cache_strategy = #noCache;
      });
    },
  );

  /*
  * from shape:
  {
    #Array : [JSON__207];
    #Boolean : Bool;
    #Null;
    #Number : Int;
    #Object : [(Text, JSON__207)];
    #String : Text
  };
  */
  func processCat(data : Text) : ?Cat {
    let blob = serdeJson.fromText(data);
    from_candid(blob);
  };

  public func getCats() : async [Cat] {
    let catEntries = cats.entries();
    var catList = Buffer.fromArray<Cat>([]);
    for (entry in catEntries) {
      let (id, cat) = entry;
      catList.add(cat);
    };
    Buffer.toArray(catList);
  };

  server.post(
    "/cats",
    func(req, res) : Response {
      let body = req.body;
      switch body {
        case null {
          res.send({
            status_code = 400;
            headers = [];
            body = Text.encodeUtf8("Invalid JSON");
            streaming_strategy = null;
            cache_strategy = #noCache;
          });
        };
        case (?body) {

          let bodyText = body.text();
          Debug.print(bodyText);
          let cat = processCat(bodyText);
          switch (cat) {
            case null {
              Debug.print("cat not parsed");
              res.send({
                status_code = 400;
                headers = [];
                body = Text.encodeUtf8("Invalid JSON");
                streaming_strategy = null;
                cache_strategy = #noCache;
              });
            };
            case (?cat) {
              cats.put(cat.name, cat);
              res.json({
                status_code = 200;
                body = "ok";
                cache_strategy = #noCache;
              });
            };
          };
        };
      };
    },
  );

  // Bind the server to the HTTP interface
  public query func http_request(req : Http.HttpRequest) : async Http.HttpResponse {
    server.http_request(req);
  };
  public func http_request_update(req : Http.HttpRequest) : async Http.HttpResponse {
    server.http_request_update(req);
  };

  public func invalidate_cache(): async () {
    server.empty_cache();
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

  system func preupgrade() {
    cacheStorage := server.cache.entries();
  };

  system func postupgrade() {
    let _ = server.cache.pruneAll();
  };

};
