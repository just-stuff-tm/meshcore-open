#!/usr/bin/env bash
set -euo pipefail

export PATH="${FLUTTER_ROOT:-/opt/flutter}/bin:${PATH}"

# Helpful quick summary at startup; never block opening a Codespace.
# Verify constraints first (non-fatal), then show flutter doctor.
bash .devcontainer/scripts/verify-constraints.sh || true
flutter doctor || true
