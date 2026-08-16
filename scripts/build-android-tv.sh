#!/usr/bin/env bash
#
# Build (and optionally install) the Android TV APK with the TMDB key
# baked in.
#
# `flutter build apk` on its own leaves `String.fromEnvironment('TMDB_KEY')`
# empty (see lib/providers/tmdb_provider.dart), so the app ships without
# metadata enrichment and the hero falls back to the provider's own
# artwork. CI passes the key from the TMDB_KEY GitHub secret; this does
# the same locally.
#
# The key is resolved, in order, from:
#   1. $TMDB_KEY in the environment
#   2. an untracked key file at .tmdb_key (gitignored)
#   3. tvos/UniStreamTV/.tmdb_key (gitignored) — same key, already on
#      disk for the tvOS archive script
#
# Usage:
#   ./scripts/build-android-tv.sh                 # build the APK
#   ./scripts/build-android-tv.sh --install        # + install on the
#                                                  # only attached device
#   ./scripts/build-android-tv.sh --install 192.168.1.193:5555
#
# The APK is universal (arm64-v8a + armeabi-v7a + x86_64). TV boxes are
# routinely 32-bit only — the Skyworth/Amlogic test box reports
# `armeabi-v7a` alone despite running Android 14 — so do not swap this
# for a `--split-per-abi` arm64 artifact without checking the target.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

INSTALL=0
DEVICE=""
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        -*) echo "Unknown option: $arg" >&2; exit 2 ;;
        *) DEVICE="$arg" ;;
    esac
done

# ── Resolve the TMDB API key ──────────────────────────────────────────
: "${TMDB_KEY:=}"
if [[ -z "$TMDB_KEY" && -f "$REPO_ROOT/.tmdb_key" ]]; then
    TMDB_KEY="$(tr -d '[:space:]' < "$REPO_ROOT/.tmdb_key")"
fi
if [[ -z "$TMDB_KEY" && -f "$REPO_ROOT/tvos/UniStreamTV/.tmdb_key" ]]; then
    TMDB_KEY="$(tr -d '[:space:]' < "$REPO_ROOT/tvos/UniStreamTV/.tmdb_key")"
fi
if [[ -z "$TMDB_KEY" ]]; then
    echo "⚠️  No TMDB key (env TMDB_KEY, .tmdb_key, or tvos/UniStreamTV/.tmdb_key)."
    echo "    Building without TMDB — hero falls back to provider artwork."
else
    echo "🔑 TMDB key found (${#TMDB_KEY} chars) — baking it in."
fi

echo "📦 Building release APK…"
flutter build apk --release --dart-define=TMDB_KEY="$TMDB_KEY"

APK="build/app/outputs/flutter-apk/app-release.apk"
echo "✅ $APK"

if [[ "$INSTALL" == "1" ]]; then
    ADB_ARGS=()
    [[ -n "$DEVICE" ]] && ADB_ARGS=(-s "$DEVICE")
    echo "📲 Installing…"
    adb "${ADB_ARGS[@]}" install -r "$APK"
    adb "${ADB_ARGS[@]}" shell monkey -p fr.unimaru.unistream \
        -c android.intent.category.LEANBACK_LAUNCHER 1 >/dev/null 2>&1
    echo "🚀 Launched."
fi
