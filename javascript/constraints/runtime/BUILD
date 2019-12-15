filegroup(
    name = "all_srcs",
    srcs = glob(["**/*"]),
    visibility = ["//:__subpackages__"],
)

constraint_setting(
    name = "runtime",
    default_constraint_value = ":node",
    visibility = ["//visibility:public"],
)

constraint_value(
    name = "node",
    constraint_setting = ":runtime",
    visibility = ["//visibility:public"],
)

constraint_value(
    name = "deno",
    constraint_setting = ":runtime",
    visibility = ["//visibility:public"],
)
