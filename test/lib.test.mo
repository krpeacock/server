import Server "../src/lib";
import Test "mo:test";
let test = Test.test;
let suite = Test.suite;

suite("my test suite", func() {
	test("simple test", func() {
		assert true;
	});

	test("test my number", func() {
		assert 1 > 0;
	});
});


