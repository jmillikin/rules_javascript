load("@rules_javascript//javascript:javascript.bzl", "js_binary")
load("@rules_javascript//typescript:typescript.bzl", "typescript_common")
load("@rules_javascript//typescript/internal:toolchain.bzl", "typescript_toolchain_info")

[typescript_toolchain_info(
    name = "toolchain_v{}".format(version),
    tags = ["manual"],
    tsc = "@typescript_v{}//bin:tsc".format(version),
    visibility = ["//visibility:public"],
) for version in typescript_common.VERSIONS]

js_binary(
    name = "tsc_wrapper",
    src = "tsc_wrapper.js",
    visibility = ["//visibility:public"],
)
