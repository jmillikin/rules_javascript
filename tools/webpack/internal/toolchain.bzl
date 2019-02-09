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
    "//javascript/node:node.bzl",
    _node_common = "node_common",
)

TOOLCHAIN_TYPE = "@rules_javascript//tools/webpack:toolchain_type"

WebpackConfigInfo = provider(fields = ["files", "webpack_config_file"])

WebpackToolchainInfo = provider(fields = ["files", "vars", "webpack_executable", "webpack_modules"])

def _webpack_toolchain_info(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
    runfiles = ctx.attr.webpack[DefaultInfo].default_runfiles.files

    webpack_modules = {}
    node_modules = ctx.attr.node_modules[_JavaScriptInfo]
    for module in node_modules.direct_modules:
        webpack_modules[module.name] = module

    toolchain = WebpackToolchainInfo(
        webpack_executable = ctx.executable.webpack,
        webpack_modules = webpack_modules,
        files = depset(
            direct = [ctx.executable.webpack],
            transitive = [
                runfiles,
                node_toolchain.files,
            ],
        ),
        vars = {"WEBPACK": ctx.executable.webpack.path},
    )
    return [
        platform_common.ToolchainInfo(webpack_toolchain = toolchain),
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

webpack_toolchain_info = rule(
    _webpack_toolchain_info,
    attrs = {
        "webpack": attr.label(
            mandatory = True,
            executable = True,
            cfg = "host",
        ),
        "node_modules": attr.label(
            mandatory = True,
            providers = [_JavaScriptInfo, _NodeModulesInfo],
        ),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
    },
    provides = [
        platform_common.ToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)

def _webpack_toolchain_alias(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE].webpack_toolchain
    return [
        DefaultInfo(files = toolchain.files),
        toolchain,
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

webpack_toolchain_alias = rule(
    _webpack_toolchain_alias,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [
        DefaultInfo,
        WebpackToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
