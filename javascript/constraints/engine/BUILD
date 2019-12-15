filegroup(
    name = "all_srcs",
    srcs = glob(["**/*"]),
    visibility = ["//:__subpackages__"],
)

constraint_setting(
    name = "engine",
    default_constraint_value = ":v8",
    visibility = ["//visibility:public"],
)

constraint_value(
    name = "v8",
    constraint_setting = ":engine",
    visibility = ["//visibility:public"],
)

constraint_value(
    name = "chakracore",
    constraint_setting = ":engine",
    visibility = ["//visibility:public"],
)
