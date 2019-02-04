load("@rules_javascript//tools/babel:babel.bzl", "babel_common")
load("@rules_javascript//tools/babel/internal:toolchain.bzl", "babel_toolchain_info")

[babel_toolchain_info(
    name = "toolchain_v{}".format(version),
    babel = "@babel_v{}//bin:babel".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in babel_common.VERSIONS]
