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

TOOLCHAIN_TYPE = "@rules_javascript//tools/yarn:toolchain_type"

YarnToolchainInfo = provider(fields = ["files", "vars", "yarn_executable"])

def _yarn_toolchain_info(ctx):
    toolchain = YarnToolchainInfo(
        yarn_executable = ctx.file.yarn_js,
        files = depset([ctx.file.yarn_js]),
        vars = {"YARN": ctx.file.yarn_js.path},
    )
    return [
        platform_common.ToolchainInfo(yarn_toolchain = toolchain),
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

yarn_toolchain_info = rule(
    _yarn_toolchain_info,
    attrs = {
        "yarn_js": attr.label(
            mandatory = True,
            allow_single_file = [".js"],
        ),
    },
    provides = [
        platform_common.ToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)

def _yarn_toolchain_alias(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE].yarn_toolchain
    return [
        DefaultInfo(files = toolchain.files),
        toolchain,
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

yarn_toolchain_alias = rule(
    _yarn_toolchain_alias,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [
        DefaultInfo,
        YarnToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
