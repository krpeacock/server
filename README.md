# Server

This is a simple HTTP server for Motoko. Its interface is designed to be similar to the popular Express.js library for Node.js.

Check out the [examples](./examples) directory for examples of how to use this library.

Live http_greet example: [https://qg33c-4aaaa-aaaab-qaica-cai.ic0.app/]([https://qg33c-4aaaa-aaaab-qaica-cai.ic0.app/])

# Installation

To install this library, run the following command:

```bash
mops add certified-cache
mops add server
```

For more information on how to install and use `mops`, see the [Mops documentation](https://mops.one).

# Usage

## Setting up

Recommendation: use the `http_greet` example as a starting point to have asset support. It includes a lot of boilerplate for the methods, but it will turn your canister into a full asset canister, compatible with the `icx-asset` util used by `dfx` as well as the `@dfinity/assets` npm package.

> Note: chunked assets (> 2mb) are not supported yet. Coming soon.

---

In order to have a cache that persists across upgrades, you will need to first initialize a stable store for the entries and pass that to the server.

You can then bind `http_request` and `http_request_update` to the server's `http_request` and `http_request_update` functions.

Finally, you should add the `preupgrade` and `postupgrade` system functions to your actor. These will be called when the actor is upgraded, and will be used to save the cache and prune it.

Here is a basic example of how to set up a server with a cache:

```lua
import Server "mo:server";

actor {
    stable var serializedEntries : Server.SerializedEntries = ([], [], [creator]);

    var server = Server.Server({ serializedEntries });


    /*
     * http request hooks
     */
    public query func http_request(req : Server.HttpRequest) : async Server.HttpResponse {
        server.http_request(req);
    };
    public func http_request_update(req : HttpRequest) : async HttpResponse {
        await server.http_request_update(req);
    };


    /*
     * upgrade hooks
     */
    system func preupgrade() {
        serializedEntries := server.entries();
    };

    system func postupgrade() {
        ignore server.cache.pruneAll();
    };
}
```

## Adding routes

As with the Express.js library, you can add routes to the server using the `get`, `post`, `put`, and `delete` functions.

Each of these functions takes a path and a callback function. The callback function is called when a request is made to the server with a matching path.

The callback function takes a `Request` object and a `Response` object. The `Request` object contains information about the request, such as the request body, query parameters, and headers. The `Response` object is used to send a response to the client.

Here is an example of how to add a route to the server:

```lua
type Request = Server.Request;
type Response = Server.Response;
type ResponseClass = Server.ResponseClass;
server.get("/", func (req : Request, res : ResponseClass) : async Response {
    res.send({
        status_code = 200;
        headers = [("Content-Type", "text/plain")];
        body = Text.encodeUtf8("Hello, world!");
        streaming_strategy = null;
        cache_strategy = #default;
    });
});
```

You can also use `res.json` to send a JSON response:

```lua
server.get("/api", func (req : Request, res : ResponseClass) : async Response {
    res.json({
        status_code = 200;
        body = "{ \"hello\": \"world\" }";
        cache_strategy = #default;
    });
});
```

## Request and response objects

The `Request` object contains information about the request, such as the request body, query parameters, and headers.

ResponseClass is a class that will register the functions you provide with the server, so that they can be called when there is a cache miss to the provided route.

The `Response` object is used to send a response to the client.

### Request

The `Request (ParsedHttpRequest)` object contains the following fields:

- `method (Text)` - The HTTP method of the request
- `url (URL)` - The parsed URL of the request
- `headers ([(Text, Text)])` - The headers
- `body (?Body) ` - The request body, if any

See ./docs/RequestTypes.mo for more details.

### Response

The `Response` object contains the following functions:

- `send (HttpResponse) : async ()` - Send a response to the client
- `json (HttpResponse) : async ()` - Send a JSON response to the client

More functions will be added in the future.

## How it works

The server uses a cache to store responses to requests. When a request is made to the server, the server first checks the cache to see if it has a response for that request. If it does, it returns the cached response. If it does not, it calls the callback function for the route and returns the response from the callback function.

Since the cache also handles certification of the responses, any cached responses can be served as http queries over the Internet Computer. This means that the server can be used to serve static files, such as HTML, CSS, and JavaScript.

For requests that are not cached, the server will upgrade the request to an update, and then call the callback function for the route. The callback function can then make any changes to the state of the actor, and then send a response to the client.

`POST`, `PUT`, and `DELETE` requests are not cached, since they are not idempotent. They will override the `cache_strategy` option to `#noCache` in the response. If you have a use case for caching these requests, please open an issue.

## Examples

See the `examples` directory for examples of how to use this library. These examples are also available on the Internet Computer as canisters:

- Http Greet: [https://qg33c-4aaaa-aaaab-qaica-cai.ic0.app/]([https://qg33c-4aaaa-aaaab-qaica-cai.ic0.app/])

## Roadmap

- [ ] `PATCH` requests
- [ ] `path/:id` routes
- [ ] `path/:id/:id2` routes
- [ ] `*` selector
- [ ] `/*` selectors
- [ ] `path/*` selectors
- [ ] `*.ext` selectors
- [x] Asset Canister (`icx-asset` support)
- [ ] `res.redirect`
- [ ] `res.sendFile`
- [ ] `res.download`
- [ ] `res.render`
- [ ] `res.sendStatus`
- [ ] Certification v2 support (fast dynamic queries)

## Reference

Below are all of the types and functions that are exported by this library, as well as links to where these types are defined.

### Types

- `type HttpRequest = Server.HttpRequest` - [./src/Server.mo](https://github.com/krpeacock/certified-cache/blob/c1f209d14f490f905b7de2a2bd3f917377310675/src/Http.mo#L36)
- `type HttpResponse = Server.HttpResponse` - [./src/Server.mo](https://github.com/krpeacock/certified-cache/blob/c1f209d14f490f905b7de2a2bd3f917377310675/src/Http.mo#L28)
- `type Request = Server.Request` - [./src/Server.mo](https://github.com/NatLabs/http-parser.mo/blob/27cba8ed0d39387e0fb660f65909ffe2a7d54413/src/Types.mo#L92)
- `type Response = Server.Response` - 
  ```
  {
    status_code : Nat16;
    headers : [Http.HeaderField];
    body : Blob;
    streaming_strategy : ?Http.StreamingStrategy;
    cache_strategy : CacheStrategy;
  };
  ```
- `type SerializedEntries = Server.SerializedEntries`
```
(
    [(HttpRequest, (HttpResponse, Nat))],
    [(AssetTypes.Key, Assets.StableAsset)], 
    [Principal]
)
```

### Classes

- Server - the primary export of this library
- ResponseClass - a class provided during `get`, `post`, `put`, and `delete`, with the following methods: 
    - `send (Response) : async ()`
    - `json (Response) : async ()`

### Functions

These functions are used internally by the library, but are also exported for use by other libraries.

- `compareRequests(req1 : HttpRequest, req2 : HttpRequest) : Bool`
    - Compares two requests to see if they are equal
- `hashRequest(req : HttpRequest) : Hash.Hash`
    - Hashes a request
- `public func encodeRequest(req : HttpRequest) : Blob`
    - Encodes a request as a blob
- `public func yieldResponse(b : HttpResponse) : Blob`
    - Encodes a response as a blob
