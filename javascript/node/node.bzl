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
    "//javascript/node/internal:toolchain.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "NodeToolchainInfo",
)

# region Versions {{{

_MIRRORS = [
    "https://mirror.bazel.build/nodejs.org/dist/",
    "https://nodejs.org/dist/",
    "https://npm.taobao.org/mirrors/node/",
]

def _urls(filename):
    return [m + filename for m in _MIRRORS]

_LATEST = "10.15.0"

_VERSION_URLS = {
    "10.15.0": {
        "darwin-x64": {
            "urls": _urls("v10.15.0/node-v10.15.0-darwin-x64.tar.xz"),
            "sha256": "90c991ad51528705b47312fb63f52cd770c66757b02b782168e4bc6c5165b8be",
        },
        "linux-x64": {
            "urls": _urls("v10.15.0/node-v10.15.0-linux-x64.tar.xz"),
            "sha256": "4ee8503c1133797777880ebf75dcf6ae3f9b894c66fd2d5da507e407064c13b5",
        },
    },
}

def _check_version(version, platform = None):
    if version not in _VERSION_URLS:
        fail("Node.js version {} not supported by rules_javascript".format(repr(version)))
    if platform != None:
        if platform not in _VERSION_URLS[version]:
            fail("Node.js platform {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

node_common = struct(
    VERSIONS = list(_VERSION_URLS),
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
    NPM_REGISTRIES = [
        "https://registry.yarnpkg.com/",
        "https://registry.npmjs.com/",
        "https://registry.npm.taobao.org/",
    ],
)

def node_register_toolchains(version = _LATEST):
    _check_version(version)
    for platform, urls in _VERSION_URLS[version].items():
        repo_name = "node_v{}-{}".format(version, platform)
        if repo_name not in native.existing_rules().keys():
            node_repository(
                name = repo_name,
                version = version,
                platform = platform,
            )
        native.register_toolchains("@rules_javascript//javascript/node/toolchains:v{}-{}".format(version, platform))

# region Repository Rules {{{

def _node_repository(ctx):
    version = ctx.attr.version
    platform = ctx.attr.platform
    _check_version(version, platform)
    source = _VERSION_URLS[version][platform]

    ctx.download_and_extract(
        url = source["urls"],
        sha256 = source["sha256"],
        stripPrefix = "node-v{}-{}".format(version, platform),
    )

    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", 'exports_files(["bin/node"])\n')

node_repository = repository_rule(
    _node_repository,
    attrs = {
        "version": attr.string(mandatory = True),
        "platform": attr.string(mandatory = True),
    },
)

# endregion }}}
