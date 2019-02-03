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

TOOLCHAIN_TYPE = "@rules_javascript//tools/webpack:toolchain_type"

WebpackToolchainInfo = provider(fields = ["files", "vars", "webpack_executable"])

def _webpack_toolchain_info(ctx):
    webpack_js = "{}/{}".format(ctx.file.node_modules.path, ctx.attr.webpack_js)
    toolchain = WebpackToolchainInfo(
        webpack_executable = webpack_js,
        files = depset(ctx.files.node_modules),
        vars = {"WEBPACK": webpack_js},
    )
    return [
        platform_common.ToolchainInfo(webpack_toolchain = toolchain),
        platform_common.TemplateVariableInfo(toolchain.vars),
    ]

webpack_toolchain_info = rule(
    _webpack_toolchain_info,
    attrs = {
        "node_modules": attr.label(
            mandatory = True,
            single_file = True,
        ),
        "webpack_js": attr.string(),
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
