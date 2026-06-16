#!/bin/bash
# Reference solution for gamecraft-bench/puzzle-gravity-shift.
#
# Drops a gravity-rotation puzzle game into /workspace/game/:
#   - Title screen with Play button.
#   - Grid-based levels with walls, ball, exit, destructible blocks, hazards.
#   - Arrow keys rotate gravity in 90-degree increments.
#   - Ball falls in current gravity direction until hitting a surface.
#   - Ball reaching exit = level complete.
#   - At least 3 levels with increasing complexity.
#   - Destructible blocks break when ball hits them.
#   - Chain reactions from gravity shifts.
#   - Undo system (Z key) to rewind gravity shifts.
#
# Source files live next to this script under files/. solve.sh copies them.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
