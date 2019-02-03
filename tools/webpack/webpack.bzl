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
    "//javascript/internal:util.bzl",
    _vendor_node_modules = "vendor_node_modules",
)
load(
    "//tools/webpack/internal:toolchain.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "WebpackToolchainInfo",
)

# region Versions {{{

_LATEST = "4.29.0"
_VERSIONS = ["4.29.0"]

def _check_version(version):
    if version not in _VERSIONS:
        fail("Webpack version {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

webpack_common = struct(
    VERSIONS = _VERSIONS,
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
)

def webpack_register_toolchains(version = _LATEST):
    _check_version(version)
    repo_name = "webpack_v{}".format(version)
    if repo_name not in native.existing_rules().keys():
        webpack_repository(
            name = repo_name,
            version = version,
        )
    native.register_toolchains("@rules_javascript//tools/webpack/toolchains:v{}".format(version))

# region Repository Rules {{{

def _webpack_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    vendor_dir = "@rules_javascript//tools/webpack/internal:webpack_v" + version
    _vendor_node_modules(ctx, vendor_dir)

webpack_repository = repository_rule(
    _webpack_repository,
    attrs = {
        "version": attr.string(mandatory = True),
        "registries": attr.string_list(
            default = _node_common.NPM_REGISTRIES,
        ),
    },
)

# endregion }}}
