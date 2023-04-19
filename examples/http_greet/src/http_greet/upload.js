const ic = require("ic0");
const fs = require("fs");
const path = require("path");
const fetch = require("isomorphic-fetch");

const { replica, HttpAgent } = ic;

const run = async () => {
  // local
  // const agent = new HttpAgent({ host: "http://localhost:8080", fetch });
  // await agent.fetchRootKey();
  // const backend = replica(agent)("renrk-eyaaa-aaaaa-aaada-cai");

  // Production
  const agent = new HttpAgent({ host: "https://icp-api.io", fetch });
  await agent.fetchRootKey();
  const backend = replica(agent)("qg33c-4aaaa-aaaab-qaica-cai");

  // convert all files in ./assets to number[]
  const files = await Promise.all(
    fs.readdirSync(path.join(__dirname, "assets")).map(async (file) => {
      const data = await fs.promises.readFile(
        path.join(__dirname, "assets", file)
      );
      return [file, new Uint8Array(data)];
    })
  );
  console.log(files);

  for (const [name, data] of files) {
    await backend.call("store", `${name}`, data);
    console.log(`Uploaded ${name}`);
  }
};

run();
