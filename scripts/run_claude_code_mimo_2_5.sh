#!/bin/bash
# Run Harbor with claude-code agent + Claude Opus 4.7 via tokenrun.org's
# Anthropic-compatible endpoint.
#
# Usage:
#   ./scripts/run_claude_code_mimo_2_5.sh --ak reasoning_effort=high -p tasks/strategy-skirmish
#   ./scripts/run_claude_code_mimo_2_5.sh --ak reasoning_effort=high -p tasks/strategy-skirmish --delete
#
# Why a wrapper rather than reusing run.sh:
#   1. Pin the agent to LocalClaudeCode (skips Harbor's region-blocked
#      curl https://claude.ai/install.sh; we already have `claude` on PATH).
#   2. Hard-code the tokenrun.org Anthropic-compatible base URL + token
#      and forward them into the agent process via `--ae`. The agent runs
#      in a separate subprocess, so host-level exports alone don't reach it.
#   3. Pin the model so the model alias logic in claude_code.py routes
#      every model alias (sonnet/opus/haiku) to opus 4.7 over the proxy.

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

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    echo "error: ANTHROPIC_AUTH_TOKEN not set (export it or put it in .env)" >&2
    exit 1
fi
: "${ANTHROPIC_BASE_URL:=https://api.anthropic.com}"
export ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL

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

exec harbor run \
    --environment-import-path gamecraft_bench.local_env:LocalSubprocessEnvironment \
    --agent-import-path gamecraft_bench.local_agents:LocalClaudeCode \
    --jobs-dir "$GAMECRAFT_BENCH_JOBS_ROOT" \
    --model mimo-v2.5-pro \
    --ae "ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN" \
    --ae "ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL" \
    ${delete_flag} \
    "$@"
