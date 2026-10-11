# Releasing

Pushing to the `production` branch runs `.github/workflows/production-release.yml`, which builds
every platform and publishes one GitHub release.

## What a release contains

| Asset | Platform | Notes |
|---|---|---|
| `app-release.apk` | Android | |
| `petit-windows-setup.exe` | Windows | Installer (recommended), see [windows-installer.md](windows-installer.md). Not code signed. |
| `petit-windows.zip` | Windows | Unzip and run `petit.exe`. Not code signed. |
| `petit-macos.zip`, `petit-macos.dmg` | macOS | Not signed or notarized. |
| `petit-ios.zip` | iOS | Unsigned `.app`; it cannot be installed on a device as is. |
| `petit-linux-x64.tar.gz` | Linux (x86_64) | Unpack and run `petit-linux/petit`. |
| `petit-linux-amd64.deb` | Debian, Ubuntu and derivatives | Installs to `/opt/petit`, adds a launcher and a menu entry. |

## Linux

Install the package (this also pulls in GTK and json-glib):

```
sudo apt install ./petit-linux-amd64.deb
```

Or use the tarball, which needs GTK 3 and libjson-glib installed:

```
tar xzf petit-linux-x64.tar.gz
./petit-linux/petit
```

Only x86_64 is built: the FFmpeg Kit plugin ships Linux libraries for x86_64.

**The Linux job is best effort for now.** If it fails, the release is still published without the
Linux assets (see the `if:` on `create-release`). Once a release has built it successfully, make it
required by adding `&& needs.build-linux.result == 'success'` to that `if:`.

Build the package locally:

```
flutter build linux --release
bash packaging/linux/build-deb.sh build/linux/x64/release/bundle \
  "$(grep '^version:' pubspec.yaml | awk '{print $2}')" petit-linux-amd64.deb
```

The Linux application id is `io.github.vader_femi.petit` (`linux/CMakeLists.txt`). The desktop entry is
named after it (`packaging/linux/io.github.vader_femi.petit.desktop`) so desktop environments can match
the running window to its icon. Change both together if you ever change the id.

## Not signed yet

Windows and macOS builds are unsigned, so users see warnings:

- **Windows**: SmartScreen shows "unknown publisher". Fixing it needs a code signing certificate
  (or a signing service); the signing step would go in `build-windows`, after `flutter build windows`.
- **macOS**: Gatekeeper blocks apps that are not signed with a *Developer ID Application* certificate
  and notarized. Until then users can right-click the app and choose Open. Signing and notarizing
  need an Apple Developer account, the certificate and notarization credentials stored as GitHub
  secrets, and steps in `build-macos-ios` after `flutter build macos`.

## Licensing

The FFmpeg Kit build used for compression is a GPL build (it includes x264 and x265), and HEVC has
its own patent licensing. Decide how to handle that (license, source offer) before distributing the
desktop builds widely. This is not legal advice.
