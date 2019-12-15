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
    "https://mirror.bazel.build/github.com/denoland/deno/releases/download/v{v}/deno_{p}.gz",
    "https://github.com/denoland/deno/releases/download/v{v}/deno_{p}.gz",
]

def _urls(version, sha256_by_platform):
    platform_rename = {
        "x86_64-linux": "linux_x64",
        "x86_64-darwin": "osx_x64",
    }
    urls = {}
    for platform, sha256 in sha256_by_platform.items():
        urls[platform] = {
            "urls": [m.format(v = version, p = platform_rename[platform]) for m in _MIRRORS],
            "sha256": sha256,
        }
    return (version, urls)

DENO_DEFAULT_VERSION = "0.21.0"

DENO_VERSION_URLS = dict([
    _urls("0.21.0", {
        "x86_64-darwin": "c59da8c181a73ab080ab5a4b74784869391389811fe5121d074485f6e110fd40",
        "x86_64-linux": "bcc874b3881c6f5b38143d7872b55d200528610cb2af360ce243a7e406e933b3",
    }),
])

def deno_check_version(version, platform = None):
    if version not in DENO_VERSION_URLS:
        fail("Deno version {} not supported by rules_javascript".format(repr(version)))
    if platform != None:
        if platform not in DENO_VERSION_URLS[version]:
            fail("Deno platform {} not supported by rules_javascript".format(repr(version)))
