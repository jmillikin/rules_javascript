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
    "//tools/babel:babel.bzl",
    _babel_common = "babel_common",
)
load(
    "//tools/yarn/internal:yarn_vendor.bzl",
    _yarn_vendor_modules = "yarn_vendor_modules",
)
load(
    "//tools/webpack:webpack.bzl",
    _webpack_common = "webpack_common",
)
load(
    "//javascript/node:node.bzl",
    _node_common = "node_common",
)
load(
    "//typescript/internal:toolchain.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "TypeScriptToolchainInfo",
)

# region Versions {{{

_LATEST = "3.2.4"
_VERSIONS = ["3.2.4"]

def _check_version(version):
    if version not in _VERSIONS:
        fail("TypeScript version {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

typescript_common = struct(
    VERSIONS = _VERSIONS,
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
)

def typescript_register_toolchains(version = _LATEST):
    _check_version(version)
    repo_name = "typescript_v{}".format(version)
    if repo_name not in native.existing_rules().keys():
        typescript_repository(
            name = repo_name,
            version = version,
        )
    native.register_toolchains("@rules_javascript//typescript/toolchains:v{}".format(version))

# region Build Rules {{{

_TypeScriptInfo = provider(fields = ["direct_sources", "direct_modules"])

_TypeScriptModuleInfo = provider(fields = ["name", "files", "declarations", "declarations_map", "source"])

def _tsc_declarations(ctx, typescript_toolchain, tsconfig_file, wrapper_params_file, dep_declarations):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]

    declarations = ctx.actions.declare_file("{}.d.ts".format(ctx.attr.name))
    declarations_map = ctx.actions.declare_file("{}.d.ts.map".format(ctx.attr.name))

    args = ctx.actions.args()
    args.add_all([
        "--",
        ctx.file._tsc_wrapper.path,
        wrapper_params_file.path,
        typescript_toolchain.tsc_executable.path,
        "--declaration",
        "--declarationMap",
        "--emitDeclarationOnly",
        "--project",
        tsconfig_file.path,
    ])
    args.add_all(ctx.attr.tsc_options)

    inputs = depset(
        direct = [ctx.file.src, tsconfig_file, wrapper_params_file],
        transitive = [
            typescript_toolchain.files,
            depset(dep_declarations),
            depset(ctx.files._tsc_wrapper),
        ],
    )

    ctx.actions.run(
        executable = node_toolchain.node_executable,
        arguments = [args],
        inputs = inputs,
        outputs = [declarations, declarations_map],
        mnemonic = "TypeScriptCheck",
        progress_message = "Typechecking {}".format(ctx.label),
    )

    return (declarations, declarations_map)

def _tsc_compile(ctx, typescript_toolchain, tsconfig_file, wrapper_params_file, dep_declarations):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]

    js_source = ctx.actions.declare_file("{}.js".format(ctx.attr.name))
    js_source_map = ctx.actions.declare_file("{}.js.map".format(ctx.attr.name))

    args = ctx.actions.args()
    args.add_all([
        "--",
        ctx.file._tsc_wrapper.path,
        wrapper_params_file.path,
        typescript_toolchain.tsc_executable.path,
        "--sourceMap",
        "--project",
        tsconfig_file.path,
    ])
    args.add_all(ctx.attr.tsc_options)

    inputs = depset(
        direct = [ctx.file.src, tsconfig_file, wrapper_params_file],
        transitive = [
            typescript_toolchain.files,
            depset(dep_declarations),
            depset(ctx.files._tsc_wrapper),
        ],
    )

    ctx.actions.run(
        executable = node_toolchain.node_executable,
        arguments = [args],
        inputs = inputs,
        outputs = [js_source, js_source_map],
        mnemonic = "TypeScriptCompile",
        progress_message = "Compiling {}".format(ctx.label),
    )

    return (js_source, js_source_map)

def _ts_common(ctx):
    typescript_toolchain = ctx.attr._typescript_toolchain[typescript_common.ToolchainInfo]

    # TODO: adjust 'module_name' based on {strip_,}import_prefix
    module_name = "{}/{}".format(ctx.label.package, ctx.label.name)

    tsconfig_file = ctx.actions.declare_file("_tsc/{}/tsconfig.json".format(ctx.attr.name))
    wrapper_params_file = ctx.actions.declare_file("_tsc/{}/params.json".format(ctx.attr.name))

    importable_paths = {}
    dep_declarations = []
    for dep in ctx.attr.deps:
        if _TypeScriptInfo not in dep:
            continue
        dep_ts = dep[_TypeScriptInfo]
        for dep_ts_mod in dep_ts.direct_modules:
            importable_paths[dep_ts_mod.name] = [dep_ts_mod.declarations.path]
            dep_declarations.append(dep_ts_mod.declarations)

    (declarations, declarations_map) = _tsc_declarations(
        ctx = ctx,
        typescript_toolchain = typescript_toolchain,
        tsconfig_file = tsconfig_file,
        wrapper_params_file = wrapper_params_file,
        dep_declarations = dep_declarations,
    )

    (js_source, js_source_map) = _tsc_compile(
        ctx = ctx,
        typescript_toolchain = typescript_toolchain,
        tsconfig_file = tsconfig_file,
        wrapper_params_file = wrapper_params_file,
        dep_declarations = dep_declarations,
    )

    tsconfig = struct(
        compilerOptions = struct(
            types = [],
            baseUrl = ".",
            rootDir = "tsc_root",
            paths = importable_paths,
            pretty = True,
            moduleResolution = "Classic",
            forceConsistentCasingInFileNames = True,
            preserveSymlinks = True,
        ),
        files = ["tsc_root/{}.ts".format(module_name)],
    )
    ctx.actions.write(tsconfig_file, tsconfig.to_json())

    wrapper_params = struct(
        tsconfig = tsconfig_file.path,
        module_name = module_name,
        src_ts = ctx.file.src.path,
        out_dir = js_source.root.path,
    )
    ctx.actions.write(wrapper_params_file, wrapper_params.to_json())

    return struct(
        module_name = module_name,
        declarations = declarations,
        declarations_map = declarations_map,
        js_source = js_source,
        js_source_map = js_source_map,
    )

