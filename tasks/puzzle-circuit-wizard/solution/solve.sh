#!/bin/bash
# Reference solution for gamecraft-bench/puzzle-circuit-wizard.
#
# Drops a complete logic-circuit puzzle game into /workspace/game/:
#   - Title screen with electronic workshop theme.
#   - Grid-based puzzle board with input terminals (left) and output terminals (right).
#   - 4 gate types: AND, OR, NOT, XOR placed via toolbox (keys 1-4).
#   - Wires auto-connect between adjacent gates.
#   - Signal propagation with visual feedback (green=correct, red=incorrect).
#   - 3 levels of escalating complexity.
#   - Test button evaluates circuit, clear button resets board.
#
# Source files live next to this script under files/.
# solve.sh just copies them into /workspace/game/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
