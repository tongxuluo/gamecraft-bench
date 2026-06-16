#!/bin/bash
# Reference solution for gamecraft-bench/tycoon-farm.
#
# Drops a minimal but coherent farm tycoon game into /workspace/game/:
#   - Title screen with New Farm (new game) and Continue (load from save).
#   - Farm scene with 8x6 tile grid, player movement, stamina/gold/day HUD.
#   - Actions: till (1), water (2), plant (3), harvest (4), sleep (SPACE at bed).
#   - 3 crop types with different growth times (1/2/3 days).
#   - Day-end transition panel showing summary, crops advance growth stages.
#   - Save persists state to user://save.json (on sleep).
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