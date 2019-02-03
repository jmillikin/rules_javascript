load("@rules_javascript//typescript:typescript.bzl", "typescript_common")

[toolchain(
    name = "v{}".format(version),
    toolchain = "@rules_javascript//typescript/internal:toolchain_v{}".format(version),
    toolchain_type = typescript_common.TOOLCHAIN_TYPE,
) for version in typescript_common.VERSIONS]
