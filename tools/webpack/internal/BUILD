load("@rules_javascript//tools/webpack:webpack.bzl", "webpack_common")
load("@rules_javascript//tools/webpack/internal:toolchain.bzl", "webpack_toolchain_info")

exports_files(["webpack_config.tmpl.js"])

[webpack_toolchain_info(
    name = "toolchain_v{}".format(version),
    node_modules = "@webpack_v{}//:node_modules".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
    webpack = "@webpack_v{}//bin:webpack".format(version),
) for version in webpack_common.VERSIONS]
