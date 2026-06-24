# Gotchas

Practical snags hit while wiring up the experiments, with fixes.

## Bazel 9 removed native `cc_*` rules

`cc_binary`, `cc_library`, etc. are no longer built into Bazel 9. You get:

```
Error in fail: This rule has been removed from Bazel. Please add a `load()` statement for it.
```

Fix: add a `rules_cc` `bazel_dep` and load the rules:

```starlark
# BUILD.bazel
load("@rules_cc//cc:defs.bzl", "cc_binary")
```

## `rules_cc` version skew vs `llvm` 0.7.3

Pinning `rules_cc` to the latest (0.2.20) breaks `llvm` 0.7.3 toolchain analysis:

```
no such target '@@rules_cc+//cc/toolchains/args/archiver_flags:use_libtool_on_macos_setting'
... errors encountered resolving select() keys for @@llvm+//toolchain:linux_x86_64_cc_toolchain
```

`llvm` 0.7.3 references an internal `rules_cc` target that 0.2.20 renamed/removed.
Fix: pin `rules_cc` to **0.2.18**, the version `llvm` 0.7.3 itself declares.

## abseil-cpp target labels

`@abseil-cpp//absl/strings:str_cat` is not a target. The aggregated library is
`@abseil-cpp//absl/strings`. Use `bazel query 'attr(name, "...", @abseil-cpp//...)'`
to find the right label.

## Passing the BuildBuddy API key without committing it

Keep the key out of all committed files. Pass it at the command line from the
environment (it lives in `$HOME/.profile` as `BUILDBUDDY_API_KEY`):

```
bazel build //... --remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY
```

`MODULE.bazel.lock` and `bazel-*` symlinks are git-ignored.
