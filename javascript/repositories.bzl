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
    "@rules_javascript//javascript/internal/deno:repository.bzl",
    _deno_repository = "deno_repository",
)
load(
    "@rules_javascript//javascript/internal/deno:versions.bzl",
    "DENO_DEFAULT_VERSION",
    "DENO_VERSION_URLS",
    "deno_check_version",
)
load(
    "@rules_javascript//javascript/internal/node:repository.bzl",
    _node_repository = "node_repository",
)
load(
    "@rules_javascript//javascript/internal/node:versions.bzl",
    "NODE_DEFAULT_VERSION",
    "NODE_VERSION_URLS",
    "NODE_CHAKRACORE_VERSION_URLS",
    "node_check_version",
)

deno_repository = _deno_repository
node_repository = _node_repository

def rules_javascript_toolchains(
    *,
    deno_version = DENO_DEFAULT_VERSION,
    node_version = NODE_DEFAULT_VERSION,
):
    _maybe(
        _rules_javascript_tools,
        repo_name = "rules_javascript_tools",
    )
    if node_version != None:
        node_check_version(node_version)
    if deno_version != None:
        deno_check_version(deno_version)

    if node_version != None:
        _node_register_toolchains(node_version)
    if deno_version != None:
        _deno_register_toolchains(deno_version)

def _maybe(repo_rule, repo_name, **kwargs):
    if repo_name in native.existing_rules().keys():
        return
    repo_rule(name = repo_name, **kwargs)

def _node_register_toolchains(version):
    platform_rename = {
        "x86_64-linux": "linux-x64",
        "x86_64-darwin": "darwin-x64",
    }
    v8_items = NODE_VERSION_URLS.get(version, {}).items()
    for platform, urls in v8_items:
        _maybe(
            node_repository,
            repo_name = "node_v{}-{}".format(version, platform_rename[platform]),
            version = version,
            platform = platform,
        )
        native.register_toolchains("@rules_javascript//javascript/toolchains/node:v{}/{}".format(version, platform))

    chakracore_items = NODE_CHAKRACORE_VERSION_URLS.get(version, {}).items()
    for platform, urls in chakracore_items:
        _maybe(
            node_repository,
            repo_name = "node-chakracore_v{}-{}".format(version, platform_rename[platform]),
            version = version,
            platform = platform,
            engine = "chakracore",
        )
        native.register_toolchains("@rules_javascript//javascript/toolchains/node-chakracore:v{}/{}".format(version, platform))

def _deno_register_toolchains(version):
    platform_rename = {
        "x86_64-linux": "linux_x64",
        "x86_64-darwin": "osx_x64",
    }
    for platform, urls in DENO_VERSION_URLS[version].items():
        _maybe(
            deno_repository,
            repo_name = "deno_v{}-{}".format(version, platform_rename[platform]),
            version = version,
            platform = platform,
        )
        native.register_toolchains("@rules_javascript//javascript/toolchains/deno:v{}/{}".format(version, platform))

def _rules_javascript_tools_impl(ctx):
    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", """
filegroup(
    name = "acorn",
    srcs = ["acorn-7.1.0/dist/acorn.js"],
    visibility = ["@rules_javascript//:__subpackages__"],
)
""")

    ctx.download_and_extract(
        url = [
            "https://registry.yarnpkg.com/acorn/-/acorn-7.1.0.tgz",
            "https://registry.npmjs.com/acorn/-/acorn-7.1.0.tgz",
            "https://registry.npm.taobao.org/acorn/-/acorn-7.1.0.tgz",
        ],
        sha256 = "a1b880de061bc27f38fd610ad73938d3d2e3ca2946c3cc78c2b358649493f1ca",
        stripPrefix = "package",
        output = "acorn-7.1.0",
    )

_rules_javascript_tools = repository_rule(
    _rules_javascript_tools_impl,
)
