#!/bin/bash
# Reference solution for gamecraft-bench/horror-tape-archive.
#
# Drops a self-contained Godot 4 horror micro-game into /workspace/game/:
#   - VHS-styled title screen with tracking lines and a tape-deck PLAY button.
#   - Tape select shelf with 3 tapes per night across 3 nights.
#   - Tape player UI: a CRT monitor that plays a procedural surveillance
#     loop (hallway / lab / storage), with PLAY/PAUSE on SPACE, scrubbing
#     on LEFT/RIGHT (and click-to-seek on the timeline), and a MARK
#     ANOMALY button that scores when the playhead sits inside an
#     anomaly window.
#   - Sanity meter drains as anomalies are witnessed and on false marks.
#   - Night results screen with retry / back-to-shelf.
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
