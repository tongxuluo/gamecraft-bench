#!/usr/bin/env bash
set -eu

# Copy oracle solution files to the workspace game directory
DEST="/workspace/game"
mkdir -p "$DEST"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp -r "$SCRIPT_DIR/files/"* "$DEST/"

echo "Zoo Keeper Tycoon oracle solution copied to $DEST"
