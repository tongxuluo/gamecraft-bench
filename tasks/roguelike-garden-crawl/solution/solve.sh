#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-garden-crawl.
#
# Drops a minimal but coherent garden-dungeon roguelike into /workspace/game/:
#   - Title screen with garden-over-dungeon theme.
#   - Grid-based floors with soil tiles for planting.
#   - Seed deck: plant seeds that grow (seedling -> mature -> blooming).
#   - Plants attack/block enemies, enemies approach from the right.
#   - Harvest mature plants for resources, buy seeds between floors.
#   - Seasons rotate every 3 floors changing enemy types/plant stats.
#   - 4 floors + boss, permadeath.
#
# Source files live next to this script under files/. solve.sh copies them.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
