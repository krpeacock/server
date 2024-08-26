# Server changelog

## unreleased

- switches from `async` and `await` tags to `async*` and `await*` tags for handlers.
  - This unfortunately is a breaking change for syntax, but these tags will allow handlers to respond without a self-call during cached request handling, and will improve performance for certification v2.

## 1.0.0

- Adds support for route parameters
  - `GET /hello/:name` will match `GET /hello/world` and `GET /hello/you`
- Normalizes paths
    - `GET /hello` and `GET /hello/` are now treated as the same route
    - paths are all processed as lowercase
- bumps dependencies
- chore: removes logs

## 0.3.1

- updates the response signature to enable inter-canister calls
- new example showing non-cached opengraph data
- bump deps

## 0.2.2

- fixing bug with missing path type

## 0.2.1

- docs updates and fix for `demo` example

## 0.2.0

- Includes asset canister support! A working example of this lives at https://github.com/krpeacock/server/blob/main/examples/http_greet/src/http_greet/main.mo

## 0.1.1

- Set up `mo-test`
- Adding unit tests
- updating examples and docs with Http types exported from server

