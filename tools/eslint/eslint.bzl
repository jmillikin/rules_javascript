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
load(
    "//tools/yarn/internal:yarn_vendor.bzl",
    _yarn_vendor_modules = "yarn_vendor_modules",
)
load(
    "//tools/eslint/internal:toolchain.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "EslintToolchainInfo",
)

# region Versions {{{

_LATEST = "5.13.0"
_VERSIONS = ["5.13.0"]

def _check_version(version):
    if version not in _VERSIONS:
        fail("ESLint version {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

eslint_common = struct(
    VERSIONS = _VERSIONS,
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
)

def eslint_register_toolchains(version = _LATEST):
    _check_version(version)
    repo_name = "eslint_v{}".format(version)
    if repo_name not in native.existing_rules().keys():
        eslint_repository(
            name = repo_name,
            version = version,
        )
    native.register_toolchains("@rules_javascript//tools/eslint/toolchains:v{}".format(version))

# region Repository Rules {{{

def _eslint_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    vendor_dir = "@rules_javascript//tools/eslint/internal:eslint_v" + version
    _yarn_vendor_modules(ctx, vendor_dir, tools = {
        "eslint": "eslint/bin/eslint.js",
    })

eslint_repository = repository_rule(
    _eslint_repository,
    attrs = {
        "version": attr.string(mandatory = True),
        "registries": attr.string_list(
            default = _node_common.NPM_REGISTRIES,
        ),
    },
)

# endregion }}}
