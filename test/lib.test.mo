import Utils "../src/Utils";
import Test "mo:test";
import Result "mo:base/Result";
import TrieMap "mo:base/TrieMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
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
		)

	},
);
