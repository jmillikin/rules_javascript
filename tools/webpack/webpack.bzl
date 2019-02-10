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

load(
    "//javascript/internal:providers.bzl",
    _JavaScriptInfo = "JavaScriptInfo",
)
load(
    "//javascript/node:node.bzl",
    _node_common = "node_common",
)
load(
    "//tools/yarn/internal:yarn_vendor.bzl",
    _yarn_vendor_modules = "yarn_vendor_modules",
)
load(
    "//tools/webpack/internal:toolchain.bzl",
    _WebpackConfigInfo = "WebpackConfigInfo",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "WebpackToolchainInfo",
)

# region Versions {{{

_LATEST = "4.29.0"
_VERSIONS = ["4.29.0"]

def _check_version(version):
    if version not in _VERSIONS:
        fail("Webpack version {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

def _bundle(ctx_actions, webpack_toolchain, webpack_config, entries, output_file, *, webpack_arguments = []):
    inputs = depset(
        direct = entries,
        transitive = [
            webpack_toolchain.files,
            webpack_config.files,
        ],
    )
    argv = ctx_actions.args()
    argv.add_all([
        "--config=" + webpack_config.webpack_config_file.path,
        "--output-filename=" + output_file.path,
        "--display=errors-only",
    ])
    argv.add_all([
        "--entry=./" + entry.path
        for entry in entries
    ])
    argv.add_all(webpack_arguments)

    if len(entries) == 1:
        progress_message = "Webpack {}".format(entries[0].short_path)
    else:
        progress_message = "Webpack {}".format([entry.short_path for entry in entries])

    ctx_actions.run(
        inputs = inputs,
        outputs = [output_file],
        executable = webpack_toolchain.webpack_executable,
        arguments = [argv],
        mnemonic = "Webpack",
        progress_message = progress_message,
    )

webpack_common = struct(
    VERSIONS = _VERSIONS,
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
    WebpackConfigInfo = _WebpackConfigInfo,
    bundle = _bundle,
)

def webpack_register_toolchains(version = _LATEST):
    _check_version(version)
    repo_name = "webpack_v{}".format(version)
    if repo_name not in native.existing_rules().keys():
        webpack_repository(
            name = repo_name,
            version = version,
        )
    native.register_toolchains("@rules_javascript//tools/webpack/toolchains:v{}".format(version))

# region Build Rules {{{

_WEBPACK_CONFIG = """
const path = require("path");
let resolve_aliases = {};
CONFIG.resolve_aliases.forEach(item => {
    resolve_aliases[item[0]] = path.resolve(process.cwd(), item[1]);
});
module.exports = {
    mode: CONFIG.webpack_mode,
    output: { path: process.cwd() },
    resolve: { alias: resolve_aliases },
};
"""

def _webpack(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
    webpack_toolchain = ctx.attr._webpack_toolchain[webpack_common.ToolchainInfo]

    if ctx.var["COMPILATION_MODE"] == "opt":
        webpack_mode = "production"
    else:
        webpack_mode = "development"

    js_deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]
    dep_modules = []
    for dep in js_deps:
        dep_modules += dep.transitive_modules

    webpack_config_file = ctx.actions.declare_file("_webpack/{}/config.js".format(ctx.attr.name))
    ctx.actions.write(
        webpack_config_file,
        "const CONFIG = {};".format(struct(
            webpack_mode = webpack_mode,
            resolve_aliases = [[mod.name, mod.source.path] for mod in dep_modules],
        ).to_json()) + _WEBPACK_CONFIG,
    )
    webpack_config = webpack_common.WebpackConfigInfo(
        webpack_config_file = webpack_config_file,
        files = depset(
            direct = [webpack_config_file],
            transitive = [mod.files for mod in dep_modules],
        ),
    )

    webpack_out = ctx.actions.declare_file(ctx.attr.name + ".bundle.js")
    webpack_common.bundle(
        ctx.actions,
        webpack_toolchain = webpack_toolchain,
        webpack_config = webpack_config,
        entries = ctx.files.srcs,
        output_file = webpack_out,
        webpack_arguments = ctx.attr.webpack_options,
    )
    return DefaultInfo(files = depset(direct = [webpack_out]))

webpack = rule(
    _webpack,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".js"],
            allow_empty = False,
        ),
        "deps": attr.label_list(
            providers = [_JavaScriptInfo],
        ),
        "webpack_options": attr.string_list(),
        "_config_tmpl": attr.label(
            allow_single_file = True,
            default = "//tools/webpack/internal:webpack_config.tmpl.js",
        ),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
        "_webpack_toolchain": attr.label(
            default = "//tools/webpack:toolchain",
        ),
    },
)

# endregion }}}

# region Repository Rules {{{

def _webpack_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    vendor_dir = "@rules_javascript//tools/webpack/internal:webpack_v" + version
    _yarn_vendor_modules(
        ctx,
        vendor_dir,
        tools = {
            "webpack": "webpack-cli/bin/cli.js",
        },
        modules = ["webpack"],
    )

webpack_repository = repository_rule(
    _webpack_repository,
    attrs = {
        "version": attr.string(mandatory = True),
        "registries": attr.string_list(
            default = _node_common.NPM_REGISTRIES,
        ),
    },
)

# endregion }}}
