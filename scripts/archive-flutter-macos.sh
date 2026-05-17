#!/usr/bin/env bash
#
# Archive + sign + notarize + staple the Flutter macOS app into a DMG
# ready for off-store distribution (drag-and-drop install).
#
# Workflow:
#   1. Build the .app via `flutter build macos --release`
#   2. Re-sign the .app with Developer ID Application + hardened
#      runtime + entitlements (Flutter signs with Apple Development
#      out of the box — we need Developer ID for off-store).
#   3. Verify the signature is acceptable.
#   4. Wrap the .app in a DMG via `hdiutil` (plain UDZO, no fancy
#      layout — add `create-dmg` later if a polished install
#      window is wanted).
#   5. Sign the DMG.
#   6. Submit to Apple's notary service via `xcrun notarytool`
#      (uses the same ASC API key as the iOS TestFlight script).
#   7. Staple the notarization ticket so the DMG can be opened
#      offline without Gatekeeper bouncing it.
#   8. Verify the stapled DMG via `spctl --assess`.
#
# Usage:
#   ./scripts/archive-flutter-macos.sh                # full pipeline
#   ./scripts/archive-flutter-macos.sh --no-notarize  # build + sign DMG only
#   ./scripts/archive-flutter-macos.sh --no-bump      # don't bump pubspec
#
# Requirements:
#   - Xcode (notarytool / stapler)
#   - Developer ID Application cert in login keychain
#       Today: "Developer ID Application: Franck Bourbon (VS8P2MA59S)"
#   - ASC API key file at ~/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8
#   - flutter on PATH

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────
: "${DEVELOPER_ID_APP:=Developer ID Application: Franck Bourbon (VS8P2MA59S)}"
: "${ASC_API_KEY_ID:=N4K77SK2A9}"
: "${ASC_API_ISSUER_ID:=025be2c7-6d3e-42a9-a892-8dfb6f3112fc}"
: "${ASC_API_KEY_FILE:=$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8}"

NOTARIZE=true
BUMP=true
COMMIT=true
for arg in "$@"; do
    case $arg in
        --no-notarize) NOTARIZE=false ;;
        --no-bump)     BUMP=false ;;
        --no-commit)   COMMIT=false ;;
        *) echo "unknown flag: $arg"; exit 2 ;;
    esac
done

# ── Paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"
ENTITLEMENTS="$ROOT/macos/Runner/Release.entitlements"
APP_PATH="$ROOT/build/macos/Build/Products/Release/unistream.app"
DMG_DIR="$ROOT/build/macos/dmg"
DMG_PATH="$DMG_DIR/UniStream.dmg"

[[ -f "$PUBSPEC" ]] || { echo "missing $PUBSPEC"; exit 1; }
[[ -f "$ENTITLEMENTS" ]] || { echo "missing $ENTITLEMENTS"; exit 1; }

# ── Bump build number (shared with iOS — same +N) ─────────────────────
if $BUMP; then
    CURRENT_LINE=$(grep -E '^version:' "$PUBSPEC" | head -1)
    CURRENT=$(echo "$CURRENT_LINE" | sed -E 's/.*\+([0-9]+).*/\1/')
    NAME=$(echo "$CURRENT_LINE" | sed -E 's/version:[[:space:]]+([^+]+)\+.*/\1/' | xargs)
    [[ -n "$CURRENT" && -n "$NAME" ]] || { echo "couldn't parse pubspec version"; exit 1; }
    NEW=$((CURRENT + 1))
    echo "→ Flutter macOS build $NAME+$CURRENT → $NAME+$NEW"
    sed -i.bak "s/^version: $NAME+$CURRENT/version: $NAME+$NEW/" "$PUBSPEC"
    rm -f "$PUBSPEC.bak"
else
    NAME=$(grep -E '^version:' "$PUBSPEC" | head -1 | sed -E 's/version:[[:space:]]+([^+]+)\+.*/\1/' | xargs)
    NEW=$(grep -E '^version:' "$PUBSPEC" | head -1 | sed -E 's/.*\+([0-9]+).*/\1/')
    echo "→ Flutter macOS build $NAME+$NEW (no bump)"
fi

# ── flutter pub get + pod install ─────────────────────────────────────
cd "$ROOT"
echo "→ flutter pub get"
flutter pub get >/dev/null

echo "→ pod install (macos)"
(cd macos && pod install --repo-update >/dev/null 2>&1 || pod install >/dev/null)

# ── Build the .app ────────────────────────────────────────────────────
echo "→ flutter build macos --release"
flutter build macos --release | tail -10 || {
    echo "✗ flutter build macos failed"
    exit 1
}
[[ -d "$APP_PATH" ]] || { echo "✗ missing $APP_PATH after build"; exit 1; }
echo "  $APP_PATH"

# ── Re-sign with Developer ID + hardened runtime ──────────────────────
# Flutter signs with "Apple Development" by default (good enough for
# `flutter run`), but distribution outside the App Store needs the
# Developer ID Application cert. We also flip on hardened runtime
# (`--options runtime`) which is a notarization prerequisite, and
# apply the entitlements file so the runtime knows what's allowed.
echo "→ codesign --deep $APP_PATH"
codesign --deep --force \
    --sign "$DEVELOPER_ID_APP" \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --timestamp \
    "$APP_PATH"

echo "→ codesign verify"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -3 || true

# Gatekeeper pre-check (still expects notarization to be stapled
# later — failures here are informational at this stage).
spctl --assess --type execute --verbose=2 "$APP_PATH" 2>&1 | tail -3 || true

# ── Build the DMG ─────────────────────────────────────────────────────
mkdir -p "$DMG_DIR"
rm -f "$DMG_PATH"

# Stage in a temp folder so the DMG only contains the .app + an
# Applications symlink (no metadata leaks).
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "→ hdiutil create $DMG_PATH"
hdiutil create -quiet \
    -volname "UniStream $NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "→ codesign DMG"
codesign --force \
    --sign "$DEVELOPER_ID_APP" \
    --timestamp \
    "$DMG_PATH"

# ── Notarize + staple ─────────────────────────────────────────────────
if $NOTARIZE; then
    [[ -f "$ASC_API_KEY_FILE" ]] || { echo "✗ missing $ASC_API_KEY_FILE"; exit 1; }
    echo "→ notarytool submit (waits — typically 1-10 min)"
    xcrun notarytool submit "$DMG_PATH" \
        --key "$ASC_API_KEY_FILE" \
        --key-id "$ASC_API_KEY_ID" \
        --issuer "$ASC_API_ISSUER_ID" \
        --wait

    echo "→ stapler staple"
    xcrun stapler staple "$DMG_PATH"

    echo "→ spctl verify stapled DMG"
    spctl --assess --type install --verbose=2 "$DMG_PATH" 2>&1 | tail -3 || true

    echo "✓ Notarized DMG ready at $DMG_PATH"
else
    echo "→ Skipping notarization (--no-notarize)"
    echo "  DMG (signed but not notarized) at $DMG_PATH"
    echo "  Gatekeeper will require right-click → Open on first launch."
fi

# ── Commit the version bump ───────────────────────────────────────────
if $BUMP && $COMMIT; then
    if git -C "$ROOT" diff --quiet "$PUBSPEC"; then
        :
    else
        git -C "$ROOT" add "$PUBSPEC"
        git -C "$ROOT" commit -m "Flutter: bump build to $NAME+$NEW for macOS DMG release" \
            >/dev/null
        echo "✓ version bump committed ($NAME+$NEW)"
    fi
fi

echo ""
echo "  Open the DMG: open \"$DMG_PATH\""
