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
    _JavaScriptInfo = "JavaScriptInfo",
    _JavaScriptModuleInfo = "JavaScriptModuleInfo",
    _NodeModulesInfo = "NodeModulesInfo",
)
load(
    "//javascript/node:node.bzl",
    _node_common = "node_common",
)
load(
    ":toolchain.bzl",
    _ToolchainInfo = "YarnToolchainInfo",
)

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
    yarn_toolchain = ctx.attr._yarn_toolchain[_ToolchainInfo]

    wrapper_params = struct(
        archives = _archives_map(ctx.files.archives),
        archive_dir = "_yarn_install/offline_mirror",
        yarnrc = "_yarn_install/yarnrc",
    )

    wrapper_params_file = ctx.actions.declare_file("_yarn/{}/params.json".format(ctx.attr.name))
    ctx.actions.write(wrapper_params_file, wrapper_params.to_json())

    node_modules = ctx.actions.declare_directory(modules_folder)
    outputs = [node_modules]
    outputs_depset = depset(outputs)

    argv = ctx.actions.args()
    argv.add_all([
        "--preserve-symlinks",
        "--preserve-symlinks-main",
        "--",
        ctx.file._yarn_wrapper.path,
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
            ctx.file._yarn_wrapper,
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

    modules = []
    for module_name in sorted(ctx.attr.modules):
        modules.append(_JavaScriptModuleInfo(
            name = module_name,
            files = outputs_depset,
            source = struct(
                path = "{}/{}".format(node_modules.path, module_name),
                short_path = "{}/{}".format(node_modules.short_path, module_name),
            ),
        ))

    return [
        DefaultInfo(files = outputs_depset),
        _JavaScriptInfo(
            direct_sources = outputs,
            transitive_sources = outputs_depset,
            direct_modules = modules,
            transitive_modules = depset(),
        ),
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
        "modules": attr.string_list(),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
        "_yarn_wrapper": attr.label(
            default = "//tools/yarn/internal:yarn_wrapper.js",
            allow_single_file = True,
        ),
        "_yarn_toolchain": attr.label(
            default = "//tools/yarn:toolchain",
        ),
    },
    provides = [
        DefaultInfo,
        _JavaScriptInfo,
        _NodeModulesInfo,
    ],
)

_TOOL_JS = """#!{NODE_EXECUTABLE}
const path = require("path");
const MAIN = {MAIN};
require(path.resolve(__dirname, MAIN.path));
"""

def _yarn_modules_tool(ctx):
    node_toolchain = ctx.attr._node_toolchain[_node_common.ToolchainInfo]

    if ctx.attr.main_src:
        path = ctx.attr.name + ".js"
        main_js = ctx.actions.declare_file(path)
        ctx.actions.expand_template(
            template = ctx.file.main_src,
            output = main_js,
            substitutions = {},
        )
        runfiles = [main_js]
    elif ctx.attr.node_modules:
        path = "../node_modules/" + ctx.attr.main
        node_modules = ctx.attr.node_modules[_NodeModulesInfo].node_modules
        runfiles = [node_modules]
    else:
        fail("expected main_src= or node_modules=")

    out_plain = ctx.actions.declare_file(ctx.attr.name)
    out_exec = ctx.actions.declare_file(ctx.attr.name + ".exec.js")

    ctx.actions.write(out_plain, _TOOL_JS.format(
        NODE_EXECUTABLE = "/usr/bin/env node",
        MAIN = struct(path = path).to_json(),
    ), is_executable = True)

    ctx.actions.write(out_exec, _TOOL_JS.format(
        NODE_EXECUTABLE = node_toolchain.node_executable.path,
        MAIN = struct(path = path).to_json(),
    ), is_executable = True)

    return DefaultInfo(
        files = depset(direct = [out_plain]),
        executable = out_exec,
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = node_toolchain.files,
        ),
    )

yarn_modules_tool = rule(
    _yarn_modules_tool,
    attrs = {
        "main": attr.string(),
        "main_src": attr.label(allow_single_file = [".js"]),
        "node_modules": attr.label(
            providers = [_NodeModulesInfo],
        ),
        "_node_toolchain": attr.label(
            default = "//javascript/node:toolchain",
        ),
    },
    executable = True,
)
