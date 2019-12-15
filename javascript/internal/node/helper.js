const fs = require("fs");
const path = require("path");

const acorn = require(path.resolve("external/rules_javascript_tools/acorn-7.1.0/dist/acorn.js"));

const pathEncode = (s) => {
	return s.replace("Z", "Z5A").replace("/", "Z2F");
};

const hasDefaultExport = (filePath) => {
	const src = fs.readFileSync(filePath);
	const tokens = acorn.tokenizer(src);
	while (true) {
		let token = tokens.getToken();
		if (token.type === acorn.tokTypes._export) {
			token = tokens.getToken();
			if (token.type === acorn.tokTypes._default) {
				return true;
			}
			if (token.type === acorn.tokTypes.braceL) {
				while (true) {
					token = tokens.getToken();
					if (token.type === acorn.tokTypes.braceR) {
						break;
					}
					if (token.type === acorn.tokTypes.eof) {
						return false;
					}
					if (token.type === acorn.tokTypes._default) {
						return true;
					}
				}
			}
		}
		if (token.type === acorn.tokTypes.eof) {
			return false;
		}
	}
}

const importStub = (mod, shimPath) => {
	let relpath = path.relative(path.dirname(shimPath), mod.file.path);
	if (mod.format === "module") {
		let defaultExport = "";
		if (hasDefaultExport(mod.file.path)) {
			defaultExport = `export { default } from ${JSON.stringify(relpath)};\n`;
		}
		return `export * from ${JSON.stringify(relpath)};\n${defaultExport}`;
	}
	return `module.exports = require(${JSON.stringify(relpath)});\n`;
}

const modExt = (mod) => {
	if (mod.format === "module") {
		return ".mjs";
	}
	return ".cjs";
}

const writeDepModules = (nodeVersion, deps) => {
	const bazelModulesRoot = path.dirname(deps.package_json.path);
	const packageJSON = {}

	if (nodeVersion.major < 12) {
		deps.modules.forEach((mod) => {
			const ext = mod.format == "module" ? ".mjs" : ".js";
			const shimPath = path.join(bazelModulesRoot, mod.name + ext);
			fs.mkdirSync(path.dirname(shimPath), {
				recursive: true,
				mod: 0o700,
			});
			fs.writeFileSync(shimPath, importStub(mod, shimPath));
		});
	} else {
		fs.mkdirSync(path.join(bazelModulesRoot, "shims"), {
			mode: 0o700,
			recursive: true,
		});

		const bazelExports = {};
		packageJSON["exports"] = bazelExports
		deps.modules.forEach((mod) => {
			const shimRelPath = path.join("shims", pathEncode(mod.name)) + modExt(mod);
			const shimPath = path.join(bazelModulesRoot, shimRelPath);
			fs.writeFileSync(shimPath, importStub(mod, shimPath));
			bazelExports["./" + mod.name] = "./" + shimRelPath;
		});
	}

	fs.writeFileSync(
		path.join(bazelModulesRoot, "package.json"),
		JSON.stringify(packageJSON) + "\n",
	);
	deps.packages.forEach((pkg) => {
		writeDepPkg(deps, pkg);
	});
};

const findFiles = (rootPath, fn) => {
	const walk = (dirName) => {
		const dirPath = path.join(rootPath, dirName)
		const dirents = fs.readdirSync(dirPath);
		const files = [];
		const dirs = [];
		dirents.forEach((dirent) => {
			const stat = fs.statSync(path.join(dirPath, dirent));
			if (stat.isFile()) {
				files.push(dirent);
			} else if (stat.isDirectory()) {
				dirs.push(dirent);
			}
		});
		files.forEach((dirent) => fn(dirName, dirent));
		dirs.forEach((dirent) => walk(path.join(dirName, dirent)));
	};
	walk("");

};

const writeDepPkg = (deps, pkg) => {
	const rootConfig = JSON.parse(fs.readFileSync(path.join(pkg.root.path, "package.json")));
	const shimDir = path.join(deps.node_modules.path, pkg.name);
	fs.mkdirSync(shimDir, {
		mode: 0o700,
	});

	findFiles(pkg.root.path, (dirPath, fileName) => {
		if (!fileName.endsWith(".js")) {
			return;
		}
		const filePath = path.join(pkg.root.path, dirPath, fileName);
		fs.mkdirSync(path.join(shimDir, dirPath), {
			mode: 0o700,
			recursive: true,
		});
		const shimPath = path.join(shimDir, dirPath, fileName); // TODO: modExt()
		fs.writeFileSync(shimPath, importStub({
			file: {path: filePath},
			format: pkg.format,
		}, shimPath));
	});

	const shimConfig = {};
	if (rootConfig.hasOwnProperty("main")) {
		shimConfig.main = rootConfig.main;
	}
	if (rootConfig.hasOwnProperty("exports")) {
		shimConfig.exports = rootConfig.exports;
	}

	fs.writeFileSync(path.join(shimDir, "package.json"), JSON.stringify(shimConfig) + "\n");
}

const library = (params) => {
	params.srcs.forEach((src) => {
		fs.writeFileSync(src.output.path, fs.readFileSync(src.input.path));
	});
	writeDepModules(params.node_version, params.deps);
};

const shellQuote = (s) => {
	return s; // TODO
}

const binaryShim = (params) => {
	const runfilesRoot = `./${path.basename(params.src.output_hermetic.path)}.runfiles`;
	const mainPath = "./" + path.join(runfilesRoot, params.workspace_name, params.src.output.short_path);
	const node = shellQuote(path.join(params.src.output_hermetic.path + ".runfiles/DUMMY", params.node_tool.short_path));

	const header = `#!/bin/sh
false && /*
exec ${node} \\
	--experimental-modules \\
	-- "$0" "$@"
*/ null;
`;

	if (params.format === "module") {
		if (params.main_fn === "") {
			return `${header}
import ${JSON.stringify(mainPath)};
`;
		}
		return `${header}
import {main} from ${JSON.stringify(mainPath)};
process.exit(main());
`;
	}
	if (params.main_fn === "") {
		return `${header}
require(${JSON.stringify(mainPath)});
`;

	}
	return `${header}
const {main} = require(${JSON.stringify(mainPath)});
process.exit(main());
`;
}

const binary = (params) => {
	fs.writeFileSync(params.src.output.path, fs.readFileSync(params.src.input.path));
	writeDepModules(params.node_version, params.deps);

	fs.writeFileSync(params.src.output_hermetic.path, binaryShim(params));
};

const main = () => {
	const params = JSON.parse(fs.readFileSync(process.argv[2]));
	const actions = {
		"library": library,
		"binary": binary,
	}
	actions[params.action](params);
}

process.exit(main());
