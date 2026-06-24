# Findings

> Status: **in progress.** This document is updated as experiments run.

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

### Open question being tested next

Experiment 01 used BuildBuddy's **default** executor image, which ships a glibc
and dynamic loader. So it does not yet prove the toolchain is hermetic *with
respect to the executor* — the LLVM compiler binaries or linked outputs might be
quietly using the container's libc. Experiment
[02](../experiments/02-restrictive-containers) re-runs the build in
progressively more restrictive container images (down to one with no libc) to
find what, if anything, the toolchain actually needs from the executor
environment.

The container image is selected with `--remote_default_exec_properties`, which
sets exec properties for the default platform **without defining a custom
platform** — so the "minimal config" property is preserved while we vary the
environment.

