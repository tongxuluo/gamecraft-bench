#!/bin/bash
# Oracle solution for cardgame-inscription-dark.
#
# Drops a complete Inscryption-style dark card battle game into /workspace/game/:
#   - Title screen (dark cabin atmosphere, flickering candle effect)
#   - Overworld map with branching paths (combat/event/shop nodes)
#   - 4-lane card battle with sacrifice mechanic, sigils, damage scale
#   - Event encounters between battles
#   - 2 full battles + 1 event minimum
#
# Source files live next to this script under files/. solve.sh copies them.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
