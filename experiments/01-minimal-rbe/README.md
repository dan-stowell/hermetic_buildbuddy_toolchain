# Experiment 01 — minimal BuildBuddy RBE, no platforms, no exec_properties

## Question

With the fully hermetic [`hermeticbuild/hermetic-llvm`](https://github.com/hermeticbuild/hermetic-llvm)
toolchain (Bazel module `llvm`) registered, can a project build `abseil-cpp` on
BuildBuddy remote execution using **only** remote flags — no `--host_platform`,
no `--platforms`, no `--extra_execution_platforms`, no `exec_properties`, and no
`buildbuddy-io/buildbuddy-toolchain`?

## Setup

The whole configuration:

- [`MODULE.bazel`](./MODULE.bazel): `bazel_dep` on `abseil-cpp`, `rules_cc`, and
  `llvm`, plus `register_toolchains("@llvm//toolchain:all")`.
- [`.bazelrc`](./.bazelrc): `--remote_executor`, `--remote_cache`, `--bes_*`.
  Nothing about platforms or toolchains.
- [`main.cc`](./main.cc) / [`BUILD.bazel`](./BUILD.bazel): a `cc_binary` that
  calls `absl::StrCat`, forcing abseil-cpp to compile + link remotely.

Run with:

```
bazel build //:hello --remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY
```

## Result: SUCCESS

abseil-cpp (and the LLVM compiler-rt runtimes) compiled and linked entirely on
BuildBuddy. Relying on Bazel's default `@platforms//host` execution platform and
BuildBuddy's **default executor container**, no extra config was needed.

- Normal build: `422 total actions, 357 remote`, binary runs and prints
  `hello buildbuddy rbe 2026`.
- Proof it was *real remote execution*, not just cache hits: a clean rebuild
  with `--spawn_strategy=remote --noremote_accept_cached` still ran all
  `357 remote` actions (no local fallback permitted, no cached results
  accepted).

Invocations (BuildBuddy):
- `https://app.buildbuddy.io/invocation/143c0ca6-45d5-435f-8240-1aa19183cf2e` (normal)
- `https://app.buildbuddy.io/invocation/bf77bafc-62ef-4c91-953c-4cbb3b2338b3` (remote-only, no cache)

## Gotchas found along the way

1. **Bazel 9 removed native `cc_binary`.** Must
   `load("@rules_cc//cc:defs.bzl", "cc_binary")` and add a `rules_cc`
   `bazel_dep`.
2. **`rules_cc` version skew.** `llvm` 0.7.3 references an internal `rules_cc`
   target (`use_libtool_on_macos_setting`) that was removed by `rules_cc`
   0.2.20. Pin `rules_cc` to **0.2.18** (the version `llvm` 0.7.3 declares).
   See [`docs/03-gotchas.md`](../../docs/03-gotchas.md).
3. **abseil label changed.** Use `@abseil-cpp//absl/strings`, not
   `@abseil-cpp//absl/strings:str_cat`.

## Caveat that motivates experiment 02

This proves the *config* can be minimal, but it does **not** yet prove the
toolchain is fully hermetic with respect to the executor. BuildBuddy's default
executor image ships a glibc and dynamic loader, so the LLVM compiler binaries
(and/or the linked output) could be silently using the container's libc. To test
true hermeticity we must run the same build in progressively more restrictive
container images — see [`experiments/02-restrictive-containers`](../02-restrictive-containers).
