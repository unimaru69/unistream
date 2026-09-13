#!/usr/bin/env bash
#
# Archive + upload UniStreamTV (tvOS) to App Store Connect / TestFlight.
#
# Workflow:
#   1. Bump CURRENT_PROJECT_VERSION in tvos/UniStreamTV/project.yml
#   2. Regenerate the Xcode project via xcodegen
#   3. Archive
#   4. Upload the archive's dSYMs to Sentry (so crashes symbolicate)
#   5. Export an .ipa via the existing ExportOptions.plist
#   6. Upload via xcrun altool (using ASC API key from ~/.appstoreconnect/private_keys/)
#   7. Commit the version bump (so git history matches what's on TestFlight)
#
# Usage:
#   ./scripts/archive-tvos.sh                # auto-bump + upload
#   ./scripts/archive-tvos.sh --no-upload    # archive + export only, skip altool
#   ./scripts/archive-tvos.sh --no-commit    # don't auto-commit the bump
#   ./scripts/archive-tvos.sh --no-bump      # re-archive at the current version
#                                            #   (use after a failed export to avoid
#                                            #    burning the next build number)
#   ./scripts/archive-tvos.sh --no-sentry    # skip the dSYM upload
#
# Requirements:
#   - xcodegen on PATH
#   - ASC API key file at ~/.appstoreconnect/private_keys/AuthKey_${ASC_API_KEY_ID}.p8
#   - Env vars (or defaults below) ASC_API_KEY_ID + ASC_API_ISSUER_ID
#   - For the dSYM upload: sentry-cli on PATH plus a token in
#     $SENTRY_AUTH_TOKEN or ~/.sentryclirc (both optional — a missing one
#     warns and moves on rather than failing the release)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────
: "${ASC_API_KEY_ID:=N4K77SK2A9}"
: "${ASC_API_ISSUER_ID:=025be2c7-6d3e-42a9-a892-8dfb6f3112fc}"

# Sentry. The org is in the DE region, and the region is encoded in the
# auth token itself — sentry-cli routes on that and ignores any
# SENTRY_URL, warning when the two disagree. So there is deliberately no
# URL set here: what matters is that the token was issued from the DE
# side (unimaru.sentry.io → Settings → Auth Tokens). A token created on
# sentry.io answers 403 for this org no matter how the CLI is configured.
#
# The token stays out of the repo: env SENTRY_AUTH_TOKEN or ~/.sentryclirc.
: "${SENTRY_ORG:=unimaru}"
: "${SENTRY_PROJECT:=unistream}"

UPLOAD=true
COMMIT=true
BUMP=true
SENTRY_UPLOAD=true
for arg in "$@"; do
    case $arg in
        --no-upload) UPLOAD=false ;;
        --no-commit) COMMIT=false ;;
        --no-bump)   BUMP=false ;;
        --no-sentry) SENTRY_UPLOAD=false ;;
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

# ── Resolve the TMDB API key ──────────────────────────────────────────
# Info.plist's TMDBAPIKey expands from the TMDB_API_KEY build setting,
# which project.yml defaults to "" — so a local archive ships with TMDB
# enrichment dormant (empty hero backdrops, no cast/overview). CI injects
# it from the `TMDB_KEY` GitHub secret; locally we read it, in order, from:
#   1. $TMDB_API_KEY / $TMDB_KEY in the environment
#   2. an untracked key file at tvos/UniStreamTV/.tmdb_key (gitignored)
# Never commit the key — that's why it's a file/env, not project.yml.
: "${TMDB_API_KEY:=${TMDB_KEY:-}}"
if [[ -z "$TMDB_API_KEY" && -f "$TVOS_DIR/.tmdb_key" ]]; then
    TMDB_API_KEY="$(tr -d '[:space:]' < "$TVOS_DIR/.tmdb_key")"
fi
if [[ -z "$TMDB_API_KEY" ]]; then
    echo "⚠️  No TMDB key (env TMDB_API_KEY/TMDB_KEY or $TVOS_DIR/.tmdb_key)."
    echo "    Building without TMDB — hero falls back to provider artwork."