def _ts_library(ctx):
    direct_js_modules = []
    direct_js_sources = []
    direct_ts_modules = []
    direct_ts_sources = []
    out_files = []
    if ctx.attr.src:
        common = _ts_common(ctx)

        out_files = [
            common.js_source,
            common.js_source_map,
            common.declarations,
            common.declarations_map,
        ]

        direct_js_sources.append(common.js_source)
        direct_js_modules.append(_JavaScriptModuleInfo(
            name = common.module_name,
            files = depset(direct_js_sources),
            source = struct(
                path = common.js_source.path,
                short_path = common.js_source.short_path,
            ),
        ))

        direct_ts_sources.append(ctx.file.src)
        direct_ts_modules.append(_TypeScriptModuleInfo(
            name = common.module_name,
            files = direct_ts_sources,
            declarations = common.declarations,
            declarations_map = common.declarations_map,
            source = struct(
                path = ctx.file.src.path,
                short_path = ctx.file.src.short_path,
            ),
        ))

    js_deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]

    return [
        DefaultInfo(files = depset(out_files)),
        _JavaScriptInfo(
            direct_modules = direct_js_modules,
            direct_sources = depset(direct = direct_js_sources),
            transitive_sources = depset(
                direct = direct_js_sources,
                transitive = [dep.transitive_sources for dep in js_deps],
            ),
            transitive_modules = depset(
                direct = direct_js_modules,
                transitive = [dep.transitive_modules for dep in js_deps],
            ),
        ),
        _TypeScriptInfo(
            direct_modules = direct_ts_modules,
            direct_sources = depset(direct = direct_ts_sources),
        ),
    ]

ts_library = rule(
    _ts_library,
    attrs = {
        "src": attr.label(
            allow_single_file = [".ts"],
        ),
        "deps": attr.label_list(
            providers = [
                [_JavaScriptInfo],
                [_JavaScriptInfo, _TypeScriptInfo],
            ],
        ),
        "import_prefix": attr.string(),
        "strip_import_prefix": attr.string(),
        "tsc_options": attr.string_list(),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
        "_typescript_toolchain": attr.label(
            default = "//typescript:toolchain",
        ),
        "_tsc_wrapper": attr.label(
            default = "//typescript/internal:tsc_wrapper.js",
            allow_single_file = True,
        ),
    },
    provides = [_JavaScriptInfo, _TypeScriptInfo],
)

def _ts_binary_babel(ctx, dep_modules):
    babel_toolchain = ctx.attr._babel_toolchain[_babel_common.ToolchainInfo]

    babel_config_file = ctx.actions.declare_file("_babel/{}/config.js".format(
        ctx.attr.name,
    ))
    preset_env = _babel_common.preset(
        babel_toolchain.babel_modules["@babel/preset-env"],
        {"targets": {"node": "current"}},
    )
    preset_typescript = _babel_common.preset(
        babel_toolchain.babel_modules["@babel/preset-typescript"],
    )
    babel_config = _babel_common.create_config(
        ctx.actions,
        babel_toolchain = babel_toolchain,
        output_file = babel_config_file,
        presets = [preset_env, preset_typescript],
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
        ctx.file.src.short_path.replace(".ts", ".js"),
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

_TS_BINARY_WEBPACK_CONFIG = """
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

def _ts_binary_webpack(ctx, babel_out):
    webpack_toolchain = ctx.attr._webpack_toolchain[_webpack_common.ToolchainInfo]

    webpack_config_file = ctx.actions.declare_file("_webpack/{}/config.js".format(ctx.attr.name))
    ctx.actions.write(
        webpack_config_file,
        "const CONFIG = {};".format(struct(
            webpack = webpack_toolchain.webpack_modules["webpack"].source.path,
            resolve_aliases = [[mod.name, mod.source.path] for mod in babel_out.modules],
        ).to_json()) + _TS_BINARY_WEBPACK_CONFIG,
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

def _ts_binary(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]

    dep_modules = depset(
        transitive = [
            dep[_JavaScriptInfo].transitive_modules
            for dep in ctx.attr.deps
        ],
    )

    babel_out = _ts_binary_babel(ctx, dep_modules)
    webpack_out = _ts_binary_webpack(ctx, babel_out)

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

ts_binary = rule(
    _ts_binary,
    executable = True,
    attrs = {
        "src": attr.label(
            allow_single_file = [".ts"],
            mandatory = True,
        ),
        "deps": attr.label_list(
            providers = [
                [_JavaScriptInfo],
                [_JavaScriptInfo, _TypeScriptInfo],
            ],
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

# region Repository Rules {{{

def _typescript_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    vendor_dir = "@rules_javascript//typescript/internal:typescript_v" + version
    _yarn_vendor_modules(ctx, vendor_dir, tools = {
        "tsc": "typescript/lib/tsc.js",
    })

typescript_repository = repository_rule(
    _typescript_repository,
    attrs = {
        "version": attr.string(mandatory = True),
        "registries": attr.string_list(
            default = _node_common.NPM_REGISTRIES,
        ),
    },
)

# endregion }}}
