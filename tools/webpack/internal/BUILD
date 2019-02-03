load("@rules_javascript//tools/webpack:webpack.bzl", "webpack_common")
load("@rules_javascript//tools/webpack/internal:toolchain.bzl", "webpack_toolchain_info")

[webpack_toolchain_info(
    name = "toolchain_v{}".format(version),
    node_modules = "@webpack_v{}//:node_modules".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
    webpack_js = "webpack-cli/bin/cli.js",
) for version in webpack_common.VERSIONS]
