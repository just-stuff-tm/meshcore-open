#!/usr/bin/env bash
set -euo pipefail

# Lightweight checks to verify devcontainer matches project constraints.
# Non-fatal: prints warnings only.

REQUIRED_FLUTTER="3.41.0"
REQUIRED_DART="3.11.0"

sep() { printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' -; }

installed_flutter="$(flutter --version 2>/dev/null | head -n1 || true)"
installed_dart="$(flutter --version 2>/dev/null | sed -n 's/.*Dart \([0-9.]*\).*/\1/p' || true)"

echo "[devcontainer] Verifying Flutter/Dart versions..."
if [[ -z "${installed_flutter}" ]]; then
  echo "⚠️  Flutter not found in PATH. Expected >= ${REQUIRED_FLUTTER}."
else
  echo "  Installed: ${installed_flutter}"
fi

# version_compare: returns 0 if $1 >= $2
version_ge() {
  # compare semantic versions (major.minor.patch)
  IFS='.' read -r -a a <<<"$1"
  IFS='.' read -r -a b <<<"$2"
  for i in 0 1 2; do
    ai=${a[i]:-0}
    bi=${b[i]:-0}
    if (( ai > bi )); then return 0; fi
    if (( ai < bi )); then return 1; fi
  done
  return 0
}

if [[ -n "${installed_flutter}" ]]; then
  ver=$(printf '%s' "${installed_flutter}" | sed -E 's/Flutter ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
  if version_ge "${ver}" "${REQUIRED_FLUTTER}"; then
    echo "✅ Flutter ${ver} meets requirement >= ${REQUIRED_FLUTTER}"
  else
    echo "⚠️  Flutter ${ver} is older than required ${REQUIRED_FLUTTER}"
  fi
fi

if [[ -n "${installed_dart}" ]]; then
  if version_ge "${installed_dart}" "${REQUIRED_DART}"; then
    echo "✅ Dart ${installed_dart} meets requirement >= ${REQUIRED_DART}"
  else
    echo "⚠️  Dart ${installed_dart} is older than required ${REQUIRED_DART}"
  fi
else
  echo "⚠️  Could not determine Dart version via 'flutter --version' output."
fi

sep

echo "Hints:"
echo " - Android SDK installation is required for this workspace and cannot be skipped; to speed rebuilds persist the Android SDK with the provided Docker volume (mounted at /opt/android-sdk)."
echo " - To persist pub cache between rebuilds, set up a Docker volume for /home/vscode/.pub-cache or use the provided devcontainer mounts."

echo
exit 0
