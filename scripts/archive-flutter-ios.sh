#!/usr/bin/env bash
#
# Archive + upload the Flutter app (iOS / iPadOS) to App Store Connect / TestFlight.
#
# Workflow:
#   1. Bump the build number in pubspec.yaml (the +N suffix)
#   2. flutter pub get + cocoapods install
#   3. flutter build ipa --release (with the existing ios/ExportOptions.plist)
#   4. Upload via xcrun altool
#   5. Commit the bump
#
# Usage:
#   ./scripts/archive-flutter-ios.sh                # auto-bump + upload
#   ./scripts/archive-flutter-ios.sh --no-upload    # build only
#   ./scripts/archive-flutter-ios.sh --no-commit    # don't auto-commit
#
# Requirements:
#   - flutter on PATH
#   - cocoapods on PATH
#   - ASC API key file at ~/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────
: "${ASC_API_KEY_ID:=N4K77SK2A9}"
: "${ASC_API_ISSUER_ID:=025be2c7-6d3e-42a9-a892-8dfb6f3112fc}"

UPLOAD=true
COMMIT=true
for arg in "$@"; do
    case $arg in
        --no-upload) UPLOAD=false ;;
        --no-commit) COMMIT=false ;;
        *) echo "unknown flag: $arg"; exit 2 ;;
    esac
done

# ── Locate paths ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"
EXPORT_OPTIONS="$ROOT/ios/ExportOptions.plist"

[[ -f "$PUBSPEC" ]] || { echo "missing $PUBSPEC"; exit 1; }
[[ -f "$EXPORT_OPTIONS" ]] || { echo "missing $EXPORT_OPTIONS"; exit 1; }

# ── Bump build number ─────────────────────────────────────────────────
CURRENT_LINE=$(grep -E '^version:' "$PUBSPEC" | head -1)
CURRENT=$(echo "$CURRENT_LINE" | sed -E 's/.*\+([0-9]+).*/\1/')
NAME=$(echo "$CURRENT_LINE" | sed -E 's/version:[[:space:]]+([^+]+)\+.*/\1/' | xargs)
[[ -n "$CURRENT" && -n "$NAME" ]] || { echo "couldn't parse pubspec version"; exit 1; }
NEW=$((CURRENT + 1))
echo "→ Flutter build $NAME+$CURRENT → $NAME+$NEW"

sed -i.bak "s/^version: $NAME+$CURRENT/version: $NAME+$NEW/" "$PUBSPEC"
rm -f "$PUBSPEC.bak"

# ── flutter clean + dependencies ──────────────────────────────────────
cd "$ROOT"
echo "→ flutter pub get"
flutter pub get >/dev/null

echo "→ pod install"
(cd ios && pod install --repo-update >/dev/null 2>&1 || pod install >/dev/null)

# ── Build iOS .ipa ────────────────────────────────────────────────────
echo "→ flutter build ipa (this can take several minutes)…"
flutter build ipa --release \
    --export-options-plist="$EXPORT_OPTIONS" \
    | tail -20 || true

IPA_PATH=$(find "$ROOT/build/ios/ipa" -name '*.ipa' | head -1 || true)
[[ -n "$IPA_PATH" && -f "$IPA_PATH" ]] || {
    echo "✗ ipa missing — common cause: archive succeeded but flutter's"
    echo "  exporter failed. Try opening ios/Runner.xcworkspace in Xcode,"
    echo "  Product → Archive, then Organizer → Distribute App."
    exit 1
}
echo "  $IPA_PATH"

# ── Upload to TestFlight ──────────────────────────────────────────────
if $UPLOAD; then
    echo "→ Uploading to App Store Connect"
    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_PATH" \
        --apiKey "$ASC_API_KEY_ID" \
        --apiIssuer "$ASC_API_ISSUER_ID"
    echo "✓ Flutter build $NAME+$NEW uploaded"
else
    echo "→ Skipping upload (--no-upload)"
    echo "  IPA available at: $IPA_PATH"
fi

# ── Commit the version bump ───────────────────────────────────────────
if $COMMIT; then
    if git diff --quiet "$PUBSPEC"; then
        :
    else
        git add "$PUBSPEC"
        git commit -m "Flutter: bump build to $NAME+$NEW for TestFlight upload" \
            >/dev/null
        echo "✓ version bump committed ($NAME+$NEW)"
    fi
fi
