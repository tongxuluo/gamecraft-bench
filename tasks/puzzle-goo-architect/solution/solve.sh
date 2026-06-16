#!/bin/bash
# Reference solution for gamecraft-bench/puzzle-goo-architect.
#
# Drops a minimal but coherent goo-construction puzzle game into /workspace/game/:
#   - Title screen with animated goo blobs and Start button.
#   - Level select with 3 levels showing different structural challenges.
#   - Gameplay: drag goo blobs from supply, attach to structure, physics sim,
#     reach goal pipe. Multiple goo types (standard, rigid, balloon).
#   - Win condition when goo reaches goal pipe.
#   - Results screen with blobs saved count.
#
# Source files (.gd, .tscn, demo traces) live next to this script under
# files/. solve.sh just copies them into /workspace/game/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
