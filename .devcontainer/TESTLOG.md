# Devcontainer Test Log

Environment verification run captured in Codespaces.

## Run Output

```text
@just-stuff-tm ➜ /workspaces/meshcore-open (main) $ flutter doctor -v
[✓] Flutter (Channel stable, 3.41.0, on Ubuntu 24.04.3 LTS 6.8.0-1030-azure,
    locale en_US.UTF-8) [45ms]
    • Flutter version 3.41.0 on channel stable at /opt/flutter
    • Upstream repository https://github.com/flutter/flutter.git
    • Framework revision 44a626f4f0 (2 days ago), 2026-02-10 10:16:12 -0800
    • Engine revision 3452d735bd
    • Dart version 3.11.0
    • DevTools version 2.54.1
    • Feature flags: enable-web, enable-linux-desktop, enable-macos-desktop,
      enable-windows-desktop, enable-android, enable-ios, cli-animations,
      enable-native-assets, omit-legacy-version-file, enable-lldb-debugging,
      enable-uiscene-migration

[✓] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
    [2.7s]
    • Android SDK at /opt/android-sdk
    • Emulator version unknown
    • Platform android-36, build-tools 36.0.0
    • ANDROID_HOME = /opt/android-sdk
    • ANDROID_SDK_ROOT = /opt/android-sdk
    • Java binary at: /usr/lib/jvm/java-17-openjdk-amd64/bin/java
      This JDK is specified by the JAVA_HOME environment variable.
      To manually set the JDK path, use: `flutter config --jdk-dir="path/to/jdk"`.
    • Java version OpenJDK Runtime Environment (build 17.0.18+8-Ubuntu-124.04.1)
    • All Android licenses accepted.

[✓] Chrome - develop for the web [50ms]
    • CHROME_EXECUTABLE = /usr/bin/chromium-browser

[✓] Linux toolchain - develop for Linux desktop [312ms]
    • Ubuntu clang version 18.1.3 (1ubuntu1)
    • cmake version 3.28.3
    • ninja version 1.11.1
    • pkg-config version 1.8.1
    ! Unable to access driver information using 'eglinfo'.
      It is likely available from your distribution (e.g.: apt install mesa-utils)

[✓] Connected device (2 available) [197ms]
    • Linux (desktop) • linux  • linux-x64      • Ubuntu 24.04.3 LTS
      6.8.0-1030-azure
    • Chrome (web)    • chrome • web-javascript • unknown

[✓] Network resources [268ms]
    • All expected network resources are available.

• No issues found!
@just-stuff-tm ➜ /workspaces/meshcore-open (main) $ flutter pub get
Resolving dependencies... 
Downloading packages... 
  dbus 0.7.11 (0.7.12 available)
  ffi 2.1.5 (2.2.0 available)
  flutter_blue_plus 2.1.0 (2.1.1 available)
  flutter_blue_plus_darwin 8.1.0 (8.1.1 available)
  flutter_blue_plus_winrt 0.0.16 (0.0.18 available)
  flutter_foreground_task 6.5.0 (9.2.0 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  flutter_lints 5.0.0 (6.0.0 available)
  flutter_local_notifications 18.0.1 (20.1.0 available)
  flutter_local_notifications_linux 5.0.0 (7.0.0 available)
  flutter_local_notifications_platform_interface 8.0.0 (10.0.0 available)
  flutter_map 7.0.2 (8.2.2 available)
  hooks 1.0.0 (1.0.1 available)
  lints 5.1.1 (6.1.0 available)
  meta 1.17.0 (1.18.1 available)
  mgrs_dart 2.0.0 (3.0.0 available)
  mobile_scanner 6.0.11 (7.1.4 available)
  objective_c 9.2.5 (9.3.0 available)
  package_info_plus 8.3.1 (9.0.0 available)
  pointycastle 3.9.1 (4.0.0 available)
  proj4dart 2.1.0 (3.0.0 available)
  source_span 1.10.1 (1.10.2 available)
  test_api 0.7.8 (0.7.9 available)
  timezone 0.10.1 (0.11.0 available)
  unicode 0.3.1 (1.1.9 available)
  url_launcher_ios 6.3.6 (6.4.0 available)
  wakelock_plus 1.3.3 (1.4.0 available)
Got dependencies!
27 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
@just-stuff-tm ➜ /workspaces/meshcore-open (main) $ flutter analyze
Analyzing meshcore-open...                                              
No issues found! (ran in 3.1s)
@just-stuff-tm ➜ /workspaces/meshcore-open (main) $ flutter test
00:11 +33: All tests passed!                                                     
@just-stuff-tm ➜ /workspaces/meshcore-open (main) $
```
