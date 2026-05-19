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

# ── Desktop integration ──────────────────────────────────────────
# Install a `.desktop` entry + icon into ~/.local/share so the GNOME
# / KDE launcher shows UniStream with the right icon and a working
# Exec= pointing at the current AppImage path. On Fedora vanilla
# (no AppImageLauncher) this is what produces an iconified entry
# in the Activities overview.
#
# Skipped when:
#   • $APPIMAGE is unset — we're being run with `--appimage-extract-
#     and-run`, or directly from a squashfs-root: there's no stable
#     Exec target so we don't try to integrate.
#   • $UNISTREAM_NO_DESKTOP_INTEGRATION=1 — escape hatch.
#   • AppImageLauncher (or similar) has already integrated this
#     AppImage: detected by an `appimagekit_*.desktop` file.
#   • Our own entry already exists and Exec= matches $APPIMAGE
#     (idempotent — no rewrite cost on subsequent launches).
_integrate_desktop() {
  [ -n "${UNISTREAM_NO_DESKTOP_INTEGRATION:-}" ] && return 0
  [ -z "${APPIMAGE:-}" ] && return 0

  local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  local desktop_dir="$data_home/applications"
  local icon_theme="$data_home/icons/hicolor"
  local icon_dir="$icon_theme/256x256/apps"
  local target="$desktop_dir/unistream.desktop"

  # AppImageLauncher already integrated it — leave its files alone.
  if ls "$desktop_dir"/appimagekit_*unistream*.desktop >/dev/null 2>&1; then
    return 0
  fi
  # Our entry already up to date.
  if [ -f "$target" ] && grep -qFx "Exec=${APPIMAGE} %U" "$target"; then
    return 0
  fi

  mkdir -p "$desktop_dir" "$icon_dir"

  # Install icon if missing or older than the bundled copy. Guard
  # against a prior broken state where `unistream.png` is a directory
  # (a stray `mkdir -p .../unistream.png` somewhere upstream nested
  # the real PNG inside an eponymous dir) — `cp` into that directory
  # would just deepen the mess.
  local icon_src="${HERE}/usr/share/icons/hicolor/256x256/apps/unistream.png"
  local icon_dst="$icon_dir/unistream.png"
  if [ -d "$icon_dst" ]; then
    rm -rf "$icon_dst"
  fi
  if [ -f "$icon_src" ] && [ ! "$icon_dst" -nt "$icon_src" ]; then
    cp "$icon_src" "$icon_dst" 2>/dev/null || true
  fi

  # Write canonical .desktop. Icon= is an ABSOLUTE PATH on purpose:
  # the by-name lookup (Icon=unistream) only resolves if hicolor has
  # a valid `index.theme` AND `gtk-update-icon-cache` could index it
  # — neither holds in a vanilla user home (gtk-update-icon-cache
  # silently refuses without index.theme). Absolute path bypasses
  # the theme machinery entirely.
  cat > "$target" <<DESKTOP
[Desktop Entry]
Name=UniStream
Comment=IPTV & VOD streaming application
Exec=${APPIMAGE} %U
Icon=${icon_dst}
Type=Application
Categories=AudioVideo;Video;Player;
Terminal=false
StartupWMClass=unistream
X-AppImage-Version=1
DESKTOP
  chmod 0644 "$target" 2>/dev/null || true

  # Refresh desktop-file index — best-effort, never fatal.
  update-desktop-database "$desktop_dir" 2>/dev/null || true
}
# Run in the background so the user doesn't pay for cache rebuilds
# on every launch. First-run case: the user just double-clicked the
# AppImage, so they're already inside the app — the launcher entry
# only matters next time around.
_integrate_desktop &

