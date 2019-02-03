"use strict";

const CONFIG = {CONFIG_JSON};

const BAZEL_INPUT_PATHS = new Set(CONFIG.bazel_input_paths);
const MODULE_PATHS = new Map(CONFIG.module_paths);
const DIRECT_DEPS = new Map(CONFIG.direct_deps.map(item => {
    const [src, deps] = item;
    return [src, new Set(deps)];
}));

const q = JSON.stringify

class BazelResolver {
    apply(resolver) {
        resolver.getHook("resolve").tapAsync("BazelResolver", (request, ctx, callback) => {
            const module_name = request.request;
            const issuer = request.context.issuer;
            const resolved = this.resolve(module_name, issuer);
            if (resolved.path) {
                callback(null, {path: resolved.path});
            } else {
                callback(resolved.error, null);
            }
        });
    }
    resolve(module_name, issuer) {
        if (issuer === null) {
            // Webpack entry point. This path is templated into the Webpack
            // config, so if it's not found then you are having a bad problem
            // and you will not go to space today.
            if (BAZEL_INPUT_PATHS.has(module_name)) {
                return {path: module_name};
            }
            return {error: `internal error: ${q(module_name)} not listed in ${q(Array.from(BAZEL_INPUT_PATHS.keys()))}`};
        }

        // MODULE_PATHS is the entire transitive dependency graph of this target.
        const path = MODULE_PATHS.get(module_name);
        if (!path) {
            return {error: `module ${q(module_name)} not found anywhere, is it spelled correctly?`};
        }

        // DIRECT_DEPS is a map from source file name to that target's set of direct dependencies.
        //
        // The keys are source file names because that's how Webpack reports the issuer to its
        // resolver plugins. Note that this implies source file names must be globally unique when
        // building a Webpack bundle -- this constraint is enforced by the build rule.
        const deps = DIRECT_DEPS.get(issuer) || new Set();
        if (deps.has(module_name)) {
            return {path}
        }
        const declared = Array.from(deps.keys());
        return {error: `module ${q(module_name)} is imported from ${q(issuer)} but not listed as a direct dependency.`};
    }
}

module.exports = {
  mode: CONFIG.webpack_mode,
  entry: CONFIG.bazel_input_paths,
  output: {
      path: process.cwd(),
      filename: CONFIG.bazel_output_path,
  },
  resolve: {
      plugins: [new BazelResolver()],
  },
  stats: "errors-only",
};
