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
    "//javascript/node:node.bzl",
    _node_common = "node_common",
)
load(
    "//tools/yarn/internal:yarn_vendor.bzl",
    _yarn_vendor_modules = "yarn_vendor_modules",
)
load(
    "//tools/babel/internal:toolchain.bzl",
    _BabelConfigInfo = "BabelConfigInfo",
    _BabelPresetInfo = "BabelPresetInfo",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "BabelToolchainInfo",
)

# region Versions {{{

_LATEST = "7.3.1"
_VERSIONS = ["7.3.1"]

def _check_version(version):
    if version not in _VERSIONS:
        fail("Babel version {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

def _preset(module, options = {}):
    return _BabelPresetInfo(
        module = module,
        options = options,
    )

def _create_config(ctx_actions, babel_toolchain, output_file, *, presets = [], overrides = []):
    if output_file.extension != "js":
        fail("Babel configuration files must have the '.js' extension")

    ctx_actions.write(output_file, """
const path = require("path");
const CONFIG = {CONFIG};
let presets = CONFIG.presets.map((preset) => {{
    return [
        path.resolve(process.cwd(), preset.path),
        preset.options,
    ];
}});
module.exports = {{
    presets: presets,
    overrides: CONFIG.overrides,
}}
""".format(
        CONFIG = struct(
            presets = [{
                "path": p.module.source.path,
                "options": p.options,
            } for p in presets],
            overrides = overrides,
        ).to_json(),
    ))
    return _BabelConfigInfo(
        babel_config_file = output_file,
        files = depset(
            direct = [output_file],
            transitive = [
                preset.module.files
                for preset in presets
            ],
        ),
    )

def _compile(ctx_actions, babel_toolchain, babel_config, module, output_file, *, babel_arguments = []):
    inputs = depset(
        transitive = [
            babel_toolchain.files,
            babel_config.files,
            module.files,
        ],
    )
    argv = ctx_actions.args()
    argv.add_all([
        "--no-babelrc",
        "--config-file=./" + babel_config.babel_config_file.path,
        "--env-name=production",
        "--source-root=.",
        "--out-file=./" + output_file.path,
        "./" + module.source.path,
    ])
    argv.add_all(babel_arguments)
    ctx_actions.run(
        inputs = inputs,
        outputs = [output_file],
        executable = babel_toolchain.babel_executable,
        arguments = [argv],
        mnemonic = "Babel",
        progress_message = "Babel {}".format(module.source.short_path),
    )

babel_common = struct(
    VERSIONS = _VERSIONS,
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
    BabelConfigInfo = _BabelConfigInfo,
    BabelPresetInfo = _BabelPresetInfo,
    create_config = _create_config,
    compile = _compile,
    preset = _preset,
)

def babel_register_toolchains(version = _LATEST):
    _check_version(version)
    repo_name = "babel_v{}".format(version)
    if repo_name not in native.existing_rules().keys():
        babel_repository(
            name = repo_name,
            version = version,
        )
    native.register_toolchains("@rules_javascript//tools/babel/toolchains:v{}".format(version))

# region Repository Rules {{{

def _babel_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    vendor_dir = "@rules_javascript//tools/babel/internal:babel_v" + version
    _yarn_vendor_modules(
        ctx,
        vendor_dir,
        tools = {
            "babel": "@babel/cli/bin/babel.js",
        },
        modules = [
            "@babel/preset-env",
            "@babel/preset-flow",
            "@babel/preset-react",
            "@babel/preset-typescript",
        ],
    )

babel_repository = repository_rule(
    _babel_repository,
    attrs = {
        "version": attr.string(mandatory = True),
        "registries": attr.string_list(
            default = _node_common.NPM_REGISTRIES,
        ),
    },
)

# endregion }}}
