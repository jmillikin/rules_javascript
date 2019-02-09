load("@rules_javascript//typescript:typescript.bzl", "typescript_common")
load("@rules_javascript//typescript/internal:toolchain.bzl", "typescript_toolchain_info")

exports_files(["tsc_wrapper.js"])

[typescript_toolchain_info(
    name = "toolchain_v{}".format(version),
    tags = ["manual"],
    tsc = "@typescript_v{}//bin:tsc".format(version),
    visibility = ["//visibility:public"],
) for version in typescript_common.VERSIONS]
