#!/bin/bash
# Reference solution for gamecraft-bench/horror-floor-13.
#
# Drops a minimal but coherent elevator horror game into /workspace/game/:
#   - Art-deco title screen with floor panel and a CLOSE DOORS button.
#   - Elevator interior with floor selector, door animations, passenger
#     silhouettes, and a corruption gauge.
#   - Passengers request floors; delivering to wrong floors adds corruption.
#   - Floor vignettes with unique horror themes per floor.
#   - Floor 13 ending with two outcomes based on corruption level.
#
# Source files live next to this script under files/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
