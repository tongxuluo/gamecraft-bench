#!/bin/bash
# Reference solution for gamecraft-bench/puzzle-portal-lab.
#
# Drops a complete 2D portal-placement puzzle game into /workspace/game/:
#   - Title screen with laboratory aesthetic and portal imagery.
#   - Chamber select showing progression through test chambers.
#   - Gameplay: 2D grid chambers with walls, player movement, portal placement,
#     laser redirection, weighted cubes, pressure plates, and locked exits.
#   - Momentum conservation through portals.
#   - 3+ test chambers with escalating complexity.
#   - Completion screen with next chamber option.
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
