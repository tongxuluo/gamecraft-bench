#!/usr/bin/env bash
set -eu

# solve.sh — copies the oracle solution into the workspace
# Note: this script should be run with execute permission (chmod +x solve.sh)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/files"
TARGET_DIR="/workspace/game"

rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

cp -r "${SOURCE_DIR}/." "${TARGET_DIR}/"

echo "Oracle solution deployed to ${TARGET_DIR}"
