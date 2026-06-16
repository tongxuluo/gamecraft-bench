#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-word-spell.
#
# Drops a complete word-spell roguelike into /workspace/game/:
#   - Title screen
#   - Combat: 7 letter tiles, click to form words, submit to cast spell
#   - Damage = word length * multiplier (rare letters bonus)
#   - Enemy HP + attacks each turn
#   - Between fights: gain/upgrade letters
#   - 3 fights + boss, win/lose screens
#
# Source files live next to this script under files/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
