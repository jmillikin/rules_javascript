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

load("@rules_javascript//javascript/internal/deno:versions.bzl", "DENO_VERSION_URLS", "deno_check_version")

def _deno_repository(ctx):
    platform_rename = {
        "x86_64-linux": "linux_x64",
        "x86_64-darwin": "osx_x64",
    }
    version = ctx.attr.version
    platform = ctx.attr.platform
    deno_check_version(version, platform)
    source = DENO_VERSION_URLS[version][platform]

    #ctx.download_and_extract(
    #    url = source["urls"],
    #    sha256 = source["sha256"],
    #    stripPrefix = "node-v{}-{}".format(version, platform),
    #)

    ctx.download(
        url = source["urls"],
        sha256 = source["sha256"],
        output = "bin/deno.gz",
        executable = True,
    )
    exec_result = ctx.execute(["gzip", "-d", "bin/deno.gz"])
    if exec_result.return_code != 0:
        fail(exec_result.stderr)

    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", 'exports_files(["bin/deno"])\n')

deno_repository = repository_rule(
    _deno_repository,
    attrs = {
        "version": attr.string(
            mandatory = True,
        ),
        "platform": attr.string(
            mandatory = True,
        ),
    },
)
