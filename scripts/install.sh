#!/bin/bash
# Installs (or updates) Telelucent from the latest GitHub release.
#   curl -fsSL https://raw.githubusercontent.com/samir-sarwar/telelucent/main/scripts/install.sh | bash
set -euo pipefail

URL="https://github.com/samir-sarwar/telelucent/releases/latest/download/Telelucent.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Telelucent…"
curl -fsSL "$URL" -o "$TMP/Telelucent.zip"
ditto -x -k "$TMP/Telelucent.zip" "$TMP"

DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

pkill -x Telelucent 2>/dev/null && sleep 0.5 || true
rm -rf "$DEST/Telelucent.app"
mv "$TMP/Telelucent.app" "$DEST/"
# The app isn't notarized; files fetched with curl aren't quarantined, but clear it just in case.
xattr -dr com.apple.quarantine "$DEST/Telelucent.app" 2>/dev/null || true

echo "Installed $DEST/Telelucent.app"
open "$DEST/Telelucent.app"
