filegroup(
    name = "all_srcs",
    srcs = glob(["**/*"]) + [
        "//javascript/toolchains/deno:all_srcs",
        "//javascript/toolchains/node:all_srcs",
        "//javascript/toolchains/node-chakracore:all_srcs",
    ],
    visibility = ["//:__subpackages__"],
)
