#!/usr/bin/env bash
set -euo pipefail

export PATH="${FLUTTER_ROOT:-/opt/flutter}/bin:${PATH}"

PUB_CACHE_DIR="${PUB_CACHE:-/home/vscode/.pub-cache}"
mkdir -p "${PUB_CACHE_DIR}" || true
if [ ! -w "${PUB_CACHE_DIR}" ] && command -v sudo >/dev/null 2>&1; then
  sudo chown -R "$(id -u):$(id -g)" "${PUB_CACHE_DIR}" || true
fi
if [ -w "${PUB_CACHE_DIR}" ]; then
  export PUB_CACHE="${PUB_CACHE_DIR}"
else
  export PUB_CACHE="/tmp/.pub-cache"
  mkdir -p "${PUB_CACHE}"
  echo "[devcontainer] PUB_CACHE not writable; using ${PUB_CACHE} for this session."
fi

flutter pub get
