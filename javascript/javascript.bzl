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
    _NodeModulesInfo = "NodeModulesInfo",
)
load(
    "//javascript/node:node.bzl",
    _node_common = "node_common",
    _node_register_toolchains = "node_register_toolchains",
)
load(
    "//tools/babel:babel.bzl",
    _babel_register_toolchains = "babel_register_toolchains",
)
load(
    "//tools/eslint:eslint.bzl",
    _eslint_register_toolchains = "eslint_register_toolchains",
)
load(
    "//tools/webpack:webpack.bzl",
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

def _js_library(ctx):
    # TODO: adjust 'module_name' based on {strip_,}import_prefix
    module_name = "{}/{}".format(ctx.label.package, ctx.label.name)

    direct_deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]
    transitive_srcs = depset(
        direct = ctx.files.src,
        transitive = [
            dep_js.transitive_srcs
            for dep_js in direct_deps
        ],
    )
    transitive_deps = depset(
        direct = direct_deps,
        transitive = [
            dep_js.transitive_deps
            for dep_js in direct_deps
        ],
    )

    return _JavaScriptInfo(
        src = ctx.file.src,
        module_name = module_name,
        direct_deps = depset(direct_deps),
        transitive_srcs = transitive_srcs,
        transitive_deps = transitive_deps,
    )

js_library = rule(
    _js_library,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
            mandatory = True,
        ),
        "deps": attr.label_list(
            providers = [_JavaScriptInfo],
        ),
        "import_prefix": attr.string(),
        "strip_import_prefix": attr.string(),
    },
    provides = [_JavaScriptInfo],
)

def _js_binary(ctx):
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
                main = ctx.file.src.path,
                workspace_name = ctx.workspace_name,
            ).to_json(),
        },
        is_executable = True,
    )

    return DefaultInfo(
        runfiles = ctx.runfiles(
            files = [ctx.file.src] + node_modules,
            transitive_files = depset(transitive = [
                transitive_srcs,
                node_toolchain.files,
            ]),
        ),
    )

js_binary = rule(
    _js_binary,
    executable = True,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
        ),
        "deps": attr.label_list(
            providers = [
                [_JavaScriptInfo],
                [_NodeModulesInfo],
            ],
        ),
        "node_options": attr.string_list(),
        "_launcher_template": attr.label(
            default = "//javascript/internal:js_binary.tmpl.js",
            allow_single_file = True,
        ),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
    },
)

# endregion }}}
