#!/bin/bash
# Reference solution for gamecraft-bench/puzzle-pipe-crisis.
#
# Drops a pipe-routing puzzle game into /workspace/game/:
#   - Title screen with industrial theme
#   - Grid-based pipe placement with rotation
#   - Fluid flows from sources through connected pipes to drains
#   - Color matching, countdown timer, multiple levels
#   - Failure on dead ends / overflow, success on drain reached
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
