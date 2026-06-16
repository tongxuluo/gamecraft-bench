#!/bin/bash
# Verifier entrypoint for gamecraft-bench/strategy-ashen-spire.
#
# Defers to the shared replay+judge framework in `gamecraft_bench.verifier`. That
# module owns:
#   - running the build_check from /tests/rubric.json
#   - replaying each /workspace/game/demo_outputs/*.json under Xvfb
#   - calling the configured multimodal judge (GAMECRAFT_BENCH_JUDGE) per
#     (demo, requirement) pair
#   - aggregating max-over-demos and evaluating rubric.score_formula
#   - writing reward.txt (Harbor reads this), breakdown.json, ctrf.json,
#     judge_log.json, build.log, and per-demo replays/frames under
#     /logs/verifier/demos/<id>/
#
# Resolves the verifier package via $PYTHONPATH (set by scripts/run.sh) or
# the repo path on this host. In Docker mode the package would be installed
# into the image; LocalSubprocessEnvironment uses PYTHONPATH directly.
set -u

mkdir -p /logs/verifier

# ---- locate python + the gamecraft_bench package ------------------------------

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
    # Fall back: find the repo by walking up from this script's dir.
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

# ---- run the verifier ---------------------------------------------------

PROJECT="${GAME_PROJECT_PATH:-/workspace/game}"
RUBRIC="${GAMECRAFT_BENCH_RUBRIC:-/tests/rubric.json}"
OUTPUT="/logs/verifier"
mkdir -p "$OUTPUT"
if resolved="$(readlink -f "$OUTPUT" 2>/dev/null)"; then
    OUTPUT="$resolved"
fi

set +e
"$PY" -m gamecraft_bench.verifier \
    --project "$PROJECT" \
    --rubric  "$RUBRIC" \
    --output  "$OUTPUT"
rc=$?
set -e

# reward.txt is already written by the verifier CLI. Belt-and-suspenders:
# if it is missing for any reason, materialize a 0 so Harbor doesn't see a
# RewardFileNotFoundError.
if [ ! -f "$OUTPUT/reward.txt" ]; then
    mkdir -p "$OUTPUT"
    if [ -f "$OUTPUT/breakdown.json" ]; then
        "$PY" -c 'import json,sys; print("{:.6f}".format(float(json.load(open(sys.argv[1])).get("reward", 0.0))))' "$OUTPUT/breakdown.json" > "$OUTPUT/reward.txt" || echo 0 > "$OUTPUT/reward.txt"
    else
        echo 0 > "$OUTPUT/reward.txt"
    fi
fi

exit 0
