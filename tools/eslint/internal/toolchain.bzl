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

TOOLCHAIN_TYPE = "@rules_javascript//tools/eslint:toolchain_type"

EslintToolchainInfo = provider(fields = ["files", "vars", "eslint_executable"])

def _eslint_toolchain_info(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
    runfiles = ctx.attr.eslint[DefaultInfo].default_runfiles.files
    toolchain = EslintToolchainInfo(
        eslint_executable = ctx.executable.eslint,
        files = depset(
            direct = [ctx.executable.eslint],
            transitive = [
                runfiles,
                node_toolchain.files,
            ],
        ),
        vars = {"ESLINT": ctx.executable.eslint.path},
    )
    return [
        platform_common.ToolchainInfo(eslint_toolchain = toolchain),
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

eslint_toolchain_info = rule(
    _eslint_toolchain_info,
    attrs = {
        "eslint": attr.label(
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

def _eslint_toolchain_alias(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE].eslint_toolchain
    return [
        DefaultInfo(files = toolchain.files),
        toolchain,
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

eslint_toolchain_alias = rule(
    _eslint_toolchain_alias,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [
        DefaultInfo,
        EslintToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
