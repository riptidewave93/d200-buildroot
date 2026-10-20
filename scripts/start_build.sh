#!/bin/bash
# Configure and build Buildroot with our external tree.
#   start_build.sh [release|debug]
set -e
# shellcheck source=scripts/buildroot-env.sh
. "$(dirname "${BASH_SOURCE[0]}")/buildroot-env.sh"

br_configure
echo "Building the ${flavor} image, this may take a bit!"
br_make -j"$(nproc)"

"${ourpath}/scripts/collect_output.sh" "${flavor}"
