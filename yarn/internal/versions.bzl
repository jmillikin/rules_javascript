# Copyright 2019 the rules_javascript authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

_MIRRORS = [
    "https://registry.yarnpkg.com/yarn/-/yarn-{v}.tgz",
    "https://registry.npmjs.com/yarn/-/yarn-{v}.tgz",
    "https://registry.npm.taobao.org/yarn/-/yarn-{v}.tgz",
    "https://github.com/yarnpkg/yarn/releases/download/v{v}/yarn-v{v}.tar.gz",
]

def _urls(version, sha256):
    return (version, dict(
        urls =  [m.format(v = version) for m in _MIRRORS],
        sha256 = sha256,
    ))

YARN_DEFAULT_VERSION = "1.19.1"

YARN_VERSION_URLS = dict([
    _urls("1.19.1", "34293da6266f2aae9690d59c2d764056053ff7eebc56b80b8df05010c3da9343"),
    _urls("1.13.0", "125d40ebf621ebb08e3f66a618bd2cc5cd77fa317a312900a1ab4360ed38bf14"),
])
