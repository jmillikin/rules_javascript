workspace(name = "rules_javascript")

load("@rules_javascript//javascript:repositories.bzl", "rules_javascript_toolchains")

rules_javascript_toolchains()

# rules_javascript_toolchains(node_version = "10.13.0")

# rules_javascript_toolchains(node_version = "13.0.1")

load("@rules_javascript//yarn:yarn.bzl", "yarn_register_toolchains")

yarn_register_toolchains("1.19.1")
yarn_register_toolchains("1.13.0")

load("@rules_javascript//yarn:yarn.bzl", "yarn_archives")

yarn_archives(
    name = "yarn_archives",
    lockfiles = ["//demo-install-dirs:yarn/yarn.lock"],
)

local_repository(
    name = "test_external",
    path = "test_external",
)

load("//tests/integration:util.bzl", "integration_test_archives")

integration_test_archives(name = "integration_test_archives")
