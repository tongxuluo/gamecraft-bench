#!/bin/bash
# Run Harbor with codex agent via OpenAI-compatible endpoint.
#
# Usage:
#   ./scripts/run_codex_gpt_5_5.sh --ak reasoning_effort=high -p tasks/strategy-skirmish
#   ./scripts/run_codex_gpt_5_5.sh --ak reasoning_effort=high -p tasks/strategy-skirmish --delete
#
# Requires OPENAI_API_KEY (or OPENAI_BASE_URL for proxies) in .env.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ -f ".venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    source ".venv/bin/activate"
fi

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
fi

export PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}"

if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "error: OPENAI_API_KEY not set (export it or put it in .env)" >&2
    exit 1
fi
export OPENAI_API_KEY

# Default to --no-delete unless the caller passed an explicit choice.
delete_flag="--no-delete"
for arg in "$@"; do
    case "$arg" in
        --delete|--no-delete) delete_flag=""; break ;;
    esac
done

: "${GAMECRAFT_BENCH_JOBS_ROOT:=$REPO_ROOT/../gamecraft-bench-jobs}"
mkdir -p "$GAMECRAFT_BENCH_JOBS_ROOT"

reasoning_effort_set=0
for arg in "$@"; do
    case "$arg" in
        reasoning_effort=?*|--ak=reasoning_effort=?*) reasoning_effort_set=1 ;;
    esac
done
if [ "$reasoning_effort_set" -ne 1 ]; then
    echo "error: reasoning_effort must be set via Harbor args, e.g. --ak reasoning_effort=high" >&2
    exit 1
fi

# Forward OPENAI_BASE_URL if set (for proxy routing).
base_url_flags=()
if [ -n "${OPENAI_BASE_URL:-}" ]; then
    base_url_flags=(--ae "OPENAI_BASE_URL=$OPENAI_BASE_URL")
fi

exec harbor run \
    --environment-import-path gamecraft_bench.local_env:LocalSubprocessEnvironment \
    --agent-import-path gamecraft_bench.local_agents:LocalCodex \
    --jobs-dir "$GAMECRAFT_BENCH_JOBS_ROOT" \
    --model gpt-5.5 \
    --ae "OPENAI_API_KEY=$OPENAI_API_KEY" \
    "${base_url_flags[@]}" \
    ${delete_flag} \
    "$@"
