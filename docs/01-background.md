# Background: why a BuildBuddy RBE toolchain has historically been needed

## The problem remote execution creates

When Bazel runs a build locally, its C/C++ rules auto-detect a toolchain by
probing the local machine (`/usr/bin/gcc`, system headers, etc.). Those probed
paths are baked into the action command lines.

Remote Build Execution (RBE) ships those action command lines to a *different*
machine — a BuildBuddy executor running inside some container image. If the
action says "run `/usr/bin/gcc` with these system include dirs," but the
executor container has a different compiler, different glibc, or different
headers, the build is either non-reproducible or fails outright.

So for RBE you need two things to line up:

1. **A C/C++ toolchain whose paths/behavior are valid on the executor.**
2. **A way to tell BuildBuddy which executor environment (container image, OS)
   to run actions in**, via Bazel *execution platforms* carrying
   `exec_properties` such as `container-image` and `OSFamily`.

## What `buildbuddy-io/buildbuddy-toolchain` provides

[`buildbuddy-io/buildbuddy-toolchain`](https://github.com/buildbuddy-io/buildbuddy-toolchain)
solves both at once:

- It registers a **C/C++ toolchain** that matches the compiler/glibc baked into
  BuildBuddy's default executor images (e.g. Ubuntu 16.04 / GCC 5.4 / glibc
  2.23, with newer Ubuntu 20.04 / 22.04 / 24.04 variants available).
- It defines **execution platforms** with the right `exec_properties` (which
  container image to pull, `OSFamily`, etc.).

You then point Bazel at it with flags roughly like:

```
--host_platform=@buildbuddy_toolchain//:platform
--platforms=@buildbuddy_toolchain//:platform
--extra_execution_platforms=@buildbuddy_toolchain//:platform
--crosstool_top=@buildbuddy_toolchain//:toolchain   # WORKSPACE-era
```

The toolchain is therefore tightly coupled to BuildBuddy's executor images: the
compiler you build *with* must match the system the executor runs.

## What changes with a hermetic toolchain

[`hermeticbuild/hermetic-llvm`](https://github.com/hermeticbuild/hermetic-llvm)
(Bazel module name `llvm`) is a **zero-sysroot, fully hermetic** C/C++
cross-compilation toolchain. It downloads LLVM/clang plus Bazel-built
runtime/libc stacks (libc++, libc++abi, compiler-rt, libunwind, sanitizers) and
brings its own sysroot. Nothing is taken from the host or the executor.

That removes reason **#1** above entirely: the toolchain is identical on the
local machine and on any Linux executor, so it no longer has to *match* the
executor image. The compiler, headers, and libc all travel with the build as
ordinary remote inputs.

That leaves reason **#2** — how does Bazel/BuildBuddy decide which container to
run actions in, and can that be reduced to nothing (or near nothing)?

## The hypothesis under test

With a hermetic toolchain registered, a project should be able to use BuildBuddy
RBE with only:

```
build --remote_executor=grpcs://remote.buildbuddy.io
build --remote_cache=grpcs://remote.buildbuddy.io
build --remote_header=x-buildbuddy-api-key=<KEY>
```

and **no** custom `platforms`, `extra_execution_platforms`, or `exec_properties`
— relying on Bazel's default `@platforms//host` execution platform and
BuildBuddy's default executor container. `abseil-cpp` is the test case.

The experiments in [`/experiments`](../experiments) and the findings in
[`02-findings.md`](./02-findings.md) record whether that holds in practice and
what (if anything) the irreducible minimum config turns out to be.

## Tooling versions used

- Bazel (via Bazelisk): **9.1.1**
- `hermetic-llvm` module `llvm`: **0.7.3** (BCR) — requires Bazel 7.7+, 8.5+
  recommended.
- `abseil-cpp`: latest BCR is **20260526.0** at time of writing.
