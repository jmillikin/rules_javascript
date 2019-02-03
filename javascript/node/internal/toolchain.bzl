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

TOOLCHAIN_TYPE = "@rules_javascript//javascript/node:toolchain_type"

NodeToolchainInfo = provider(fields = ["files", "vars", "node_executable"])

def _node_toolchain_info(ctx):
    toolchain = NodeToolchainInfo(
        node_executable = ctx.file.node,
        files = depset([ctx.file.node]),
        vars = {"NODE": ctx.file.node.path},
    )
    return [
        platform_common.ToolchainInfo(node_toolchain = toolchain),
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

node_toolchain_info = rule(
    _node_toolchain_info,
    attrs = {
        "node": attr.label(
            allow_single_file = True,
        ),
    },
    provides = [
        platform_common.ToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)

def _node_toolchain_alias(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE].node_toolchain
    return [
        DefaultInfo(files = toolchain.files),
        toolchain,
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

node_toolchain_alias = rule(
    _node_toolchain_alias,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [
        DefaultInfo,
        NodeToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
