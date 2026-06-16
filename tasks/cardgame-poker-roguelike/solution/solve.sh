#!/bin/bash
# Reference solution for gamecraft-bench/cardgame-poker-roguelike.
#
# Drops a minimal but coherent Balatro-style poker roguelike into /workspace/game/:
#   - Title screen with casino-noir aesthetic.
#   - Hand of 8 cards, select up to 5 to form poker hands.
#   - Scoring: base chips x multiplier, modified by Jokers.
#   - 3 blinds (Small, Big, Boss) with escalating targets.
#   - Shop between rounds: buy jokers, remove cards.
#   - Gold economy, win after 3 blinds, lose if score < target.
#
# Source files live next to this script under files/. solve.sh copies them.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
