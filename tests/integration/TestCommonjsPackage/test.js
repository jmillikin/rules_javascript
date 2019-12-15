import { assertJsBinaryStdout, setup } from "../integration_test.js";

const workspace = setup();

assertJsBinaryStdout({
    workspace,
    wantStdout: [
        "in //:hello",
        "in //lib:hello",
        "typescript.version:  3.7.2",
        "tsserver.version:  3.7.2",
        "",
    ].join("\n"),
    binTarget: "//:hello",
    binOutputPath: "bazel-bin/hello",
    genruleTarget: "//:hello_genrule",
    genruleOutputPath: "bazel-bin/hello_out.txt",
});
