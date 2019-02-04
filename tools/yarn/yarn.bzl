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
    _NodeModulesInfo = "NodeModulesInfo",
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

# region Build Rules {{{

def _archives_map(archives):
    path_to_basename = {}
    seen_basenames = {}
    for archive in archives:
        basename = archive.basename
        if basename in seen_basenames:
            fail("Duplicate archive basename: {}".format(repr(basename)), attr = "archives")
        seen_basenames[basename] = True
        path_to_basename[archive.path] = basename

    return {path: path_to_basename[path] for path in sorted(path_to_basename)}

def _yarn_install(ctx):
    # Node.JS resolves package names relative to the _first_ 'node_modules'
    # component of the caller's directory. Detect common ways the user can
    # break their resolution path, and help get close to their intent.
    modules_folder = ctx.attr.name
    if modules_folder == "node_modules":
        # OK
        pass
    elif "node_modules/" in modules_folder:
        # Imports will be resolved relative to the top of this target,
        # which will cause confusing error messages. Reject the name.
        fail("Yarn can't install to a target containing \"node_modules/\"" +
             ' (try name = "FOO/node_modules", or just name = "node_modules")')
    elif modules_folder.endswith("/node_modules"):
        # OK
        pass
    else:
        # Fiddle with the output path a bit to get a low-collision name that
        # ends in a 'node_modules' component.
        modules_folder = "_yarn/{}/node_modules".format(ctx.attr.name)

    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]
    yarn_toolchain = ctx.attr._yarn_toolchain[yarn_common.ToolchainInfo]

    wrapper_params = struct(
        archives = _archives_map(ctx.files.archives),
        archive_dir = "_yarn_install/offline_mirror",
        yarnrc = "_yarn_install/yarnrc",
    )

    wrapper_params_file = ctx.actions.declare_file("_yarn/{}/params.json".format(ctx.attr.name))
    ctx.actions.write(wrapper_params_file, wrapper_params.to_json())

    node_modules = ctx.actions.declare_directory(modules_folder)
    outputs = [node_modules]

    argv = ctx.actions.args()
    argv.add_all([
        "--",
        ctx.file._yarn_install.path,
        wrapper_params_file.path,
        yarn_toolchain.yarn_executable.path,
        "install",
        "--frozen-lockfile",
        "--no-default-rc",
        "--offline",
        "--silent",
        "--production",
        "--ignore-scripts",
        "--no-bin-links",
        "--use-yarnrc=" + wrapper_params.yarnrc,
        "--cwd=" + ctx.file.package_json.dirname,
        "--cache-folder=_yarn_install/cache",
        "--modules-folder=" + node_modules.path,
    ])

    inputs = depset(
        direct = ctx.files.archives + [
            ctx.file.package_json,
            ctx.file.yarn_lock,
            ctx.file._yarn_install,
            wrapper_params_file,
        ],
        transitive = [
            node_toolchain.files,
            yarn_toolchain.files,
        ],
    )

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = node_toolchain.node_executable,
        arguments = [argv],
        mnemonic = "Yarn",
        progress_message = "Yarn install {}".format(ctx.file.package_json.owner),
    )

    return [
        DefaultInfo(files = depset([node_modules])),
        _NodeModulesInfo(node_modules = node_modules),
    ]

yarn_install = rule(
    _yarn_install,
    attrs = {
        "package_json": attr.label(
            allow_single_file = [".json"],
            mandatory = True,
        ),
        "yarn_lock": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "archives": attr.label_list(
            allow_files = [".tar.gz", ".tgz"],
        ),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
        "_yarn_install": attr.label(
            default = "//tools/yarn/internal:yarn_install.js",
            allow_single_file = True,
        ),
        "_yarn_toolchain": attr.label(
            default = "//tools/yarn:toolchain",
        ),
    },
    provides = [
        DefaultInfo,
        _NodeModulesInfo,
    ],
)

# endregion }}}

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

def _yarn_modules(ctx):
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
    if ctx.attr.bins:
        ctx.file("bin/BUILD.bazel", """
load("@rules_javascript//javascript:javascript.bzl", "js_binary")
[js_binary(
    name = bin_name,
    src = bin_name + "_main.js",
    deps = ["//:node_modules"],
    visibility = ["//visibility:public"],
) for bin_name in {bin_names}]
""".format(bin_names = repr(sorted(ctx.attr.bins))))

    for (bin_name, bin_main_js) in ctx.attr.bins.items():
        ctx.file("bin/{}_main.js".format(bin_name), "require(({}).path)".format(
            struct(path = "../node_modules/" + bin_main_js).to_json(),
        ))

yarn_modules = repository_rule(
    _yarn_modules,
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
        "bins": attr.string_dict(),
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
load("@rules_javascript//javascript:javascript.bzl", "js_binary")
js_binary(
    name = "yarn",
    src = "//:cli_js",
    visibility = ["//visibility:public"],
)""")

yarn_repository = repository_rule(
    _yarn_repository,
    attrs = {
        "version": attr.string(mandatory = True),
    },
)

# endregion }}}
