#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-slot-fortune.
#
# Drops a complete slot-machine roguelike into /workspace/game/:
#   - Title screen with stylized slot machine art.
#   - 3x3 slot grid that spins with symbol interactions.
#   - 12 symbol types with adjacency bonuses and synergies.
#   - Shop between spins to add/remove symbols.
#   - Escalating rent each round; lose if gold < rent.
#   - Deterministic scenario support for demo traces.
#
# Source files live next to this script under files/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
