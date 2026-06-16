#!/usr/bin/env bash
set -eu

# Copy oracle solution files into the workspace game directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/files"
DEST_DIR="/workspace/game"

rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"
cp -r "${SOURCE_DIR}/." "${DEST_DIR}/"

echo "Potion Shop Tycoon oracle solution deployed to ${DEST_DIR}"
