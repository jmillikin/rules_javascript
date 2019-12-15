filegroup(
    name = "all_srcs",
    srcs = glob(["**/*"]) + [
        "//javascript/internal/deno:all_srcs",
        "//javascript/internal/node:all_srcs",
        "//javascript/internal/toolchains:all_srcs",
    ],
    visibility = ["//:__subpackages__"],
)
