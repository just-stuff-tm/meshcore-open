#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".devcontainer/Dockerfile" ]; then
  echo "[devcontainer] Expected to run from repository root containing .devcontainer/Dockerfile"
  exit 1
fi
