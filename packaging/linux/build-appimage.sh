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
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/bin/lib:${HERE}/usr/bin:${LD_LIBRARY_PATH:-}"
# Unset GTK_PATH to avoid host module conflicts
unset GTK_MODULES 2>/dev/null || true
unset GTK3_MODULES 2>/dev/null || true
exec "${HERE}/usr/bin/unistream" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# Bundle all non-glibc shared libraries needed by the binary and its .so deps
echo "==> Bundling shared libraries..."

bundle_lib() {
  local libpath="$1"
  local libname
  libname=$(basename "$libpath")
  # Skip libs that MUST come from the host system:
  # - glibc core (libc, libm, libdl, librt, libpthread, ld-linux)
  # - GPU/graphics stack (EGL, GL, GLX, GLESv2, vulkan, drm, gbm) — must match host GPU drivers
  # - X11/Wayland core — must match host display server
  # - Mesa internals, nvidia, etc.
  case "$libname" in
    libc.so*|libm.so*|libdl.so*|librt.so*|libpthread.so*|ld-linux*|libgcc_s*|linux-vdso*) return 0 ;;
    libEGL.so*|libGL.so*|libGLX.so*|libGLESv2.so*|libGLdispatch.so*) return 0 ;;
    libvulkan.so*|libdrm*.so*|libgbm.so*|libglapi.so*) return 0 ;;
    libX11.so*|libX11-xcb.so*|libxcb.so*|libXext.so*|libXi.so*|libXfixes.so*|libXcursor.so*|libXrandr.so*|libXrender.so*|libXcomposite.so*|libXdamage.so*|libXinerama.so*|libXxf86vm.so*) return 0 ;;
    libwayland-client.so*|libwayland-server.so*|libwayland-cursor.so*|libwayland-egl.so*) return 0 ;;
    libstdc++.so*) return 0 ;;
  esac
  if [ ! -f "$APPDIR/usr/lib/$libname" ]; then
    cp "$libpath" "$APPDIR/usr/lib/" 2>/dev/null && echo "   Bundled $libname" || true
  fi
}

# Pass 1: bundle deps of all binaries/libs in the Flutter bundle
mapfile -t BINS < <(find "$APPDIR/usr/bin" -type f \( -name "*.so" -o -name "*.so.*" -o -executable \) 2>/dev/null)
for bin in "${BINS[@]}"; do
  mapfile -t DEPS < <(ldd "$bin" 2>/dev/null | grep "=> /" | awk '{print $3}' || true)
  for dep in "${DEPS[@]}"; do
    [ -n "$dep" ] && bundle_lib "$dep"
  done
done

# Pass 2: explicitly bundle libmpv and all its transitive deps
for lib in libmpv.so libmpv.so.2 libmpv.so.1; do
  LIBPATH=$(ldconfig -p 2>/dev/null | grep "$lib" | head -1 | awk '{print $NF}' || true)
  if [ -n "${LIBPATH:-}" ] && [ -f "$LIBPATH" ]; then
    bundle_lib "$LIBPATH"
    mapfile -t MPV_DEPS < <(ldd "$LIBPATH" 2>/dev/null | grep "=> /" | awk '{print $3}' || true)
    for dep in "${MPV_DEPS[@]}"; do
      [ -n "$dep" ] && bundle_lib "$dep"
    done
  fi
done

# Pass 3: resolve deps of newly bundled libs (transitive)
echo "==> Resolving transitive dependencies..."
mapfile -t BUNDLED < <(find "$APPDIR/usr/lib" -type f -name "*.so*" 2>/dev/null)
for lib in "${BUNDLED[@]}"; do
  mapfile -t TDEPS < <(ldd "$lib" 2>/dev/null | grep "=> /" | awk '{print $3}' || true)
  for dep in "${TDEPS[@]}"; do
    [ -n "$dep" ] && bundle_lib "$dep"
  done
done

echo "==> $(find "$APPDIR/usr/lib" -type f | wc -l) libraries bundled."

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
