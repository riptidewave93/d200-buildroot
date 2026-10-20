#!/bin/bash
# Rebuild one package from scratch, e.g. after changing its patches or config, then
# rebuild the images and collect them.
#   rebuild_package.sh <package> [release|debug]
set -e
pkg="${1}"
# shellcheck source=scripts/buildroot-env.sh
. "$(dirname "${BASH_SOURCE[0]}")/buildroot-env.sh" "${2}"

br_configure
br_make "${pkg}-dirclean"
br_make -j"$(nproc)"

"${ourpath}/scripts/collect_output.sh" "${flavor}"
