#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-dice-throne.
#
# Drops a complete dice-rolling roguelike into /workspace/game/:
#   - Title screen
#   - Combat: roll 5 dice, lock/reroll up to 2 times, resolve abilities
#   - Enemy rolls visible dice, resolves after player
#   - Between fights: equipment selection modifies dice faces
#   - 3 fights + boss encounter
#   - Win/lose screens
#
# Source files live next to this script under files/. solve.sh copies them.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
