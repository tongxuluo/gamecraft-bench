#!/bin/bash
# Reference solution for gamecraft-bench/cardgame-spire-descent.
#
# Drops a complete deckbuilder roguelike into /workspace/game/:
#   - Title screen with New Run button.
#   - Class select (Warrior, Rogue, Mage) with unique starting decks.
#   - Map screen with branching paths (combat/shop/rest nodes).
#   - Card combat: draw hand, spend energy, play attack/block cards.
#   - Enemy intent display, turn-based combat with HP persistence.
#   - Card draft after combat (pick 1 of 3).
#   - Boss fight after 3+ regular fights.
#   - Win/lose screens.
#
# Source files live next to this script under files/. solve.sh copies them
# into /workspace/game/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
