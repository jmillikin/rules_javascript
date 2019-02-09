# Copyright 2019 the rules_javascript authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

"""Bazel build rules for JavaScript.

```python
load("@rules_javascript//javascript:javascript.bzl", "javascript_register_toolchains")
javascript_register_toolchains()
```
"""

load(
    "//javascript/internal:providers.bzl",
    _JavaScriptInfo = "JavaScriptInfo",
    _JavaScriptModuleInfo = "JavaScriptModuleInfo",
)
load(
    "//javascript/node:node.bzl",
    _node_common = "node_common",
    _node_register_toolchains = "node_register_toolchains",
)
load(
    "//tools/babel:babel.bzl",
    _babel_common = "babel_common",
    _babel_register_toolchains = "babel_register_toolchains",
)
load(
    "//tools/eslint:eslint.bzl",
    _eslint_register_toolchains = "eslint_register_toolchains",
)
load(
    "//tools/webpack:webpack.bzl",
    _webpack_common = "webpack_common",
    _webpack_register_toolchains = "webpack_register_toolchains",
)
load(
    "//tools/yarn:yarn.bzl",
    _yarn_register_toolchains = "yarn_register_toolchains",
)
load(
    "//typescript:typescript.bzl",
    _typescript_register_toolchains = "typescript_register_toolchains",
)

def _version(kwargs, prefix):
    key = prefix + "_"
    if key in kwargs:
        return {"version": kwargs[key]}
    return {}

def javascript_register_toolchains(**kwargs):
    toolchains = dict(
        babel = _babel_register_toolchains,
        eslint = _eslint_register_toolchains,
        node = _node_register_toolchains,
        webpack = _webpack_register_toolchains,
        typescript = _typescript_register_toolchains,
        yarn = _yarn_register_toolchains,
    )
    for (kwarg_prefix, register) in toolchains.items():
        register_kwargs = {}
        for key, value in kwargs.items():
            if key.startswith(kwarg_prefix + "_"):
                register_kwargs[key[len(kwarg_prefix) + 1:]] = value
        register(**register_kwargs)

# region Build Rules {{{

def _module_name(ctx, src):
    # TODO: adjust 'module_prefix' based on {strip_,}import_prefix
    return src.short_path[:-len(".js")]

def _js_library(ctx):
    direct_sources = []
    direct_modules = []
    if ctx.attr.src:
        direct_sources = depset(direct = ctx.files.src)
        direct_modules.append(_JavaScriptModuleInfo(
            name = _module_name(ctx, ctx.file.src),
            files = direct_sources,
            source = struct(
                path = ctx.file.src.path,
                short_path = ctx.file.src.short_path,
            ),
        ))

    deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]
    return _JavaScriptInfo(
        direct_modules = direct_modules,
        direct_sources = direct_sources,
        transitive_sources = depset(
            direct = ctx.files.src,
            transitive = [dep.transitive_sources for dep in deps],
        ),
        transitive_modules = depset(
            direct = direct_modules,
            transitive = [dep.transitive_modules for dep in deps],
        ),
    )

js_library = rule(
    _js_library,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
        ),
        "deps": attr.label_list(
            providers = [_JavaScriptInfo],
        ),
        "import_prefix": attr.string(),
        "strip_import_prefix": attr.string(),
    },
    provides = [_JavaScriptInfo],
)

def _js_binary_babel(ctx, dep_modules):
    babel_toolchain = ctx.attr._babel_toolchain[_babel_common.ToolchainInfo]

    babel_config_file = ctx.actions.declare_file("_babel/{}/config.js".format(
        ctx.attr.name,
    ))
    preset_env = _babel_common.preset(
        babel_toolchain.babel_modules["@babel/preset-env"],
        {"targets": {"node": "current"}},
    )
    babel_config = _babel_common.create_config(
        ctx.actions,
        babel_toolchain = babel_toolchain,
        output_file = babel_config_file,
        presets = [preset_env],
    )

    babel_modules = []
    for dep_module in dep_modules:
        babel_out = ctx.actions.declare_file("_babel_out/{}/{}.js".format(
            ctx.attr.name,
            dep_module.name,
        ))
        babel_modules.append(_JavaScriptModuleInfo(
            name = dep_module.name,
            files = depset(direct = [babel_out]),
            source = struct(
                path = babel_out.path,
                short_path = babel_out.short_path,
            ),
        ))
        _babel_common.compile(
            ctx.actions,
            babel_toolchain = babel_toolchain,
            babel_config = babel_config,
            module = dep_module,
            output_file = babel_out,
            babel_arguments = ctx.attr.babel_options,
        )

    babel_out = ctx.actions.declare_file("_babel_out/{}/{}".format(
        ctx.attr.name,
        ctx.file.src.short_path,
    ))
    main_babel_out = babel_out
    _babel_common.compile(
        ctx.actions,
        babel_toolchain = babel_toolchain,
        babel_config = babel_config,
        module = _JavaScriptModuleInfo(
            files = depset(direct = ctx.files.src),
            source = ctx.file.src,
        ),
        output_file = babel_out,
        babel_arguments = ctx.attr.babel_options,
    )

    return struct(
        main_js = main_babel_out,
        modules = babel_modules,
    )

