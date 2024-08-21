import Server "../../src/lib";
import Blob "mo:base/Blob";
import CertifiedCache "mo:certified-cache";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HM "mo:base/HashMap";
import HashMap "mo:StableHashMap/FunctionalStableHashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import serdeJson "mo:serde/JSON";
import Option "mo:base-0.7.3/Option";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

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
      res.send({
        status_code = 200;
        headers = [("Content-Type", "text/html")];
        body = Text.encodeUtf8(
          "<html><body><h1>hello world</h1></body></html>"
        );
        streaming_strategy = null;
        cache_strategy = #default;
      });
    },
  );

  // Cached endpoint
  server.get(
    "/hi",
    func(req : Request, res : ResponseClass) : async Response {
      Debug.print("hi");
      res.send({
        headers = [("Content-Type", "text/plain")];
        status_code = 200;
        body = Text.encodeUtf8("hi");
        streaming_strategy = null;
        cache_strategy = #default;
      });
    },
  );

  server.get(
    "/json",
    func(req : Request, res : ResponseClass) : async Response {
      res.json({
        status_code = 200;
        body = "{\"hello\":\"world\"}";
        cache_strategy = #noCache;
      });
    },
  );

  server.get(
    "/404",
    func(req : Request, res : ResponseClass) : async Response {
      res.send({
        status_code = 404;
        headers = [("Content-Type", "text/plain")];
        body = Text.encodeUtf8("Not found");
        streaming_strategy = null;
        cache_strategy = #noCache;
      });
    },
  );

  // server.get("/redirect",
  //   func(req, res) : Response {
  //     res.redirect("/hi");
  //   },
  // );

  // Dynamic endpoint
  server.get(
    "/queryParams",
    func(req : Request, res : ResponseClass) : async Response {
      let obj = req.url.queryObj;
      Debug.print(
        debug_show {
          keys = obj.keys;
          original = obj.original;
        }
      );
      let keys = Iter.fromArray(obj.keys);

      var body = "{";

      for (key in keys) {
        let value = obj.get(key);
        switch value {
          case null {};
          case (?value) {
            body := body # "\"" # key # "\":\"" # value # "\",";
          };
        };
      };
      // trim the last comma
      body := Text.trimEnd(body, #text ",");

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
  var cats = [
    {
      name = "Sardine";
      age = 7;
    },
    {
      name = "Olive";
      age = 4;
    },
  ];

  server.get(
    "/cats",
    func(req : Request, res : ResponseClass) : async Response {
      Debug.print("cats endpoint");
      var catJson = "[";
      for (cat in Iter.fromArray(cats)) {
        catJson := catJson # "{\"name\":\"" # cat.name # "\",\"age\":" # Nat.toText(cat.age) # "},";
      };
      catJson := Text.trimEnd(catJson, #text ",");
      catJson := catJson # "]";

      res.json({
        status_code = 200;
        body = catJson;
        cache_strategy = #noCache;
      });
    },
  );

  server.get(
    "/cats/:name",
    func(req : Request, res : ResponseClass) : async Response {
      Debug.print("cats/:name endpoint");
      switch (req.params) {
        case null {
          res.send({
            status_code = 400;
            headers = [];
            body = Text.encodeUtf8("Invalid path");
            streaming_strategy = null;
            cache_strategy = #noCache;
          });
        };
        case (?params) {
          let name = params.get("name");
          Debug.print("found cat with name: " # debug_show name);
          switch name {
            case null {
              res.send({
                status_code = 400;
                headers = [];
                body = Text.encodeUtf8("Invalid path");
                streaming_strategy = null;
                cache_strategy = #noCache;
              });
            };
            case (?n) {
              let cat = Array.find(
                cats,
                func(cat : Cat) : Bool {
                  Text.toLowercase(cat.name) == Text.toLowercase(n);
                },
              );

              Debug.print("found cat: " # debug_show cat);
              switch cat {
                case null {
                  res.send({
                    status_code = 404;
                    headers = [];
                    body = Text.encodeUtf8("Cat not found");
                    streaming_strategy = null;
                    cache_strategy = #noCache;
                  });
                };
                case (?cat) {
                  res.json({
                    status_code = 200;
                    body = "{\"name\":\"" # cat.name # "\",\"age\":" # Nat.toText(cat.age) # "}";
                    cache_strategy = #noCache;
                  });
                };
              };
            };
          };
        };
      };
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
    let #ok(blob) = serdeJson.fromText(data, null);
    let cat : ?Cat = from_candid (blob);
  };

  public func getCats() : async [Cat] {
    cats;
  };

  server.post(
    "/cats",
    func(req : Request, res : ResponseClass) : async Response {
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
              let buf : Buffer.Buffer<Cat> = Buffer.fromArray(cats);
              buf.add(cat);
              cats := Buffer.toArray(buf);
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
