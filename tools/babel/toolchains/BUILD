load("@rules_javascript//tools/babel:babel.bzl", "babel_common")

[toolchain(
    name = "v{}".format(version),
    toolchain = "@rules_javascript//tools/babel/internal:toolchain_v{}".format(version),
    toolchain_type = babel_common.TOOLCHAIN_TYPE,
) for version in babel_common.VERSIONS]
