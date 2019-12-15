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

load("@rules_javascript//javascript/internal:toolchain.bzl", _JAVASCRIPT_TOOLCHAIN_TYPE = "JAVASCRIPT_TOOLCHAIN_TYPE")

load("@rules_javascript//javascript/internal:providers.bzl", _JsInfo = "JsInfo", _JsPackageInfo = "JsPackageInfo", _JsModuleInfo = "JsModuleInfo")

JsInfo = _JsInfo
JsPackageInfo = _JsPackageInfo
JsModuleInfo = _JsModuleInfo
JAVASCRIPT_TOOLCHAIN_TYPE = _JAVASCRIPT_TOOLCHAIN_TYPE

def javascript_toolchain(ctx):
    return ctx.toolchains[JAVASCRIPT_TOOLCHAIN_TYPE].javascript_toolchain

def _js_library(ctx):
    javascript = javascript_toolchain(ctx)

    lib = javascript.actions.library(
        toolchain = javascript,
        actions = ctx.actions,
        import_prefix = ctx.attr.import_prefix,
        strip_import_prefix = ctx.attr.strip_import_prefix,
        rule_name = ctx.attr.name,
        srcs = ctx.files.srcs,
        format = ctx.attr.format,
        deps = [dep[JsInfo] for dep in ctx.attr.deps],
    )

    return [
        DefaultInfo(
            files = lib.files,
        ),
        lib.js_info,
    ]

js_library = rule(
    _js_library,
    attrs = {
        "srcs": attr.label_list(
            allow_empty = False,
            allow_files = [".js"],
            mandatory = True,
        ),
        "deps": attr.label_list(
            providers = [JsInfo],
        ),
        "import_prefix": attr.string(),
        "strip_import_prefix": attr.string(),
        "format": attr.string(
            default = "module",
            values = ["module", "commonjs"],
        ),
    },
    toolchains = [JAVASCRIPT_TOOLCHAIN_TYPE],
    provides = [JsInfo],
)

def _js_binary(ctx):
    javascript = javascript_toolchain(ctx)

    out = javascript.actions.executable(
        toolchain = javascript,
        actions = ctx.actions,
        name = ctx.attr.name,
        src = ctx.file.src,
        format = ctx.attr.format,
        main = ctx.attr.main,
        workspace_name = ctx.workspace_name,
        deps = [dep[JsInfo] for dep in ctx.attr.deps],
    )

    return DefaultInfo(
        files = depset(direct = [out.wrapper]),
        executable = out.hermetic,
        runfiles = ctx.runfiles(
            files = ctx.files.data + out.runfiles.files,
            transitive_files = out.runfiles.transitive_files,
            symlinks = out.runfiles.symlinks,
        ),
    )

js_binary = rule(
    _js_binary,
    executable = True,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
            mandatory = True,
        ),
        "data": attr.label_list(
            allow_files = True,
        ),
        "deps": attr.label_list(
            providers = [JsInfo],
        ),
        "format": attr.string(
            default = "module",
            values = ["module", "commonjs"],
        ),
        "main": attr.string(
            default = "main",
        ),
    },
    toolchains = [JAVASCRIPT_TOOLCHAIN_TYPE],
)

def _js_test(ctx):
    javascript = javascript_toolchain(ctx)

    #dep_modules = depset(
    #    transitive = [
    #        dep[JavascriptInfo].transitive_modules
    #        for dep in ctx.attr.deps
    #    ],
    #)

    deps = [dep[JsInfo] for dep in ctx.attr.deps]

    out = javascript.actions.test(
        toolchain = javascript,
        actions = ctx.actions,
        name = ctx.attr.name,
        src = ctx.file.src,
        format = ctx.attr.format,
        main = ctx.attr.main,
        deps = deps,
    )

    return DefaultInfo(
        files = depset(direct = []),
        executable = out.hermetic,
        runfiles = ctx.runfiles(
            files = ctx.files.data + [
                ctx.file.src,
            ],
            transitive_files = depset(
                transitive = [javascript.all_files] + [dep.transitive_srcs for dep in deps],
            ),
        ),
    )

js_test = rule(
    _js_test,
    test = True,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
            mandatory = True,
        ),
        "data": attr.label_list(
            allow_files = True,
        ),
        "deps": attr.label_list(
            providers = [JsInfo],
        ),
        "format": attr.string(
            default = "module",
            values = ["module", "commonjs"],
        ),
        "main": attr.string(
            default = "main",
        ),
    },
    toolchains = [JAVASCRIPT_TOOLCHAIN_TYPE],
)

"""
# TODO: move somewhere else?
JavascriptInfo = provider(fields = [
    "transitive_modules",
])
JavascriptModuleInfo = provider(fields = [
    "name",
    "files",
    "source",
])

def _module_name(ctx, src):
    # TODO: adjust 'module_prefix' based on {strip_,}import_prefix
    return src.short_path[:-len(".js")]

def _js_library(ctx):
    direct_sources = depset()
    direct_modules = []
    if ctx.attr.src:
        direct_sources = depset(direct = ctx.files.src)
        direct_modules.append(JavascriptModuleInfo(
            name = _module_name(ctx, ctx.file.src),
            files = direct_sources,
            source = struct(
                path = ctx.file.src.path,
                short_path = ctx.file.src.short_path,
            ),
        ))

    deps = [dep[_JavaScriptInfo] for dep in ctx.attr.deps]
    return _JavaScriptInfo(
        direct_modules = direct_modules,
        direct_sources = direct_sources,
        transitive_sources = depset(
            direct = ctx.files.src,
            transitive = [dep.transitive_sources for dep in deps],
        ),
        transitive_modules = depset(
            direct = direct_modules,
            transitive = [dep.transitive_modules for dep in deps],
        ),
    )


js_library = rule(
    _js_library,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
        ),
        "deps": attr.label_list(
            providers = [JavascriptInfo],
        ),
        "import_prefix": attr.string(),
        "strip_import_prefix": attr.string(),
    },
    toolchains = [JAVASCRIPT_TOOLCHAIN_TYPE],
    provides = [JavascriptInfo],
)

def _js_binary(ctx):
    javascript = javascript_toolchain(ctx)

    dep_modules = depset(
        transitive = [
            dep[JavascriptInfo].transitive_modules
            for dep in ctx.attr.deps
        ],
    )

    out_plain = ctx.actions.declare_file(ctx.attr.name)
    out_exec = ctx.actions.declare_file(ctx.attr.name + ".hermetic.js")


    return DefaultInfo(
        files = depset(direct = [out_plain]),
        executable = out_exec,
        runfiles = ctx.runfiles(
            files = ctx.files.src,
            transitive_files = javascript. TODO toolchain files needed to execute a script,
        ),
    )

js_binary = rule(
    _js_binary,
    executable = True,
    attrs = {
        "src": attr.label(
            allow_single_file = [".js"],
            mandatory = True,
        ),
        "deps": attr.label_list(
            providers = [JavascriptInfo],
        ),
    },
    toolchains = [JAVASCRIPT_TOOLCHAIN_TYPE],
)
"""
