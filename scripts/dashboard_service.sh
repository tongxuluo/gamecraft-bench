#!/bin/bash
# Start the GameCraft-Bench dashboard server.
# Usage: ./scripts/dashboard_service.sh [--jobs-root <path>] [--port <port>]
#
# Forward port <port> in VS Code (Ports panel) then open http://localhost:<port>/
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a; source "$REPO_ROOT/.env"; set +a
fi

PORT="${GAMECRAFT_BENCH_DASHBOARD_PORT:-${GAMECRAFT_BENCH_PLAY_PORT:-6090}}"
JOBS_ROOT="${GAMECRAFT_BENCH_JOBS_ROOT:-$REPO_ROOT/../gamecraft-bench-jobs}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --jobs-root) JOBS_ROOT="$2"; shift 2 ;;
        --port)      PORT="$2";      shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

source "$REPO_ROOT/.venv/bin/activate"
export PYTHONPATH="$REPO_ROOT"
export GAMECRAFT_BENCH_JOBS_ROOT="$JOBS_ROOT"

echo "GameCraft-Bench Dashboard  →  http://localhost:$PORT/"
echo "Jobs root: $JOBS_ROOT"
exec uvicorn gamecraft_bench.dashboard.server:app --host 0.0.0.0 --port "$PORT"
