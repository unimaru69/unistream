#!/bin/bash
set -euo pipefail

# Build AppImage for UniStream
# Run from project root after `flutter build linux --release`

APP_NAME="UniStream"
BINARY_NAME="unistream"
ARCH="${ARCH:-x86_64}"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="build/AppDir"

echo "==> Preparing AppDir..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APPDIR/usr/share/applications"

# Copy Flutter bundle
cp -r "$BUILD_DIR"/* "$APPDIR/usr/bin/"

# Copy icon (convert JPG to PNG if needed)
if command -v convert &>/dev/null; then
  convert assets/images/logo.jpg -resize 256x256 "$APPDIR/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png"
  cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png" "$APPDIR/${BINARY_NAME}.png"
elif command -v magick &>/dev/null; then
  magick assets/images/logo.jpg -resize 256x256 "$APPDIR/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png"
  cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png" "$APPDIR/${BINARY_NAME}.png"
else
  # Fallback: use sips on macOS or just copy the JPG
  cp assets/images/logo.jpg "$APPDIR/${BINARY_NAME}.png" 2>/dev/null || true
fi

# Copy desktop file
cp packaging/linux/unistream.desktop "$APPDIR/${BINARY_NAME}.desktop"
cp packaging/linux/unistream.desktop "$APPDIR/usr/share/applications/${BINARY_NAME}.desktop"

# Create AppRun
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="${HERE}/usr/bin/lib:${HERE}/usr/lib:${LD_LIBRARY_PATH:-}"
exec "${HERE}/usr/bin/unistream" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# Bundle system libraries that might be missing on target
echo "==> Bundling system libraries..."
for lib in libmpv.so libmpv.so.2; do
  LIBPATH=$(ldconfig -p 2>/dev/null | grep "$lib" | head -1 | awk '{print $NF}')
  if [ -n "$LIBPATH" ] && [ -f "$LIBPATH" ]; then
    cp "$LIBPATH" "$APPDIR/usr/lib/"
    echo "   Bundled $lib"
  fi
done

# Download appimagetool if not present
APPIMAGETOOL="build/appimagetool"
if [ ! -f "$APPIMAGETOOL" ]; then
  echo "==> Downloading appimagetool..."
  wget -q -O "$APPIMAGETOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  chmod +x "$APPIMAGETOOL"
fi

# Build AppImage
echo "==> Building AppImage..."
ARCH="$ARCH" "$APPIMAGETOOL" "$APPDIR" "build/${APP_NAME}-${ARCH}.AppImage"

echo ""
echo "==> Done! AppImage created at: build/${APP_NAME}-${ARCH}.AppImage"
echo "    To run: chmod +x build/${APP_NAME}-${ARCH}.AppImage && ./build/${APP_NAME}-${ARCH}.AppImage"
