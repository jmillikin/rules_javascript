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

const shardedTests = (tests) => {
	const totalShardsEnv = process.env["TEST_TOTAL_SHARDS"];
	if (!totalShardsEnv) {
		return tests;
	}
	const totalShards = parseInt(totalShardsEnv, 10);
	if (isNaN(totalShards) || totalShards < 1) {
		console.log(`"Invalid \${TEST_TOTAL_SHARDS} (expected 0 < N, got ${JSON.stringify(totalShardsEnv)})`);
		process.exit(1);
	}

	const shardIndexEnv = process.env["TEST_SHARD_INDEX"] || "";
	const shardIndex = parseInt(shardIndexEnv, 10);
	if (isNaN(shardIndex) || shardIndex < 0 || shardIndex >= totalShards) {
		console.log(`"Invalid \${TEST_SHARD_INDEX} (expected 0 <= N < ${totalShards}, got ${JSON.stringify(shardIndexEnv)})`);
		process.exit(1);
	}

	return tests.filter((_test, ii) => ii % totalShards == shardIndex);
}

export const runTests = (tests) => {
	const testShardStatusFile = process.env["TEST_SHARD_STATUS_FILE"];
	if (testShardStatusFile) {
		fs.writeFileSync(testShardStatusFile, "");
	}
	let exitCode = 0;
	shardedTests(tests).forEach((test) => {
		console.log(`==================== START: ${test.name}`);
		try {
			test.call(test);
		} catch (err) {
			console.log(`==================== FAIL: ${test.name}`)
			console.log(err);
			console.log("====================");
			exitCode = 1;
			return;
		}
		console.log(`==================== PASS: ${test.name}`);
	});
	process.exit(exitCode)
}
