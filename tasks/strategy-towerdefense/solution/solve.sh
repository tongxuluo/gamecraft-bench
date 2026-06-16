#!/bin/bash
# Reference solution for gamecraft-bench/strategy-towerdefense.
#
# Drops a minimal but coherent tower-defense game into /workspace/game/:
#   - Title screen with Start (new game) and Load (continue from save).
#   - Stage select with 2 stages, each showing recommended level + enemy info.
#   - Battle: DP regen, hand of 3 unit types, drag-deploy on deployable cells,
#     fixed path with 3 enemy types in 3 waves, base life counter.
#   - Victory/Defeat result screens with retry + return to stage select.
#   - Save persists cleared stages to user://save.json (only on victory).
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
