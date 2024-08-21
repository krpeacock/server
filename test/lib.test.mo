import Utils "../src/Utils";
import Test "mo:test";
import HttpParser "mo:http-parser";
import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
let test = Test.test;
let suite = Test.suite;
let expect = Test.expect;


suite(
	"my test suite",
	func() {
		test(
			"simple test",
			func() {
				assert true;
			},
		);

		test(
			"parsePathParams",
			func() {
				let pattern = "/foo/:bar";
				let path = "/foo/bar";
				let #ok(map) = Utils.parsePathParams(pattern, path);
				assert map.size() == 1;
				assert map.get("bar") == ?"bar";
			},
		);

		test(
			"parsePathParams with multiple params",
			func() {
				let pattern = "/foo/:bar/:baz";
				let path = "/foo/bar/baz";
				let #ok(map) = Utils.parsePathParams(pattern, path);
				assert map.size() == 2;
				assert map.get("bar") == ?"bar";
				assert map.get("baz") == ?"baz";
			},
		);

		test(
			"parsePathParams with missing param",
			func() {
				let pattern = "/foo/:bar";
				let path = "/foo";
				let result = Utils.parsePathParams(pattern, path);

				expect.result<Utils.PathParams, Text>(result, Utils.showPathParamsResult, Utils.pathParamsResultEqual).equal(#err("Pattern and path have different number of parts."));
			},
		);

		test(
			"parsePathParams with bad param name",
			func() {
				let pattern = "/foo/:";
				let path = "/foo/bar";
				let result = Utils.parsePathParams(pattern, path);

				expect.result<Utils.PathParams, Text>(result, Utils.showPathParamsResult, Utils.pathParamsResultEqual).equal(#err("bad parameter name: " # ":"));
			},
		);

		test(
			"Several parameters with the same name",
			func() {
				let pattern = "/foo/:bar/:bar";
				let path = "/foo/bar/baz";
				let result = Utils.parsePathParams(pattern, path);

				expect.result<Utils.PathParams, Text>(result, Utils.showPathParamsResult, Utils.pathParamsResultEqual).equal(#err("duplicate parameter name: " # "bar"));
			},
		);

		test("Path that doesn't match the pattern", func() {
			let pattern = "/foo/:bar";
			let path = "/cat/bar";
			let result = Utils.parsePathParams(pattern, path);

			expect.result<Utils.PathParams, Text>(result, Utils.showPathParamsResult, Utils.pathParamsResultEqual).equal(#err("Path does not match the pattern. Expected: foo, got: cat"));
		});

		test("pattern match with query params", func() {
			let pattern = "/foo/:bar";
			let path = "/foo/bar?baz=qux";
			let result = Utils.parsePathParams(pattern, path);

			let expected = TrieMap.TrieMap<Text, Text>(Text.equal, Text.hash);
			expected.put("bar", "bar");

			expect.result<Utils.PathParams, Text>(result, Utils.showPathParamsResult, Utils.pathParamsResultEqual).equal(#ok(expected));
		});


		test("simplify route", func() {
			let headers = HttpParser.Headers([]);
			let route = "/foo//bar/";
			let url = HttpParser.URL(route, headers);
			let (simplified, _) = Utils.simplifyRoute(url);

			expect.text(simplified).equal("/foo/bar");

			let route1 = "/foo/bar";
			let url1 = HttpParser.URL(route1, headers);
			let (simplified1, _) = Utils.simplifyRoute(url1);

			expect.text(simplified1).equal("/foo/bar");

			let route2 = "/foo//bar";
			let url2 = HttpParser.URL(route2, headers);
			let (simplified2, _) = Utils.simplifyRoute(url2);

			expect.text(simplified2).equal("/foo/bar");

			let complicatedRoute = "/foo//bar/:baz/:qux///?test=1#header";
			let complicatedUrl = HttpParser.URL(complicatedRoute, headers);
			let (complicatdBase, complicatedFull) = Utils.simplifyRoute(complicatedUrl);

			expect.text(complicatdBase).equal("/foo/bar/:baz/:qux");
			expect.text(complicatedFull).equal("/foo/bar/:baz/:qux?test=1#header");
		});
	},
);
