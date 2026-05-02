#!/usr/bin/env bash
# prepare-flathub-submission.sh
#
# Produces a ready-to-PR Flatpak manifest for github.com/flathub/fr.unimaru.unistream
# by downloading the GitHub Release tarball for a given tag, hashing it,
# and patching the URL + sha256 in the manifest.
#
# Usage:
#   bash packaging/linux/prepare-flathub-submission.sh <tag>
#
# Example:
#   bash packaging/linux/prepare-flathub-submission.sh v1.0.0
#
# Output (4 files — the manifest references each by its actual filename
# next to the .yml, the renames are done by the manifest itself via
# `dest-filename:`):
#   build/flathub/<tag>/fr.unimaru.unistream.yml
#   build/flathub/<tag>/fr.unimaru.unistream.metainfo.xml
#   build/flathub/<tag>/unistream.desktop
#   build/flathub/<tag>/unistream.png
#
# Then:
#   1. Fork github.com/flathub/flathub (one-time)
#   2. Create a new app PR targeting the `new-pr` branch
#   3. Push the three files above into a folder named `fr.unimaru.unistream/`
#   4. Open the PR — Flathub bots will validate the manifest

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <tag> (e.g. v1.0.0)" >&2
  exit 1
fi

TAG="$1"
REPO="unimaru69/unistream"
TARBALL="unistream-linux-x86_64.tar.gz"
URL="https://github.com/${REPO}/releases/download/${TAG}/${TARBALL}"

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_DIR="${ROOT_DIR}/packaging/linux"
OUT_DIR="${ROOT_DIR}/build/flathub/${TAG}"

mkdir -p "${OUT_DIR}"

echo "==> Fetching ${URL}"
curl -fsSL --retry 3 -o "${OUT_DIR}/${TARBALL}" "${URL}"

echo "==> Computing sha256"
SHA256=$(shasum -a 256 "${OUT_DIR}/${TARBALL}" | awk '{print $1}')
echo "    ${SHA256}"

echo "==> Patching manifest"
# Use perl rather than sed -i for portability between macOS and Linux.
perl -pe "s|TODO_REPLACE_WITH_ACTUAL_SHA256_AFTER_RELEASE|${SHA256}|g; s|/v[0-9]+\\.[0-9]+\\.[0-9]+/|/${TAG}/|g" \
  "${SRC_DIR}/fr.unimaru.unistream.yml" > "${OUT_DIR}/fr.unimaru.unistream.yml"

# Copy sibling sources verbatim under their original filenames.
# The manifest references them as `path: <filename>` next to the .yml,
# and applies any rename via `dest-filename:` at build time.
cp "${SRC_DIR}/fr.unimaru.unistream.metainfo.xml" "${OUT_DIR}/"
cp "${SRC_DIR}/unistream.desktop"                "${OUT_DIR}/"
cp "${SRC_DIR}/unistream.png"                    "${OUT_DIR}/"

# Drop the local tarball — Flathub fetches its own copy from the release URL.
rm "${OUT_DIR}/${TARBALL}"

echo
echo "==> Done. Files ready in:"
echo "    ${OUT_DIR}/"
echo
echo "Next steps (one-shot per app):"
echo "  1. Open https://github.com/flathub/flathub#new-app-submissions"
echo "  2. Fork github.com/flathub/flathub if not done"
echo "  3. Create branch 'new-pr/fr.unimaru.unistream' in your fork"
echo "  4. Add the four files from ${OUT_DIR}/ under fr.unimaru.unistream/"
echo "  5. Open a PR titled 'Add fr.unimaru.unistream' against flathub:new-pr"
echo "  6. Wait for the Flatpak External Data Checker bot to validate"
