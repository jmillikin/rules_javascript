load("@rules_javascript//javascript/internal:toolchain.bzl", "javascript_toolchain_alias")

filegroup(
    name = "all_srcs",
    srcs = glob(["**/*"]) + [
        "//javascript/constraints:all_srcs",
        "//javascript/internal:all_srcs",
        "//javascript/toolchains:all_srcs",
    ],
    visibility = ["//:__subpackages__"],
)

toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)

javascript_toolchain_alias(
    name = "current_javascript_toolchain",
    visibility = ["//visibility:public"],
)
