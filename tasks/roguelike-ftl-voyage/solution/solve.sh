#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-ftl-voyage.
#
# Drops a complete FTL-style starship roguelike into /workspace/game/:
#   - Title screen with ship silhouette and star field.
#   - Ship view: rooms (weapons/shields/engines/medbay), crew dots draggable.
#   - Sector map: nodes connected by lines, click to jump (costs fuel).
#   - Events: text + choices (fight/flee/trade).
#   - Combat: power weapons, fire at enemy, enemy fires back, systems damage.
#   - Fuel/scrap/hull resources.
#   - Repair at shops.
#   - Final boss after 3 sectors.
#
# Source files live next to this script under files/. solve.sh copies them.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
