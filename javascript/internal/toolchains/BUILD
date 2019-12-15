load("@rules_javascript//javascript/internal/deno:versions.bzl", "DENO_VERSION_URLS")
load("@rules_javascript//javascript/internal/deno:toolchain.bzl", "deno_toolchain_info")
load("@rules_javascript//javascript/internal/node:versions.bzl", "NODE_VERSION_URLS", "NODE_CHAKRACORE_VERSION_URLS")
load("@rules_javascript//javascript/internal/node:toolchain.bzl", "node_toolchain_info")

filegroup(
    name = "all_srcs",
    srcs = glob(["**/*"]),
    visibility = ["//:__subpackages__"],
)

[deno_toolchain_info(
    name = "deno/v{}/x86_64-linux".format(version),
    deno_tool = "@deno_v{}-linux_x64//:bin/deno".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in DENO_VERSION_URLS]

[deno_toolchain_info(
    name = "deno/v{}/x86_64-darwin".format(version),
    deno_tool = "@deno_v{}-osx_x64//:bin/deno".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in DENO_VERSION_URLS]

[node_toolchain_info(
    name = "node/v{}/x86_64-linux".format(version),
    node_version = version,
    node_tool = "@node_v{}-linux-x64//:bin/node".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in NODE_VERSION_URLS]

[node_toolchain_info(
    name = "node/v{}/x86_64-darwin".format(version),
    node_version = version,
    node_tool = "@node_v{}-darwin-x64//:bin/node".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in NODE_VERSION_URLS]

[node_toolchain_info(
    name = "node-chakracore/v{}/x86_64-linux".format(version),
    node_version = version,
    node_tool = "@node-chakracore_v{}-linux-x64//:bin/node".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in NODE_CHAKRACORE_VERSION_URLS]

[node_toolchain_info(
    name = "node-chakracore/v{}/x86_64-darwin".format(version),
    node_version = version,
    node_tool = "@node-chakracore_v{}-darwin-x64//:bin/node".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in NODE_CHAKRACORE_VERSION_URLS]