else
    echo "→ TMDB key found (len=${#TMDB_API_KEY}) — enrichment enabled"
fi

# ── Bump CURRENT_PROJECT_VERSION ──────────────────────────────────────
CURRENT=$(grep -E '^[[:space:]]+CURRENT_PROJECT_VERSION:' "$PROJECT_YML" \
    | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')
[[ -n "$CURRENT" ]] || { echo "couldn't parse CURRENT_PROJECT_VERSION"; exit 1; }

if $BUMP; then
    NEW=$((CURRENT + 1))
    echo "→ tvOS build $CURRENT → $NEW"
    # Both targets share the same build number — replace every occurrence.
    sed -i.bak "s/CURRENT_PROJECT_VERSION: \"$CURRENT\"/CURRENT_PROJECT_VERSION: \"$NEW\"/g" "$PROJECT_YML"
    rm -f "$PROJECT_YML.bak"
else
    NEW=$CURRENT
    echo "→ tvOS build $NEW (--no-bump)"
fi

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
    TMDB_API_KEY="$TMDB_API_KEY" \
    | xcbeautify --quieter 2>/dev/null || true)

[[ -d "$ARCHIVE_PATH" ]] || { echo "✗ archive missing — fix the build error and retry"; exit 1; }

# ── Upload dSYMs to Sentry ────────────────────────────────────────────
# Without this, every UniStreamTV frame in a tvOS crash or App Hang shows
# up on Sentry as `<redacted>` and the event carries `native_missing_dsym`
# — you can see the app hung inside UIKit, never which of our views got it
# there. Uploading from the archive (rather than a build phase) keeps it
# off every incremental build and catches the exact binary we ship.
#
# Never fatal: a missing sentry-cli or token degrades to a warning so a
# release is never blocked on observability tooling.
if $SENTRY_UPLOAD; then
    : "${SENTRY_AUTH_TOKEN:=}"
    DSYM_DIR="$ARCHIVE_PATH/dSYMs"

    if ! command -v sentry-cli >/dev/null 2>&1; then
        echo "⚠️  sentry-cli not on PATH — skipping dSYM upload."
        echo "    Install with: brew install getsentry/tools/sentry-cli"
        echo "    tvOS stack traces will stay unsymbolicated for build $NEW."
    elif [[ -z "$SENTRY_AUTH_TOKEN" && ! -f "$HOME/.sentryclirc" ]]; then
        echo "⚠️  No Sentry auth token (env SENTRY_AUTH_TOKEN or ~/.sentryclirc)"
        echo "    — skipping dSYM upload for build $NEW."
    elif [[ ! -d "$DSYM_DIR" ]]; then
        echo "⚠️  No dSYMs at $DSYM_DIR — check DEBUG_INFORMATION_FORMAT."
    else
        echo "→ Uploading dSYMs to Sentry ($SENTRY_ORG/$SENTRY_PROJECT)"
        if SENTRY_ORG="$SENTRY_ORG" SENTRY_PROJECT="$SENTRY_PROJECT" \
           sentry-cli debug-files upload --include-sources "$DSYM_DIR"; then
            echo "✓ dSYMs uploaded for build $NEW"
        else
            echo "⚠️  dSYM upload failed — build $NEW will report unsymbolicated."
            echo "    A 403 here usually means the token was issued on"
            echo "    sentry.io rather than the DE region that hosts this org."
        fi
    fi
else
    echo "→ Skipping dSYM upload (--no-sentry)"
fi

# ── Export .ipa ───────────────────────────────────────────────────────
# Export uses the Xcode keychain account (signingStyle: automatic in
# ExportOptions.plist + allowProvisioningUpdates). Earlier we tried to
# pass the ASC API key here as well to avoid keychain freshness issues,
# but the cloud-signing path requires the key to have App Manager /
# Admin role on the team — Developer-role keys hit "Cloud signing
# permission error". Keychain path is universal regardless of role; if
# you see "No Accounts / No signing certificate", just re-sign into
# Xcode → Settings → Accounts.
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
if $COMMIT && $BUMP; then
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
