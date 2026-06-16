#!/bin/bash
# Reference solution for gamecraft-bench/cardgame-gwent-war.
#
# Drops a complete Gwent-style row-based card battle game into /workspace/game/:
#   - Title screen with faction selection (Northern Realms, Monsters)
#   - Battlefield: 3 rows per side (melee/ranged/siege), hand of cards
#   - Play cards from hand to rows, special abilities (weather, hero, spy)
#   - Pass mechanic for bluffing, best-of-3 rounds
#   - AI opponent with strategic card play
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
