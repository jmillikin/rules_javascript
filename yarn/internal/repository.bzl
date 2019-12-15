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

load(":versions.bzl", "YARN_DEFAULT_VERSION", "YARN_VERSION_URLS")

def _yarn_repository(ctx):
    version = ctx.attr.version
    source = YARN_VERSION_URLS[version]

    ctx.download_and_extract(
        url = source["urls"],
        sha256 = source["sha256"],
        stripPrefix = "yarn-v{}".format(version),
    )

    ctx.template("bin/yarn.js", "bin/yarn.js", substitutions = {
        "require(__dirname + '/../lib/cli')": "require('~/lib/cli')",
    })

    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", "")
    ctx.file("lib/BUILD.bazel", """
load("@rules_javascript//javascript:javascript.bzl", "js_library")
js_library(
    name = "cli",
    srcs = ["cli.js"],
    format = "commonjs",
    visibility = ["//bin:__pkg__"],
)
""")
    ctx.file("bin/BUILD.bazel", """
load("@rules_javascript//javascript:javascript.bzl", "js_binary")
js_binary(
    name = "yarn",
    src = "yarn.js",
    format = "commonjs",
    main = "",
    deps = ["//lib:cli"],
    visibility = ["//visibility:public"],
)
""")

yarn_repository = repository_rule(
    _yarn_repository,
    attrs = {
        "version": attr.string(
            mandatory = True,
            values = list(YARN_VERSION_URLS),
        ),
    },
)
