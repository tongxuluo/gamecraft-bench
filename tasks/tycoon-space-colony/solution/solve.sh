#!/usr/bin/env bash
set -eu

# Copy oracle solution files to the workspace game directory
DEST="/workspace/game"
SRC="$(dirname "$0")/files"

rm -rf "$DEST"
mkdir -p "$DEST"
cp -r "$SRC"/* "$DEST"/

echo "Space Colony Tycoon oracle solution deployed to $DEST"
