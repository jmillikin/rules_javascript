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

import * as fs from "fs";
import * as path from "path";
import { execFileSync } from "child_process";

export function main() {
    const config = JSON.parse(process.argv[2]);

    const scratch_dir = path.resolve(process.cwd(), "_yarn_install");
    fs.mkdirSync(scratch_dir);

    const archives = JSON.parse(fs.readFileSync(config["archives_json"], "utf8"))["archives"];
    const archive_dir = path.join(scratch_dir, "archives");
    fs.mkdirSync(archive_dir);

    archives.forEach((archive) => {
        const targetPath = path.resolve(process.cwd(), archive["path"]);
        const basename = path.basename(archive["path"]);
        const symlinkPath = path.join(archive_dir, basename);
        fs.symlinkSync(targetPath, symlinkPath);
    });

    fs.symlinkSync(
        path.resolve(process.cwd(), config["package_json"]),
        path.join(scratch_dir, "package.json")
    );
    fs.symlinkSync(
        path.resolve(process.cwd(), config["yarn_lock"]),
        path.join(scratch_dir, "yarn.lock")
    );

    const yarnrc = path.join(scratch_dir, "yarnrc");
    fs.writeFileSync(yarnrc, `
disable-self-update-check true
yarn-offline-mirror ${JSON.stringify(archive_dir)}
`);

    const yarn_argv = [
        "install",
        "--frozen-lockfile",
        "--offline",
        "--production",
        "--ignore-scripts",
        "--no-default-rc",
        "--no-bin-links",
        "--use-yarnrc=" + yarnrc,
        "--cwd=" + scratch_dir,
        "--cache-folder=" + path.join(scratch_dir, "cache"),
        "--modules-folder=" + path.resolve(process.cwd(), config["modules_folder"]),
    ].concat(config["yarn_options"])

    execFileSync(config["yarn"], yarn_argv, {stdio: 'inherit'});
}

