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

TOOLCHAIN_TYPE = "@rules_javascript//typescript:toolchain_type"

TypescriptToolchainInfo = provider(fields = ["files", "vars", "tsc_executable"])

def _typescript_toolchain_info(ctx):
    toolchain = TypescriptToolchainInfo(
        tsc_executable = ctx.file.tsc_js,
        files = depset([ctx.file.tsc_js]) + ctx.files.tsc_files,
        vars = {"TSC": ctx.file.tsc_js.path},
    )
    return [
        platform_common.ToolchainInfo(typescript_toolchain = toolchain),
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

typescript_toolchain_info = rule(
    _typescript_toolchain_info,
    attrs = {
        "tsc_js": attr.label(
            allow_single_file = [".js"],
        ),
        "tsc_files": attr.label(),
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
        TypescriptToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
