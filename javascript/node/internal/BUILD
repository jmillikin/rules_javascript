load("@rules_javascript//javascript/node:node.bzl", "node_common")
load("@rules_javascript//javascript/node/internal:toolchain.bzl", "node_toolchain_info")

[node_toolchain_info(
    name = "toolchain_v{}-linux-x64".format(version),
    node = "@node_v{}-linux-x64//:bin/node".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in node_common.VERSIONS]

[node_toolchain_info(
    name = "toolchain_v{}-darwin-x64".format(version),
    node = "@node_v{}-darwin-x64//:bin/node".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in node_common.VERSIONS]
