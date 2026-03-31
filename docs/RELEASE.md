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

2. **AppImage** (optional): use `appimage-builder` or `linuxdeploy` to package the bundle into a portable AppImage.

## Running a Release Build Locally

```bash
# macOS
open build/macos/Build/Products/Release/UniStream.app

# Linux
./build/linux/x64/release/bundle/unistream

# Windows
.\build\windows\x64\runner\Release\unistream.exe
```
