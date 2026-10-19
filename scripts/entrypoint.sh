#!/bin/bash
# Runs inside the builder container (the repo is mounted at /repo).
set -e
echo "entrypoint.sh - Starting build process..."
cd /repo
make builder-build
echo "entrypoint.sh - Done! Images are in ./output/"
