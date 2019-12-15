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

load("@rules_javascript//javascript/internal:toolchain.bzl", "JavascriptToolchainInfo")
load("@rules_javascript//javascript/internal:providers.bzl", "JsModuleInfo", "JsInfo")

def _template_vars(toolchain):
    return platform_common.TemplateVariableInfo({
        # TODO
    })

def _module_name(src, import_prefix, strip_import_prefix):
    path = src.path
    if not path.endswith(".js"):
        fail("expected .js extension")
    path = path[:-len(".js")]
    workspace_prefix = "{}/".format(src.owner.workspace_root)
    if path.startswith(workspace_prefix):
        path = path[len(workspace_prefix):]
    if strip_import_prefix != "":
        if strip_import_prefix.startswith("/"):
            strip_import_prefix = strip_import_prefix[1:] + "/"
            if path.startswith(strip_import_prefix):
                path = path[len(strip_import_prefix):]
            else:
                fail("path {} does not start with prefix {}".format(
                    repr(path),
                    repr(strip_import_prefix),
                ))
        else:
            fail("relative strip_import_prefix: not implemented") # TODO
    if import_prefix != "":
        fail("import_prefix: not implemented") # TODO
    return path

def _library(toolchain, actions, rule_name, srcs, import_prefix, strip_import_prefix, format, deps):
    print("\njs_library(\n  rule_name = {},\n  srcs = {},\n  import_prefix = {},\n  strip_import_prefix = {},\n  format = {},\n  deps = {},\n)".format(
        repr(rule_name),
        srcs,
        repr(import_prefix),
        repr(strip_import_prefix),
        repr(format),
        deps,
    ))

    if format == "module":
        ext = ".mjs"
    else:
        ext = ".cjs"

    deps_modules = actions.declare_directory("{}/node_modules".format(rule_name))
    deps_package = actions.declare_file("{}/node_modules/~/package.json".format(rule_name))

    modules = {}
    copied_srcs = {}
    for ii, src in enumerate(srcs):
        print("\nsrcs[{}]\n  .path = {}\n  .short_path = {}\n  .root.path = {}\n  .owner = {}\n  .owner.workspace_root = {}".format(
            ii,
            repr(src.path),
            repr(src.short_path),
            repr(src.root.path),
            repr(src.owner),
            repr(src.owner.workspace_root),
        ))

        module_name = _module_name(src, import_prefix, strip_import_prefix)
        copied_src = actions.declare_file("{}/_virtual_srcs/{}{}".format(rule_name, module_name, ext))
        copied_srcs[src] = copied_src

        modules[module_name] = JsModuleInfo(
            file = copied_src,
            format = format
        )

    params = actions.declare_file("{}/params.json".format(rule_name))
    actions.write(
        output = params,
        content = struct(
            action = "library",
            format = format,
            node_version = toolchain.actions.node_version,
            srcs = [struct(
                input = struct(path = src.path),
                output = struct(path = copied_srcs[src].path),
            ) for src in srcs],
            deps = struct(
                node_modules = struct(path = deps_modules.path),
                package_json = struct(path = deps_package.path),
                packages = [
                    struct(
                        name = pkg_name,
                        root = struct(path = pkg.root.path),
                        format = pkg.format,
                    )
                    for dep in deps for (pkg_name, pkg) in dep.packages.items()
                ],
                modules = [
                    struct(
                        name = name,
                        file = struct(path = mod.file.path),
                        format = mod.format,
                    )
                    for dep in deps for (name, mod) in dep.modules.items()
                ],
            ),
        ).to_json(),
    )

    dep_inputs = []
    for dep in deps:
        for mod in dep.modules.values():
            dep_inputs.append(mod.file)
        for pkg in dep.packages.values():
            dep_inputs.append(pkg.root)

    args = actions.args()
    args.add(toolchain.actions._helper_js)
    args.add(params.path)
    outputs = copied_srcs.values() + [deps_package, deps_modules]
    actions.run(
        executable = toolchain.actions.node_tool.executable,
        inputs = [
            toolchain.actions._acorn_js,
            toolchain.actions._helper_js,
            params,
        ] + srcs + dep_inputs,
        outputs = outputs,
        arguments = [args],
        mnemonic = "JsLibrary",
        progress_message = "TODO Progress Message",
    )

    return struct(
        files = depset(
            direct = outputs,
        ),
        js_info = JsInfo(
            packages = {},
            modules = modules,
            direct_deps = deps,
            transitive_deps = depset(
                direct = deps,
                transitive = [dep.transitive_deps for dep in deps],
            ),
            direct_files = outputs,
            transitive_files = depset(
                direct = outputs,
                transitive = [dep.transitive_files for dep in deps],
            )
        ),
    )

