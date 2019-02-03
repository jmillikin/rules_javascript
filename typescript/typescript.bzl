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
    "//typescript/internal:toolchain.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "TypescriptToolchainInfo",
)

# region Versions {{{

def _urls(filename):
    return [registry + filename for registry in _node_common.NPM_REGISTRIES]

_LATEST = "3.2.4"

_VERSION_URLS = {
    "3.2.4": {
        "urls": _urls("typescript/-/typescript-3.2.4.tgz"),
        "sha256": "4f19aecb8092697c727d063ead0446b09947092b802be2e77deb57c33e06fdad",
    },
}

def _check_version(version):
    if version not in _VERSION_URLS:
        fail("Typescript version {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

# region Toolchain {{{

def typescript_register_toolchains(version = _LATEST):
    _check_version(version)
    repo_name = "typescript_v{}".format(version)
    if repo_name not in native.existing_rules().keys():
        typescript_repository(
            name = repo_name,
            version = version,
        )
    native.register_toolchains("@rules_javascript//typescript/toolchains:v{}".format(version))

# endregion }}}

typescript_common = struct(
    VERSIONS = list(_VERSION_URLS),
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
)

# region Build Rules {{{

_TypeScriptInfo = provider()

def _tsc_declarations(ctx, node_toolchain, typescript_toolchain, tsconfig_file, wrapper_params_file, dep_declarations):
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
            node_toolchain.files,
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
        mnemonic = "Typescript",
        progress_message = "Typechecking {}".format(ctx.label),
    )

    return (declarations, declarations_map)

def _tsc_compile(ctx, node_toolchain, typescript_toolchain, tsconfig_file, wrapper_params_file, dep_declarations):
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
            node_toolchain.files,
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
        mnemonic = "Typescript",
        progress_message = "Compiling {}".format(ctx.label),
    )

    return (js_source, js_source_map)

def _ts_library(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
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
        node_toolchain = node_toolchain,
        typescript_toolchain = typescript_toolchain,
        tsconfig_file = tsconfig_file,
        wrapper_params_file = wrapper_params_file,
        dep_declarations = dep_declarations,
    )

    (js_source, js_source_map) = _tsc_compile(
        ctx = ctx,
        node_toolchain = node_toolchain,
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

    js_direct_deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]
    js_transitive_deps = depset(
        direct = js_direct_deps,
        transitive = [
            dep_js.transitive_deps
            for dep_js in js_direct_deps
        ],
    )

    return [
        DefaultInfo(files = depset([
            js_source,
            js_source_map,
            declarations,
            declarations_map,
        ])),
        _JavaScriptInfo(
            src = js_source,
            module_name = module_name,
            direct_deps = depset(js_direct_deps),
            transitive_deps = js_transitive_deps,
        ),
        _TypeScriptInfo(
            src = ctx.files.src,
            declarations = declarations,
            declarations_map = declarations_map,
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

# endregion }}}

# region Repository Rules {{{

def _typescript_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    source = _VERSION_URLS[version]

    ctx.download_and_extract(
        url = source["urls"],
        sha256 = source["sha256"],
        stripPrefix = "package",
    )

    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.symlink(ctx.attr._overlay_BUILD, "BUILD.bazel")

typescript_repository = repository_rule(
    _typescript_repository,
    attrs = {
        "version": attr.string(mandatory = True),
        "_overlay_BUILD": attr.label(
            default = "//typescript/internal:typescript.BUILD",
            single_file = True,
        ),
    },
)

# endregion }}}
