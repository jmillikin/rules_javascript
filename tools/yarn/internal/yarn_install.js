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

const config_path = process.argv[2];
const config = JSON.parse(fs.readFileSync(config_path, "utf8"));

const archive_dir = path.resolve(process.cwd(), config["archive_dir"]);
fs.mkdirSync(archive_dir, {recursive: true});

Object.entries(config["archives"]).forEach((pair) => {
    const [target, basename] = pair;
    fs.symlinkSync(
        path.resolve(process.cwd(), target),
        path.resolve(archive_dir, basename),
    );
});

fs.writeFileSync(config["yarnrc"], `
disable-self-update-check true
yarn-offline-mirror ${JSON.stringify(archive_dir)}
`)

process.argv.splice(1, 2);

const yarn_main_js = path.join(process.cwd(), process.argv[1]);
require(yarn_main_js);
