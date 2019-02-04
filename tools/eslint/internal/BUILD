load("@rules_javascript//tools/eslint:eslint.bzl", "eslint_common")
load("@rules_javascript//tools/eslint/internal:toolchain.bzl", "eslint_toolchain_info")

[eslint_toolchain_info(
    name = "toolchain_v{}".format(version),
    eslint = "@eslint_v{}//bin:eslint".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
) for version in eslint_common.VERSIONS]
