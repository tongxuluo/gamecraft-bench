#!/bin/bash
# Reference solution for gamecraft-bench/horror-dollhouse.
#
# Drops a minimal but coherent horror puzzle game into /workspace/game/:
#   - Title screen with eerie atmosphere and a Begin button.
#   - Split-view gameplay: left half is a top-down miniature dollhouse,
#     right half is the same room rendered at full size in side-view.
#   - Click objects in the dollhouse to manipulate them; the same action
#     mirrors instantly in the full-size house.
#   - Three rooms (parlor, kitchen, attic) unlock progressively.
#   - Sanity meter that decays over time.
#   - Win state when the player reaches the attic and uncovers the truth.
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
