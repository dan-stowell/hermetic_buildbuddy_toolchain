# Experiment 02 — how hermetic is it, really? (restrictive container images)

## Question

Experiment 01 worked, but on BuildBuddy's **default** executor image, which
ships a glibc + dynamic loader. So it didn't prove the toolchain is hermetic
*with respect to the executor* — the LLVM compiler binaries or the linked output
could quietly be using the container's libc.

This experiment strips the executor environment down to find what (if anything)
the toolchain actually needs from it.

## How the container is selected — still no custom platform

The container image is chosen with **`--remote_default_exec_properties`**, which
applies exec properties to any execution platform that doesn't already set them.
Bazel's default `@platforms//host` platform sets none, so these defaults take
effect. We therefore change the executor environment **without defining a single
custom platform** — the "minimal config" property from experiment 01 is
preserved.

```
--remote_default_exec_properties=OSFamily=Linux
--remote_default_exec_properties=container-image=docker://<image>
```

## Method

Rather than walk the ladder slowly, we tested the **hardest** case first: an
image with no libc at all. If the build survives that, every less-restrictive
image trivially would too.

Image used: **`gcr.io/distroless/static-debian12`** — contains only
ca-certificates, tzdata, and `/etc/passwd`. **No glibc, no dynamic loader, no
shell, no compiler.** It exists for fully static Go/Rust binaries.

All builds run with `--spawn_strategy=remote --noremote_accept_cached` so there
is no local fallback and no cache masking.

## Result: SUCCESS — fully hermetic

`abseil-cpp` + the LLVM compiler-rt runtimes compiled and linked inside
`distroless/static-debian12`. `422 total actions, 357 remote`, and the resulting
binary runs locally and prints `hello buildbuddy rbe 2026`.

Because clang itself ran successfully in a container with no libc/loader, the
toolchain must be carrying everything it needs (compiler, loader, libc, headers,
runtimes) as ordinary Bazel action inputs. **The executor environment is
irrelevant.**

Invocation: `https://app.buildbuddy.io/invocation/69e0cc35-724e-472b-84ed-63caf81a59f8`

## Control — proving the container property was actually honored

A success in a stripped-down image is only meaningful if BuildBuddy really used
that image (and didn't silently fall back to its default). Re-running with a
deliberately invalid image name fails immediately:

```
Remote Execution Failure: Invalid Argument: error creating runner for command:
invalid image name "gcr.io/distroless/THIS-IMAGE-DOES-NOT-EXIST-xyz:latest"
```

So `container-image` is genuinely applied — the `distroless/static` success is
real. Invocation:
`https://app.buildbuddy.io/invocation/9b6066d8-7ec8-4071-a422-3c10bf5dfdd3`

## Reproduce

```
bazel build //:hello \
  --remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY \
  --remote_default_exec_properties=OSFamily=Linux \
  --remote_default_exec_properties=container-image=docker://gcr.io/distroless/static-debian12:latest \
  --spawn_strategy=remote --noremote_accept_cached
```

See also [`run-ladder.sh`](./run-ladder.sh) to run a fuller ladder of images.
