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

TOOLCHAIN_TYPE = "@rules_javascript//tools/babel:toolchain_type"

BabelToolchainInfo = provider(fields = ["files", "vars", "babel_executable"])

def _babel_toolchain_info(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
    runfiles = ctx.attr.babel[DefaultInfo].default_runfiles.files
    toolchain = BabelToolchainInfo(
        babel_executable = ctx.executable.babel,
        files = depset(
            direct = [ctx.executable.babel],
            transitive = [
                runfiles,
                node_toolchain.files,
            ],
        ),
        vars = {"BABEL": ctx.executable.babel.path},
    )
    return [
        platform_common.ToolchainInfo(babel_toolchain = toolchain),
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

babel_toolchain_info = rule(
    _babel_toolchain_info,
    attrs = {
        "babel": attr.label(
            mandatory = True,
            executable = True,
            cfg = "host",
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

def _babel_toolchain_alias(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE].babel_toolchain
    return [
        DefaultInfo(files = toolchain.files),
        toolchain,
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

babel_toolchain_alias = rule(
    _babel_toolchain_alias,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [
        DefaultInfo,
        BabelToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
