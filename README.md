# hermetic_buildbuddy_toolchain

Investigating whether a dedicated **BuildBuddy RBE toolchain is still necessary**
now that a fully hermetic LLVM toolchain
([`hermeticbuild/hermetic-llvm`](https://github.com/hermeticbuild/hermetic-llvm))
exists — and if not, finding the **minimal** Bazel config to use BuildBuddy
remote cache + remote execution without custom platforms or `exec_properties`.

The repo is the source of truth. Everything is documented under
[`docs/`](./docs), and runnable experiments live under
[`experiments/`](./experiments).

## Answer (TL;DR)

**No dedicated BuildBuddy RBE toolchain is needed.** With a hermetic toolchain,
`abseil-cpp` builds on BuildBuddy remote execution with just:

```starlark
# MODULE.bazel
bazel_dep(name = "abseil-cpp", version = "20260526.0")
bazel_dep(name = "rules_cc", version = "0.2.18")   # pin: matches llvm 0.7.3
bazel_dep(name = "llvm", version = "0.7.3")        # hermeticbuild/hermetic-llvm
register_toolchains("@llvm//toolchain:all")
```

```
# .bazelrc
build --remote_executor=grpcs://remote.buildbuddy.io
build --remote_cache=grpcs://remote.buildbuddy.io
# + --remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY at the CLI
```

No custom `platforms`, no `extra_execution_platforms`, no `exec_properties`, no
`buildbuddy-io/buildbuddy-toolchain`. It's genuinely hermetic: the same build
succeeds even in a `distroless/static` executor image with no libc. Full
reasoning in [`docs/04-conclusion.md`](./docs/04-conclusion.md).

## Start here

- [`docs/00-initial-prompt.md`](./docs/00-initial-prompt.md) — the original
  request and standing instructions.
- [`docs/01-background.md`](./docs/01-background.md) — why a BuildBuddy toolchain
  has historically been needed, and the hypothesis under test.
- [`docs/02-findings.md`](./docs/02-findings.md) — what the experiments showed.
- [`docs/03-gotchas.md`](./docs/03-gotchas.md) — practical snags and fixes.
- [`docs/04-conclusion.md`](./docs/04-conclusion.md) — the answer, with caveats.

## Experiments

- [`experiments/01-minimal-rbe`](./experiments/01-minimal-rbe) — minimal config
  builds abseil-cpp on RBE (the copyable template).
- [`experiments/02-restrictive-containers`](./experiments/02-restrictive-containers)
  — proves hermeticity by building in a no-libc container.
- [`experiments/03-no-toolchain-contrast`](./experiments/03-no-toolchain-contrast)
  — removes the toolchain to show why it's needed / what it buys.

## Secrets

A BuildBuddy API key is read from `$HOME/.profile` (`BUILDBUDDY_API_KEY`). It is
**never** committed. Builds pass it via
`--remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY`.
