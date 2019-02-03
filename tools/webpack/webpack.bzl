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
    "//javascript/internal:util.bzl",
    _vendor_node_modules = "vendor_node_modules",
)
load(
    "//tools/webpack/internal:toolchain.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "WebpackToolchainInfo",
)
load(
    "@rules_javascript//javascript/internal:util.bzl",
    _ConfigSettings = "ConfigSettings",
)

# region Versions {{{

_LATEST = "4.29.0"
_VERSIONS = ["4.29.0"]

def _check_version(version):
    if version not in _VERSIONS:
        fail("Webpack version {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

webpack_common = struct(
    VERSIONS = _VERSIONS,
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
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

def _webpack_bundle(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
    webpack_toolchain = ctx.attr._webpack_toolchain[webpack_common.ToolchainInfo]

    settings = ctx.attr._config_settings[_ConfigSettings]
    if settings.compilation_mode == "opt":
        webpack_mode = "production"
    else:
        webpack_mode = "development"

    transitive_deps = depset()
    for dep in ctx.attr.deps:
        dep = dep[_JavaScriptInfo]
        transitive_deps += depset([dep])
        transitive_deps += dep.transitive_deps

    seen_modules = {}
    seen_srcs = {}
    module_paths = []
    direct_deps = []
    transitive_srcs = []
    for src in ctx.files.srcs:
        seen_srcs[src.path] = True
        direct_deps.append([
            src.path,
            [dep[_JavaScriptInfo].module_name for dep in ctx.attr.deps],
        ])
    for dep in transitive_deps:
        if dep.module_name in seen_modules:
            # TODO: include the old name, new name, and labels of the responsible rules
            fail("Duplicate module name {}".format(repr(dep.module_name)))
        seen_modules[dep.module_name] = dep
        if dep.src.path in seen_srcs:
            # TODO: include the old name, new name, and labels of the responsible rules
            fail("Duplicate source file {}".format(repr(dep.src.path)))
        seen_srcs[dep.src.path] = True
    for module_name in sorted(seen_modules):
        dep = seen_modules[module_name]
        module_paths.append([module_name, dep.src.path])
        direct_deps.append([dep.src.path, [subdep.module_name for subdep in dep.direct_deps]])

    transitive_srcs = depset(ctx.files.srcs + [
        dep.src
        for dep in transitive_deps
    ])

    out = ctx.actions.declare_file(ctx.attr.name + ".bundle.js")
    config_js = ctx.actions.declare_file("_webpack/{}/config.js".format(ctx.attr.name))
    inputs = node_toolchain.files + webpack_toolchain.files + transitive_srcs + depset([config_js])
    outputs = [out]

    config = struct(
        webpack_mode = webpack_mode,
        bazel_input_paths = [src.path for src in ctx.files.srcs],
        bazel_output_path = out.path,
        module_paths = module_paths,
        direct_deps = direct_deps,
    )
    ctx.actions.expand_template(
        template = ctx.file._config_tmpl,
        output = config_js,
        substitutions = {
            "{CONFIG_JSON}": config.to_json(),
        },
    )

    argv = ctx.actions.args()
    argv.add_all([
        "--",
        webpack_toolchain.webpack_executable.path,
        "--config=" + config_js.path,
    ])
    argv.add_all(ctx.attr.webpack_options)

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = node_toolchain.node_executable,
        arguments = [argv],
        mnemonic = "Webpack",
        progress_message = "Webpack {}".format(ctx.label),
    )
    return DefaultInfo(files = depset(outputs))

webpack_bundle = rule(
    _webpack_bundle,
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
        "_config_settings": attr.label(
            default = "//javascript/internal:config_settings",
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
    _vendor_node_modules(ctx, vendor_dir)

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
