# Windows installer

Each release publishes two Windows files:

| Asset | What it is |
|---|---|
| `petit-windows-setup.exe` | Installer (recommended). Start menu entry, optional desktop icon, uninstaller. |
| `petit-windows.zip` | The app folder. Unzip anywhere and run `petit.exe`. |

## Installing

Run `petit-windows-setup.exe`. By default it installs for the current user (no admin prompt) under
`%LocalAppData%\Programs\Petit`; the first wizard page offers "for all users" (`Program Files`) instead.
Upgrading is done by running a newer installer: it replaces the old version.

Silent install and uninstall (for scripts):

```
petit-windows-setup.exe /VERYSILENT /SUPPRESSMSGBOXES
"%LocalAppData%\Programs\Petit\unins000.exe" /VERYSILENT
```

The installer also installs the Microsoft Visual C++ runtime if the PC does not have it yet
(Flutter apps need it; fresh Windows installs sometimes lack it). That step asks for admin rights
only when the runtime is actually missing.

## How it is built

`packaging/windows/petit.iss` is an [Inno Setup](https://jrsoftware.org/isinfo.php) script. The
`build-windows` job in `production-release.yml`:

1. builds the app and creates the zip (as before),
2. downloads `vc_redist.x64.exe` from Microsoft and checks it is signed by Microsoft,
3. installs Inno Setup with Chocolatey and compiles the installer with the version from `pubspec.yaml`,
4. uploads it as `petit-windows-installer`.

Steps 2 to 4 are best effort (`continue-on-error`). If one fails, the run shows a warning and the
release is still published with the zip. If the Visual C++ download fails, the installer is built without
the runtime.

To build it locally on Windows (Inno Setup 6 installed):

```
flutter build windows --release
ISCC /DAppVersion=1.0.25 /DAppBuild=25 packaging\windows\petit.iss
```

The result is `packaging\windows\Output\petit-windows-setup.exe`.

## Things to know

- **Not signed yet.** Windows SmartScreen will say "unknown publisher" until the installer and
  `petit.exe` are signed with a code signing certificate. When you have one, add a signing step after
  "Build installer" (and sign `petit.exe` before it is packaged) in the workflow.
- **`AppId` in `petit.iss` must never change.** It is how Windows recognises an upgrade of the same app.
- **x64 only**, like the FFmpeg Kit plugin. The installer also runs on Windows on ARM through
  emulation.
- The version shown comes from `version:` in `pubspec.yaml` (`1.0.25+25` becomes 1.0.25, build 25).
