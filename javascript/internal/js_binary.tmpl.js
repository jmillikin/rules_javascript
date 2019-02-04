#!{NODE_EXECUTABLE}
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const CONFIG = {JS_BINARY_CONFIG};
const node_executable = process.argv[0];

let cwd = process.cwd();
let runfiles = cwd;
if (fs.existsSync(__filename + ".runfiles")) {
    runfiles = path.resolve(__filename + ".runfiles", CONFIG.workspace_name);
}

let node_path = [runfiles];
node_path.push(...CONFIG.node_path.map(rel => path.resolve(cwd, rel)));

let main_argv = [];
main_argv.push("--preserve-symlinks");
main_argv.push("--preserve-symlinks-main");
main_argv.push(...CONFIG.node_args);
main_argv.push("--");
main_argv.push(path.resolve(runfiles, CONFIG.main));
main_argv.push(...process.argv.slice(2));

process.exit(spawnSync(node_executable, main_argv, {
  stdio: "inherit",
  env: {
      NODE_PATH: node_path.join(path.delimiter),
  }
}).status);
