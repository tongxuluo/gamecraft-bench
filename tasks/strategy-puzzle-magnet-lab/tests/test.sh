#!/bin/bash
set -u
mkdir -p /logs/verifier
PY="${PY:-python3}"
if ! command -v "$PY" >/dev/null 2>&1; then
    PY=python
fi
if ! "$PY" -c 'import gamecraft_bench.verifier' 2>/dev/null; then
    here="$(dirname "$(readlink -f "$0")")"
    candidate="$here"
    while [ "$candidate" != "/" ]; do
        if [ -d "$candidate/gamecraft_bench/verifier" ]; then
            export PYTHONPATH="$candidate:${PYTHONPATH:-}"
            break
        fi
        candidate="$(dirname "$candidate")"
    done
fi
PROJECT="${GAME_PROJECT_PATH:-/workspace/game}"
RUBRIC="${GAMECRAFT_BENCH_RUBRIC:-/tests/rubric.json}"
OUTPUT="/logs/verifier"
mkdir -p "$OUTPUT"
if resolved="$(readlink -f "$OUTPUT" 2>/dev/null)"; then
    OUTPUT="$resolved"
fi
set +e
"$PY" -m gamecraft_bench.verifier --project "$PROJECT" --rubric "$RUBRIC" --output "$OUTPUT"
rc=$?
set -e
if [ ! -f "$OUTPUT/reward.txt" ]; then
    mkdir -p "$OUTPUT"
    if [ -f "$OUTPUT/breakdown.json" ]; then
        "$PY" -c 'import json,sys; print("{:.6f}".format(float(json.load(open(sys.argv[1])).get("reward", 0.0))))' "$OUTPUT/breakdown.json" > "$OUTPUT/reward.txt" || echo 0 > "$OUTPUT/reward.txt"
    else
        echo 0 > "$OUTPUT/reward.txt"
    fi
fi
exit 0
