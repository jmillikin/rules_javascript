import { assertJsBinaryStdout, setup } from "../integration_test.js";

const workspace = setup();

assertJsBinaryStdout({
    workspace,
    wantStdout: "in //:hello\nin //lib:hello\nin //:hello_impl\n",
    binTarget: "//:hello",
    binOutputPath: "bazel-bin/hello",
    genruleTarget: "//:hello_genrule",
    genruleOutputPath: "bazel-bin/hello_out.txt",
});
