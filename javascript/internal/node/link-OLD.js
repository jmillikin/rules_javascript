
def _executable(toolchain, actions, name, src, format, main, deps):
out_wrapper = actions.declare_file(name)
actions.write(
    output = out_wrapper,
    content = """#!/bin/sh
if [ "${{0#/}}" != "$0" ]; then
loader="$0".mjs
else
loader="./$0".mjs
fi
exec "$0.mjs.runfiles/"{workspace}/{node} \\
--no-warnings \\
--preserve-symlinks \\
--experimental-modules \\
--loader="${{loader}}" \\
-- "${{loader}}" "$@"
""".format(
workspace = _shell_escape(toolchain.actions.node_tool.executable.owner.workspace_name),
node = _shell_escape(toolchain.actions.node_tool.executable.short_path),
),
    is_executable = True,
)


out_hermetic = actions.declare_file(name + ".mjs")
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
if [ "${{0#/}}" != "$0" ]; then
loader="$0"
else
loader="./$0"
fi
exec "$0.runfiles/"{workspace}/{node} \\
--no-warnings \\
--preserve-symlinks \\
--experimental-modules \\
--loader="${{loader}}" \\
-- "$0" "$@"
*/ null;
const CONFIG = {config};
{loader}
""".format(
workspace = _shell_escape(toolchain.actions.node_tool.executable.owner.workspace_name),
node = _shell_escape(toolchain.actions.node_tool.executable.short_path),
config = struct(
    main = struct(
        name = src.path,
        path = src.short_path,
        format = format,
        main_fn = main,
    ),
    modules = dict([
        (mod.module_name, struct(
            imports = dict([
                ("~/" + dep.module_name, {
                  "path": dep.src.short_path,
                  "format": dep.format,
                })
                for dep in mod.deps
            ]),
        ))
        for mod in modules
    ]),
).to_json(),
loader = _LOADER,
),
    is_executable = True,
)

return struct(
    hermetic = out_hermetic,
    wrapper = out_wrapper,
)

def _test(toolchain, actions, name, src, format, main, deps):
modules = deps + [
    struct(
        module_name = src.path,
        src = src,
        transitive_srcs = depset(),
        deps = deps,
    )
]

out_hermetic = actions.declare_file(name + ".mjs")
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
if [ "${{0#/}}" != "$0" ]; then
loader="$0"
else
loader="./$0"
fi
if [ -z "${{RUNFILES_DIR}}" ]; then
runfiles="$0.runfiles"
else
runfiles="${{RUNFILES_DIR}}"
fi
exec "${{runfiles}}/"{workspace}/{node} \\
--no-warnings \\
--preserve-symlinks \\
--experimental-modules \\
--loader="${{loader}}" \\
-- "$0" "$@"
*/ null;
const CONFIG = {config};
{loader}
""".format(
workspace = _shell_escape(toolchain.actions.node_tool.executable.owner.workspace_name),
node = _shell_escape(toolchain.actions.node_tool.executable.short_path),
config = struct(
    main = struct(
        name = src.path,
        path = src.short_path,
        format = format,
        main_fn = main,
    ),
    modules = dict([
        (mod.module_name, struct(
            imports = dict([
                ("~/" + dep.module_name, {
                  "path": dep.src.short_path,
                  "format": dep.format,
                })
                for dep in mod.deps
            ]),
        ))
        for mod in modules
    ]),
).to_json(),
loader = _LOADER,
),
    is_executable = True,
)

return struct(
    hermetic = out_hermetic,
)
