# Experiment 03 — the contrast: what happens with NO hermetic toolchain

## Question

Experiments 01 and 02 show abseil-cpp builds on BuildBuddy RBE with minimal
config *because* of the hermetic `llvm` toolchain. This experiment removes that
toolchain to confirm the toolchain is what makes it work — and to reproduce the
historical failure mode that motivated `buildbuddy-io/buildbuddy-toolchain`.

[`MODULE.bazel`](./MODULE.bazel) is identical to experiment 01 **except** it has
no `llvm` dep and no `register_toolchains(...)`. Bazel falls back to its
**auto-detected** C/C++ toolchain, which probes the *client* machine and records
the client's compiler path.

On this client VM, that path is `/bin/gcc` (a symlink to `gcc-13`):

```
/bin/gcc -> gcc-13
```

## Result: FAILURE in every executor image

### (a) `gcr.io/distroless/static-debian12` (no compiler)

```
gcc failed: error executing CppCompile command /bin/gcc ...
executable file `/bin/gcc` not found in $PATH: No such file or directory
```

Invocation: `https://app.buildbuddy.io/invocation/05f96ccc-fb38-4548-924e-8fe363549589`

### (b) BuildBuddy's DEFAULT executor image

Same failure — even the default image doesn't have a compiler at `/bin/gcc`:

```
gcc failed: error executing CppCompile command /bin/gcc ...
executable file `/bin/gcc` not found in $PATH: No such file or directory
```

Invocation: `https://app.buildbuddy.io/invocation/466a8351-5c03-4af9-a748-06775fb07a09`

## Why this is the whole point

The auto-detected toolchain bakes in a **client-side** compiler path
(`/bin/gcc`) and ships it to the executor. The executor is a different machine
with a different filesystem, so the action fails. Even if some executor image
*did* happen to have `/bin/gcc`, you'd be compiling with that container's
arbitrary gcc + glibc — non-reproducible and silently coupled to the image.

This is exactly the problem `buildbuddy-io/buildbuddy-toolchain` was created to
solve, and it solved it by shipping a toolchain whose paths/compiler **match**
specific BuildBuddy executor images. You picked an Ubuntu image and used the
matching toolchain.

A **hermetic** toolchain (experiments 01–02) solves the same problem more
fundamentally: instead of matching the executor, it makes the executor
irrelevant — the compiler, loader, libc, headers, and runtimes all travel with
the build as action inputs. That's why no custom platform, no `exec_properties`,
and no BuildBuddy-specific toolchain are needed.

## Reproduce

```
# (a) restrictive image
bazel build //:hello \
  --remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY \
  --remote_default_exec_properties=OSFamily=Linux \
  --remote_default_exec_properties=container-image=docker://gcr.io/distroless/static-debian12:latest \
  --spawn_strategy=remote --noremote_accept_cached

# (b) default image
bazel build //:hello \
  --remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY \
  --spawn_strategy=remote --noremote_accept_cached
```
