"""Session manager: snapshot game → Xvfb + Godot + x11vnc lifecycle."""

from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path

from .. import config as cfg

_DISPLAY_BASE = 300
_DISPLAY_COUNT = 8
_SNAP_ROOT = Path("/tmp/gamecraftbench-dashboard")


@dataclass
class Session:
    sid: str
    trial_id: str          # e.g. "strategy-skirmish__4B7yCV5"
    game_dir: Path         # snapshot path
    display: int
    vnc_port: int
    procs: list[subprocess.Popen] = field(default_factory=list)
    last_ping: float = field(default_factory=time.time)


class SessionManager:
    def __init__(self) -> None:
        self._sessions: dict[str, Session] = {}
        self._display_pool: set[int] = set(range(_DISPLAY_BASE, _DISPLAY_BASE + _DISPLAY_COUNT))
        self._lock = asyncio.Lock()

    # ------------------------------------------------------------------
    # Trial discovery
    # ------------------------------------------------------------------

    @staticmethod
    def list_trials(jobs_root: Path) -> list[dict]:
        """Scan jobs_root for trials and return analysis-ready metadata."""
        trials = []
        for run_dir in sorted(jobs_root.iterdir(), reverse=True):
            if not run_dir.is_dir():
                continue
            run_config = _read_json(run_dir / "config.json") or {}
            for trial_dir in sorted(run_dir.iterdir()):
                if not trial_dir.is_dir():
                    continue
                if trial_dir.name in {"agent", "verifier", "sandbox", "logs", "artifacts"}:
                    continue

                game_dir = trial_dir / "sandbox" / "workspace" / "game"
                result = _read_json(trial_dir / "result.json") or {}
                breakdown = _read_json(trial_dir / "verifier" / "breakdown.json") or {}
                reward = _reward(result, breakdown, trial_dir)
                task = _task_name(result, trial_dir)
                agent = _agent_name(result, run_config)
                model = _model_name(result, run_config)
                family = _family_name(task)
                exception = result.get("exception_info")
                exception_type = None
                if isinstance(exception, dict):
                    exception_type = exception.get("type") or exception.get("class")
                if exception_type is None and (trial_dir / "exception.txt").exists():
                    exception_type = "Exception"
                status = _status(exception_type, game_dir, breakdown)
                demos = breakdown.get("demos") if isinstance(breakdown.get("demos"), list) else []
                category_scores = _category_scores(breakdown)
                metric_scores = _metric_scores(reward, category_scores)
                requirements = _requirements(breakdown)

                trials.append({
                    "trial_id": trial_dir.name,
                    "trial_dir": str(trial_dir),
                    "run": run_dir.name,
                    "task": task,
                    "family": family,
                    "agent": agent,
                    "model": model,
                    "game_dir": str(game_dir),
                    "has_game": game_dir.is_dir(),
                    "reward": reward,
                    "status": status,
                    "failure_stage": _failure_stage(status, breakdown, game_dir, exception_type),
                    "exception": exception_type,
                    "started_at": result.get("started_at"),
                    "finished_at": result.get("finished_at"),
                    "duration_seconds": _duration_seconds(result),
                    "cost_usd": (result.get("agent_result") or {}).get("cost_usd"),
                    "input_tokens": (result.get("agent_result") or {}).get("n_input_tokens"),
                    "output_tokens": (result.get("agent_result") or {}).get("n_output_tokens"),
                    "cache_tokens": (result.get("agent_result") or {}).get("n_cache_tokens"),
                    "build_ok": breakdown.get("build_ok"),
                    "verifier_errors": breakdown.get("errors") if isinstance(breakdown.get("errors"), list) else [],
                    "judge": (breakdown.get("judge") or {}).get("model"),
                    "demo_count": len(demos),
                    "demo_seconds": sum(float(d.get("duration_seconds") or 0) for d in demos),
                    "frame_count": sum(len(d.get("frames") or []) for d in demos if isinstance(d, dict)),
                    "demo_ids": [d.get("demo_id") for d in demos if isinstance(d, dict) and d.get("demo_id")],
                    "category_scores": category_scores,
                    "metric_scores": metric_scores,
                    "requirements": requirements,
                    "requirement_summary": _requirement_summary(requirements),
                })
        return trials

    # ------------------------------------------------------------------
    # Session lifecycle
    # ------------------------------------------------------------------
    async def start(self, trial_id: str, game_src: Path) -> Session:
        async with self._lock:
            if not self._display_pool:
                oldest = min(self._sessions.values(), key=lambda s: s.last_ping)
                await self._stop_session(oldest)
            display = self._display_pool.pop()

        sid = uuid.uuid4().hex[:8]
        snap = _SNAP_ROOT / sid / "game"
        snap.parent.mkdir(parents=True, exist_ok=True)
        await asyncio.to_thread(shutil.copytree, str(game_src), str(snap))

        vnc_port = 5900 + display
        try:
            procs = await asyncio.to_thread(self._spawn, snap, display, vnc_port)
        except Exception:
            # 如果 Xvfb/Godot/x11vnc 任一启动失败，归还 display 并清理目录
            async with self._lock:
                self._display_pool.add(display)
            await asyncio.to_thread(shutil.rmtree, str(snap.parent), ignore_errors=True)
            raise

        sess = Session(sid=sid, trial_id=trial_id, game_dir=snap,
                    display=display, vnc_port=vnc_port, procs=procs)
        async with self._lock:
            self._sessions[sid] = sess
        return sess

    async def refresh(self, sid: str, game_src: Path) -> None:
        async with self._lock:
            sess = self._sessions.get(sid)
        if sess is None:
            raise KeyError(sid)
        # procs order from _spawn: [xvfb, godot, x11vnc]. Kill only godot
        # so the VNC connection stays alive across refresh.
        if len(sess.procs) >= 2:
            godot = sess.procs[1]
            if godot.poll() is None:
                try:
                    godot.terminate()
                    godot.wait(timeout=3)
                except Exception:
                    godot.kill()
        await asyncio.to_thread(shutil.rmtree, str(sess.game_dir), True)
        await asyncio.to_thread(shutil.copytree, str(game_src), str(sess.game_dir))
        new_godot = await asyncio.to_thread(self._spawn_godot, sess.game_dir, sess.display)
        async with self._lock:
            if len(sess.procs) >= 2:
                sess.procs[1] = new_godot
            else:
                sess.procs.append(new_godot)

    async def stop(self, sid: str) -> None:
        async with self._lock:
            sess = self._sessions.pop(sid, None)
        if sess:
            await asyncio.to_thread(self._teardown, sess)

    def ping(self, sid: str) -> None:
        sess = self._sessions.get(sid)
        if sess:
            sess.last_ping = time.time()

    def get(self, sid: str) -> Session | None:
        return self._sessions.get(sid)

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------
    def _spawn(self, game_dir: Path, display: int, vnc_port: int) -> list[subprocess.Popen]:
        disp = f":{display}"
        env = {**os.environ, "DISPLAY": disp, "GODOT_SILENCE_ROOT_WARNING": "1"}

        xvfb = subprocess.Popen(
            ["Xvfb", disp, "-screen", "0", "1280x720x24", "-nolisten", "tcp"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        sock = Path(f"/tmp/.X11-unix/X{display}")
        deadline = time.time() + 5
        while not sock.exists() and time.time() < deadline:
            time.sleep(0.05)

        godot = self._spawn_godot(game_dir, display)

        x11vnc = subprocess.Popen(
            ["x11vnc", "-display", disp, "-rfbport", str(vnc_port),
            "-nopw", "-forever", "-shared", "-quiet", "-noncache"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env,
        )
        # 等待 x11vnc 真正绑定端口
        import socket
        deadline = time.time() + 3
        while time.time() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", vnc_port), timeout=0.2):
                    break
            except OSError:
                time.sleep(0.05)
        else:
            raise RuntimeError(f"x11vnc failed to bind port {vnc_port}")

        return [xvfb, godot, x11vnc]

    def _spawn_godot(self, game_dir: Path, display: int) -> subprocess.Popen:
        disp = f":{display}"
        env = {**os.environ, "DISPLAY": disp, "GODOT_SILENCE_ROOT_WARNING": "1"}
        godot_bin = cfg.GODOT_BIN or "godot"
        return subprocess.Popen(
            [godot_bin, "--path", str(game_dir),
             "--display-driver", "x11", "--rendering-driver", "opengl3",
             "--audio-driver", "Dummy", "--resolution", "1280x720",
             "--single-window"],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )

    def _teardown(self, sess: Session) -> None:
        for p in reversed(sess.procs):
            if p.poll() is None:
                try:
                    p.terminate(); p.wait(timeout=3)
                except Exception:
                    p.kill()
        shutil.rmtree(sess.game_dir.parent, ignore_errors=True)
        self._display_pool.add(sess.display)

    async def _stop_session(self, sess: Session) -> None:
        """Must be called with lock held."""
        self._sessions.pop(sess.sid, None)
        await asyncio.to_thread(self._teardown, sess)


def _read_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text())
    except Exception:
        return None


def _reward(result: dict, breakdown: dict, trial_dir: Path) -> float | None:
    rewards = (result.get("verifier_result") or {}).get("rewards") or {}
    value = rewards.get("reward", breakdown.get("reward"))
    if value is None:
        try:
            value = float((trial_dir / "verifier" / "reward.txt").read_text().strip())
        except Exception:
            return None
    try:
        return float(value)
    except Exception:
        return None


def _task_name(result: dict, trial_dir: Path) -> str:
    path = ((result.get("task_id") or {}).get("path")
            or ((result.get("config") or {}).get("task") or {}).get("path"))
    if path:
        return Path(path).name
    if "__" in trial_dir.name:
        return trial_dir.name.rsplit("__", 1)[0]
    return trial_dir.name


_FAMILY_LABELS = {
    "cardgame": "Card game",
    "horror": "Horror",
    "idle": "Idle",
    "openworld": "Open-world",
    "platformer": "Platformer",
    "puzzle": "Puzzle",
    "racing": "Racing",
    "rhythm": "Rhythm",
    "roguelike": "Roguelike",
    "shooter": "Shooter",
    "simulation": "Simulation",
    "sports": "Sports",
    "strategy": "Strategy",
    "tycoon": "Tycoon",
    "visualnovel": "Visual novel",
}


def _family_name(task: str) -> str:
    prefix = str(task or "").split("-", 1)[0].lower()
    return _FAMILY_LABELS.get(prefix, prefix or "unknown")


def _agent_name(result: dict, run_config: dict) -> str:
    info_name = (result.get("agent_info") or {}).get("name")
    agent_cfg = ((result.get("config") or {}).get("agent") or {})
    name = info_name or agent_cfg.get("name")
    import_path = agent_cfg.get("import_path") or _first_agent(run_config).get("import_path")
    if name:
        return str(name)
    if import_path:
        lower = str(import_path).lower()
        if "claude" in lower:
            return "claude-code"
        if "codex" in lower:
            return "codex"
    return "unknown"


def _model_name(result: dict, run_config: dict) -> str:
    model_info = (result.get("agent_info") or {}).get("model_info") or {}
    agent_cfg = ((result.get("config") or {}).get("agent") or {})
    return str(
        model_info.get("name")
        or agent_cfg.get("model_name")
        or _first_agent(run_config).get("model_name")
        or "unknown"
    )


def _first_agent(run_config: dict) -> dict:
    agents = run_config.get("agents")
    if isinstance(agents, list) and agents:
        return agents[0] or {}
    return {}


def _duration_seconds(result: dict) -> float | None:
    from datetime import datetime

    started = result.get("started_at")
    finished = result.get("finished_at")
    if not started or not finished:
        return None
    try:
        a = datetime.fromisoformat(str(started).replace("Z", "+00:00"))
        b = datetime.fromisoformat(str(finished).replace("Z", "+00:00"))
        return max(0.0, (b - a).total_seconds())
    except Exception:
        return None


def _status(exception_type: str | None, game_dir: Path, breakdown: dict) -> str:
    if not game_dir.is_dir():
        return "no-game"
    if breakdown:
        if breakdown.get("build_ok") is False:
            return "build-failed"
        return "verified"
    if exception_type:
        return "errored"
    return "generated"


def _failure_stage(status: str, breakdown: dict, game_dir: Path, exception_type: str | None) -> str:
    if not game_dir.is_dir():
        return "no-game"
    if breakdown.get("build_ok") is False:
        return "build"
    errors = breakdown.get("errors")
    if isinstance(errors, list) and errors:
        return "verifier"
    if breakdown and not breakdown.get("demos"):
        return "no-demo"
    if breakdown:
        return "scored"
    if exception_type:
        return "agent-exception"
    return "not-verified"


def _category_scores(breakdown: dict) -> dict[str, float]:
    groups: dict[str, list[float]] = {}
    for req in breakdown.get("requirements") or []:
        rid = str(req.get("id") or "")
        category = _category_for_requirement(rid)
        if not category:
            continue
        try:
            groups.setdefault(category, []).append(float(req.get("aggregated")))
        except Exception:
            pass
    return {
        category: sum(values) / len(values)
        for category, values in groups.items()
        if values
    }


def _metric_scores(reward: float | None, category_scores: dict[str, float]) -> dict[str, float | None]:
    return {
        "M": category_scores.get("Core Mechanics"),
        "D": category_scores.get("Content Depth"),
        "V": category_scores.get("Functional Visuals"),
        "A": category_scores.get("Presentation & Art"),
        "Overall": reward,
    }


def _requirements(breakdown: dict) -> list[dict]:
    reqs = []
    for req in breakdown.get("requirements") or []:
        rid = str(req.get("id") or "")
        try:
            score = float(req.get("aggregated"))
        except Exception:
            score = None
        reqs.append({
            "id": rid,
            "category": _category_for_requirement(rid),
            "score": score,
            "agg": req.get("agg"),
            "per_demo": req.get("per_demo") if isinstance(req.get("per_demo"), dict) else {},
            "description": _short_text(req.get("description")),
        })
    return reqs


def _short_text(value: object, limit: int = 240) -> str | None:
    if not isinstance(value, str):
        return None
    text = " ".join(value.split())
    if len(text) <= limit:
        return text
    return text[:limit].rstrip() + "..."


def _requirement_summary(requirements: list[dict]) -> dict:
    scored = [r for r in requirements if isinstance(r.get("score"), (int, float))]
    if not scored:
        return {"n": 0, "pass": 0, "partial": 0, "fail": 0, "low": 0}
    return {
        "n": len(scored),
        "pass": sum(1 for r in scored if float(r["score"]) >= 0.999),
        "partial": sum(1 for r in scored if 0.0 < float(r["score"]) < 0.999),
        "fail": sum(1 for r in scored if float(r["score"]) <= 0.0),
        "low": sum(1 for r in scored if float(r["score"]) < 0.5),
    }


def _category_for_requirement(requirement_id: str) -> str | None:
    prefix = requirement_id[:1].upper()
    return {
        "M": "Core Mechanics",
        "D": "Content Depth",
        "V": "Functional Visuals",
        "A": "Presentation & Art",
    }.get(prefix)
