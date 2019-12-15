load("@rules_javascript//yarn/internal:toolchain.bzl", "yarn_toolchain_alias")

filegroup(
    name = "all_srcs",
    srcs = glob(["*"]) + [
        "//yarn/internal:all_srcs",
        "//yarn/toolchains:all_srcs",
    ],
    visibility = ["//:__subpackages__"],
)

toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)

yarn_toolchain_alias(
    name = "current_yarn_toolchain",
    visibility = ["//visibility:public"],
)
