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

JAVASCRIPT_TOOLCHAIN_TYPE = "@rules_javascript//javascript:toolchain_type"

JavascriptToolchainInfo = provider(fields = ["all_files", "actions"])

def _template_vars(toolchain):
    return platform_common.TemplateVariableInfo({
        "NODE": toolchain.actions.node_tool.executable.path,
        # TODO
    })

def _javascript_toolchain_alias(ctx):
    toolchain = ctx.toolchains[JAVASCRIPT_TOOLCHAIN_TYPE].javascript_toolchain
    return [
        DefaultInfo(files = toolchain.all_files),
        _template_vars(toolchain),
    ]

javascript_toolchain_alias = rule(
    _javascript_toolchain_alias,
    toolchains = [JAVASCRIPT_TOOLCHAIN_TYPE],
    provides = [
        DefaultInfo,
        platform_common.TemplateVariableInfo,
    ],
)