def _executable(toolchain, actions, name, src, format, main, deps, workspace_name):
    rule_name = name

    if format == "module":
        ext = ".mjs"
    else:
        ext = ".cjs"
    main_name = "index" + ext

    out_wrapper = actions.declare_file(rule_name)

    actions.write(
        output = out_wrapper,
        content = """#!/bin/bash
exec "$0"_hermetic{ext}.runfiles/{workspace_name}/{node_js} \\
  --experimental-modules \\
  -- "$0"_hermetic{ext} "$@"
""".format(
            ext = ext,
            workspace_name = workspace_name,
            node_js = toolchain.actions.node_tool.executable.short_path,
        ),
    )

    out_hermetic = actions.declare_file(rule_name + "_hermetic" + ext)

    copied_main = actions.declare_file("{}_hermetic/{}".format(rule_name, main_name))

    deps_modules = actions.declare_directory("{}_hermetic/node_modules".format(rule_name))
    deps_package = actions.declare_file("{}_hermetic/node_modules/~/package.json".format(rule_name))

    params = actions.declare_file("{}_hermetic/params.json".format(rule_name))
    actions.write(
        output = params,
        content = struct(
            action = "binary",
            format = format,
            src = struct(
                input = struct(path = src.path),
                output = struct(
                    path = copied_main.path,
                    short_path = copied_main.short_path,
                ),
                output_hermetic = struct(
                    path = out_hermetic.path,
                ),
            ),
            main_fn = main,
            workspace_name = workspace_name,
            node_version = toolchain.actions.node_version,
            node_tool = struct(
                path = toolchain.actions.node_tool.executable.path,
                short_path = toolchain.actions.node_tool.executable.short_path,
            ),
            deps = struct(
                node_modules = struct(path = deps_modules.path),
                package_json = struct(path = deps_package.path),
                packages = [
                    struct(
                        name = pkg_name,
                        root = struct(path = pkg.root.path),
                        format = pkg.format,
                    )
                    for dep in deps for (pkg_name, pkg) in dep.packages.items()
                ],
                modules = [
                    struct(
                        name = name,
                        file = struct(path = mod.file.path),
                        format = mod.format,
                    )
                    for dep in deps for (name, mod) in dep.modules.items()
                ],
            ),
        ).to_json(),
    )

    dep_inputs = []
    for dep in deps:
        for mod in dep.modules.values():
            dep_inputs.append(mod.file)
        for pkg in dep.packages.values():
            dep_inputs.append(pkg.root)

    args = actions.args()
    args.add(toolchain.actions._helper_js)
    args.add(params.path)
    actions.run(
        executable = toolchain.actions.node_tool.executable,
        inputs = [
            toolchain.actions._acorn_js,
            toolchain.actions._helper_js,
            params,
            src,
        ] + dep_inputs,
        outputs = [copied_main, deps_modules, deps_package, out_hermetic],
        arguments = [args],
        mnemonic = "JsBinary",
        progress_message = "TODO Progress Message",
    )

    node = toolchain.actions.node_tool.executable
    return struct(
        hermetic = out_hermetic,
        wrapper = out_wrapper,
        runfiles = struct(
            files = [copied_main, deps_modules, deps_package, toolchain.actions.node_tool.executable],
            transitive_files = depset(transitive = [
                dep.transitive_files for dep in deps
            ]),
            symlinks = {
                "{}.runfiles/x/{}".format(out_hermetic.path, node.short_path): node,
            },
        )
    )

def _test(toolchain, actions, name, src, format, main, deps):
    out_hermetic = actions.declare_file(name + ".mjs")
    return struct(
        hermetic = out_hermetic,
    )

def _parse_version(raw):
    [major, minor, patch] = raw.split(".")
    return struct(
        major = int(major),
        minor = int(minor),
        patch = int(patch),
    )

def _node_toolchain_info(ctx):
    # node_runfiles = ctx.attr.node_tool[DefaultInfo].default_runfiles.files
    node_runfiles = depset()
    toolchain = JavascriptToolchainInfo(
        all_files = depset(
            # direct = [ctx.executable.node_tool],
            direct = [
                ctx.file.node_tool,
            ],
            transitive = [node_runfiles],
        ),
        actions = struct(
            # TODO
            node_tool = ctx.attr.node_tool.files_to_run,
            node_version = _parse_version(ctx.attr.node_version),
            executable = _executable,
            library = _library,
            test = _test,
            _acorn_js = ctx.file._acorn_js,
            _helper_js = ctx.file._helper_js,
        )
        # node_tool = ctx.attr.node_tool.files_to_run,
        # node_env = {},
    )
    return [
        platform_common.ToolchainInfo(javascript_toolchain = toolchain),
        _template_vars(toolchain),
    ]

node_toolchain_info = rule(
    _node_toolchain_info,
    attrs = {
        "node_version": attr.string(
            mandatory = True,
        ),
        "node_tool": attr.label(
            mandatory = True,
            # executable = True,
            # cfg = "host",
            allow_single_file = True,
        ),
        "_acorn_js": attr.label(
            allow_single_file = True,
            default = "@rules_javascript_tools//:acorn",
        ),
        "_helper_js": attr.label(
            allow_single_file = True,
            default = "//javascript/internal/node:helper_js",
        ),
    },
    provides = [
        platform_common.ToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
