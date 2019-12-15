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

load("@rules_javascript//javascript/internal/node:versions.bzl", "NODE_VERSION_URLS", "node_check_version")

def _node_repository(ctx):
    platform_rename = {
        "x86_64-linux": "linux-x64",
        "x86_64-darwin": "darwin-x64",
    }
    version = ctx.attr.version
    platform = ctx.attr.platform
    node_check_version(version, platform)
    source = NODE_VERSION_URLS[version][platform]

    ctx.download_and_extract(
        url = source["urls"],
        sha256 = source["sha256"],
        stripPrefix = "node-v{}-{}".format(version, platform_rename[platform]),
    )

    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", 'exports_files(["bin/node"])\n')

node_repository = repository_rule(
    _node_repository,
    attrs = {
        "version": attr.string(
            mandatory = True,
        ),
        "platform": attr.string(
            mandatory = True,
        ),
        "engine": attr.string(
            default = "v8",
            values = ["chakracore", "v8"],
        ),
    },
)
