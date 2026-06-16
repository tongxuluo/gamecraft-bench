#!/bin/bash
# Reference solution for gamecraft-bench/puzzle-lemming-factory.
#
# Drops a complete Lemming Factory game into /workspace/game/:
#   - Title screen with factory theme and marching creature silhouettes.
#   - Level select with 3 levels of increasing difficulty.
#   - Gameplay: creatures march from entrance, player assigns jobs (digger,
#     builder, blocker, climber) to guide them to exit door.
#   - Win/loss conditions based on save quota.
#   - HUD with job toolbar, saved count, timer.
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
