"""Replay a demo trace against a Godot project and record the screen.

Pipeline per trace:

1. Start Xvfb on a free display sized to the viewport.
2. Launch Godot bound to that display (with ``-- --scenario <id>`` if
   the trace specified one), wait for its window, and focus it.
3. Start ffmpeg x11grab on the same display, recording to mp4.
4. Step through ``trace.events`` one by one. For each event, sleep
   until its ``frame / fps`` second offset and then post the input via
   xdotool.
5. After the last event, hold until ``trace.duration_frames``.
6. Tear everything down: graceful stop on ffmpeg (so the mp4 muxes
   correctly), then Godot, then Xvfb.

The result is a deterministic mp4 the judge can score.

This module is intentionally process-driven (Xvfb / xdotool / ffmpeg /
godot are all subprocesses). It does not try to talk X11 directly.
"""

from __future__ import annotations

import contextlib
import dataclasses
import fcntl
import json
import os
import random
import signal
import shutil
import subprocess
import time
from pathlib import Path

from .. import config as cfg

_DEFAULT_GODOT_WINDOW_TIMEOUT_SECONDS = 45.0


# Supported game-control keycodes. This is intentionally not a text-entry
# surface: traces should describe gameplay inputs, not arbitrary typing.
_KEYCODES: dict[str, str] = {
    "ESCAPE": "Escape",
    "ENTER": "Return",
    "SPACE": "space",
    "TAB": "Tab",
    "BACKSPACE": "BackSpace",
    "DELETE": "Delete",
    "UP": "Up",
    "DOWN": "Down",
    "LEFT": "Left",
    "RIGHT": "Right",
    "SHIFT": "Shift_L",
    "CTRL": "Control_L",
    "ALT": "Alt_L",
    **{c: c.lower() for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"},
    **{str(d): str(d) for d in range(10)},
}


class ReplayError(RuntimeError):
    """Raised when the replay pipeline fails to start, run, or finish."""


@dataclasses.dataclass(frozen=True)
class ReplayResult:
    output_mp4: Path
    duration_seconds: float
    godot_returncode: int


def replay_trace(
    *,
    project_dir: Path,
    trace_path: Path,
    output_mp4: Path,
    viewport: tuple[int, int] = (1280, 720),
    record_size: tuple[int, int] | None = (854, 480),
    fps: int = 30,
    godot_bin: str | None = None,
    settle_seconds: float = 1.5,
    log_dir: Path | None = None,
    max_replay_seconds: float = 90.0,
) -> ReplayResult:
    """Run a single trace; emit an mp4 + per-process logs.

    ``viewport`` is the logical window/Xvfb size — trace pixel
    coordinates are in this frame. ``record_size`` is the resolution the
    mp4 is encoded at. Defaulting to 854x480 (16:9 480p) keeps replays
    small enough to feed straight into multimodal judges without a
    second transcode pass; pass ``None`` to record at native viewport.

    ``log_dir``, if provided, gets ``godot.log``, ``ffmpeg.log`` and
    ``xvfb.log``. Useful when something fails inside one of the
    subprocesses.

    ``max_replay_seconds`` is a hard wall-clock cap covering the entire
    event-loop + hold phase. The trace's own ``duration_frames`` (and
    any ``frame`` offsets) are clamped to this so a malformed trace
    cannot stall the verifier indefinitely. When the cap fires we raise
    ``ReplayError`` and let the caller mark this demo failed and move
    on; the ``finally`` block tears down all subprocesses cleanly.
    """
    project_dir = Path(project_dir).resolve()
    trace_path = Path(trace_path).resolve()
    output_mp4 = Path(output_mp4).resolve()
    output_mp4.parent.mkdir(parents=True, exist_ok=True)

    if log_dir is not None:
        log_dir = Path(log_dir).resolve()
        log_dir.mkdir(parents=True, exist_ok=True)

    godot = godot_bin or cfg.GODOT_BIN
    if not godot:
        raise ReplayError("no Godot binary configured (set GAMECRAFT_BENCH_GODOT_BIN)")
    for tool in ("Xvfb", "xdotool", "ffmpeg"):
        if shutil.which(tool) is None:
            raise ReplayError(f"required tool not on PATH: {tool}")

    trace = json.loads(trace_path.read_text())
    events = list(trace.get("events", []))
    duration_frames = int(trace.get("duration_frames", 0))
    scenario = trace.get("scenario")
    replay_frames = max(
        duration_frames,
        *(int(ev["frame"]) for ev in events),
    ) if events else duration_frames
    if replay_frames < 0:
        raise ReplayError(f"negative trace duration/frame in {trace_path}")
    trace_seconds = replay_frames / fps
    if trace_seconds > max_replay_seconds:
        raise ReplayError(
            f"trace lasts {trace_seconds:.2f}s, exceeding "
            f"max_replay_seconds={max_replay_seconds}s"
        )

    w, h = viewport

    procs: list[subprocess.Popen] = []
    log_handles: list = []

    def _open_log(name: str):
        if log_dir is None:
            return subprocess.DEVNULL
        h = open(log_dir / name, "wb")
        log_handles.append(h)
        return h

    try:
        # 1. Xvfb. Pick a free display, retry on collision: concurrent
        #    verifiers can race on the abstract socket @/tmp/.X11-unix/Xn
        #    even when each has a private /tmp, because the abstract
        #    namespace lives in the (shared) network namespace.
        xvfb_log = _open_log("xvfb.log")
        xvfb, display_n = _start_xvfb(xvfb_log, viewport=(w, h))
        display = f":{display_n}"
        procs.append(xvfb)

        env = {**os.environ, "DISPLAY": display, "GODOT_SILENCE_ROOT_WARNING": "1",
               "LP_NUM_THREADS": "1"}

        # 2. Godot. Forwarded args (after `--`) are read by the project
        #    via OS.get_cmdline_user_args(); we use this for --scenario.
        godot_cmd: list[str] = [
            godot,
            "--path", str(project_dir),
            "--display-driver", "x11",
            "--rendering-driver", "opengl3",
            "--audio-driver", "Dummy",
            "--resolution", f"{w}x{h}",
            "--single-window",
        ]
        if scenario:
            godot_cmd += ["--", "--scenario", str(scenario)]
        godot_log = _open_log("godot.log")
        godot_proc = subprocess.Popen(
            godot_cmd, env=env, stdout=godot_log, stderr=godot_log,
            preexec_fn=lambda: signal.signal(signal.SIGPIPE, signal.SIG_IGN),
        )
        procs.append(godot_proc)

        # Give Godot a moment to map a window before we start sending input.
        time.sleep(settle_seconds)
        if godot_proc.poll() is not None:
            raise ReplayError(
                f"godot exited early with code {godot_proc.returncode} "
                f"(see {log_dir/'godot.log' if log_dir else 'godot.log'})"
            )
        window_id = _find_godot_window(
            env,
            pid=godot_proc.pid,
            timeout=_godot_window_timeout_seconds(),
        )

        # Ensure the Godot window has X11 input focus. Without a window
        # manager, xdotool's --window flag on key events silently fails
        # because there is no WM to broker focus. XSetInputFocus (what
        # windowfocus does) works without a WM and makes subsequent
        # keydown/keyup/key events land in the Godot window.
        _xdotool(env, "windowfocus", "--sync", window_id)

        # 3. ffmpeg x11grab. Start recording only after the game window exists
        #    and is focused so trace frame 0 lines up with frame 0 of the
        #    recorded gameplay rather than with a black Xvfb startup screen.
        ffmpeg_log_path = log_dir / "ffmpeg.log" if log_dir is not None else None
        ffmpeg_log = _open_log("ffmpeg.log")
        ffmpeg_cmd = [
            "ffmpeg", "-y",
            "-f", "x11grab",
            "-framerate", str(fps),
            "-video_size", f"{w}x{h}",
            "-i", display,
        ]
        if record_size is not None and record_size != viewport:
            rw, rh = record_size
            ffmpeg_cmd += ["-vf", f"scale={rw}:{rh}:flags=lanczos"]
        ffmpeg_record_seconds = trace_seconds + 2.0
        ffmpeg_cmd += [
            "-t", f"{ffmpeg_record_seconds:.3f}",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-pix_fmt", "yuv420p",
            str(output_mp4),
        ]
        ffmpeg = subprocess.Popen(
            ffmpeg_cmd, env=env,
            stdin=subprocess.PIPE, stdout=ffmpeg_log, stderr=ffmpeg_log,
        )
        procs.append(ffmpeg)
        _wait_for_ffmpeg_capture(ffmpeg, ffmpeg_log_path, timeout=15.0)

        # 4. Walk events on a real-time clock anchored at recording start.
        #    A wall-clock deadline (max_replay_seconds) bounds the whole
        #    event loop + hold so a trace claiming a huge duration_frames
        #    or with an event at a far-future frame cannot stall us.
        t0 = time.time()
        deadline = t0 + max_replay_seconds
        last_frame = 0
        for ev in events:
            frame = int(ev["frame"])
            target = min(t0 + frame / fps, deadline)
            if not _sleep_until(target, deadline=deadline):
                raise ReplayError(
                    f"replay exceeded max_replay_seconds={max_replay_seconds}s "
                    f"while waiting for event at frame {frame}"
                )
            _post_event(ev, env, window_id=window_id)
            last_frame = max(last_frame, frame)

        # 5. Hold for the rest of the requested duration (clamped).
        end_target = min(t0 + replay_frames / fps, deadline)
        _sleep_until(end_target, deadline=deadline)
        elapsed = time.time() - t0

        # 6. Stop ffmpeg gracefully so the mp4 mux finalises.
        with contextlib.suppress(Exception):
            assert ffmpeg.stdin is not None
            ffmpeg.stdin.write(b"q\n")
            ffmpeg.stdin.flush()
        try:
            ffmpeg.wait(timeout=10)
        except subprocess.TimeoutExpired:
            ffmpeg.terminate()
            ffmpeg.wait(timeout=5)

        # 7. Stop Godot.
        godot_rc = _stop(godot_proc)

        if not output_mp4.exists() or output_mp4.stat().st_size == 0:
            raise ReplayError(
                f"recording is empty: {output_mp4}. See ffmpeg/godot logs."
            )

        return ReplayResult(
            output_mp4=output_mp4,
            # Downstream sampling should use the trace's logical timeline,
            # not wall-clock slippage from Godot startup, xdotool, or encoder
            # stalls on a loaded host.
            duration_seconds=trace_seconds,
            godot_returncode=godot_rc,
        )

    finally:
        for p in reversed(procs):
            if p.poll() is None:
                _stop(p)
        for h in log_handles:
            with contextlib.suppress(Exception):
                h.close()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _bound_x11_displays() -> set[int]:
    """Return display numbers already bound on this host.

    Checks both the filesystem socket ``/tmp/.X11-unix/X<n>`` and the
    abstract socket ``@/tmp/.X11-unix/X<n>``. Filesystem sockets live in
    the mount namespace (per-trial private /tmp under the sandbox), but
    Xvfb also binds an abstract name in the network namespace, which we
    do not unshare — so concurrent trials in different sandboxes can
    still collide on the abstract socket alone.
    """
    bound: set[int] = set()
    sock_dir = Path("/tmp/.X11-unix")
    if sock_dir.is_dir():
        for entry in sock_dir.iterdir():
            name = entry.name
            if name.startswith("X") and name[1:].isdigit():
                bound.add(int(name[1:]))
    try:
        for line in Path("/proc/net/unix").read_text().splitlines()[1:]:
            parts = line.split()
            if len(parts) < 8:
                continue
            path = parts[-1]
            # Abstract sockets are shown with a leading '@'.
            if path.startswith("@/tmp/.X11-unix/X"):
                tail = path[len("@/tmp/.X11-unix/X"):]
                if tail.isdigit():
                    bound.add(int(tail))
    except OSError:
        pass
    return bound


def _free_display(
    *, start: int = 99, end: int = 199, skip: set[int] | None = None
) -> int:
    """Pick a display number not currently bound by any X server.
    ``skip`` lets the caller exclude numbers it has already tried this
    invocation (Xvfb can lose the race between probe and bind)."""
    bound = _bound_x11_displays()
    skip = skip or set()
    for n in range(start, end):
        if n in bound or n in skip:
            continue
        return n
    raise ReplayError(f"no free X display in :{start}..:{end - 1}")


def _wait_for_xvfb(
    proc: subprocess.Popen, display_n: int, *, timeout: float
) -> None:
    """Wait for this Xvfb process to bind its X11 UNIX socket.

    Do not use xdotool as the readiness signal here. Under load it can
    hang while connecting, and in the old scan-then-start flow it could
    accidentally connect to another verifier's display. The caller now
    selects a high display under a process lock, so seeing that display
    appear in /proc/net/unix while this proc is alive is enough.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        if proc.poll() is not None:
            raise ReplayError(
                f"Xvfb on :{display_n} exited early with code {proc.returncode}"
            )
        if _x_display_bound(display_n):
            return
        time.sleep(0.05)
    raise ReplayError(f"Xvfb on :{display_n} did not bind in {timeout}s")


def _x_display_bound(display_n: int) -> bool:
    suffix = f"/tmp/.X11-unix/X{display_n}"
    try:
        for line in Path("/proc/net/unix").read_text().splitlines()[1:]:
            parts = line.split()
            if len(parts) < 8:
                continue
            path = parts[-1]
            if path == suffix or path == f"@{suffix}":
                return True
    except OSError:
        pass
    return False


def _start_xvfb(
    log,
    *,
    viewport: tuple[int, int],
    timeout: float = 5.0,
    max_attempts: int = 5,
) -> tuple[subprocess.Popen, int]:
    """Launch Xvfb and return ``(proc, display_n)``.

    Serialize display selection across local verifier processes and start
    Xvfb on an explicit high display number. The lock removes the
    scan-then-start race; the high range avoids colliding with desktop
    displays and other older verifier runs that default to ``:99``.
    """
    w, h = viewport
    last_err: ReplayError | None = None
    display_start = int(cfg._env("GAMECRAFT_BENCH_XVFB_DISPLAY_START", "200") or "200")
    display_end = int(cfg._env("GAMECRAFT_BENCH_XVFB_DISPLAY_END", "500") or "500")
    for _ in range(max_attempts):
        proc: subprocess.Popen | None = None
        display_n = -1
        try:
            with open("/tmp/gamecraft-bench-xvfb-display.lock", "w") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                display_n = _free_display_randomized(
                    start=display_start,
                    end=display_end,
                )
                proc = subprocess.Popen(
                    ["Xvfb", f":{display_n}", "-screen", "0",
                     f"{w}x{h}x24", "-nolisten", "tcp"],
                    stdout=log, stderr=log,
                )
                _wait_for_xvfb(proc, display_n, timeout=timeout)
                return proc, display_n
        except ReplayError as exc:
            last_err = exc
            if proc is not None:
                with contextlib.suppress(Exception):
                    _stop(proc)
    raise last_err or ReplayError("Xvfb failed to start after retries")


def _free_display_randomized(*, start: int, end: int) -> int:
    bound = _bound_x11_displays()
    candidates = [n for n in range(start, end) if n not in bound]
    if not candidates:
        raise ReplayError(f"no free X display in :{start}..:{end - 1}")
    rng = random.Random(f"{os.getpid()}:{time.time_ns()}")
    return candidates[rng.randrange(len(candidates))]


def _sleep_until(target: float, *, deadline: float | None = None) -> bool:
    """Sleep until ``target``. Returns True on success, False if ``deadline``
    fires first (target == deadline counts as success). The 10ms tick keeps
    us responsive to the deadline without busy-looping."""
    while True:
        now = time.time()
        if now >= target:
            return True
        if deadline is not None and now >= deadline:
            return False
        time.sleep(min(target - now, 0.01))


def _wait_for_ffmpeg_capture(
    proc: subprocess.Popen,
    log_path: Path | None,
    *,
    timeout: float,
) -> None:
    """Wait until ffmpeg has captured at least one X11 frame.

    Starting the process is not enough: under CPU load, ffmpeg can spend
    several seconds probing/configuring before x11grab emits its first
    frame. The replay clock must start after that point, or early trace
    input happens before the recording timeline exists.
    """
    if log_path is None:
        time.sleep(0.2)
        return

    deadline = time.time() + timeout
    last_tail = b""
    while time.time() < deadline:
        if proc.poll() is not None:
            detail = _decode_log_tail(last_tail)
            raise ReplayError(
                f"ffmpeg exited before recording started with code "
                f"{proc.returncode}{detail}"
            )
        try:
            data = log_path.read_bytes()
        except OSError:
            data = b""
        if b"frame=" in data:
            return
        last_tail = data[-1200:]
        time.sleep(0.05)

    detail = _decode_log_tail(last_tail)
    raise ReplayError(f"ffmpeg did not start recording within {timeout}s{detail}")


def _decode_log_tail(data: bytes) -> str:
    if not data:
        return ""
    text = data.decode(errors="replace").strip()
    return f"; log tail: {text}" if text else ""


def _godot_window_timeout_seconds() -> float:
    raw = (cfg._env("GAMECRAFT_BENCH_GODOT_WINDOW_TIMEOUT_SECONDS", "") or "").strip()
    if not raw:
        return _DEFAULT_GODOT_WINDOW_TIMEOUT_SECONDS
    try:
        value = float(raw)
    except ValueError:
        return _DEFAULT_GODOT_WINDOW_TIMEOUT_SECONDS
    return value if value > 0 else _DEFAULT_GODOT_WINDOW_TIMEOUT_SECONDS


def _stop(proc: subprocess.Popen, *, term_timeout: float = 5.0) -> int:
    if proc.poll() is not None:
        return proc.returncode
    proc.terminate()
    try:
        return proc.wait(timeout=term_timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        return proc.wait(timeout=2.0)


def _find_godot_window(env: dict, *, pid: int, timeout: float) -> str:
    deadline = time.time() + timeout
    last_err = ""
    while time.time() < deadline:
        try:
            r = subprocess.run(
                ["xdotool", "search", "--onlyvisible", "--pid", str(pid)],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=0.5,
            )
        except subprocess.TimeoutExpired:
            last_err = "xdotool search timed out"
        else:
            if r.returncode == 0:
                ids = [line.strip() for line in r.stdout.decode().splitlines() if line.strip()]
                if ids:
                    return ids[-1]
            last_err = (r.stderr or b"").decode(errors="replace").strip()

        try:
            r = subprocess.run(
                ["xdotool", "search", "--onlyvisible", "--name", ".*"],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=0.5,
            )
        except subprocess.TimeoutExpired:
            last_err = "xdotool window search timed out"
        else:
            if r.returncode == 0:
                ids = [line.strip() for line in r.stdout.decode().splitlines() if line.strip()]
                if ids:
                    win = ids[-1]
                    _xdotool(env, "windowactivate", "--sync", win)
                    return win
            last_err = (r.stderr or b"").decode(errors="replace").strip()
        time.sleep(0.05)
    detail = f": {last_err}" if last_err else ""
    raise ReplayError(f"could not find Godot X window in {timeout}s{detail}")


def _post_event(ev: dict, env: dict, *, window_id: str) -> None:
    typ = ev["type"]
    if typ == "wait":
        return
    if typ == "mouse_move":
        _xdotool(env, "mousemove", "--window", window_id,
                 str(int(ev["x"])), str(int(ev["y"])))
        return
    if typ == "mouse_click":
        button = _mouse_button(ev.get("button", "left"))
        # Single xdotool invocation chains move + down + up so they
        # land in tight succession (avoids extra context switches).
        _xdotool(env, "mousemove", "--window", window_id,
                 str(int(ev["x"])), str(int(ev["y"])),
                 "mousedown", button, "mouseup", button)
        return
    if typ in ("mouse_down", "mouse_up"):
        button = _mouse_button(ev.get("button", "left"))
        action = "mousedown" if typ == "mouse_down" else "mouseup"
        # Move first so the press / release lands at the requested coords.
        _xdotool(env, "mousemove", "--window", window_id,
                 str(int(ev["x"])), str(int(ev["y"])),
                 action, button)
        return
    if typ in ("key_press", "key_down", "key_up"):
        sym = _normalize_keycode(ev["keycode"])
        action = {"key_press": "key", "key_down": "keydown", "key_up": "keyup"}[typ]
        _xdotool(env, action, "--window", window_id, sym)
        return
    raise ReplayError(f"unknown event type: {typ!r}")


def _mouse_button(button: object) -> str:
    raw = str(button).strip().lower()
    if raw == "left":
        return "1"
    if raw == "right":
        return "3"
    raise ReplayError(f"unknown mouse button: {button!r}")


def _normalize_keycode(keycode: object) -> str:
    key = str(keycode).strip().upper()
    mapped = _KEYCODES.get(key)
    if mapped is None:
        raise ReplayError(f"unknown keycode: {keycode!r}")
    return mapped


def _xdotool(env: dict, *args: str) -> None:
    subprocess.run(["xdotool", *args], env=env, check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
