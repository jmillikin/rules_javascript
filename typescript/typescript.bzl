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
    _NodeModulesInfo = "NodeModulesInfo",
)
load(
    "//javascript/internal:util.bzl",
    _vendor_yarn_modules = "vendor_yarn_modules",
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

_TypeScriptInfo = provider()

def _tsc_declarations(ctx, typescript_toolchain, tsconfig_file, wrapper_params_file, dep_declarations):
    declarations = ctx.actions.declare_file("{}.d.ts".format(ctx.attr.name))
    declarations_map = ctx.actions.declare_file("{}.d.ts.map".format(ctx.attr.name))

    args = ctx.actions.args()
    args.add_all([
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
        executable = ctx.executable._tsc_wrapper,
        arguments = [args],
        inputs = inputs,
        outputs = [declarations, declarations_map],
        mnemonic = "TypeScriptCheck",
        progress_message = "Typechecking {}".format(ctx.label),
    )

    return (declarations, declarations_map)

def _tsc_compile(ctx, typescript_toolchain, tsconfig_file, wrapper_params_file, dep_declarations):
    js_source = ctx.actions.declare_file("{}.js".format(ctx.attr.name))
    js_source_map = ctx.actions.declare_file("{}.js.map".format(ctx.attr.name))

    args = ctx.actions.args()
    args.add_all([
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
        executable = ctx.executable._tsc_wrapper,
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
        dep_js = dep[_JavaScriptInfo]
        dep_ts = dep[_TypeScriptInfo]
        importable_paths[dep_js.module_name] = [dep_ts.declarations.path]
        dep_declarations.append(dep_ts.declarations)

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
    common = _ts_common(ctx)

    js_direct_deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]
    js_transitive_srcs = depset(
        direct = [common.js_source],
        transitive = [
            dep_js.transitive_srcs
            for dep_js in js_direct_deps
        ],
    )
    js_transitive_deps = depset(
        direct = js_direct_deps,
        transitive = [
            dep_js.transitive_deps
            for dep_js in js_direct_deps
        ],
    )

    return [
        DefaultInfo(files = depset([
            common.js_source,
            common.js_source_map,
            common.declarations,
            common.declarations_map,
        ])),
        _JavaScriptInfo(
            src = common.js_source,
            module_name = common.module_name,
            direct_deps = depset(js_direct_deps),
            transitive_srcs = js_transitive_srcs,
            transitive_deps = js_transitive_deps,
        ),
        _TypeScriptInfo(
            src = ctx.files.src,
            declarations = common.declarations,
            declarations_map = common.declarations_map,
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
                # [_JavaScriptInfo],
                [_JavaScriptInfo, _TypeScriptInfo],
                # [_NodeModulesInfo],
            ],
        ),
        "import_prefix": attr.string(),
        "strip_import_prefix": attr.string(),
        "tsc_options": attr.string_list(),
        "_typescript_toolchain": attr.label(
            default = "//typescript:toolchain",
        ),
        "_tsc_wrapper": attr.label(
            default = "//typescript/internal:tsc_wrapper",
            executable = True,
            cfg = "host",
        ),
    },
    provides = [_JavaScriptInfo, _TypeScriptInfo],
)

def _ts_binary(ctx):
    common = _ts_common(ctx)

    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]

    node_path = []
    node_modules = []
    for dep in ctx.attr.deps:
        if _NodeModulesInfo in dep:
            dep_modules = dep[_NodeModulesInfo].node_modules
            node_modules.append(dep_modules)
            node_path.append(dep_modules.path)

    transitive_srcs = depset(
        transitive = [
            dep[_JavaScriptInfo].transitive_srcs
            for dep in ctx.attr.deps
            if _JavaScriptInfo in dep
        ],
    )

    ctx.actions.expand_template(
        template = ctx.file._launcher_template,
        output = ctx.outputs.executable,
        substitutions = {
            "{NODE_EXECUTABLE}": node_toolchain.node_executable.path,
            "{JS_BINARY_CONFIG}": struct(
                node_path = node_path,
                node_args = ctx.attr.node_options,
                main = common.js_source.short_path,
                workspace_name = ctx.workspace_name,
            ).to_json(),
        },
        is_executable = True,
    )

    return DefaultInfo(
        runfiles = ctx.runfiles(
            files = [common.js_source] + node_modules,
            transitive_files = depset(transitive = [
                transitive_srcs,
                node_toolchain.files,
            ]),
        ),
    )

ts_binary = rule(
    _ts_binary,
    executable = True,
    attrs = {
        "src": attr.label(
            allow_single_file = [".ts"],
        ),
        "deps": attr.label_list(
            providers = [
                # [_JavaScriptInfo],
                [_JavaScriptInfo, _TypeScriptInfo],
                [_NodeModulesInfo],
            ],
        ),
        "node_options": attr.string_list(),
        "tsc_options": attr.string_list(),
        "_launcher_template": attr.label(
            default = "//javascript/internal:js_binary.tmpl.js",
            allow_single_file = True,
        ),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
        "_typescript_toolchain": attr.label(
            default = "//typescript:toolchain",
        ),
        "_tsc_wrapper": attr.label(
            default = "//typescript/internal:tsc_wrapper",
            executable = True,
            cfg = "host",
        ),
    },
)

# endregion }}}

# region Repository Rules {{{

def _typescript_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    vendor_dir = "@rules_javascript//typescript/internal:typescript_v" + version
    _vendor_yarn_modules(ctx, vendor_dir, bins = {
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
