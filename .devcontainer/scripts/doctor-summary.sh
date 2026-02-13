#!/usr/bin/env bash
set -euo pipefail

export PATH="${FLUTTER_ROOT:-/opt/flutter}/bin:${PATH}"

# Helpful quick summary at startup; never block opening a Codespace.
flutter doctor || true
