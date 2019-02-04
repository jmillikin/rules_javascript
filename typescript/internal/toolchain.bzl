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

TOOLCHAIN_TYPE = "@rules_javascript//typescript:toolchain_type"

TypeScriptToolchainInfo = provider(fields = ["files", "vars", "tsc_executable"])

def _typescript_toolchain_info(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
    runfiles = ctx.attr.tsc[DefaultInfo].default_runfiles.files
    toolchain = TypeScriptToolchainInfo(
        tsc_executable = ctx.executable.tsc,
        files = depset(
            direct = [ctx.executable.tsc],
            transitive = [
                runfiles,
                node_toolchain.files,
            ],
        ),
        vars = {"TSC": ctx.executable.tsc.path},
    )
    return [
        platform_common.ToolchainInfo(typescript_toolchain = toolchain),
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

typescript_toolchain_info = rule(
    _typescript_toolchain_info,
    attrs = {
        "tsc": attr.label(
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

def _typescript_toolchain_alias(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE].typescript_toolchain
    return [
        DefaultInfo(files = toolchain.files),
        toolchain,
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

typescript_toolchain_alias = rule(
    _typescript_toolchain_alias,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [
        DefaultInfo,
        TypeScriptToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
