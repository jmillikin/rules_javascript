#!/bin/sh
false && /*
node="$1"
shift
test_name="$1"
exec "${node}" \
	--preserve-symlinks \
	--preserve-symlinks-main \
	-- ./tests/integration/"${test_name}"/test.js "$@"
*/ null;

import { strict as assert } from "assert";
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

// https://github.com/bazelbuild/bazel/issues/10415
(function fixPathEnv() {
	process.env["PATH"] = process.env["PATH"]
		.split(path.delimiter)
		.filter((elem) => elem !== ".")
		.join(path.delimiter);
})();

export const setup = () => {
	const testName = process.argv[2];
	const config = JSON.parse(process.argv[3]);

	const testcaseTmpdir = fs.mkdtempSync(
		path.join(process.env["TEST_TMPDIR"],
			"testcase."),
	);
	const workspacePath = path.join(testcaseTmpdir, "workspace");

	const skelPath = path.resolve(path.join("tests", "integration", testName));
	execFileSync("rsync", ["--archive", skelPath + "/workspace/", workspacePath + "/"]);
	execFileSync("find", [workspacePath, "-name", "BUILD.skel.bazel", "-execdir", "mv", "{}", "BUILD", ";"], {stdio: "inherit"});

	const nodeVersion = config["node_version"]
		? JSON.stringify(config["node_version"])
		: "None";
	const denoVersion = config["deno_version"]
		? JSON.stringify(config["deno_version"])
		: "None";

	let existingWorkspace = "";
	const workspaceFilePath = path.join(workspacePath, "WORKSPACE");
	if (fs.existsSync(workspaceFilePath)) {
		existingWorkspace = fs.readFileSync(workspaceFilePath);
		fs.unlinkSync(workspaceFilePath);
	}

	fs.writeFileSync(workspaceFilePath, `
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
	name = "rules_cc",
	sha256 = "1d4dbbd1e1e9b57d40bb0ade51c9e882da7658d5bfbf22bbd15b68e7879d761f",
	strip_prefix = "rules_cc-8bd6cd75d03c01bb82561a96d9c1f9f7157b13d0",
	urls = ["https://mirror.bazel.build/github.com/bazelbuild/rules_cc/archive/8bd6cd75d03c01bb82561a96d9c1f9f7157b13d0.zip"],
)

local_repository(
name = "rules_javascript",
path = "${process.cwd()}",
)
load("@rules_javascript//javascript:repositories.bzl", "rules_javascript_toolchains")
rules_javascript_toolchains(node_version = ${nodeVersion}, deno_version = ${denoVersion})

${existingWorkspace}
`);

	fs.mkdirSync(path.join(workspacePath, "platforms"));
	fs.writeFileSync(path.join(workspacePath, "platforms", "BUILD"), `
platform(
	name = "deno-v8",
	parents = ["@local_config_platform//:host"],
	constraint_values = [
		"@rules_javascript//javascript/constraints/engine:v8",
		"@rules_javascript//javascript/constraints/runtime:deno",
	],
)
platform(
	name = "node-chakracore",
	parents = ["@local_config_platform//:host"],
	constraint_values = [
		"@rules_javascript//javascript/constraints/engine:chakracore",
		"@rules_javascript//javascript/constraints/runtime:node",
	],
)
platform(
	name = "node-v8",
	parents = ["@local_config_platform//:host"],
	constraint_values = [
		"@rules_javascript//javascript/constraints/engine:v8",
		"@rules_javascript//javascript/constraints/runtime:node",
	],
)
`)

	const distdir = path.resolve("../integration_test_archives/archives");
	fs.writeFileSync(path.join(workspacePath, ".bazelrc"), `
build --distdir=${distdir}
build --distdir=${distdir}/node
build --distdir=${distdir}/node-chakracore
build --distdir=${distdir}/rules_cc
build --distdir=${distdir}/rules_java
build --host_platform=//platforms:${config["runtime"]}-${config["engine"]}
`)

	return {
		path: workspacePath,
		bazel: (argv, options) => {
			const opts = Object.assign({
				stdio: "inherit",
				cwd: workspacePath,
				env: {
					TEST_TMPDIR: path.join(testcaseTmpdir, "output-root"),
					PATH: process.env["PATH"],
				},
			}, options);
			return execFileSync("sh", [
				"-c",
				'exec bazel "$@"',
				"sh",
				...argv,
			], opts);
		},
	};
}

export function assertJsBinaryStdout({
	workspace,
	wantStdout,
	binTarget,
	binOutputPath,
	genruleTarget,
	genruleOutputPath,
}) {
	workspace.bazel(["build", binTarget]);

	{
		const processStdout = execFileSync(binOutputPath, [], {
			stdio: "pipe",
			cwd: workspace.path,
		});
		assert.equal(processStdout.toString(), wantStdout);
	}

	{
		const processStdout = workspace.bazel(["run", binTarget], { stdio: "pipe" });
		assert.equal(processStdout.toString(), wantStdout);
	}

	workspace.bazel(["build", genruleTarget]);
	assert.equal(
		fs.readFileSync(path.join(workspace.path, genruleOutputPath)).toString(),
		wantStdout,
	);
}
