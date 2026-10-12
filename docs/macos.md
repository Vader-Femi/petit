# macOS

## Installing a release

1. Open `petit-macos.dmg` and drag **Petit** into **Applications** (or unzip `petit-macos.zip`).
2. The build is **not signed or notarized yet**, so macOS blocks the first launch. Either
   - right-click the app, choose **Open**, then **Open** again; or
   - open **System Settings > Privacy & Security** and click **Open Anyway** after the first attempt; or
   - in Terminal: `xattr -dr com.apple.quarantine /Applications/petit.app`

The app is called Petit everywhere you see it (Dock, menu bar, window title), but the bundle file
is still `petit.app` because the release workflow refers to that name.

## What is configured here

| Setting | Where | Value |
|---|---|---|
| Display name | `macos/Runner/Info.plist` (`CFBundleName`, `CFBundleDisplayName`) | Petit |
| Bundle file name | `macos/Runner/Configs/AppInfo.xcconfig` (`PRODUCT_NAME`) | `petit` |
| Bundle identifier | `AppInfo.xcconfig` (`PRODUCT_BUNDLE_IDENTIFIER`) | `com.example.petit` (a placeholder, see below) |
| Minimum window size | `macos/Runner/MainFlutterWindow.swift` | 480 x 480 |
| Minimum macOS | Xcode project and `Podfile` | 12.0 |
| Sandbox | `macos/Runner/*.entitlements` | on; files chosen in a dialog or dropped on the window; outgoing network (Firebase) |

### App icon

The macOS icon is built from `assets/images/app_logo.png` by a script, because (unlike iOS) macOS
does not round or shade icons for you:

```
pip install pillow
python3 packaging/macos/make_icon.py
```

It writes the seven PNGs in `macos/Runner/Assets.xcassets/AppIcon.appiconset/`. `icons_launcher` is
disabled for macOS on purpose, so running it will not overwrite them. Re-run the script if the logo
changes.

### Remembered "Save to" folder

The folder chosen in the "Save to" tile is remembered, but the macOS sandbox only keeps access to a
folder chosen in a dialog while the app is running. After a restart the saved folder may not be writable
any more; the app then opens the dialog once and remembers the new choice. (Storing security-scoped
bookmarks would remove that extra step.)

### HEIC photos

HEIC is what iPhones and Macs save by default. Flutter and the bundled FFmpeg cannot read it, so on
macOS the app asks the system to decode it: `ImageConverter` in `MainFlutterWindow.swift` (ImageIO)
converts the HEIC to a JPEG, which is then compressed like any other image. Windows and Linux still
report that HEIC is not supported. The carousel shows a placeholder instead of a preview for HEIC
files, because Flutter cannot draw them.

### Bundle identifier

`com.example.petit` is Flutter's placeholder. Before you sign and notarize for real, pick your own
(for example `io.github.vader-femi.petit`). Changing it is not just a one-line edit: the macOS app in
Firebase is registered under the old id, so you must also register the new one, replace
`macos/Runner/GoogleService-Info.plist`, and regenerate `lib/firebase_options.dart` with
`flutterfire configure`. The sandbox container folder also moves, so saved settings start fresh.

## Signing and notarization (not done yet)

This needs an Apple Developer Program membership and a **Developer ID Application** certificate.
A plan for when you have them (untested):

1. Export the certificate as a `.p12` and store it, its password, your Apple ID team id and an
   app-specific password (or an App Store Connect API key) as GitHub secrets.
2. In `build-macos-ios`, after `flutter build macos --release`: create a temporary keychain, import the
   certificate, then sign the app with the hardened runtime and the entitlements:

   ```
   codesign --force --deep --options runtime --timestamp \
     --entitlements macos/Runner/Release.entitlements \
     --sign "Developer ID Application: <Name> (<TEAMID>)" \
     build/macos/Build/Products/Release/petit.app
   ```
3. Zip the app, then notarize and staple it before creating the DMG:

   ```
   xcrun notarytool submit petit-macos.zip --apple-id ... --team-id ... --password ... --wait
   xcrun stapler staple build/macos/Build/Products/Release/petit.app
   ```
4. Sign the DMG too (`codesign --sign ... petit-macos.dmg`), notarize and staple it.

Things that may need attention: the FFmpeg Kit frameworks are embedded libraries, so signing with
`--deep` must cover them, and the hardened runtime may need the
`com.apple.security.cs.disable-library-validation` entitlement if they are signed by someone else.
Check the notarization log if Apple rejects the build.
