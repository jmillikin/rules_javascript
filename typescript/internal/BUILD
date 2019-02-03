load("@rules_javascript//typescript:typescript.bzl", "typescript_common")
load("@rules_javascript//typescript/internal:toolchain.bzl", "typescript_toolchain_info")

exports_files(["tsc_wrapper.js"])

[typescript_toolchain_info(
    name = "toolchain_v{}".format(version),
    tags = ["manual"],
    tsc_files = "@typescript_v{}//:tsc_files".format(version),
    tsc_js = "@typescript_v{}//:tsc_js".format(version),
    visibility = ["//visibility:public"],
) for version in typescript_common.VERSIONS]