exec "${HERE}/usr/bin/unistream" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# ──────────────────────────────────────────────────────────────────
# Vendored libmpv + FFmpeg (pinned to a media_kit-compatible version)
# ──────────────────────────────────────────────────────────────────
#
# media_kit 1.2.6 (our pinned Dart-side package) does NOT support
# libmpv 0.39+. Past that, the player crashes at first setProperty:
#   `m_config_core.c:571: m_config_cache_from_shadow: Assertion
#    `group_index >= 0' failed`
# This is documented as media_kit issue #1010 — mpv 0.39 restructured
# option groups and no media_kit release has caught up yet.
#
# Building on a current Fedora (mpv 0.41) and bundling the host's
# libmpv reproduces the crash on every run. We need to pin libmpv to
# a known-compatible build (mpv 0.37 from Ubuntu 24.04 LTS, which
# ships FFmpeg 6.x as its companion).
#
# Why Ubuntu noble debs and not Fedora RPMs:
#   • pool.ubuntu.com/* URLs are stable for every version ever
#     published (forever — that's the archive's mandate).
#   • Fedora's GA tree is dropped from active mirrors a few months
#     after a release EOLs; RPM Fusion doesn't maintain an archive.
#   • The host OS is irrelevant — these libs live under $APPDIR/usr/lib
#     and are loaded via LD_LIBRARY_PATH set by AppRun. They never
#     touch system /usr/lib64.
VENDOR_DIR="build/vendor/libmpv"
VENDOR_STAMP="$VENDOR_DIR/.fetched-v1"

vendor_libmpv() {
  if [ -f "$VENDOR_STAMP" ]; then
    echo "==> Using cached vendored libmpv ($VENDOR_DIR)"
    return 0
  fi
  echo "==> Vendoring libmpv 0.37 + FFmpeg 6 from Ubuntu noble pool..."
  local UBUNTU="http://archive.ubuntu.com/ubuntu/pool"
  local TMP="build/vendor/.tmp"
  rm -rf "$TMP" "$VENDOR_DIR"
  mkdir -p "$TMP" "$VENDOR_DIR"
  (
    cd "$TMP"

    # Discover the current "noble" pool filename for each package.
    # Ubuntu's pool listing pages stay HTML-stable. Wrap each curl
    # in a helper so a 404 says WHICH URL was wrong.
    fetch_idx() {
      local url="$1"
      curl -fsSL "$url" || { echo "!! 404 on $url" >&2; return 1; }
    }
    local idx_mpv idx_ffmpeg idx_libass idx_libplacebo
    idx_mpv=$(fetch_idx       "$UBUNTU/universe/m/mpv/")     || exit 1
    idx_ffmpeg=$(fetch_idx    "$UBUNTU/universe/f/ffmpeg/")  || exit 1
    idx_libass=$(fetch_idx    "$UBUNTU/universe/liba/libass/")    || exit 1
    idx_libplacebo=$(fetch_idx "$UBUNTU/universe/libp/libplacebo/") || exit 1

    local debs=()
    local d
    d=$(echo "$idx_mpv" | grep -oE 'libmpv2_0\.37[^"]*_amd64\.deb' | sort -uV | tail -1)
    [ -z "$d" ] && { echo "!! No libmpv2 0.37 found in noble pool" >&2; exit 1; }
    debs+=("$UBUNTU/universe/m/mpv/$d")

    local pkg
    for pkg in libavformat60 libavcodec60 libavutil58 libswscale7 libswresample4 libpostproc57; do
      d=$(echo "$idx_ffmpeg" | grep -oE "${pkg}_[^\"]+_amd64\.deb" | sort -uV | tail -1)
      [ -n "$d" ] && debs+=("$UBUNTU/universe/f/ffmpeg/$d")
    done
    d=$(echo "$idx_libass" | grep -oE 'libass9_[^"]+_amd64\.deb' | sort -uV | tail -1)
    [ -n "$d" ] && debs+=("$UBUNTU/universe/liba/libass/$d")
    d=$(echo "$idx_libplacebo" | grep -oE 'libplacebo[0-9]+_[^"]+_amd64\.deb' | sort -uV | tail -1)
    [ -n "$d" ] && debs+=("$UBUNTU/universe/libp/libplacebo/$d")

    echo "    ${#debs[@]} packages to fetch."
    local url
    for url in "${debs[@]}"; do
      echo "    · $(basename "$url")"
      curl -fsSL -O "$url" || { echo "!! Failed: $url" >&2; exit 1; }
    done

    local deb
    for deb in *.deb; do
      ar x "$deb"
      if [ -f data.tar.xz ];  then tar xf data.tar.xz
      elif [ -f data.tar.zst ]; then tar xf data.tar.zst
      fi
      rm -f control.tar.* data.tar.* debian-binary
    done
    # Flatten all .so files (preserving symlinks) into VENDOR_DIR.
    find usr -name 'lib*.so*' \( -type f -o -type l \) \
         -exec cp -a {} "../libmpv/" \;
  )
  # Repoint libmpv.so.2 → libmpv.so.2.X.Y (the deb ships them but cp -a
  # may have flattened weirdly). Idempotent.
  (
    cd "$VENDOR_DIR"
    local real
    real=$(ls libmpv.so.2.* 2>/dev/null | head -1)
    [ -n "$real" ] && ln -sf "$real" libmpv.so.2
  )
  rm -rf "build/vendor/.tmp"
  touch "$VENDOR_STAMP"
  echo "    Vendored $(find "$VENDOR_DIR" -name 'lib*.so*' | wc -l) libs."
}

