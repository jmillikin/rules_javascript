load("@rules_javascript//tools/yarn:yarn.bzl", "yarn_common")
load("@rules_javascript//tools/yarn/internal:toolchain.bzl", "yarn_toolchain_info")

exports_files(["yarn_install.js"])

[yarn_toolchain_info(
    name = "toolchain_v{}".format(version),
    tags = ["manual"],
    visibility = ["//visibility:public"],
    yarn_js = "@yarn_v{}//:lib/cli.js".format(version),
) for version in yarn_common.VERSIONS]
