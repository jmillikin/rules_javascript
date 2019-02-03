load(":util.bzl", "config_settings")

config_setting(
    name = "compilation_mode_dbg",
    values = {"compilation_mode": "dbg"},
)

config_setting(
    name = "compilation_mode_fastbuild",
    values = {"compilation_mode": "fastbuild"},
)

config_setting(
    name = "compilation_mode_opt",
    values = {"compilation_mode": "opt"},
)

config_settings(
    name = "config_settings",
    compilation_mode = select({
        ":compilation_mode_dbg": "dbg",
        ":compilation_mode_fastbuild": "fastbuild",
        ":compilation_mode_opt": "opt",
    }),
    visibility = ["//visibility:public"],
)
