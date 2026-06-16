#!/usr/bin/env bash
set -eu

# Copy solution files to the workspace game directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/files"
TARGET_DIR="/workspace/game"

rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"
cp -r "${SOURCE_DIR}/." "${TARGET_DIR}/"

echo "Gladiator Arena Tycoon deployed to ${TARGET_DIR}"
