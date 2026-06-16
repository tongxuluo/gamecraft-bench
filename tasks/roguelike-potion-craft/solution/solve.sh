#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-potion-craft.
#
# Drops a complete potion-brewing roguelike into /workspace/game/:
#   - Title screen with bubbling cauldron theme.
#   - Map: grid of nodes with ingredient icons, arrow-key movement.
#   - Gather ingredients by stepping on nodes.
#   - Brewing: combine 2-3 ingredients to make potions (recipe matching).
#   - Customers with requests; sell matching potion for gold.
#   - Wrong potion = reputation loss. Lose all reputation = game over.
#   - Discover new recipes by experimenting.
#   - 3 map floors, each harder. Win after completing all floors.
#
# Source files live next to this script under files/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
