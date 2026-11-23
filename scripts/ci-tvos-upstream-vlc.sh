#!/usr/bin/env bash
# CI only: point the tvOS project at the upstream prebuilt VLCKit.
#
# project.yml depends on the local package tvos/Packages/VLCKitTrueHD, whose
# 387 MB binary is gitignored and takes over an hour to rebuild from source
# (scripts/build-tvos-vlc-truehd.sh). A runner has neither. This swaps the
# dependency back to the upstream package — same VLC 3.x API, no MLP/TrueHD —
# so CI still compiles the app and runs every test that does not need the
# TrueHD decoder. Run it before `xcodegen generate`, and set the environment variable
# TEST_RUNNER_UNISTREAM_UPSTREAM_VLC=1 for `xcodebuild test` so the
# TrueHD-only tests skip instead of failing.
#
# Never run this before an archive: the shipped build must use the local
# package. It edits project.yml in place; do not commit the result.
set -euo pipefail

PROJECT_YML="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tvos/UniStreamTV/project.yml}"

grep -q 'path: ../Packages/VLCKitTrueHD' "$PROJECT_YML" \
    || { echo "VLCKitTrueHD local package not found in $PROJECT_YML"; exit 1; }
perl -0pi -e 's|path: \.\./Packages/VLCKitTrueHD|url: https://github.com/tylerjonesio/vlckit-spm\n    from: "3.5.1"|' "$PROJECT_YML"
grep -q 'tylerjonesio/vlckit-spm' "$PROJECT_YML"
echo "tvOS project now uses upstream VLCKit (no TrueHD) — CI only."
