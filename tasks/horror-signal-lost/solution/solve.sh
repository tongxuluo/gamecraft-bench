#!/bin/bash
# Reference solution for gamecraft-bench/horror-signal-lost.
#
# Drops a minimal but coherent radio-horror game into /workspace/game/:
#   - Flickering title screen with static effects and TUNE IN button.
#   - Radio station with frequency dial, signal locking, transcript display.
#   - Map with pin placement and triangulation mechanic.
#   - Battery gauge that depletes over time.
#   - Jamming events with escape mechanic.
#   - Two endings based on triangulation success vs battery death.
#
# Source files live next to this script under files/.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"

mkdir -p "$GAME"
cp -r "$SRC"/. "$GAME"/

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
