load("@rules_javascript//tools/eslint:eslint.bzl", "eslint_common")
load("@rules_javascript//tools/eslint/internal:toolchain.bzl", "eslint_toolchain_info")

[eslint_toolchain_info(
    name = "toolchain_v{}".format(version),
    node_modules = "@eslint_v{}//:node_modules".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
    eslint_js = "eslint/bin/eslint.js",
) for version in eslint_common.VERSIONS]
