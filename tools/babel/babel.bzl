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
    _JavaScriptModuleInfo = "JavaScriptModuleInfo",
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

# region Build Rules {{{

def _module_dir(module_name):
    idx = module_name.rfind("/")
    if idx == -1:
        return module_name
    return module_name[:idx]

def _babel_config_dummy(ctx):
    config_file = ctx.actions.declare_file("_babel/{}/config.js".format(
        ctx.attr.name,
    ))
    ctx.actions.write(config_file, """
const path = require("path");
const CONFIG = {CONFIG};

let resolve = module.parent.require("resolve");
const orig_resolve_sync = resolve.sync;
const babel_dir = path.dirname(module.parent.filename);
resolve.sync = function(name, opts) {{
    if (name.startsWith("@babel/")) {{
        opts.basedir = babel_dir;
    }}
    return orig_resolve_sync(name, opts);
}}
module.exports = {{
    extends: path.resolve(process.cwd(), CONFIG.extends),
}}
""".format(
        CONFIG = struct(
            extends = ctx.file.babel_config.path,
        ).to_json(),
    ))

    return _BabelConfigInfo(
        babel_config_file = config_file,
        files = depset(
            direct = [config_file, ctx.file.babel_config],
        )
    )

def _babel(ctx):
    babel_toolchain = ctx.attr._babel_toolchain[_ToolchainInfo]

    if _BabelConfigInfo in ctx.attr.babel_config:
        babel_config = ctx.attr.babel_config[_BabelConfigInfo]
    else:
        babel_config = _babel_config_dummy(ctx)

    js_deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]
    babel_inputs = depset(transitive = [
        babel_toolchain.files,
        babel_config.files,
    ])

    # Running Babel with `--relative --out-dir=./out-root ./src/main.js` will
    # write output to `./src/out-root/main.js`, which is the exact opposite of
    # what we want when all the output files are supposed to end up in a
    # per-target output directory.
    #
    # Work around this by splitting inputs by dirname, and implementing the
    # relative output path calculation ourselves.
    #
    # See also:
    # * https://github.com/babel/babel/issues/8193

    modules_by_dir = {}
    for dep in js_deps:
        for module in dep.transitive_modules:
            module_dir = _module_dir(module.name)
            modules_by_dir.setdefault(module_dir, []).append(module)

    all_outputs = []
    out_modules = []
    for dirname in sorted(modules_by_dir):
        dir_inputs = []
        dir_outputs = []
        dir_modules = modules_by_dir[dirname]
        for module in dir_modules:
            module_output = ctx.actions.declare_file("_babel_out/{}/{}.js".format(
                ctx.attr.name,
                module.name,
            ))
            dir_inputs.append(module.files)
            dir_outputs.append(module_output)
            all_outputs.append(module_output)
            out_modules.append(_JavaScriptModuleInfo(
                name = module.name,
                files = depset(direct = [module_output]),
                source = struct(
                    path = module_output.path,
                    short_path = module_output.short_path,
                )
            ))

        argv = ctx.actions.args()
        argv.add_all([
            "--no-babelrc",
            "--config-file=./" + babel_config.babel_config_file.path,
            "--env-name=production",
            "--source-root=.",
            "--out-dir=./" + dir_outputs[0].dirname,
        ])
        argv.add_all([module.source.path for module in dir_modules])
        argv.add_all(ctx.attr.babel_options)

        ctx.actions.run(
            inputs = depset(
                transitive = [babel_inputs] + dir_inputs,
            ),
            outputs = dir_outputs,
            executable = babel_toolchain.babel_executable,
            arguments = [argv],
            mnemonic = "Babel",
            progress_message = "Babel {} => {}".format(ctx.label, dirname),
        )

    return [
        DefaultInfo(files = depset(direct = all_outputs)),
        _JavaScriptInfo(
            direct_modules = out_modules,
            direct_sources = depset(all_outputs),
            transitive_modules = out_modules,
            transitive_sources = depset(all_outputs),
        ),
    ]

babel = rule(
    _babel,
    attrs = {
        "babel_options": attr.string_list(),
        "babel_config": attr.label(
            allow_single_file = [".js"],
            providers = [_BabelConfigInfo],
            mandatory = True,
        ),
        "deps": attr.label_list(
            providers = [_JavaScriptInfo],
        ),
        "_babel_toolchain": attr.label(
            default = "//tools/babel:toolchain",
        ),
    },
    provides = [DefaultInfo, _JavaScriptInfo],
)

def _babel_config(ctx):
    js_deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]

    return _BabelConfigInfo(
        babel_config_file = ctx.file.src,
        files = depset(
            direct = ctx.files.src,
            transitive = [
                dep.transitive_sources for dep in js_deps
            ],
        )
    )

babel_config = rule(
    _babel_config,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
        ),
        "deps": attr.label_list(
            providers = [_JavaScriptInfo],
        ),
    },
    provides = [_BabelConfigInfo],
)

# }}}

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
