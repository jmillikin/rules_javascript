load(
    "//javascript/internal/node:versions.bzl",
    "NODE_VERSION_URLS",
    "NODE_CHAKRACORE_VERSION_URLS",
)

def _integration_test_archives(ctx):
    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", """
filegroup(
    name = {},
    srcs = glob(["archives/**/*"]),
    visibility = ["//visibility:public"],
)
""".format(repr(ctx.name)))

    for urls_by_platform in NODE_VERSION_URLS.values():
        for urls in urls_by_platform.values():
            url = urls["urls"][0]
            basename = url[url.rindex('/')+1:]
            ctx.download(
                url = urls["urls"],
                sha256 = urls["sha256"],
                output = "archives/node/" + basename,
            )

    for urls_by_platform in NODE_CHAKRACORE_VERSION_URLS.values():
        for urls in urls_by_platform.values():
            url = urls["urls"][0]
            basename = url[url.rindex('/')+1:]
            ctx.download(
                url = urls["urls"],
                sha256 = urls["sha256"],
                output = "archives/node-chakracore/" + basename,
            )

    ctx.download(
        url = "https://mirror.bazel.build/github.com/bazelbuild/rules_cc/archive/8bd6cd75d03c01bb82561a96d9c1f9f7157b13d0.zip",
        sha256 = "1d4dbbd1e1e9b57d40bb0ade51c9e882da7658d5bfbf22bbd15b68e7879d761f",
        output = "archives/rules_cc/8bd6cd75d03c01bb82561a96d9c1f9f7157b13d0.zip",
    )

    ctx.download(
        url = "https://mirror.bazel.build/github.com/bazelbuild/rules_java/archive/7cf3cefd652008d0a64a419c34c13bdca6c8f178.zip",
        sha256 = "bc81f1ba47ef5cc68ad32225c3d0e70b8c6f6077663835438da8d5733f917598",
        output = "archives/rules_java/7cf3cefd652008d0a64a419c34c13bdca6c8f178.zip",
    )

    ctx.download(
        url = "https://registry.yarnpkg.com/acorn/-/acorn-7.1.0.tgz",
        sha256 = "a1b880de061bc27f38fd610ad73938d3d2e3ca2946c3cc78c2b358649493f1ca",
        output = "archives/acorn-7.1.0.tgz",
    )

    ctx.download(
        url = "https://registry.yarnpkg.com/yarn/-/yarn-1.19.1.tgz",
        sha256 = "34293da6266f2aae9690d59c2d764056053ff7eebc56b80b8df05010c3da9343",
        output = "archives/yarn-1.19.1.tgz",
    )

    ctx.download(
        url = "https://registry.yarnpkg.com/typescript/-/typescript-3.7.2.tgz",
        sha256 = "bd068e5c31005b7128123efb0e4d78002e0de958a4616f17026c3a45b508e714",
        output = "archives/typescript-3.7.2.tgz",
    )

integration_test_archives = repository_rule(_integration_test_archives)

def _test_target(test, runtime, engine, node_version):
    return native.sh_test(
        name = "{}__{}-{}-v{}".format(test, runtime, engine, node_version),
        srcs = ["integration_test.js"],
        args = [
            "$(NODE)",
            test,
            "'{}'".format(struct(
                runtime = "node",
                engine = engine,
                node_version = node_version,
            ).to_json()),
        ],
        data = [
            ":javascript_toolchain",
            "//:all_srcs",
            "//tests:unittest_js",
            "@integration_test_archives",
        ] + native.glob([test + "/**/*"]),
        exec_compatible_with = [
            "//javascript/constraints/runtime:node",
        ],
        toolchains = ["//javascript:current_javascript_toolchain"],
    )


def integration_test_targets():
    tests = native.glob(["Test*"], exclude_directories = 0)
    out = []
    for test in tests:
        for node_version in NODE_VERSION_URLS:
            out.append(_test_target(
                test = test,
                runtime = "node",
                engine = "v8",
                node_version = node_version,
            ))
        for node_version in NODE_CHAKRACORE_VERSION_URLS:
            out.append(_test_target(
                test = test,
                runtime = "node",
                engine = "chakracore",
                node_version = node_version,
            ))
    return out
