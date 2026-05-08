#!/usr/bin/env bash
#
# Archive + upload UniStreamTV (tvOS) to App Store Connect / TestFlight.
#
# Workflow:
#   1. Bump CURRENT_PROJECT_VERSION in tvos/UniStreamTV/project.yml
#   2. Regenerate the Xcode project via xcodegen
#   3. Archive
#   4. Export an .ipa via the existing ExportOptions.plist
#   5. Upload via xcrun altool (using ASC API key from ~/.appstoreconnect/private_keys/)
#   6. Commit the version bump (so git history matches what's on TestFlight)
#
# Usage:
#   ./scripts/archive-tvos.sh                # auto-bump + upload
#   ./scripts/archive-tvos.sh --no-upload    # archive + export only, skip altool
#   ./scripts/archive-tvos.sh --no-commit    # don't auto-commit the bump
#
# Requirements:
#   - xcodegen on PATH
#   - ASC API key file at ~/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8
#   - Env vars (or defaults below) ASC_API_KEY_ID + ASC_API_ISSUER_ID

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
TVOS_DIR="$ROOT/tvos/UniStreamTV"
PROJECT_YML="$TVOS_DIR/project.yml"
EXPORT_OPTIONS="$TVOS_DIR/ExportOptions.plist"

[[ -f "$PROJECT_YML" ]] || { echo "missing $PROJECT_YML"; exit 1; }
[[ -f "$EXPORT_OPTIONS" ]] || { echo "missing $EXPORT_OPTIONS"; exit 1; }

# ── Bump CURRENT_PROJECT_VERSION ──────────────────────────────────────
CURRENT=$(grep -E '^[[:space:]]+CURRENT_PROJECT_VERSION:' "$PROJECT_YML" \
    | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')
[[ -n "$CURRENT" ]] || { echo "couldn't parse CURRENT_PROJECT_VERSION"; exit 1; }
NEW=$((CURRENT + 1))
echo "→ tvOS build $CURRENT → $NEW"

# Both targets share the same build number — replace every occurrence.
sed -i.bak "s/CURRENT_PROJECT_VERSION: \"$CURRENT\"/CURRENT_PROJECT_VERSION: \"$NEW\"/g" "$PROJECT_YML"
rm -f "$PROJECT_YML.bak"

# ── Regenerate Xcode project ──────────────────────────────────────────
echo "→ xcodegen"
(cd "$TVOS_DIR" && xcodegen generate >/dev/null)

# ── Archive ───────────────────────────────────────────────────────────
ARCHIVE_PATH="/tmp/UniStreamTV-$NEW.xcarchive"
EXPORT_DIR="/tmp/UniStreamTV-$NEW-export"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

echo "→ Archiving (this can take a few minutes)…"
(cd "$TVOS_DIR" && xcodebuild archive \
    -project UniStreamTV.xcodeproj \
    -scheme UniStreamTV \
    -destination 'generic/platform=tvOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    | xcbeautify --quieter 2>/dev/null || true)

[[ -d "$ARCHIVE_PATH" ]] || { echo "✗ archive missing — fix the build error and retry"; exit 1; }

# ── Export .ipa ───────────────────────────────────────────────────────
echo "→ Exporting .ipa"
(cd "$TVOS_DIR" && xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist ExportOptions.plist \
    -allowProvisioningUpdates \
    | xcbeautify --quieter 2>/dev/null || true)

IPA_PATH=$(find "$EXPORT_DIR" -name '*.ipa' | head -1 || true)
[[ -n "$IPA_PATH" && -f "$IPA_PATH" ]] || { echo "✗ ipa missing under $EXPORT_DIR"; exit 1; }
echo "  $IPA_PATH"

# ── Upload to TestFlight ──────────────────────────────────────────────
if $UPLOAD; then
    echo "→ Uploading to App Store Connect"
    xcrun altool --upload-app \
        --type appletvos \
        --file "$IPA_PATH" \
        --apiKey "$ASC_API_KEY_ID" \
        --apiIssuer "$ASC_API_ISSUER_ID"
    echo "✓ tvOS build $NEW uploaded — should appear in TestFlight in ~5-10 min"
else
    echo "→ Skipping upload (--no-upload)"
    echo "  IPA available at: $IPA_PATH"
fi

# ── Commit the version bump ───────────────────────────────────────────
if $COMMIT; then
    cd "$ROOT"
    if git diff --quiet "$PROJECT_YML"; then
        :  # nothing changed (race / re-run)
    else
        # Also stage the regenerated xcodeproj since project.yml drives it.
        git add "$PROJECT_YML" "$TVOS_DIR/UniStreamTV.xcodeproj/project.pbxproj"
        git commit -m "tvOS: bump CURRENT_PROJECT_VERSION to $NEW for TestFlight upload" \
            >/dev/null
        echo "✓ version bump committed (build $NEW)"
    fi
fi
