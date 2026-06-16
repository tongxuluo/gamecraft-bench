#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-spelunk-depths.
#
# Drops a minimal but coherent spelunky-style platformer roguelike into /workspace/game/:
#   - Title screen with cave entrance theme.
#   - Side-view procedural platformer with physics objects.
#   - Ropes and bombs as consumables, gold collection.
#   - Shopkeeper that turns hostile if player steals.
#   - Ghost timer (60s) forces forward progress.
#   - 4 floors, permadeath, exit door at bottom of each floor.
#
# Source files live next to this script under files/. solve.sh copies them.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
