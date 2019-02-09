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
    "//javascript/internal:providers.bzl",
    _JavaScriptInfo = "NodeModulesInfo",
)
load(
    "//javascript/node:node.bzl",
    _node_common = "node_common",
)
load(
    "//tools/yarn/internal:toolchain.bzl",
    _TOOLCHAIN_TYPE = "TOOLCHAIN_TYPE",
    _ToolchainInfo = "YarnToolchainInfo",
)
load("//tools/yarn/internal:yarn_install.bzl", "yarn_install")

# region Versions {{{

_RELEASE_MIRRORS = [
    "https://mirror.bazel.build/github.com/yarnpkg/yarn/releases/download/",
    "https://github.com/yarnpkg/yarn/releases/download/",
]

def _urls(release_filename, npm_filename):
    urls = [m + release_filename for m in _RELEASE_MIRRORS]
    urls += [registry + npm_filename for registry in _node_common.NPM_REGISTRIES]
    return urls

_LATEST = "1.13.0"

_VERSION_URLS = {
    "1.13.0": {
        "urls": _urls("v1.13.0/yarn-v1.13.0.tar.gz", "yarn/-/yarn-1.13.0.tgz"),
        "sha256": "125d40ebf621ebb08e3f66a618bd2cc5cd77fa317a312900a1ab4360ed38bf14",
    },
}

def _check_version(version):
    if version not in _VERSION_URLS:
        fail("Yarn version {} not supported by rules_javascript".format(repr(version)))

# endregion }}}

yarn_common = struct(
    VERSIONS = list(_VERSION_URLS),
    ToolchainInfo = _ToolchainInfo,
    TOOLCHAIN_TYPE = _TOOLCHAIN_TYPE,
)

def yarn_register_toolchains(version = _LATEST):
    _check_version(version)
    repo_name = "yarn_v{}".format(version)
    if repo_name not in native.existing_rules().keys():
        yarn_repository(
            name = repo_name,
            version = version,
        )
    native.register_toolchains("@rules_javascript//tools/yarn/toolchains:v{}".format(version))

# region Repository Rules {{{

def _yarn_lock_name(line):
    start = 0
    if line.startswith('"'):
        start = 1
    terminus = line.index("@", start + 1)
    return line[start:terminus]

def _yarn_lock_filename(package):
    name = package["name"].replace("/", "-")
    return "{}-{}.tgz".format(name, package["version"])

def _parse_yarn_lock(yarn_lock):
    packages = []
    current = None
    for line in yarn_lock.split("\n"):
        if line == "" or line.startswith("#"):
            continue
        if not line.startswith(" "):
            current = {"name": _yarn_lock_name(line)}
            packages.append(current)
            continue
        if line.startswith('  version "'):
            current["version"] = line[len('  version "'):-1]
            current["filename"] = _yarn_lock_filename(current)
        elif line.startswith('  resolved "'):
            current["resolved"] = line[len('  resolved "'):-1]
        elif line.startswith("  integrity sha"):
            current["integrity"] = [line[len("  integrity "):]]
    return packages

def _yarn_urls(registries, package):
    url = package["resolved"]
    fragment_start = url.find("#")
    if fragment_start != -1:
        url = url[:fragment_start]

    yarnpkg_com = "https://registry.yarnpkg.com/"
    if url.startswith(yarnpkg_com):
        base = url[len(yarnpkg_com):]
        out = []
        for registry in registries:
            out.append(registry + base)
        return out

    return [url]

_YARN_MODULES_BUILD = """
load("@rules_javascript//tools/yarn:yarn.bzl", "yarn_install")
yarn_install(
    name = "node_modules",
    package_json = "package.json",
    yarn_lock = "yarn.lock",
    archives = glob(["archives/*.tgz"]),
    modules = {modules}
    visibility = ["//visibility:public"],
)
"""

_YARN_MODULES_BIN_BUILD = """
load("@rules_javascript//tools/yarn/internal:yarn_install.bzl", "yarn_modules_tool")
[yarn_modules_tool(
    name = tool_name,
    main = tool_main,
    node_modules = "//:node_modules",
    visibility = ["//visibility:public"],
) for (tool_name, tool_main) in {tools}]
"""

def _yarn_node_modules(ctx):
    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))

    ctx.symlink(ctx.attr.package_json, "package.json")
    ctx.symlink(ctx.attr.yarn_lock, "yarn.lock")

    cat_cmd = ctx.execute(["cat", "yarn.lock"])
    if cat_cmd.return_code != 0:
        fail("Failed to read yarn.lock: {}".format(cat_cmd.stderr))

    for package in _parse_yarn_lock(cat_cmd.stdout):
        urls = _yarn_urls(ctx.attr.registries, package)
        ctx.report_progress("Fetching {}".format(package["filename"]))
        ctx.download(
            url = urls,
            output = "archives/" + package["filename"],
            sha256 = "",
            # https://github.com/bazelbuild/bazel/pull/7208
            # integrity = package["integrity"]
        )

    ctx.file("BUILD.bazel", _YARN_MODULES_BUILD.format(
        modules = repr(sorted(ctx.attr.modules)),
    ))
    if ctx.attr.tools:
        ctx.file("bin/BUILD.bazel", _YARN_MODULES_BIN_BUILD.format(
            tools = repr(sorted(ctx.attr.tools.items())),
        ))

yarn_node_modules = repository_rule(
    _yarn_node_modules,
    attrs = {
        "package_json": attr.label(
            allow_single_file = [".json"],
            mandatory = True,
        ),
        "yarn_lock": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "registries": attr.string_list(
            default = _node_common.NPM_REGISTRIES,
        ),
        "modules": attr.string_list(),
        "tools": attr.string_dict(),
    },
)

def _yarn_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    source = _VERSION_URLS[version]

    ctx.download_and_extract(
        url = source["urls"],
        sha256 = source["sha256"],
        stripPrefix = "yarn-v{}".format(version),
    )

    # Disable warning about ignoring scripts when called with `--ignore-scripts`.
    ctx.template("lib/cli.js", "lib/cli.js", substitutions = {
        "_this2.reporter.warn(_this2.reporter.lang('ignoredScripts'));": "",
    }, executable = False)

    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", """
filegroup(
    name = "cli_js",
    srcs = ["lib/cli.js"],
    visibility = ["//bin:__pkg__"],
)
""")
    ctx.file("bin/BUILD.bazel", """
load("@rules_javascript//tools/yarn/internal:yarn_install.bzl", "yarn_modules_tool")
yarn_modules_tool(
    name = "yarn",
    main_src = "//:cli_js",
    visibility = ["//visibility:public"],
)
""")

yarn_repository = repository_rule(
    _yarn_repository,
    attrs = {
        "version": attr.string(mandatory = True),
    },
)

# endregion }}}
