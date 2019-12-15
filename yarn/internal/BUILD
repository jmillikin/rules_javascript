load("@rules_javascript//yarn/internal:versions.bzl", "YARN_VERSION_URLS")
load("@rules_javascript//yarn/internal:toolchain.bzl", "yarn_toolchain_info")
load("@rules_javascript//javascript:javascript.bzl", "js_binary")

filegroup(
    name = "all_srcs",
    srcs = glob(["*"]),
    visibility = ["//:__subpackages__"],
)

[yarn_toolchain_info(
    name = "toolchain_v{}".format(version),
    yarn_tool = "@yarn_v{}//bin:yarn".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in YARN_VERSION_URLS]

js_binary(
    name = "yarn_install",
    src = "yarn_install.js",
    visibility = ["//visibility:public"],
)
