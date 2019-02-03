load("@rules_javascript//javascript/node:node.bzl", "node_common")

[toolchain(
    name = "v{}-linux-x64".format(version),
    exec_compatible_with = [
        "@bazel_tools//platforms:linux",
        "@bazel_tools//platforms:x86_64",
    ],
    toolchain = "@rules_javascript//javascript/node/internal:toolchain_v{}-linux-x64".format(version),
    toolchain_type = node_common.TOOLCHAIN_TYPE,
) for version in node_common.VERSIONS]

[toolchain(
    name = "v{}-darwin-x64".format(version),
    exec_compatible_with = [
        "@bazel_tools//platforms:osx",
        "@bazel_tools//platforms:x86_64",
    ],
    toolchain = "@rules_javascript//javascript/node/internal:toolchain_v{}-darwin-x64".format(version),
    toolchain_type = node_common.TOOLCHAIN_TYPE,
) for version in node_common.VERSIONS]
