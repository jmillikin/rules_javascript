load("@rules_javascript//javascript/internal/deno:versions.bzl", "DENO_VERSION_URLS")
load("@rules_javascript//javascript/internal:toolchain.bzl", "JAVASCRIPT_TOOLCHAIN_TYPE")

filegroup(
    name = "all_srcs",
    srcs = glob(["**/*"]),
    visibility = ["//:__subpackages__"],
)

[toolchain(
    name = "v{}/x86_64-linux".format(version),
    exec_compatible_with = [
        "@bazel_tools//platforms:linux",
        "@bazel_tools//platforms:x86_64",
        "//javascript/constraints/engine:v8",
        "//javascript/constraints/runtime:deno",
    ],
    toolchain = "@rules_javascript//javascript/internal/toolchains:deno/v{}/x86_64-linux".format(version),
    toolchain_type = JAVASCRIPT_TOOLCHAIN_TYPE,
) for version in DENO_VERSION_URLS]

[toolchain(
    name = "v{}/x86_64-darwin".format(version),
    exec_compatible_with = [
        "@bazel_tools//platforms:osx",
        "@bazel_tools//platforms:x86_64",
        "//javascript/constraints/engine:v8",
        "//javascript/constraints/runtime:deno",
    ],
    toolchain = "@rules_javascript//javascript/internal/toolchains:deno/v{}/x86_64-darwin".format(version),
    toolchain_type = JAVASCRIPT_TOOLCHAIN_TYPE,
) for version in DENO_VERSION_URLS]
