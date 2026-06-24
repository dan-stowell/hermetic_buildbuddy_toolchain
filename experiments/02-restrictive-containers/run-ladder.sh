#!/usr/bin/env bash
# Build //:hello on BuildBuddy RBE in progressively more restrictive executor
# container images, to find what (if anything) the hermetic toolchain needs from
# the executor environment.
#
# The container is chosen purely via --remote_default_exec_properties, so NO
# custom Bazel platform is ever defined.
#
# Requires BUILDBUDDY_API_KEY in the environment (it is in $HOME/.profile).
set -euo pipefail

: "${BUILDBUDDY_API_KEY:?set BUILDBUDDY_API_KEY (see \$HOME/.profile)}"

# Most -> least capable. "static" has no libc/loader; it is the real test.
IMAGES=(
  ""                                            # BuildBuddy default image
  "gcr.io/distroless/cc-debian12:latest"        # glibc + libstdc++, no shell
  "gcr.io/distroless/base-debian12:latest"      # glibc, no libstdc++
  "gcr.io/distroless/static-debian12:latest"    # NO libc, NO loader, NO shell
)

for img in "${IMAGES[@]}"; do
  echo "=================================================================="
  if [[ -z "$img" ]]; then
    echo "IMAGE: <BuildBuddy default>"
    container_flags=()
  else
    echo "IMAGE: $img"
    container_flags=(
      --remote_default_exec_properties=OSFamily=Linux
      --remote_default_exec_properties=container-image=docker://"$img"
    )
  fi
  echo "=================================================================="
  bazel clean >/dev/null 2>&1
  if bazel build //:hello \
      --remote_header=x-buildbuddy-api-key="$BUILDBUDDY_API_KEY" \
      "${container_flags[@]}" \
      --spawn_strategy=remote --noremote_accept_cached; then
    echo "RESULT: SUCCESS in '${img:-<default>}'"
    ./bazel-bin/hello
  else
    echo "RESULT: FAILURE in '${img:-<default>}'"
  fi
  echo
done
