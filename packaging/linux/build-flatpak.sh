#!/bin/bash
set -euo pipefail

# Build Flatpak for UniStream — LOCAL DEV BUILD
#
# Uses fr.unimaru.unistream.dev.yml which points the source at the local
# Flutter bundle. The Flathub-facing manifest (fr.unimaru.unistream.yml)
# fetches a remote tarball instead and is consumed by
# prepare-flathub-submission.sh once a release is cut.
#
# Prerequisites (Fedora / Linux):
#   sudo dnf install -y flatpak flatpak-builder
#   flatpak remote-add --user --if-not-exists flathub \
#     https://flathub.org/repo/flathub.flatpakrepo
#   flatpak install -y --user flathub \
#     org.gnome.Platform//50 org.gnome.Sdk//50
#   flutter build linux --release --dart-define=TMDB_KEY=$TMDB_KEY
#
# Usage (from project root):
#   bash packaging/linux/build-flatpak.sh

APP_ID="fr.unimaru.unistream"
MANIFEST="packaging/linux/${APP_ID}.dev.yml"
BUILD_DIR="build/linux/x64/release/bundle"
ICON_PATH="packaging/linux/unistream.png"

if [ ! -d "$BUILD_DIR" ]; then
  echo "ERROR: Flutter build not found at $BUILD_DIR"
  echo "Run 'flutter build linux --release --dart-define=TMDB_KEY=\$TMDB_KEY' first."
  exit 1
fi

if [ ! -f "$ICON_PATH" ]; then
  echo "ERROR: Icon missing at $ICON_PATH (should be committed to git)."
  echo "Regenerate with: sips -s format png -z 256 256 assets/images/logo.jpg --out $ICON_PATH"
  exit 1
fi

echo "==> Building Flatpak from $MANIFEST"
flatpak-builder --force-clean --user --install \
  build/flatpak "$MANIFEST"

echo
echo "==> Done. Run with:"
echo "    flatpak run $APP_ID"
echo
echo "==> Export a standalone .flatpak bundle:"
echo "    flatpak build-bundle ~/.local/share/flatpak/repo ${APP_ID}.flatpak $APP_ID"
