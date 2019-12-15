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

YARN_TOOLCHAIN_TYPE = "@rules_javascript//yarn:toolchain_type"

YarnToolchainInfo = provider(fields = ["all_files", "yarn_tool", "yarn_env"])

def _template_vars(toolchain):
    return platform_common.TemplateVariableInfo({
        "YARN": toolchain.yarn_tool.executable.path,
    })

def _yarn_toolchain_info(ctx):
    yarn_runfiles = ctx.attr.yarn_tool[DefaultInfo].default_runfiles.files
    toolchain = YarnToolchainInfo(
        all_files = depset(
            direct = [ctx.executable.yarn_tool],
            transitive = [yarn_runfiles],
        ),
        yarn_tool = ctx.attr.yarn_tool.files_to_run,
        yarn_env = ctx.attr.yarn_env,
    )
    return [
        platform_common.ToolchainInfo(yarn_toolchain = toolchain),
        _template_vars(toolchain),
    ]

yarn_toolchain_info = rule(
    _yarn_toolchain_info,
    attrs = {
        "yarn_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "host",
        ),
        "yarn_env": attr.string_dict(),
    },
    provides = [
        platform_common.ToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)

def _yarn_toolchain_alias(ctx):
    toolchain = ctx.toolchains[YARN_TOOLCHAIN_TYPE].yarn_toolchain
    return [
        DefaultInfo(files = toolchain.all_files),
        _template_vars(toolchain),
    ]

yarn_toolchain_alias = rule(
    _yarn_toolchain_alias,
    toolchains = [YARN_TOOLCHAIN_TYPE],
    provides = [
        DefaultInfo,
        platform_common.TemplateVariableInfo,
    ],
)
