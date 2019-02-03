load("@rules_javascript//tools/eslint:eslint.bzl", "eslint_common")

[toolchain(
    name = "v{}".format(version),
    toolchain = "@rules_javascript//tools/eslint/internal:toolchain_v{}".format(version),
    toolchain_type = eslint_common.TOOLCHAIN_TYPE,
) for version in eslint_common.VERSIONS]
