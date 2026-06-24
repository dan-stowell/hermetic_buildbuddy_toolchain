# Initial prompt

This repository's work began with the following request (verbatim), on
2026-06-24:

> Good morning!
> In light of hermeticbuild/llvm, I want to revisit whether a toolchain for
> using BuildBuddy RBE is necessary at all. If so, I wonder if it's possible to
> just point builds at a remote cache and remote executor and not have to
> specify extra execution platforms, platforms, or anything else.
> abseil-cpp is probably a good test case.
> I have placed a BuildBuddy API key in $HOME/.profile for experimentation
> buildbuddy-io/buildbuddy-toolchain is the current toolchain
> Please use Bazel for everything.
> Please commit and push often -- you're the only one working in this repo.
> Please document everything (including this initial prompt) -- the repo is the
> source of truth.

## Standing instructions distilled from the prompt

- **Goal:** Determine whether a dedicated BuildBuddy RBE *toolchain* is still
  necessary now that a fully hermetic LLVM toolchain
  ([`hermeticbuild/hermetic-llvm`](https://github.com/hermeticbuild/hermetic-llvm))
  exists. If a toolchain is *not* necessary, find the **minimal** Bazel config
  that lets a normal project use BuildBuddy remote cache + remote execution —
  ideally without custom `platforms`, `extra_execution_platforms`, or
  `exec_properties`.
- **Test case:** `abseil-cpp`.
- **Secrets:** A BuildBuddy API key lives in `$HOME/.profile` as
  `BUILDBUDDY_API_KEY`. It must **never** be committed to the repo.
- **Tooling:** Use Bazel for everything.
- **Workflow:** Commit and push often; the repo is the single source of truth,
  so document everything (including this prompt and all findings).
