JsInfo = provider(
    doc = "",
    fields = {
        "packages": "map from package name to JsPackageInfo",
        "modules": "map from module name to JsModuleInfo",
        "direct_deps": "",
        "transitive_deps": "",
        "direct_files": "",
        "transitive_files": "",
    },
)

JsPackageInfo = provider(
    doc = "",
    fields = {
        "root": "File of a directory containing this package",
        "format": "either 'module' or 'commonjs'",
    },
)

JsModuleInfo = provider(
    doc = "",
    fields = {
        "file": "File of the module",
        "format": "either 'module' or 'commonjs'",
    },
)
