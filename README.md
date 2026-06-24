# hermetic_buildbuddy_toolchain

Investigating whether a dedicated **BuildBuddy RBE toolchain is still necessary**
now that a fully hermetic LLVM toolchain
([`hermeticbuild/hermetic-llvm`](https://github.com/hermeticbuild/hermetic-llvm))
exists — and if not, finding the **minimal** Bazel config to use BuildBuddy
remote cache + remote execution without custom platforms or `exec_properties`.

The repo is the source of truth. Everything is documented under
[`docs/`](./docs), and runnable experiments live under
[`experiments/`](./experiments).

## Start here

- [`docs/00-initial-prompt.md`](./docs/00-initial-prompt.md) — the original
  request and standing instructions.
- [`docs/01-background.md`](./docs/01-background.md) — why a BuildBuddy toolchain
  has historically been needed, and the hypothesis under test.
- [`docs/02-findings.md`](./docs/02-findings.md) — what the experiments showed.

## Secrets

A BuildBuddy API key is read from `$HOME/.profile` (`BUILDBUDDY_API_KEY`). It is
**never** committed. Builds pass it via
`--remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY`.
