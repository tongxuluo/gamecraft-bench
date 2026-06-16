#!/bin/bash
# Verifier entrypoint for gamecraft-bench/openworld-stealth.
#
# Defers to the shared replay+judge framework in `gamecraft_bench.verifier`.

set -u

mkdir -p /logs/verifier

PY="${PY:-python3}"
if ! command -v "$PY" >/dev/null 2>&1; then
    if command -v python >/dev/null 2>&1; then
        PY=python
    else
        echo "no python interpreter found" >&2
        echo 0 > /logs/verifier/reward.txt
        exit 1
    fi
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

set +e
"$PY" -m gamecraft_bench.verifier \
    --project "$PROJECT" \
    --rubric  "$RUBRIC" \
    --output  "$OUTPUT"
rc=$?
set -e

if [ ! -f "$OUTPUT/reward.txt" ]; then
    echo 0 > "$OUTPUT/reward.txt"
fi

exit 0
