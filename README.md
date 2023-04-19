# Server

This is a simple HTTP server for Motoko. Its interface is designed to be similar to the popular Express.js library for Node.js.

# Installation

To install this library, run the following command:

```bash
mops add certified-cache
mops add server
```

For more information on how to install and use `mops`, see the [Mops documentation](https://mops.one).

# Usage

## Setting up

In order to have a cache that persists across upgrades, you will need to first initialize a stable store for the entries and pass that to the server.

You can then bind `http_request` and `http_request_update` to the server's `http_request` and `http_request_update` functions.

Finally, you should add the `preupgrade` and `postupgrade` system functions to your actor. These will be called when the actor is upgraded, and will be used to save the cache and prune it.

Here is an example of how to set up a server with a cache:

```lua
import Server "mo:server";

actor {
    type Request = Server.Request;
    type Response = Server.Response;
    type HttpRequest = Server.HttpRequest;
    type HttpResponse = Server.HttpResponse;
    type ResponseClass = Server.ResponseClass;

    stable var cacheStorage : [(HttpRequest, (HttpResponse, Nat))] = [];

    var server = Server.Server(cacheStorage);


    /*
     * http request hooks
     */
    public query func http_request(req : HttpRequest) : async HttpResponse {
        server.http_request(req);
    };
    public func http_request_update(req : HttpRequest) : async HttpResponse {
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
}
```

## Adding routes

As with the Express.js library, you can add routes to the server using the `get`, `post`, `put`, and `delete` functions.

Each of these functions takes a path and a callback function. The callback function is called when a request is made to the server with a matching path.

The callback function takes a `Request` object and a `Response` object. The `Request` object contains information about the request, such as the request body, query parameters, and headers. The `Response` object is used to send a response to the client.

Here is an example of how to add a route to the server:

```lua
server.get("/", func (req, res) {
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
server.get("/api", func (req, res) {
    res.json({
        status_code = 200;
        body = "{ \"hello\": \"world\" }";
        cache_strategy = #default;
    });
});
```

## Request and response objects

The `Request` object contains information about the request, such as the request body, query parameters, and headers.

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

- Demo: https://q56hh-gyaaa-aaaab-qaiaq-cai.ic0.app/

## Roadmap

- [ ] `PATCH` requests
- [ ] `path/:id` routes
- [ ] `path/:id/:id2` routes
- [ ] `*` selector
- [ ] `/*` selectors
- [ ] `path/*` selectors
- [ ] `*.ext` selectors
- [ ] Asset Canister (`icx-asset` support)
- [ ] `res.redirect`
- [ ] `res.sendFile`
- [ ] `res.download`
- [ ] `res.render`
- [ ] `res.sendStatus`
- [ ] Certification v2 support (fast dynamic queries)

## Credits

This project currently copies the `http-parser` library into its source tree. This is because the `http-parser` library is not currently installable as a package on `mops`. Source code is available at https://github.com/NatLabs/http-parser.mo
