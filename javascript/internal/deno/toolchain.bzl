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

def _template_vars(toolchain):
    return platform_common.TemplateVariableInfo({
        # TODO
    })

def _shell_escape(s):
    return s # TODO

def _executable(toolchain, actions, name, src, format, main, deps):
    out_hermetic = actions.declare_file(name + ".deno-hermetic.js")
    actions.write(
        output = out_hermetic,
        content = """#!/bin/sh
false && /*
echo '$0:   '"$0"
echo '$@:   '"$@"
echo '$PWD: '"$PWD"
# echo "-------------------------"
# find .
# echo "-------------------------"
exec "$0.runfiles/"{workspace}/{deno} \\
  run \\
  -- ./{main} "$@"
*/ null;
""".format(
    workspace = _shell_escape(toolchain.actions.deno_tool.executable.owner.workspace_name),
    deno = _shell_escape(toolchain.actions.deno_tool.executable.short_path),
    main = src.path,
),
        is_executable = True,
    )

    out_wrapper = out_hermetic

    return struct(
        hermetic = out_hermetic,
        wrapper = out_wrapper,
    )

def _test(toolchain, actions, name, src, format, main, deps):
    out_hermetic = actions.declare_file(name + ".js")
    actions.write(
        output = out_hermetic,
        content = """#!/bin/sh
false && /*
echo '$0:   '"$0"
echo '$@:   '"$@"
echo '$PWD: '"$PWD"
# echo "-------------------------"
# find .
# echo "-------------------------"
if [ -z "${{RUNFILES_DIR}}" ]; then
  runfiles="$0.runfiles"
else
  runfiles="${{RUNFILES_DIR}}"
fi
exec "${{runfiles}}/"{workspace}/{deno} \\
  -- "${{runfiles}}/"{workspace}/{main} "$@"
*/ null;
""".format(
    workspace = _shell_escape(toolchain.actions.deno_tool.executable.owner.workspace_name),
    deno = _shell_escape(toolchain.actions.deno_tool.executable.short_path),
    main = src.short_path,
),
        is_executable = True,
    )

    return struct(
        hermetic = out_hermetic,
    )

def _deno_toolchain_info(ctx):
    # node_runfiles = ctx.attr.node_tool[DefaultInfo].default_runfiles.files
    deno_runfiles = depset()
    toolchain = JavascriptToolchainInfo(
        all_files = depset(
            # direct = [ctx.executable.deno_tool],
            direct = [ctx.file.deno_tool],
            transitive = [deno_runfiles],
        ),
        actions = struct(
            # TODO
            deno_tool = ctx.attr.deno_tool.files_to_run,
            executable = _executable,
            test = _test,
        )
        # deno_tool = ctx.attr.deno_tool.files_to_run,
        # deno_env = {},
    )
    return [
        platform_common.ToolchainInfo(javascript_toolchain = toolchain),
        _template_vars(toolchain),
    ]

deno_toolchain_info = rule(
    _deno_toolchain_info,
    attrs = {
        "deno_tool": attr.label(
            mandatory = True,
            # executable = True,
            # cfg = "host",
            allow_single_file = True,
        ),
    },
    provides = [
        platform_common.ToolchainInfo,
        platform_common.TemplateVariableInfo,
    ],
)
