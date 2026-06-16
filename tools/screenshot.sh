#!/bin/bash
# screenshot.sh — wrapper that launches Xvfb + Godot to capture a PNG.
#
# Replaces the old `godot --headless --script screenshot.gd` pattern which
# fails because headless mode uses a dummy renderer with no viewport texture.
#
# This wrapper:
#   1. Picks a free X display (probes /proc/net/unix to avoid collisions)
#   2. Starts a temporary Xvfb on that display
#   3. Runs Godot with real rendering (opengl3) under that display
#   4. Tears down Xvfb on exit (trap ensures cleanup even on failure)
#
# Usage:
#   /workspace/tools/screenshot.sh --path /workspace/game \
#       --out /workspace/frame.png [--frames 60] [--scenario <id>]
#
# All flags are forwarded to screenshot.gd via Godot's user-args mechanism.
# --path is consumed by this script to set the Godot project path.
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SCREENSHOT_GD="${SCRIPT_DIR}/screenshot.gd"

# --- Parse --path from args (required), pass the rest through ---------------
PROJECT_PATH=""
FORWARD_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            PROJECT_PATH="$2"
            shift 2
            ;;
        --path=*)
            PROJECT_PATH="${1#--path=}"
            shift
            ;;
        *)
            FORWARD_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$PROJECT_PATH" ]]; then
    echo "screenshot.sh: --path <project> is required" >&2
    exit 2
fi

# --- Find a free display number ---------------------------------------------
_free_display() {
    local bound
    bound=$(awk '$NF ~ /^@\/tmp\/\.X11-unix\/X[0-9]+$/ {
        sub(/.*X/, "", $NF); print $NF
    }' /proc/net/unix 2>/dev/null | sort -n)

    for n in $(seq 99 250); do
        if ! echo "$bound" | grep -qx "$n" && \
           [[ ! -e "/tmp/.X11-unix/X${n}" ]]; then
            echo "$n"
            return
        fi
    done
    echo "screenshot.sh: no free display in :99..:250" >&2
    exit 3
}

DISPLAY_N=$(_free_display)
export DISPLAY=":${DISPLAY_N}"

# --- Start Xvfb, ensure cleanup on exit ------------------------------------
Xvfb "$DISPLAY" -screen 0 1280x720x24 -nolisten tcp &>/dev/null &
XVFB_PID=$!

cleanup() {
    kill "$XVFB_PID" 2>/dev/null || true
    wait "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Wait for Xvfb socket to appear (up to 3s)
for _i in $(seq 1 60); do
    [[ -e "/tmp/.X11-unix/X${DISPLAY_N}" ]] && break
    # Also check if Xvfb died early
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        echo "screenshot.sh: Xvfb on :${DISPLAY_N} died early" >&2
        exit 3
    fi
    sleep 0.05
done

if [[ ! -e "/tmp/.X11-unix/X${DISPLAY_N}" ]]; then
    echo "screenshot.sh: Xvfb on :${DISPLAY_N} did not start in 3s" >&2
    exit 3
fi

# --- Run Godot with real rendering ------------------------------------------
godot \
    --path "$PROJECT_PATH" \
    --display-driver x11 \
    --rendering-driver opengl3 \
    --audio-driver Dummy \
    --resolution 1280x720 \
    --script "$SCREENSHOT_GD" \
    -- "${FORWARD_ARGS[@]}"
