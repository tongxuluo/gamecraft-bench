#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-train-heist.
#
# Drops a complete procedural train-car roguelike into /workspace/game/:
#   - Title screen with train silhouette
#   - Side-view train with 8 cars visible
#   - Move forward (RIGHT key) car-by-car
#   - Encounters: combat, shop, trap, treasure
#   - HP + gold + inventory (3 slots)
#   - Guards advance from behind (turn pressure)
#   - Reach engine car = win
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
