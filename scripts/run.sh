#!/bin/bash
# Run a Harbor job using the local subprocess environment.
#
# Examples:
#   ./scripts/run.sh -p tasks/simple-pong --agent oracle
#   ./scripts/run.sh -p tasks/simple-pong --agent oracle --delete   # force cleanup
#
# This script deliberately stays simple:
#   1. cd to repo root
#   2. activate .venv if it exists
#   3. load .env if it exists
#   4. set PYTHONPATH so `import gamecraft_bench` works
#   5. call `harbor run` with our custom env class
#
# Sandbox retention: defaults to --no-delete so the agent's generated
# project survives under jobs/<job>/<trial>/sandbox for inspection.
# Pass --delete explicitly to opt in to Harbor's normal cleanup.

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

# Default to --no-delete unless the caller passed an explicit choice.
delete_flag="--no-delete"
for arg in "$@"; do
    case "$arg" in
        --delete|--no-delete) delete_flag=""; break ;;
    esac
done

: "${GAMECRAFT_BENCH_JOBS_ROOT:=$REPO_ROOT/../gamecraft-bench-jobs}"
mkdir -p "$GAMECRAFT_BENCH_JOBS_ROOT"

exec harbor run \
    --environment-import-path gamecraft_bench.local_env:LocalSubprocessEnvironment \
    --jobs-dir "$GAMECRAFT_BENCH_JOBS_ROOT" \
    ${delete_flag} \
    "$@"
