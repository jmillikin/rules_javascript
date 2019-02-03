// Copyright 2019 the rules_javascript authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

const fs = require("fs");
const path = require("path");

const CONFIG_PATH = process.argv[2];
const CONFIG = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));

const tsc_root = path.resolve(path.dirname(CONFIG.tsconfig), "tsc_root");
fs.symlinkSync(
    path.resolve(process.cwd(), CONFIG.out_dir),
    tsc_root,
);
fs.symlinkSync(
    path.resolve(process.cwd(), CONFIG.src_ts),
    path.resolve(tsc_root, `${CONFIG.module_name}.ts`),
);

if (process.argv.includes("--emitDeclarationOnly")) {
    process.argv.push("--outFile");
    process.argv.push(path.resolve(
        tsc_root,
        `${CONFIG.module_name}.d.ts`
    ));
} else {
    process.argv.push("--outDir");
    process.argv.push(tsc_root);
}

process.argv.splice(1, 2);

const tsc_main_js = path.join(process.cwd(), process.argv[1]);
require(tsc_main_js);
