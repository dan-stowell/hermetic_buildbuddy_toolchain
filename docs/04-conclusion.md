# Conclusion: is a BuildBuddy RBE toolchain necessary?

**No — not for a C/C++ project that uses a fully hermetic toolchain.**

With [`hermeticbuild/hermetic-llvm`](https://github.com/hermeticbuild/hermetic-llvm)
(Bazel module `llvm`) registered, `abseil-cpp` builds on BuildBuddy remote
execution with nothing but "point at the remote cache and executor." No
`buildbuddy-io/buildbuddy-toolchain`, no custom `platforms`, no
`extra_execution_platforms`, no `exec_properties`.

## The minimal configuration that works

`MODULE.bazel`:

```starlark
bazel_dep(name = "abseil-cpp", version = "20260526.0")
bazel_dep(name = "rules_cc", version = "0.2.18")  # pin: matches llvm 0.7.3
bazel_dep(name = "llvm", version = "0.7.3")
register_toolchains("@llvm//toolchain:all")
```

`.bazelrc`:

```
build --remote_executor=grpcs://remote.buildbuddy.io
build --remote_cache=grpcs://remote.buildbuddy.io
```

Plus the API key at the command line (never committed):

```
bazel build //... --remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY
```

That's the whole thing.

## Why it works (and why a toolchain used to be required)

Remote execution ships action command lines to a different machine. Bazel's
**auto-detected** C/C++ toolchain bakes in the *client's* compiler path
(`/bin/gcc` on our VM) and assumptions about its libc/headers. On the executor —
a different machine — that path may not exist (it doesn't, even in BuildBuddy's
default image: experiment [03](../experiments/03-no-toolchain-contrast)), and
even if it did you'd be compiling with the container's arbitrary compiler.

Two ways to fix the mismatch:

1. **Match the executor** — what `buildbuddy-io/buildbuddy-toolchain` does: ship
   a C/C++ toolchain whose compiler/glibc line up with a specific BuildBuddy
   Ubuntu executor image, and define the execution platforms with the right
   `exec_properties`. This couples your build to BuildBuddy's images.

2. **Make the executor irrelevant** — what a hermetic toolchain does: download
   the compiler, loader, libc, headers, and runtimes and feed them to every
   action as ordinary remote inputs. The executor only has to be able to run
   those inputs.

Experiment [02](../experiments/02-restrictive-containers) shows approach #2 is
genuinely hermetic: the build succeeds even inside
`gcr.io/distroless/static-debian12`, an image with **no libc, no dynamic loader,
no shell, and no compiler**. A bogus-image control proves BuildBuddy really used
that container. Since the executor environment supplies nothing, there is nothing
left for a BuildBuddy-specific toolchain to configure.

## "Can I avoid specifying platforms / exec_properties entirely?"

Yes.

- **Platforms:** not needed. Bazel's default `@platforms//host` execution
  platform is sufficient. Toolchain resolution selects the hermetic linux/x86_64
  toolchain from the host constraints.
- **`exec_properties` / container image:** not needed for the default executor.
  If you *want* a specific container, set it with
  `--remote_default_exec_properties=container-image=docker://...` (and
  `OSFamily=Linux`) — that applies to the default platform, so you still define
  no custom platform. With a hermetic toolchain you mostly don't need even this.

## Caveats / scope

- Tested for **Linux x86_64 host → Linux x86_64 target**, C/C++ (`abseil-cpp`),
  on BuildBuddy's shared RBE. Cross-compiling, other languages with their own
  toolchains (Go, Rust, Java, Python with native deps, protoc/grpc plugins), or
  rules that shell out to system tools may still need platform/`exec_properties`
  work — anything not hermeticized re-introduces the executor dependency.
- Requires Bazel 7.7+ (8.5+ recommended); validated here on **Bazel 9.1.1**.
- Version-pin `rules_cc` to **0.2.18** to match `llvm` 0.7.3 (see
  [gotchas](./03-gotchas.md)).
- The default-image build pulls and links LLVM compiler-rt from source the first
  time, so a cold build is a few minutes; results cache on BuildBuddy afterward.

## Implications for this repo

The repo is named `hermetic_buildbuddy_toolchain`, but the finding is that the
interesting artifact is **not** a new toolchain — it's the demonstration that, in
the hermetic world, **no BuildBuddy-specific toolchain is required at all**. The
"toolchain" reduces to a few lines of `MODULE.bazel` + `.bazelrc` that any
project can copy. See [`experiments/01-minimal-rbe`](../experiments/01-minimal-rbe)
for the copyable template.
