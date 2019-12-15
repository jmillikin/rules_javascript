import { assertJsBinaryStdout, setup } from "../integration_test.js";

const workspace = setup();

assertJsBinaryStdout({
    workspace,
    wantStdout: [
        "in //:hello",
        "in //:upper",
        "in //middle-a:middle",
        "in //lower-a:lower",
        "in //middle-b:middle",
        "in //lower-b:lower",
        "",
    ].join("\n"),
    binTarget: "//:hello",
    binOutputPath: "bazel-bin/hello",
    genruleTarget: "//:hello_genrule",
    genruleOutputPath: "bazel-bin/hello_out.txt",
});
