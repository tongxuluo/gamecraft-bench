#!/bin/bash
# Reference solution for gamecraft-bench/cardgame-autobattler.
#
# Drops a complete auto-chess style autobattler into /workspace/game/:
#   - Title screen with tavern theme and "Find Match" button.
#   - Shop/Draft phase: buy creatures from a shop of 5, place on 4x2 board.
#   - Auto-combat: creatures fight automatically with animations.
#   - Tribal synergies: Beast, Undead, Mech, Dragon, Elemental.
#   - Gold economy with interest, reroll, level up.
#   - 8 rounds of escalating difficulty, HP-based elimination.
#   - 3 demo traces: title flow, draft+battle round, late-game round.
#
# Source files live next to this script under files/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
