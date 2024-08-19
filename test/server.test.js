import { expect, test, describe, afterAll } from "vitest";
import fetch from "isomorphic-fetch";
import canisterIds from "../.dfx/local/canister_ids.json";
import mainnetIds from "../canister_ids.json";

const express = require("express");
const app = express();

const helloCanisterId = canisterIds.test.local;
// const helloCanisterId = mainnetIds.test.ic;
console.log(`canisterId: ${helloCanisterId}`);

function createUrl(path) {
  const url = new URL(path, `http://127.0.0.1:4943`);
  url.searchParams.set(`canisterId`, helloCanisterId);
  // const url = new URL(path, `https://${helloCanisterId}.icp0.io`);
  return url;
}

const cats = [
  { name: "Sardine", age: 7 },
  { name: "Olive", age: 4 },
];

app.get(`/hi`, (req, res) => {
  res.send(`hi`);
});

app.get(`/json`, (req, res) => {
  res.json({ hello: `world` });
});

app.get(`/404`, (req, res) => {
  res.status(404).send(`Not found`);
});

app.get(`/`, (req, res) => {
  res.send(`<html><body><h1>hello world</h1></body></html>`);
});

app.get(`/queryParams`, (req, res) => {
  res.json(req.query);
});

app.get(`/cats`, (req, res) => {
  res.json(cats);
});

// app.get(`/cats/:name`, (req, res) => {
//   const cat = cats.find((cat) => cat.name === req.params.name);
//   if (!cat) {
//     res.status(404).send(`Not found`);
//     return;
//   }
//   res.json(cat);
// });

const server = app.listen(4999);

const awaitJson = async (url, options) => {
  const response = await fetch(url, options);
  const json = await response.text();
  return json;
};

const awaitText = async (url, options) => {
  const response = await fetch(url, options);
  const text = await response.text();
  return text;
};

test(`should handle a basic greeting`, async () => {
  const text = await awaitText(createUrl(`/hi`));

  expect(text).toBe(`hi`);
});

test(`should serve html`, async () => {
  const text = await awaitText(createUrl(`/`));
  expect(text).toMatchSnapshot();
});

describe(`headers`, () => {
  test(`plaintext`, async () => {
    const response = await fetch(createUrl(`/hi`));
    expect(response.headers.get(`content-type`)).toBe(`text/plain`);
  });

  test(`json`, async () => {
    const response = await fetch(createUrl(`/json`));
    expect(response.headers.get(`content-type`)).toBe(`application/json`);
  });

  test(`html`, async () => {
    const response = await fetch(createUrl(`/`));
    expect(response.headers.get(`content-type`)).toBe(`text/html`);
  });

  test(`404`, async () => {
    const response = await fetch(createUrl(`/404`));
    expect(response.headers.get(`content-type`)).toBe(`text/plain`);

    const text = await response.text();
    expect(text).toBe(`Not found`);

    expect(response.status).toBe(404);
  });
});

describe(`compare with express`, () => {
  test(`should handle a basic greeting`, async () => {
    const text = await awaitText(`http://127.0.0.1:4999/hi`);
    const canisterText = await awaitText(createUrl(`/hi`));
    expect(text).toBe(canisterText);
  });

  test(`should serve json`, async () => {
    const json = await awaitJson(`http://127.0.0.1:4999/json`);
    const canisterJson = await awaitJson(createUrl(`/json`));
    expect(json).toEqual(canisterJson);
  });

  test(`should serve html`, async () => {
    const text = await awaitText(`http://127.0.0.1:4999/`);
    const canisterText = await awaitText(createUrl(`/`));
    expect(text).toBe(canisterText);
  });

  test(`should serve 404`, async () => {
    const response = await fetch(`http://127.0.0.1:4999/404`);
    const canisterResponse = await fetch(createUrl(`/404`));

    expect(response.status).toBe(canisterResponse.status);
    expect(response.statusText).toBe(canisterResponse.statusText);
    expect(await response.text()).toBe(await canisterResponse.text());
  });

  test(`should handle query params`, async () => {
    const json = await awaitJson(`http://127.0.0.1:4999/queryParams?foo=bar`);
    const canisterJson = await awaitJson(createUrl(`/queryParams?foo=bar`));
    expect(json).toEqual(canisterJson);

    const json2 = await awaitJson(
      `http://127.0.0.1:4999/queryParams?foo=bar&baz=qux`
    );
    const canisterJson2 = await awaitJson(
      `https://${helloCanisterId}.icp0.io/queryParams?foo=bar&baz=qux`
    );
    expect(json2).toEqual(canisterJson2);
  }, 10_000);

  test(`should handle multiple cats`, async () => {
    const json = await awaitJson(`http://127.0.0.1:4999/cats`);
    const canisterJson = await awaitJson(createUrl(`/cats`));
    expect(json).toEqual(canisterJson);
  });

  test.only(`should handle a single cat`, async () => {
    const json = await awaitJson(`http://127.0.0.1:4999/cats/Sardine`);
    const canisterJson = await awaitJson(createUrl(`/cats/Sardine`));
    expect(json).toEqual(canisterJson);
  });
});

afterAll(() => {
  server.close();
});
