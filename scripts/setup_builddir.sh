#!/bin/bash
# Fetch Buildroot at a pinned commit into ./BuildEnv/buildroot (once).
#   setup_builddir.sh <repo-url> <commit>
set -e
echo "Running setup_builddir.sh"

ourpath="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
buildenv="${ourpath}/BuildEnv"
repo="${1}"
commit="${2}"

if [ -d "${buildenv}/buildroot/.git" ]; then
    have="$(git -C "${buildenv}/buildroot" rev-parse HEAD)"
    if [ "${have}" = "${commit}" ]; then
        echo "Buildroot already at ${commit}"
        exit 0
    fi
    echo "Error: BuildEnv has Buildroot ${have}, want ${commit}. Run 'make clean' first."
    exit 1
fi

mkdir -p "${buildenv}/buildroot"
cd "${buildenv}/buildroot"
git init -q
git remote add origin "${repo}"
git fetch -q --depth 1 origin "${commit}"
git checkout -q FETCH_HEAD
echo "Buildroot checked out at $(git rev-parse HEAD)"
echo "Finished setup_builddir.sh"
