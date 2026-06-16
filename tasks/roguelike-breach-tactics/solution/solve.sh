#!/bin/bash
# Oracle solution for gamecraft-bench/roguelike-breach-tactics.
#
# Drops a complete Into-the-Breach-style tactics game into /workspace/game/:
#   - Title screen
#   - 5x5 grid battlefield with buildings to protect
#   - 3 mech units (punch, artillery, shield) with click-to-select/move/attack
#   - Enemies show intent arrows before executing
#   - Turn-based: player moves, then enemies execute
#   - Buildings have HP; lose if all destroyed
#   - Win after surviving 4 turns
#   - Between-mission upgrade choice
#
# PURE PROGRAMMATIC (ColorRect/Label/StyleBox). No asset files needed.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