_JS_BINARY_WEBPACK_CONFIG = """
const path = require("path");
const webpack = require(path.resolve(process.cwd(), CONFIG.webpack));
let resolve_aliases = {};
CONFIG.resolve_aliases.forEach(item => {
    resolve_aliases[item[0]] = path.resolve(process.cwd(), item[1]);
});
module.exports = {
    mode: "production",
    target: "node",
    plugins: [new webpack.BannerPlugin({
        banner: "/*! NODE_EXECUTABLE */",
        raw: true,
        entryOnly: true,
    })],
    output: { path: process.cwd() },
    resolve: { alias: resolve_aliases },
};
"""

def _js_binary_webpack(ctx, babel_out):
    webpack_toolchain = ctx.attr._webpack_toolchain[_webpack_common.ToolchainInfo]

    webpack_config_file = ctx.actions.declare_file("_webpack/{}/config.js".format(ctx.attr.name))
    ctx.actions.write(
        webpack_config_file,
        "const CONFIG = {};".format(struct(
            webpack = webpack_toolchain.webpack_modules["webpack"].source.path,
            resolve_aliases = [[mod.name, mod.source.path] for mod in babel_out.modules],
        ).to_json()) + _JS_BINARY_WEBPACK_CONFIG,
    )
    webpack_config = _webpack_common.WebpackConfigInfo(
        webpack_config_file = webpack_config_file,
        files = depset(
            direct = [webpack_config_file],
            transitive = [mod.files for mod in babel_out.modules],
        ),
    )

    webpack_out = ctx.actions.declare_file("_webpack_out/{}/bundle.js".format(ctx.attr.name))
    _webpack_common.bundle(
        ctx.actions,
        webpack_toolchain = webpack_toolchain,
        webpack_config = webpack_config,
        entries = [babel_out.main_js],
        output_file = webpack_out,
            webpack_arguments = ctx.attr.webpack_options,
    )

    return struct(
        bundle_js = webpack_out,
    )

def _js_binary(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]

    dep_modules = depset(
        transitive = [
            dep[_JavaScriptInfo].transitive_modules
            for dep in ctx.attr.deps
        ],
    )

    babel_out = _js_binary_babel(ctx, dep_modules)
    webpack_out = _js_binary_webpack(ctx, babel_out)

    out_plain = ctx.actions.declare_file(ctx.attr.name)
    out_exec = ctx.actions.declare_file(ctx.attr.name + ".hermetic.js")

    ctx.actions.expand_template(
        template = webpack_out.bundle_js,
        output = out_plain,
        substitutions = {
            "/*! NODE_EXECUTABLE */": "#!/usr/bin/env node\n",
        },
        is_executable = True,
    )

    ctx.actions.expand_template(
        template = webpack_out.bundle_js,
        output = out_exec,
        substitutions = {
            "/*! NODE_EXECUTABLE */": "#!{}\n".format(
                node_toolchain.node_executable.path,
            ),
        },
        is_executable = True,
    )
    return DefaultInfo(
        files = depset(direct = [out_plain]),
        executable = out_exec,
        runfiles = ctx.runfiles(
            files = ctx.files.src,
            transitive_files = node_toolchain.files,
        ),
    )

js_binary = rule(
    _js_binary,
    executable = True,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
            mandatory = True,
        ),
        "deps": attr.label_list(
            providers = [_JavaScriptInfo],
        ),
        "babel_options": attr.string_list(),
        "webpack_options": attr.string_list(),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
        "_babel_toolchain": attr.label(
            default = "//tools/babel:toolchain",
        ),
        "_webpack_toolchain": attr.label(
            default = "//tools/webpack:toolchain",
        ),
    },
)

# endregion }}}

