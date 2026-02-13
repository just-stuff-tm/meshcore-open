#!/usr/bin/env bash
set -euo pipefail

export PATH="${FLUTTER_ROOT:-/opt/flutter}/bin:${PATH}"

flutter config --no-analytics --android-sdk "${ANDROID_SDK_ROOT:-/opt/android-sdk}" --enable-android --enable-linux-desktop --enable-web
flutter doctor --android-licenses < <(yes)
flutter pub get

# Warm Gradle/Maven caches during container creation to speed up first Android run/build.
if ! flutter build apk --debug; then
  echo "[devcontainer] Gradle warmup build failed; continuing setup."
fi

flutter doctor -v
