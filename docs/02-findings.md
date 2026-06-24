# Findings

> Status: **answered.** See [`04-conclusion.md`](./04-conclusion.md) for the
> full write-up; the short version is below.

See [`experiments/`](../experiments) for the runnable cases that produced these
findings. Each experiment directory has its own `README.md` describing exactly
what was tried and the result.

## Summary so far

**A dedicated BuildBuddy RBE toolchain is NOT required for a C++ project that
uses a fully hermetic toolchain.** With `hermeticbuild/hermetic-llvm` registered,
`abseil-cpp` builds on BuildBuddy remote execution using only:

```
build --remote_executor=grpcs://remote.buildbuddy.io
build --remote_cache=grpcs://remote.buildbuddy.io
# + --remote_header=x-buildbuddy-api-key=<KEY> at the command line
```

No `--host_platform`, no `--platforms`, no `--extra_execution_platforms`, no
`exec_properties`, no `buildbuddy-io/buildbuddy-toolchain`. Bazel's default
`@platforms//host` execution platform plus BuildBuddy's default executor
container are enough. (Experiment
[01](../experiments/01-minimal-rbe): 357 actions ran remotely, verified with
`--spawn_strategy=remote --noremote_accept_cached`.)

### It is genuinely hermetic, not just minimally configured

Experiment 01 used BuildBuddy's **default** executor image (which ships a glibc),
so on its own it only proves the *config* can be minimal. Experiment
[02](../experiments/02-restrictive-containers) re-ran the build inside
`gcr.io/distroless/static-debian12` — an image with **no libc, no dynamic
loader, no shell, no compiler** — and it still succeeded (357 remote actions, no
cache). A bogus-image control proved BuildBuddy actually used that container. So
the toolchain carries everything (compiler, loader, libc, headers, runtimes) as
action inputs; the executor environment is irrelevant.

The container image was selected with `--remote_default_exec_properties`, which
sets exec properties on the default platform **without defining a custom
platform** — so the "minimal config" property held throughout.

### The contrast confirms the toolchain is what does the work

Experiment [03](../experiments/03-no-toolchain-contrast) removed the hermetic
toolchain. Bazel's auto-detected toolchain baked in the client's `/bin/gcc` and
failed on the executor — in the restrictive image *and* in BuildBuddy's default
image (`executable file /bin/gcc not found`). That is the exact historical
failure `buildbuddy-io/buildbuddy-toolchain` existed to fix (by matching the
executor image). A hermetic toolchain fixes it by making the executor
irrelevant.

### Scope

Validated for Linux x86_64 → Linux x86_64, C/C++ (`abseil-cpp`), on Bazel 9.1.1.
Other languages/cross-compiles/system-tool-dependent rules may still need
platform work — see [conclusion caveats](./04-conclusion.md#caveats--scope).

