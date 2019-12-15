console.log("in node loader");
console.log("  process.argv: ", process.argv);
console.log("  import.meta: ", import.meta);

import { builtinModules } from 'module';
import { existsSync } from 'fs';
import * as path from 'path';
import { execFileSync } from "child_process";
// console.log("builtinModules: ", builtinModules);

import { URL, pathToFileURL } from 'url';
const baseURL = pathToFileURL(process.cwd() + "/").href;

async function resolve_v10(specifier,
                              parentModuleURL = baseURL,
                              defaultResolver) {
  if (specifier === process.argv[1]) {
    return {
      url: "file:///FAKE_DYNAMIC_MAIN",
      format: 'dynamic',
    }
  }

  const formats = {
              "commonjs": "cjs",
              "module": "esm",
            };

  console.log("resolve_v10");
  console.log("  parentModuleURL: ", parentModuleURL);
  if (parentModuleURL === import.meta.url) {
      console.log("LOADING MAIN: ", CONFIG.main);
      if (specifier === CONFIG.main.name) {
        let mapped = CONFIG.main.path;
        // TODO hack
        const runfilesPath = path.join(process.argv[1] + '.runfiles/rules_javascript', mapped);
        console.log("runfilesPath: ", runfilesPath);
        if (existsSync(runfilesPath)) {
          mapped = runfilesPath;
        }
        const resolved = new URL(mapped, baseURL);
        resolved.searchParams.append('name', specifier);
        return {
            url: resolved.href,
            format: formats[CONFIG.main.format],
        }
      }
  }

  let selfName = new URL(parentModuleURL).searchParams.get('name');
  if (selfName === null) {
    panic();
  }

  const selfModule = CONFIG.modules[selfName];
  const mapped = selfModule.imports[specifier];
  console.log("  mapped: ", mapped);
  if (mapped) {
    const resolved = new URL(mapped.path, baseURL);
    resolved.searchParams.append('name', specifier);
    return {
        url: resolved.href,
        format: formats[mapped.format],
    }
  }

  console.log("NOT FOUND: " + specifier);
  return null;
}

async function resolve_v13(specifier,
                              parentModuleURL = baseURL,
                              defaultResolver) {
  // const mainUrl = new URL(process.argv[1], "file:///").href;
  const mainUrl = import.meta.url;
  console.log("mainUrl: ", mainUrl);
  if (specifier === mainUrl) {
    return {
      url: "file:///FAKE_DYNAMIC_MAIN",
      format: 'dynamic',
    }
  }

  if (parentModuleURL === import.meta.url) {
      if (specifier === CONFIG.main.name) {
        const mapped = CONFIG.main.path;

        // FIXME
        const mappedPath = path.resolve(
          process.argv[1] + ".runfiles/__main__",
          mapped
        );

        const resolved = new URL(mappedPath, baseURL);
        resolved.searchParams.append('name', specifier);
        return {
            url: resolved.href,
            format: CONFIG.main.format,
        }
      }
  }

  let selfName = new URL(parentModuleURL).searchParams.get('name');
  if (selfName === null) {
    panic2();
  }

  const selfModule = CONFIG.modules[selfName];
  const mapped = selfModule.imports[specifier];
  console.log("  mapped: ", mapped);
  if (mapped) {
    const resolved = new URL(mapped.path, baseURL);
    resolved.searchParams.append('name', specifier);
    return {
        url: resolved.href,
        format: mapped.format,
    }
  }

  console.log("NOT FOUND: " + specifier);
  return null;
}

export async function resolve(specifier,
                              parentModuleURL = baseURL,
                              defaultResolver) {
  console.log(`\nresolve(${JSON.stringify(specifier)}, ${JSON.stringify(parentModuleURL)})`);
  console.log("  import.meta: ", import.meta);

  // TODO: builtinModules
  if (specifier === 'url' || specifier === 'module'
       || specifier === 'child_process' || specifier === 'fs'
       || specifier === 'path') {
    return defaultResolver(specifier, parentModuleURL, defaultResolver);
  }

  let resolver = null;
  if (process.versions.node.startsWith('10.')) {
    resolver = resolve_v10;
  } else {
    resolver = resolve_v13;
  }

  const resolved = await resolver(specifier, parentModuleURL, defaultResolver);
  console.log(`  -> ${JSON.stringify(resolved)}`);
  return resolved;
}

export async function dynamicInstantiate(url) {
  // console.log("dynamicInstantiate");
  // console.log("  url: ", url);
  // console.log("  import.meta: ", import.meta);
  return {
    exports: [],
    execute: async (exports) => {
      // console.log("dynamicInstantiate execute");
      // console.log("  url: ", url);
      // console.log("exports: " + JSON.stringify(Object.keys(exports)));

      await import(CONFIG.main.name)
        .then((main) => {
          if (CONFIG.main.main_fn !== "") {
            const main_fn = main[CONFIG.main.main_fn];
            try {
              main_fn();
            } catch (exc) {
              console.log(exc.stack);
              process.exit(1);
            }
          }
        })
        .catch((err) => {
          console.log('---------------------------');
          console.log("LOAD ERROR: ", err);
          execFileSync("find", ["."], {stdio: 'inherit'});
          console.log('---------------------------');
          console.log(process.cwd())
          console.log('---------------------------');
          console.log(process.argv)
          console.log('---------------------------');
          console.log(process.env);
          console.log('---------------------------');
              process.exit(1);
        });
      console.log("After main runs?");
    }
  };
}
