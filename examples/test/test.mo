import Server "../../src/lib";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import serdeJson "mo:serde/JSON";
import Text "mo:base/Text";
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
    func(_ : Request, res : ResponseClass) : async Response {
      res.send({
        status_code = 200;
        headers = [("Content-Type", "text/html")];
        body = Text.encodeUtf8(
          "<html><body><h1>hello world</h1></body></html>"
        );
        streaming_strategy = null;
        cache_strategy = #noCache;
      });
    },
  );

  // Cached endpoint
  server.get(
    "/hi",
    func(_ : Request, res : ResponseClass) : async Response {
      res.send({
        headers = [("Content-Type", "text/plain")];
        status_code = 200;
        body = Text.encodeUtf8("hi");
        streaming_strategy = null;
        cache_strategy = #noCache;
      });
    },
  );

  server.get(
    "/json",
    func(_ : Request, res : ResponseClass) : async Response {
      res.json({
        status_code = 200;
        body = "{\"hello\":\"world\"}";
        cache_strategy = #noCache;
      });
    },
  );

  server.get(
    "/404",
    func(_ : Request, res : ResponseClass) : async Response {
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

  func displayCat(cat : Cat) : Text {
    "{\"name\":\"" # cat.name # "\",\"age\":" # Nat.toText(cat.age) # "}";
  };

  server.get(
    "/cats",
    func(_ : Request, res : ResponseClass) : async Response {
      var catJson = "[";
      for (cat in Iter.fromArray(cats)) {
        catJson := catJson # displayCat(cat) # ",";
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
                    body = displayCat(cat);
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
    let #ok(blob) = serdeJson.fromText(data, null) else return null;
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
          let cat = processCat(bodyText);
          switch (cat) {
            case (null) {
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
