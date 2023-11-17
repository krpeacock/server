pushd examples/http_greet
dfx start --background --clean
dfx deploy http_greet

node ./src/http_greet/upload.js
