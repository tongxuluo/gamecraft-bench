#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-dungeon-shop.
#
# Drops a complete dungeon shopkeeper roguelike into /workspace/game/:
#   - Title screen with cozy shop aesthetic.
#   - Shop phase: drag items to shelves, set prices, adventurers buy.
#   - Thief events: click to catch thieves stealing items.
#   - End of day: restock from dungeon loot drops.
#   - Upgrade shop between days (more shelves, security, better stock).
#   - 5 days, escalating gold targets, lose if bankrupt.
#
# Source files live next to this script under files/.
# solve.sh just copies them into /workspace/game/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
