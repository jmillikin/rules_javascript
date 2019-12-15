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

load("@rules_javascript//yarn/internal:versions.bzl", "YARN_DEFAULT_VERSION")
load("@rules_javascript//yarn/internal:repository.bzl", _yarn_repository = "yarn_repository")
load("@rules_javascript//yarn/internal:toolchain.bzl", _YARN_TOOLCHAIN_TYPE = "YARN_TOOLCHAIN_TYPE")
load("@rules_javascript//yarn/internal:lockfile_parser.bzl", "parse_yarn_lock")
load("@rules_javascript//javascript/internal:providers.bzl", "JsInfo", "JsPackageInfo")

YARN_TOOLCHAIN_TYPE = _YARN_TOOLCHAIN_TYPE
yarn_repository = _yarn_repository

_DEFAULT_REGISTRIES = [
    "https://registry.yarnpkg.com/",
    "https://registry.npmjs.com/",
    "https://registry.npm.taobao.org/",
]

def _yarn_archives(ctx):
    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", """filegroup(
    name = {name},
    srcs = glob(["archives/*.tgz"]),
    visibility = ["//visibility:public"],
)""".format(name = repr(ctx.name)))

    archive_filenames = []
    urls = {}
    integrity = {}
    for lockfile in ctx.attr.lockfiles:
        lockfile_content = ctx.read(lockfile)
        for package in parse_yarn_lock(lockfile_content):
            archive_filename = "{}-{}.tgz".format(
                package["name"].replace("/", "-"),
                package["version"]
            )
            if archive_filename not in urls:
                archive_filenames.append(archive_filename)
                urls[archive_filename] = _registry_urls(
                    ctx.attr.registries,
                    package["resolved"],
                )
            if archive_filename not in integrity:
                if "integrity" in package:
                    integrity[archive_filename] = package["integrity"]

    for archive_filename in archive_filenames:
        ctx.download(
            url = urls[archive_filename],
            output = "archives/" + archive_filename,
            integrity = integrity.get(archive_filename, ""),
        )

def _registry_urls(registries, url):
    yarnpkg_com = "https://registry.yarnpkg.com/"
    if not url.startswith(yarnpkg_com):
        return [url]
    base = url[len(yarnpkg_com):]
    out = []
    for registry in registries:
        out.append(registry + base)
    return out

yarn_archives = repository_rule(
    _yarn_archives,
    attrs = {
        "lockfiles": attr.label_list(
            allow_files = True,
            mandatory = True,
            allow_empty = False,
        ),
        "registries": attr.string_list(
            default = _DEFAULT_REGISTRIES,
        ),
    },
)

def _yarn_install(ctx):
    node_modules = ctx.actions.declare_directory(ctx.attr.name + "/node_modules")
    package_roots = {}
    for package in ctx.attr.packages:
        package_roots[package] = ctx.actions.declare_directory("{}/node_modules/{}".format(
            ctx.attr.name,
            package,
        ))

    archives_json = ctx.actions.declare_file(ctx.attr.name + "/archives.json")
    ctx.actions.write(
        archives_json,
        struct(
            archives = [{
                "path": f.path,
            } for f in ctx.files.archives],
        ).to_json(),
    )

    yarn = ctx.toolchains[YARN_TOOLCHAIN_TYPE].yarn_toolchain

    argv = ctx.actions.args()
    argv.add(struct(
        yarn = yarn.yarn_tool.executable.path,
        modules_folder = node_modules.path,
        yarn_options = ctx.attr.yarn_options,
        package_json = ctx.file.package_json.path,
        archives_json = archives_json.path,
        yarn_lock = ctx.file.yarn_lock.path,
    ).to_json())

    inputs = depset(
        direct = [
            archives_json,
            ctx.file.package_json,
            ctx.file.yarn_lock,
        ] + ctx.files.archives,
        transitive = [
            yarn.all_files,
        ]
    )
    outputs = [node_modules] + package_roots.values()

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = ctx.executable._yarn_install,
        arguments = [argv],
        tools = [
            yarn.yarn_tool,
        ],
        mnemonic = "Yarn",
        progress_message = "Yarn install {}".format(ctx.label),
    )

    return [
        DefaultInfo(files = depset(direct = outputs)),
        JsInfo(
            packages = dict([
                (name, JsPackageInfo(
                    root = package_roots[name],
                    format = "commonjs",
                ))
                for name in ctx.attr.packages
            ]),
            modules = {},
            direct_deps = [],
            transitive_deps = depset(),
            direct_files = outputs,
            transitive_files = depset(direct = outputs),
        ),
    ]

yarn_install = rule(
    _yarn_install,
    attrs = {
        "archives": attr.label_list(
            allow_files = [".tgz"],
            allow_empty = False,
            mandatory = True,
        ),
        "package_json": attr.label(
            allow_single_file = ["package.json"],
            mandatory = True,
        ),
        "yarn_lock": attr.label(
            allow_single_file = ["yarn.lock"],
            mandatory = True,
        ),
        "packages": attr.string_list(),
        "tools": attr.string_dict(),
        "yarn_options": attr.string_list(),
        "_yarn_install": attr.label(
            default = "//yarn/internal:yarn_install",
            executable = True,
            cfg = "host",
        )
    },
    toolchains = [YARN_TOOLCHAIN_TYPE],
    provides = [JsInfo],
)

def yarn_register_toolchains(version = YARN_DEFAULT_VERSION):
    repo_name = "yarn_v{}".format(version)
    if repo_name not in native.existing_rules().keys():
        yarn_repository(
            name = repo_name,
            version = version,
        )
    native.register_toolchains("@rules_javascript//yarn/toolchains:v{}".format(version))
