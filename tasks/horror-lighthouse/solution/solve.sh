#!/bin/bash
# Reference solution for gamecraft-bench/horror-lighthouse.
#
# Drops a complete horror-themed lighthouse game into /workspace/game/:
#   - Title screen with stormy coast, lighthouse silhouette + sweeping beam,
#     weathered serif title and a Begin Watch button.
#   - Lighthouse cross-section with three accessible floors (Lamp Room,
#     Quarters, Fuel Storage) plus a window-view of the sea where ships
#     approach the rocks.
#   - Lamp maintenance: rotate beam (arrow keys), focused beam (SPACE),
#     fuel refill, lens cleaning, repairing creature damage.
#   - Fuel management: gauge, dim/bright trade-off, supply boats per night.
#   - Creature interference: tentacles, false bioluminescent lures,
#     structural damage that the player must repair.
#   - Three escalating nights with a climactic third night and a result
#     screen with a clear ending condition.
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
