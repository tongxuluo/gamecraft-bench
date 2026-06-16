#!/bin/bash
set -u

DEFAULT_PROJECT="/workspace/game"
DEFAULT_RUBRIC="/tests/rubric.json"
DEFAULT_OUTPUT="/logs/verifier"

mkdir -p "$DEFAULT_OUTPUT"
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
PROJECT="${GAME_PROJECT_PATH:-$DEFAULT_PROJECT}"
RUBRIC="${GAMECRAFT_BENCH_RUBRIC:-$DEFAULT_RUBRIC}"
OUTPUT="${GAMECRAFT_BENCH_VERIFIER_OUTPUT:-$DEFAULT_OUTPUT}"
mkdir -p "$OUTPUT"
set +e
"$PY" -m gamecraft_bench.verifier --project "$PROJECT" --rubric "$RUBRIC" --output "$OUTPUT"
rc=$?
set -e
if [ ! -f "$OUTPUT/reward.txt" ]; then
    echo 0 > "$OUTPUT/reward.txt"
fi
exit 0
