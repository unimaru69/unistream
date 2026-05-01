# UniStream — Build & Release Guide

## Prerequisites

- Flutter SDK (stable channel, >= 3.32)
- For macOS: Xcode command line tools (`xcode-select --install`)
- For iOS: Xcode with a valid signing identity (Apple Developer account for device builds)
- For Linux: `sudo apt install libmpv-dev libsecret-1-dev libgtk-3-dev`
- For Windows: Visual Studio 2022 with "Desktop development with C++" workload

## Build Commands

### macOS

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/UniStream.app`

### Windows

```bash
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\`

### Linux

```bash
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/`

The bundle directory contains the executable and required shared libraries. Copy the entire `bundle/` folder for distribution.

### iOS (requires Apple Developer account for device deployment)

```bash
flutter build ios --no-codesign
```

For a signed build destined to TestFlight or the App Store:

```bash
flutter build ipa
```

## Packaging

### macOS — DMG

Install `create-dmg` via Homebrew:

```bash
brew install create-dmg
```

Create the DMG:

```bash
create-dmg \
  --volname "UniStream" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "UniStream.app" 150 190 \
  --app-drop-link 450 190 \
  "UniStream.dmg" \
  "build/macos/Build/Products/Release/UniStream.app"
```

### Windows — MSIX

Add the `msix` package to `dev_dependencies` in `pubspec.yaml`:

```yaml
dev_dependencies:
  msix: ^3.16.0
```

Configure MSIX in `pubspec.yaml`:

```yaml
msix_config:
  display_name: UniStream
  publisher_display_name: UniStream
  identity_name: com.unistream.app
  msix_version: 1.0.0.0
  logo_path: assets/icon.png
```

Build the MSIX package:

```bash
dart run msix:create
```

Output: `build\windows\x64\runner\Release\unistream.msix`

### Linux — Bundle

The release build output at `build/linux/x64/release/bundle/` is self-contained. For distribution:

1. **Tarball** (simplest):
   ```bash
   cd build/linux/x64/release
   tar czf unistream-linux-x64.tar.gz bundle/
   ```

2. **AppImage** (recommended):
```bash
bash packaging/linux/build-appimage.sh
```

3. **Flatpak** (for Flathub / sandboxed distribution):
```bash
# Prerequisites: flatpak-builder, org.freedesktop.Platform//24.08
bash packaging/linux/build-flatpak.sh
# Run: flatpak run fr.unimaru.unistream
# Export bundle: flatpak build-bundle ~/.local/share/flatpak/repo UniStream.flatpak fr.unimaru.unistream
```

### Windows — MSIX

```bash
flutter pub run msix:create
```

Output: `build/windows/x64/runner/Release/unistream.msix`

## CI signing & notarization secrets

The `release.yml` workflow produces a signed + notarized DMG when a
Developer ID certificate is configured as a GitHub Actions secret.
Without these secrets the job falls back to an unsigned `.app.zip` so
forks still build.

Configure these repository secrets to enable the signed pipeline:

| Secret | What it is | Where to find it |
|---|---|---|
| `MACOS_CERT_BASE64` | Developer ID Application `.p12` exported from Keychain Access, base64-encoded (`base64 -i cert.p12 \| pbcopy`) | Keychain → export the "Developer ID Application: …" certificate as `.p12` |
| `MACOS_CERT_PASSWORD` | The password set when exporting the `.p12` | You picked it on export |
| `MACOS_DEVELOPER_ID` | Full identity string, e.g. `Developer ID Application: UniMaru (VS8P2MA59S)` | `security find-identity -v -p codesigning` |
| `MACOS_NOTARY_USER` | Apple ID email used on developer.apple.com | Apple ID account |
| `MACOS_NOTARY_PASSWORD` | App-specific password for `notarytool` (NOT your Apple ID password) | <https://appleid.apple.com> → Sign-In and Security → App-Specific Passwords |
| `MACOS_NOTARY_TEAM` | 10-character team ID | Apple Developer → Membership |
| `TMDB_KEY` | TMDB v3 API key | <https://www.themoviedb.org/settings/api> |

When all `MACOS_*` secrets are present, the macOS job:
1. Imports the `.p12` into a temp keychain
2. Builds, then codesigns the `.app` with `--options runtime` (hardened runtime) and `Release.entitlements`
3. Builds a DMG via `create-dmg`
4. Signs the DMG
5. Submits it to `notarytool --wait`
6. Staples the notarization ticket
7. Uploads `UniStream.dmg` as a release asset

If any secret is missing the job emits the unsigned `unistream-macos.zip`
as before.

## Running a Release Build Locally

```bash
# macOS
open build/macos/Build/Products/Release/UniStream.app

# Linux
./build/linux/x64/release/bundle/unistream

# Windows
.\build\windows\x64\runner\Release\unistream.exe
```
