#!/bin/bash
# Run Harbor with Kimi Code CLI via the Kimi coding API.
#
# Usage:
#   ./scripts/run_kimi_code.sh -p tasks/strategy-skirmish
#   ./scripts/run_kimi_code.sh -p tasks/strategy-skirmish --delete
#
# Requires KIMI_API_KEY or MOONSHOT_API_KEY in .env. Optional:
#   KIMI_MODEL= kimi/kimi-for-coding by default; must be provider/model.
#   KIMI_BASE_URL= override for Kimi provider endpoint.

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

if [ -z "${KIMI_API_KEY:-}" ] && [ -z "${MOONSHOT_API_KEY:-}" ]; then
    echo "error: KIMI_API_KEY or MOONSHOT_API_KEY not set (export it or put it in .env)" >&2
    exit 1
fi

: "${KIMI_MODEL:=kimi/kimi-for-coding}"
if [[ "$KIMI_MODEL" != */* ]]; then
    echo "error: KIMI_MODEL must use Harbor's provider/model format, e.g. kimi/kimi-for-coding" >&2
    exit 1
fi
model_provider="${KIMI_MODEL%%/*}"

# Default to --no-delete unless the caller passed an explicit choice.
delete_flag="--no-delete"
for arg in "$@"; do
    case "$arg" in
        --delete|--no-delete) delete_flag=""; break ;;
    esac
done

: "${GAMECRAFT_BENCH_JOBS_ROOT:=$REPO_ROOT/../gamecraft-bench-jobs}"
mkdir -p "$GAMECRAFT_BENCH_JOBS_ROOT"

agent_env_flags=()
if [ -n "${KIMI_API_KEY:-}" ]; then
    agent_env_flags+=(--ae "KIMI_API_KEY=$KIMI_API_KEY")
fi
if [ -n "${KIMI_BASE_URL:-}" ]; then
    agent_env_flags+=(--ae "KIMI_BASE_URL=$KIMI_BASE_URL" --ak "base_url=$KIMI_BASE_URL")
fi
if [ -n "${MOONSHOT_API_KEY:-}" ]; then
    agent_env_flags+=(--ae "MOONSHOT_API_KEY=$MOONSHOT_API_KEY")
fi
if [ -n "${MOONSHOT_BASE_URL:-}" ]; then
    agent_env_flags+=(--ae "MOONSHOT_BASE_URL=$MOONSHOT_BASE_URL")
    if [ "$model_provider" = "moonshot" ] && [ -z "${KIMI_BASE_URL:-}" ]; then
        agent_env_flags+=(--ak "base_url=$MOONSHOT_BASE_URL")
    fi
fi

exec harbor run \
    --environment-import-path gamecraft_bench.local_env:LocalSubprocessEnvironment \
    --agent-import-path gamecraft_bench.local_agents:LocalKimiCli \
    --jobs-dir "$GAMECRAFT_BENCH_JOBS_ROOT" \
    --model "$KIMI_MODEL" \
    --ak "thinking=true" \
    "${agent_env_flags[@]}" \
    ${delete_flag} \
    "$@"