vendor_libmpv

# Bundle all non-glibc shared libraries needed by the binary and its .so deps
echo "==> Bundling shared libraries..."

# Names of libraries we vendored above — these MUST come from the
# vendored copy, never from the host (host's mpv 0.39+ would crash
# media_kit at runtime).
VENDORED_LIB_PREFIXES="libmpv libavformat libavcodec libavutil libswscale libswresample libpostproc libass libplacebo"

is_vendored() {
  local name="$1" prefix
  for prefix in $VENDORED_LIB_PREFIXES; do
    case "$name" in "${prefix}".so*) return 0 ;; esac
  done
  return 1
}

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
    libpipewire*.so*|libspa*.so*|libpulse*.so*|libpulsecommon*) return 0 ;;
    libasound.so*|libjack*.so*) return 0 ;;
    libva.so*|libva-*.so*|libvdpau.so*) return 0 ;;
    libstdc++.so*) return 0 ;;
  esac
  # Vendored libs win — never copy the host's mpv/FFmpeg/libass/libplacebo.
  if is_vendored "$libname"; then return 0; fi
  if [ ! -f "$APPDIR/usr/lib/$libname" ]; then
    cp "$libpath" "$APPDIR/usr/lib/" 2>/dev/null && echo "   Bundled $libname" || true
  fi
}

# Copy ALL vendored libs into $APPDIR/usr/lib first so AppRun's
# LD_LIBRARY_PATH picks them up before anything else.
echo "==> Installing vendored libmpv + FFmpeg into bundle..."
cp -a "$VENDOR_DIR"/lib*.so* "$APPDIR/usr/lib/"

# Pass 1: bundle deps of all binaries/libs in the Flutter bundle
mapfile -t BINS < <(find "$APPDIR/usr/bin" -type f \( -name "*.so" -o -name "*.so.*" -o -executable \) 2>/dev/null)
for bin in "${BINS[@]}"; do
  mapfile -t DEPS < <(ldd "$bin" 2>/dev/null | grep "=> /" | awk '{print $3}' || true)
  for dep in "${DEPS[@]}"; do
    [ -n "$dep" ] && bundle_lib "$dep"
  done
done

# Pass 2: resolve deps of vendored libmpv (its transitive non-vendored
# deps still need bundling — libuchardet, liblzma, etc.). bundle_lib
# is_vendored-guarded so it won't replace the pinned libmpv/FFmpeg.
echo "==> Resolving transitive dependencies of vendored libmpv..."
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
