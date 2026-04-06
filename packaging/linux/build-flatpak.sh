#!/bin/bash
set -euo pipefail

# Build Flatpak for UniStream
# Prerequisites:
#   - flatpak-builder installed
#   - org.freedesktop.Platform//24.08 and Sdk installed
#   - Flutter build already done: flutter build linux --release
#
# Usage (from project root):
#   bash packaging/linux/build-flatpak.sh

APP_ID="fr.unimaru.unistream"
MANIFEST="packaging/linux/${APP_ID}.yml"
BUILD_DIR="build/linux/x64/release/bundle"

if [ ! -d "$BUILD_DIR" ]; then
  echo "ERROR: Flutter build not found at $BUILD_DIR"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

# Generate icon from logo if not exists
ICON_PATH="packaging/linux/unistream.png"
if [ ! -f "$ICON_PATH" ]; then
  echo "==> Generating icon..."
  if command -v convert &>/dev/null; then
    convert assets/images/logo.jpg -resize 256x256 "$ICON_PATH"
  elif command -v magick &>/dev/null; then
    magick assets/images/logo.jpg -resize 256x256 "$ICON_PATH"
  else
    echo "WARNING: ImageMagick not found, using placeholder icon"
    cp assets/images/logo.jpg "$ICON_PATH" 2>/dev/null || true
  fi
fi

echo "==> Building Flatpak..."
flatpak-builder --force-clean --user --install \
  build/flatpak "$MANIFEST"

echo ""
echo "==> Done! Run with:"
echo "    flatpak run $APP_ID"
echo ""
echo "==> To export a .flatpak bundle:"
echo "    flatpak build-bundle ~/.local/share/flatpak/repo ${APP_ID}.flatpak $APP_ID"
