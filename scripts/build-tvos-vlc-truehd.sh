#!/usr/bin/env bash
# Rebuild the official LGPL VLC 3.x Apple TV framework with MLP/TrueHD enabled.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${VLC_TRUEHD_BUILD_DIR:-$PROJECT_ROOT/build/tvos-vlc-truehd}"
PACKAGE_DIR="$PROJECT_ROOT/tvos/Packages/VLCKitTrueHD"
KIT_REVISION=a213fd113c5c014556b40765966e77d439f0ddf9
VLC_REVISION=6de05adcbaf2e8b85fe86aad4169393098628119

if [[ -d "$PACKAGE_DIR/Artifacts/TVVLCKit.xcframework" ]]; then
    python3 - "$PACKAGE_DIR/Artifacts/build.json" "$KIT_REVISION" "$VLC_REVISION" <<'PY'
import json, sys
with open(sys.argv[1]) as file:
    manifest = json.load(file)
assert manifest == {'vlckit': sys.argv[2], 'vlc': sys.argv[3], 'truehdPatch': 1}
PY
    echo "TrueHD-enabled Apple TV framework already available."
    exit 0
fi

fetch_revision() {
    local directory="$1" repository="$2" revision="$3"
    if [[ ! -d "$directory/.git" ]]; then
        mkdir -p "$directory"
        git init -q "$directory"
        git -C "$directory" remote add origin "$repository"
        git -C "$directory" fetch --depth 1 origin "$revision"
        git -C "$directory" checkout --detach FETCH_HEAD
    fi
}

if [[ ! -f "$BUILD_DIR/.unistream-truehd-prepared" ]]; then
    fetch_revision "$BUILD_DIR" https://github.com/videolan/vlckit.git "$KIT_REVISION"
    fetch_revision "$BUILD_DIR/libvlc/vlc" https://github.com/videolan/vlc.git "$VLC_REVISION"
    [[ "$(git -C "$BUILD_DIR" rev-parse HEAD)" == "$KIT_REVISION" ]]
    [[ "$(git -C "$BUILD_DIR/libvlc/vlc" rev-parse HEAD)" == "$VLC_REVISION" ]]
    git -C "$BUILD_DIR/libvlc/vlc" -c user.name='UniStream build' \
        -c user.email='build@localhost' am "$BUILD_DIR"/libvlc/patches/*.patch
    python3 - "$BUILD_DIR" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
rules = root / 'libvlc/vlc/contrib/src/ffmpeg/rules.mak'
text = rules.read_text()
for option in ('decoder', 'demuxer', 'parser'):
    line = '\t--disable-' + option + '=mlp \\\n'
    assert line in text, 'Upstream codec configuration changed'
    text = text.replace(line, '')
rules.write_text(text)
script = root / 'buildMobileVLCKit.sh'
text = script.read_text()
# Upstream only recognises x86_64 as a simulator architecture here. Include
# the ARM64 simulator already built by -a aarch64 in the final XCFramework.
old = 'if [ "$FARCH" = "all" ] || (is_simulator_arch $arch);then'
assert old in text
text = text.replace(old, 'if [ "$FARCH" = "all" ] || [ "$FARCH" = "aarch64" ] || (is_simulator_arch $arch);then')
old = '               IPHONEOS_DEPLOYMENT_TARGET=${SDK_MIN} \\\n'
assert old in text
text = text.replace(old, old + '               TVOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO \\\n', 1)
script.write_text(text)
(root / '.unistream-truehd-prepared').write_text('VLC 3.x with MLP decoding enabled\n')
PY
fi

# Apple's old Make jobserver is incompatible with current Ninja releases.
# Keep a modern Make private to this build; never replace /usr/bin/make.
TOOLS_PREFIX="$BUILD_DIR/libvlc/vlc/extras/tools/build"
if [[ ! -x "$TOOLS_PREFIX/bin/make" ]]; then
    MAKE_SOURCE_DIR="$BUILD_DIR/unistream-build-tools"
    mkdir -p "$MAKE_SOURCE_DIR"
    curl -fL --retry 3 https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz \
        -o "$MAKE_SOURCE_DIR/make-4.4.1.tar.gz"
    python3 - "$MAKE_SOURCE_DIR/make-4.4.1.tar.gz" <<'PY'
import hashlib, sys
with open(sys.argv[1], 'rb') as file:
    assert hashlib.sha256(file.read()).hexdigest() == 'dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3'
PY
    tar -xzf "$MAKE_SOURCE_DIR/make-4.4.1.tar.gz" -C "$MAKE_SOURCE_DIR"
    (cd "$MAKE_SOURCE_DIR/make-4.4.1" && ./configure --prefix="$TOOLS_PREFIX" \
        && /usr/bin/make -j"${MAKE_JOBS:-8}" && /usr/bin/make install)
fi

(cd "$BUILD_DIR" && MAKE_JOBS="${MAKE_JOBS:-8}" ./buildMobileVLCKit.sh -t -f -a aarch64 -n -v)

FRAMEWORK="$BUILD_DIR/build/TVVLCKit.xcframework"
[[ -d "$FRAMEWORK" ]]
# Check the actual device decoder symbols, not only the presence of a track name.
nm -arch arm64 "$FRAMEWORK/tvos-arm64/TVVLCKit.framework/TVVLCKit" \
    > "$BUILD_DIR/unistream-decoder-symbols.txt"
rg '_ff_truehd_decoder' "$BUILD_DIR/unistream-decoder-symbols.txt"
mkdir -p "$PACKAGE_DIR/Artifacts"
ditto "$FRAMEWORK" "$PACKAGE_DIR/Artifacts/TVVLCKit.xcframework"
cp "$BUILD_DIR/COPYING" "$PACKAGE_DIR/COPYING.LGPL"
python3 - "$PACKAGE_DIR/Artifacts/build.json" "$KIT_REVISION" "$VLC_REVISION" <<'PY'
import json, sys
with open(sys.argv[1], 'w') as file:
    json.dump({'vlckit': sys.argv[2], 'vlc': sys.argv[3], 'truehdPatch': 1}, file, indent=2)
    file.write('\n')
PY
echo "TrueHD-enabled Apple TV framework is ready."
