# http_hello

This is a simple hello world example that demonstrates how to use the server to replace the default actor model for interacting with your canister.

It sets up a single canister that can serve all of the static assets your frontend needs while also providing a simple API for interacting with the canister.

You can see a live version of this canister at [https://qg33c-4aaaa-aaaab-qaica-cai.ic0.app/](https://qg33c-4aaaa-aaaab-qaica-cai.ic0.app/).

```bash
cd http_hello/
dfx help
dfx canister --help
```

## Running the project locally

If you want to test your project locally, you can use the following commands:

```bash
# Starts the replica, running in the background
dfx start --background

# Deploys your canisters to the replica and generates your candid interface
dfx deploy
```

You can upload the assets to your canister with

```bash
node src/http_greet/upload.js
```

or by building the `icx-asset` tool from the [sdk repo](https://github.com/dfinity/sdk) and running

```bash
icx-asset --pem <path to pem> --replica <replica> sync <CANISTER_ID> <DIRECTORY>
```

> There is a test PEM file provided for testing purposes. It is not secure and should not be used in production.

Once the job completes, your application will be available at `http://localhost:4943?canisterId={asset_canister_id}`.

Additionally, if you are making frontend changes, you can start a development server with

```bash
npm start
```

Which will start a server at `http://localhost:8080`, proxying API requests to the replica at port 4943.

### Note on frontend environment variables

If you are hosting frontend code somewhere without using DFX, you may need to make one of the following adjustments to ensure your project does not fetch the root key in production:

- set`NODE_ENV` to `production` if you are using Webpack
- use your own preferred method to replace `process.env.NODE_ENV` in the autogenerated declarations
- Write your own `createActor` constructor
