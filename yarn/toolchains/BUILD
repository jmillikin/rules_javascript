load("@rules_javascript//yarn/internal:toolchain.bzl", "YARN_TOOLCHAIN_TYPE")
load("@rules_javascript//yarn/internal:versions.bzl", "YARN_VERSION_URLS")

filegroup(
    name = "all_srcs",
    srcs = glob(["*"]),
    visibility = ["//:__subpackages__"],
)

[toolchain(
    name = "v{}".format(version),
    toolchain = "@rules_javascript//yarn/internal:toolchain_v{}".format(version),
    toolchain_type = YARN_TOOLCHAIN_TYPE,
) for version in YARN_VERSION_URLS]
