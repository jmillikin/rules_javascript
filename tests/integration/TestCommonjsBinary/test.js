import { assertJsBinaryStdout, setup } from "../integration_test.js";

const workspace = setup();

assertJsBinaryStdout({
	workspace,
	wantStdout: "Hello, world!\n",
	binTarget: "//:hello",
	binOutputPath: "bazel-bin/hello",
	genruleTarget: "//:hello_genrule",
	genruleOutputPath: "bazel-bin/hello_out.txt",
});
