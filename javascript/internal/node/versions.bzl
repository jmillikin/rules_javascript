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

_NODE_MIRRORS = [
    "https://mirror.bazel.build/nodejs.org/dist/v{v}/node-v{v}-{p}.tar.xz",
    "https://nodejs.org/dist/v{v}/node-v{v}-{p}.tar.xz",
    "https://npm.taobao.org/mirrors/node/v{v}/node-v{v}-{p}.tar.xz",
]

_NODE_CHAKRACORE_MIRRORS = [
    "https://mirror.bazel.build/github.com/nodejs/node-chakracore/releases/download/node-chakracore-v{v}/node-v{v}-{p}.tar.xz",
    "https://github.com/nodejs/node-chakracore/releases/download/node-chakracore-v{v}/node-v{v}-{p}.tar.xz",
    "https://npm.taobao.org/mirrors/node-chakracore/node-chakracore-v{v}/node-v{v}-{p}.tar.xz",
]

def _urls(project, version, sha256_by_platform):
    if project == "node":
        mirrors = _NODE_MIRRORS
    elif project == "node-chakracore":
        mirrors = _NODE_CHAKRACORE_MIRRORS
    else:
        fail()
    platform_rename = {
        "x86_64-linux": "linux-x64",
        "x86_64-darwin": "darwin-x64",
    }
    urls = {}
    for platform, sha256 in sha256_by_platform.items():
        urls[platform] = {
            "urls": [m.format(v = version, p = platform_rename[platform]) for m in mirrors],
            "sha256": sha256,
        }
    return (version, urls)

NODE_DEFAULT_VERSION = "13.2.0"

NODE_VERSION_URLS = dict([
    _urls("node", "13.2.0", {
        "x86_64-darwin": "c3eec7f79fc9e26f36068349dad0aa256564643e2ba19159cb30ad40934fede9",
        "x86_64-linux": "366df8a38b522a5899c3f48d8c9e359b3370495cf84867b2673dc10483adbdef",
    }),
    _urls("node", "13.1.0", {
        "x86_64-darwin": "b918bdc6ca5726084a737c926744cdaecde624ba39ac8aaed889f296007a5094",
        "x86_64-linux": "2eecb5a4b7975c3b406bee36b12c9a29e8bedf9553c88cad310b8f076db00881",
    }),
    _urls("node", "13.0.1", {
        "x86_64-darwin": "82d778db08f354242d1114fb98670a0b03bd81d30c7007a12c78ddea931cbcd0",
        "x86_64-linux": "d5657c19bb30b267bf2e0f2b61f6a96d8955aa30b69240f22d3fd2c65e123cf7",
    }),
    _urls("node", "12.13.0", {
        "x86_64-darwin": "d3a2cda4a4088b5f11985795b943fb34690ff3cf6a71aae715dac68a62c4725f",
        "x86_64-linux": "7a57ef2cb3036d7eacd50ae7ba07245a28336a93652641c065f747adb2a356d9",
    }),
    _urls("node", "10.15.0", {
        "x86_64-darwin": "90c991ad51528705b47312fb63f52cd770c66757b02b782168e4bc6c5165b8be",
        "x86_64-linux": "4ee8503c1133797777880ebf75dcf6ae3f9b894c66fd2d5da507e407064c13b5",
    }),
    _urls("node", "10.13.0", {
        "x86_64-darwin": "d84966a26e44b98c5408dbab7c67c02af327eb9a9012fee9827f69cd8b722766",
        "x86_64-linux": "0dc6dba645550b66f8f00541a428c29da7c3cde32fb7eda2eb626a9db3bbf08d",
    }),
])

NODE_CHAKRACORE_VERSION_URLS = dict([
    _urls("node-chakracore", "10.13.0", {
        "x86_64-darwin": "67d50144ee972ee2f27aa56c14ac22e8e6b86572e9446b219c4ef67f8ac17fc2",
        "x86_64-linux": "914fc8c5cc43ea98245a426a55ad061db863bc5669b511414bf9cbef1d5e34da",
    }),
])

def node_check_version(version, platform = None):
    if version not in NODE_VERSION_URLS:
        fail("Node.js version {} not supported by rules_javascript".format(repr(version)))
    if platform != None:
        if platform not in NODE_VERSION_URLS[version]:
            fail("Node.js platform {} not supported by rules_javascript".format(repr(version)))
