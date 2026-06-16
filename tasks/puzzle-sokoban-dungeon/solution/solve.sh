#!/bin/bash
# Reference solution for gamecraft-bench/puzzle-sokoban-dungeon.
#
# Drops a complete turn-based Sokoban dungeon puzzle game into /workspace/game/:
#   - Title screen with dungeon theme and Play button.
#   - Grid-based movement with arrow keys, turn-based enemy movement.
#   - Push crates onto pressure plates to open doors.
#   - Multiple enemy types (chaser, patrol, mimic).
#   - Multiple crate types (standard, ice, heavy).
#   - Procedural room generation across multiple floors.
#   - Items (freeze, pull, teleport) found in chests.
#   - Undo system and retry on death.
#   - Color-coded keys and locked doors.
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
