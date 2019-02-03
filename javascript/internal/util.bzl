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

def _urls(registries, url):
    yarnpkg_com = "https://registry.yarnpkg.com/"
    if url.startswith(yarnpkg_com):
        base = url[len(yarnpkg_com):]
        out = []
        for registry in registries:
            if not registry.endswith("/"):
                registry += "/"
            out.append(registry + base)
        return out
    return [url]

def vendor_node_modules(ctx, vendor_dir):
    ctx.symlink(Label(vendor_dir + "/package.json"), "package.json")
    ctx.symlink(Label(vendor_dir + "/shasums.txt"), "shasums.txt")
    ctx.symlink(Label(vendor_dir + "/yarn.lock"), "yarn.lock")

    cat_cmd = ctx.execute(["cat", "shasums.txt"])
    if cat_cmd.return_code != 0:
        fail("Failed to read shasums: {}".format(cat_cmd.stderr))
    ctx.execute(["rm", "shasums.txt"])

    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", """
load("@rules_javascript//tools/yarn:yarn.bzl", "yarn_install")
yarn_install(
    name = "node_modules",
    package_json = "package.json",
    yarn_lock = "yarn.lock",
    archives = glob(["archives/*.tgz"]),
    visibility = ["//visibility:public"],
)
""")

    for line in cat_cmd.stdout.strip().split("\n"):
        (sha256, filename, url) = line.split("")
        ctx.report_progress("Fetching {}".format(filename))
        ctx.download(
            url = _urls(ctx.attr.registries, url),
            output = "archives/" + filename,
            sha256 = sha256,
        )
