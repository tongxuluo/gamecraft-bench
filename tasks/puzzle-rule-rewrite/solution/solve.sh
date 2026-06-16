#!/bin/bash
# Oracle solution for puzzle-rule-rewrite.
#
# Drops a complete Baba-Is-You-style word-block puzzle game into /workspace/game/:
#   - Title screen with Start button
#   - Level select with 5 levels of escalating complexity
#   - Grid-based word-block pushing with rule formation
#   - Properties: STOP, WIN, PUSH, YOU, DEFEAT
#   - Undo (Z key) and Reset (R key)
#   - Win condition via touching WIN-tagged objects
#   - YOU reassignment between noun types
#
# All visuals are programmatic (ColorRect/Label/StyleBox). No external assets.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
