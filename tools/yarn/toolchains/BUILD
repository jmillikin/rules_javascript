load("@rules_javascript//tools/yarn:yarn.bzl", "yarn_common")

[toolchain(
    name = "v{}".format(version),
    toolchain = "@rules_javascript//tools/yarn/internal:toolchain_v{}".format(version),
    toolchain_type = yarn_common.TOOLCHAIN_TYPE,
) for version in yarn_common.VERSIONS]
