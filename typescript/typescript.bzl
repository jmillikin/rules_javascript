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

_TsLibraryInfo = provider()

def _ts_library(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
    typescript_toolchain = ctx.attr._typescript_toolchain[typescript_common.ToolchainInfo]

    importable_paths = {}
    dep_files = []
    for dep_target in ctx.attr.deps:
        dep = dep_target[_TsLibraryInfo]
        importable_paths[dep.module_name] = [dep.declarations.path]
        dep_files.append(dep.declarations)

    project_config = ctx.actions.declare_file("_tsconfig/{}.json".format(ctx.attr.name))

    # The source will be resolved relative to the project config directory.
    rel_execroot = "../" * len(project_config.dirname.split("/"))
    src_relpath = "{}{}".format(rel_execroot, ctx.file.src.path)

    tsconfig = struct(
        compilerOptions = struct(
            types = [],
            paths = importable_paths,
            declaration = True,
            emitDeclarationOnly = True,
            pretty = True,
            moduleResolution = "Classic",
            forceConsistentCasingInFileNames = True,
        ),
        files = [src_relpath],
    )

    ctx.actions.write(project_config, tsconfig.to_json())

    declarations = ctx.actions.declare_file("{}.d.ts".format(ctx.attr.name))
    args = ctx.actions.args()
    args.add_all([
        typescript_toolchain.tsc_executable,
        "--baseUrl",
        ".",
        "--rootDir",
        ".",
        "--project",
        project_config.path,
        "--outFile",
        declarations.path,
    ])

    inputs = depset(
        direct = [ctx.file.src, project_config],
        transitive = [
            node_toolchain.files,
            typescript_toolchain.files,
            depset(dep_files),
        ],
    )

    ctx.actions.run(
        executable = node_toolchain.node_executable,
        arguments = [args],
        inputs = inputs,
        outputs = [declarations],
        mnemonic = "Typescript",
        progress_message = "Typechecking {}".format(ctx.label),
    )

    transitive_srcs = depset(
        direct = [ctx.file.src],
        transitive = [
            dep[_TsLibraryInfo].transitive_srcs
            for dep in ctx.attr.deps
        ],
    )

    # TODO: adjust 'module_name' based on {strip_,}import_prefix
    module_name = "{}/{}".format(ctx.label.package, ctx.label.name)

    return [
        DefaultInfo(files = depset([declarations])),
        _TsLibraryInfo(
            src = ctx.files.src,
            declarations = declarations,
            module_name = module_name,
            transitive_srcs = transitive_srcs,
        ),
    ]

ts_library = rule(
    _ts_library,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js", ".jsx", ".ts", ".tsx"],
        ),
        "deps": attr.label_list(
            providers = [_TsLibraryInfo],
        ),
        "import_prefix": attr.string(),
        "strip_import_prefix": attr.string(),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
        "_typescript_toolchain": attr.label(
            default = "//typescript:toolchain",
        ),
    },
    provides = [_TsLibraryInfo],
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
