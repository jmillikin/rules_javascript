load("@rules_javascript//tools/webpack:webpack.bzl", "webpack_common")

[toolchain(
    name = "v{}".format(version),
    toolchain = "@rules_javascript//tools/webpack/internal:toolchain_v{}".format(version),
    toolchain_type = webpack_common.TOOLCHAIN_TYPE,
) for version in webpack_common.VERSIONS]
