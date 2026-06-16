"""Score a Godot project against a rubric.

End-to-end pipeline for one task:

1. Read ``rubric.json``: ``score_formula``, ``build_check``,
   ``categories``, ``requirements``.
2. Run ``build_check.cmd``. ``BUILD = 1`` if it exits 0, else 0.
   When ``BUILD`` is 0 we skip steps 3-5 — the formula multiplies by
   it anyway, the final reward is 0, and we save the work.
3. For each ``demo_outputs/*.json`` trace, replay it with
   ``replay_trace`` to produce an mp4. Sample frames at a fixed
   cadence so the judge has both video + still frames.
4. For each demo, call ``judge.score(...)`` once with the full set
   of requirements. Failures are recorded and treated as score 0 for
   every requirement on that demo.
5. Aggregate per-requirement = ``max`` over demos (best evidence wins).
6. Evaluate ``score_formula`` safely against the resulting variable
   dict and clamp to [0, 1].

Returns a structured ``ScoreResult`` plus writes per-demo artifacts
under ``output_dir`` (``replays/`` mp4s, ``frames/`` png samples,
``judge_log.json`` audit trail, ``breakdown.json`` summary).

This module owns the orchestration; subprocess plumbing lives in
``replay.py``, judge plumbing lives in ``judges/``. CLI / Harbor wiring
lives in ``cli.py``.
"""

from __future__ import annotations

import ast
import dataclasses
import json
import math
import operator
import random
import shutil
import subprocess
import time
from pathlib import Path

from .judges import JudgeError, MultimodalJudge, get_judge
from .judges.base import JudgeRequest, RequirementSpec
from .replay import ReplayError, replay_trace

_JUDGE_MAX_ATTEMPTS = 5


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


@dataclasses.dataclass(frozen=True)
class RequirementScore:
    requirement_id: str
    description: str
    per_demo: dict[str, float]    # demo_id -> 0..1
    aggregated: float             # agg over demos (or 0 if no demos)
    agg: str                      # "max" or "mean"


@dataclasses.dataclass(frozen=True)
class DemoArtifacts:
    demo_id: str
    trace_path: Path
    mp4_path: Path
    frame_paths: list[Path]
    duration_seconds: float


@dataclasses.dataclass(frozen=True)
class ScoreResult:
    reward: float                                # final score in [0, 1]
    build_ok: bool
    build_log: str
    formula: str
    requirements: list[RequirementScore]
    demos: list[DemoArtifacts]
    judge_name: str
    judge_model: str
    errors: list[str]                            # non-fatal (one per failed pair)


def score_project(
    *,
    project_dir: Path,
    rubric_path: Path,
    output_dir: Path,
    judge: MultimodalJudge | None = None,
    fps: int = 30,
    viewport: tuple[int, int] = (1280, 720),
    record_size: tuple[int, int] | None = (854, 480),
    frame_interval_seconds: float = 0.5,
    max_demo_seconds: float | None = None,
    max_demos: int | None = None,
) -> ScoreResult:
    """Score one Godot project. See module docstring for the pipeline."""
    project_dir = Path(project_dir).resolve()
    rubric_path = Path(rubric_path).resolve()
    output_dir = Path(output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    rubric = json.loads(rubric_path.read_text())
    formula: str = rubric["score_formula"]
    build_spec: dict = rubric["build_check"]
    requirements: list[dict] = rubric["requirements"]
    build_id: str = build_spec.get("id", "BUILD")

    # Resolve sampling caps: explicit kwarg > rubric value > built-in default.
    if max_demo_seconds is None:
        max_demo_seconds = float(rubric.get("max_demo_seconds", 20.0))
    if max_demos is None:
        max_demos = int(rubric.get("max_demos", 10))

    judge = judge or get_judge()
    errors: list[str] = []

    # 1. Build check.
    build_ok, build_log = _run_build_check(build_spec, output_dir)

    # Default per-requirement = 0; populated by judge if BUILD passes.
    # Per-requirement `agg` controls how the demo scores are folded into a
    # single aggregated value: "max" (default) for mechanic items where one
    # good demo proves the feature works, "mean" for visual/style items
    # where every demo is shared evidence and one slick demo shouldn't
    # cover for ten ugly ones.
    req_scores: dict[str, RequirementScore] = {
        r["id"]: RequirementScore(
            requirement_id=r["id"],
            description=r["description"],
            per_demo={},
            aggregated=0.0,
            agg=_validate_agg(r),
        )
        for r in requirements
    }

    demo_artifacts: list[DemoArtifacts] = []
    judge_log: list[dict] = []

    if build_ok:
        # 2. Replay each demo trace.
        traces = _list_traces(project_dir)
        if not traces:
            errors.append(
                f"no demo traces found under {project_dir/'demo_outputs'} — "
                f"all requirement scores will be 0"
            )
        elif max_demos > 0 and len(traces) > max_demos:
            errors.append(
                f"task ships {len(traces)} demo traces but max_demos={max_demos}; "
                f"keeping first {max_demos} by name and dropping the rest"
            )
            traces = traces[:max_demos]

        for trace_path in traces:
            demo_id = trace_path.stem
            demo_dir = output_dir / "demos" / demo_id
            demo_dir.mkdir(parents=True, exist_ok=True)
            mp4_path = demo_dir / f"{demo_id}.mp4"
            log_dir = demo_dir / "logs"
            try:
                rr = replay_trace(
                    project_dir=project_dir,
                    trace_path=trace_path,
                    output_mp4=mp4_path,
                    viewport=viewport,
                    record_size=record_size,
                    fps=fps,
                    log_dir=log_dir,
                )
            except ReplayError as e:
                errors.append(f"replay failed for {demo_id}: {e}")
                continue

            frames = _sample_frames(
                mp4_path,
                demo_dir / "frames",
                duration_seconds=rr.duration_seconds,
                interval_seconds=frame_interval_seconds,
                max_window_seconds=max_demo_seconds,
                seed=demo_id,
            )

            demo_artifacts.append(DemoArtifacts(
                demo_id=demo_id,
                trace_path=trace_path,
                mp4_path=mp4_path,
                frame_paths=frames,
                duration_seconds=rr.duration_seconds,
            ))

        # 3. Score each demo: one batched judge call returns scores for
        #    every requirement at once.
        req_specs = [RequirementSpec(id=r["id"], description=r["description"])
                     for r in requirements]
        for art in demo_artifacts:
            req = JudgeRequest(
                demo_id=art.demo_id,
                video_path=art.mp4_path,
                frame_paths=list(art.frame_paths),
                requirements=req_specs,
            )
            t0 = time.time()
            last_exc: JudgeError | None = None
            for attempt in range(_JUDGE_MAX_ATTEMPTS):
                if attempt:
                    time.sleep(5 * attempt)
                try:
                    resp = judge.score(req)
                    resp_scores = resp.scores
                    resp_rationales = resp.rationales
                    resp_raw = resp.raw
                    hard_failure = False
                    last_exc = None
                    break
                except JudgeError as e:
                    last_exc = e
            if last_exc is not None:
                resp_scores = {}
                resp_rationales = {}
                resp_raw = ""
                hard_failure = True
                errors.append(f"judge failed on {art.demo_id}: {last_exc}")
            latency_s = time.time() - t0

            for r in requirements:
                rid = r["id"]
                raw_score = resp_scores.get(rid, 0.0)
                try:
                    score = float(raw_score)
                except (TypeError, ValueError):
                    score = 0.0
                    if not hard_failure:
                        errors.append(
                            f"judge returned non-numeric score for "
                            f"{art.demo_id}/{rid}: {raw_score!r}"
                        )
                score = max(0.0, min(1.0, score))

                judge_log.append({
                    "demo_id": art.demo_id,
                    "requirement_id": rid,
                    "score": score,
                    "rationale": resp_rationales.get(rid, ""),
                    "raw": resp_raw if rid == requirements[0]["id"] else "",
                    "latency_seconds": round(latency_s, 3),
                })

                cur = req_scores[rid]
                new_per_demo = {**cur.per_demo, art.demo_id: score}
                req_scores[rid] = dataclasses.replace(
                    cur,
                    per_demo=new_per_demo,
                    aggregated=_aggregate(cur.agg, new_per_demo),
                )

    # 4. Evaluate the score formula.
    variables: dict[str, float] = {build_id: 1.0 if build_ok else 0.0}
    for rid, rs in req_scores.items():
        variables[rid] = rs.aggregated
    try:
        reward = _safe_eval_formula(formula, variables)
    except FormulaError as e:
        errors.append(f"score_formula evaluation failed: {e}")
        reward = 0.0
    reward = max(0.0, min(1.0, reward))

    result = ScoreResult(
        reward=reward,
        build_ok=build_ok,
        build_log=build_log,
        formula=formula,
        requirements=list(req_scores.values()),
        demos=demo_artifacts,
        judge_name=type(judge).__name__,
        judge_model=judge.model,
        errors=errors,
    )

    _write_artifacts(output_dir, result, judge_log, variables)
    return result


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------


def _list_traces(project_dir: Path) -> list[Path]:
    demo_dir = project_dir / "demo_outputs"
    if not demo_dir.is_dir():
        return []
    return sorted(p for p in demo_dir.iterdir() if p.suffix == ".json")


_VALID_AGG = ("max", "mean")


def _validate_agg(req: dict) -> str:
    agg = str(req.get("agg", "max")).lower()
    if agg not in _VALID_AGG:
        raise ValueError(
            f"requirement {req.get('id')!r}: agg must be one of {_VALID_AGG}, "
            f"got {req.get('agg')!r}"
        )
    return agg


def _aggregate(agg: str, per_demo: dict[str, float]) -> float:
    if not per_demo:
        return 0.0
    vals = list(per_demo.values())
    if agg == "mean":
        return sum(vals) / len(vals)
    return max(vals)


def _run_build_check(spec: dict, output_dir: Path) -> tuple[bool, str]:
    """Run the build smoke command in a shell. Captures combined output."""
    cmd = spec["cmd"]
    timeout = float(spec.get("timeout_seconds", 60))
    log_path = output_dir / "build.log"
    try:
        proc = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        log_path.write_text(out)
        return proc.returncode == 0, out
    except subprocess.TimeoutExpired as e:
        msg = f"build_check timed out after {timeout}s\n{e.stdout or ''}{e.stderr or ''}"
        log_path.write_text(msg)
        return False, msg
    except OSError as e:
        msg = f"build_check could not run: {e}"
        log_path.write_text(msg)
        return False, msg


def _sample_frames(
    mp4_path: Path,
    out_dir: Path,
    *,
    duration_seconds: float,
    interval_seconds: float,
    max_window_seconds: float | None = None,
    seed: str | None = None,
) -> list[Path]:
    """Extract one frame every ``interval_seconds`` of mp4 timeline.

    When ``max_window_seconds`` is set and the recording is longer, samples
    are drawn from a single contiguous window of that length. Window start
    is deterministic per ``seed`` (typically demo_id), so re-runs of the
    same project + trace pull the same frames.

    Returns the list of frame paths in time order. We run a single ffmpeg
    process and cap it with ``-frames:v`` so the judge gets a stable frame
    count without launching one decoder per sampled frame.
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    if shutil.which("ffmpeg") is None or duration_seconds <= 0:
        return []

    window_seconds = duration_seconds
    start = 0.0
    if (max_window_seconds is not None
            and max_window_seconds > 0
            and duration_seconds > max_window_seconds):
        slack = duration_seconds - max_window_seconds
        rng = random.Random(seed) if seed is not None else random.Random()
        start = rng.uniform(0.0, slack)
        window_seconds = max_window_seconds

    interval = max(interval_seconds, 0.1)
    sample_count = max(1, int(math.ceil(window_seconds / interval)))
    fps_value = 1.0 / interval
    pattern = out_dir / "frame_%04d.png"
    # If the recording is shorter than the logical trace window, clone the
    # final frame so the frame budget remains stable. The frozen tail is
    # still visible to the judge and should be penalized if it reflects a
    # broken replay, but the request shape stays predictable.
    vf = f"tpad=stop_mode=clone:stop_duration={window_seconds:.3f},fps={fps_value:.6f}"
    cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    if start > 0:
        cmd += ["-ss", f"{start:.3f}"]
    cmd += [
        "-i", str(mp4_path),
        "-vf", vf,
        "-frames:v", str(sample_count),
        str(pattern),
    ]
    try:
        subprocess.run(cmd, check=False, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=60)
    except subprocess.TimeoutExpired:
        return []
    return sorted(
        p for p in out_dir.glob("frame_*.png")
        if p.exists() and p.stat().st_size > 0
    )


def _write_artifacts(
    output_dir: Path,
    result: ScoreResult,
    judge_log: list[dict],
    variables: dict[str, float],
) -> None:
    breakdown = {
        "reward": result.reward,
        "formula": result.formula,
        "build_ok": result.build_ok,
        "judge": {"name": result.judge_name, "model": result.judge_model},
        "variables": variables,
        "requirements": [
            {
                "id": r.requirement_id,
                "description": r.description,
                "agg": r.agg,
                "aggregated": r.aggregated,
                "per_demo": r.per_demo,
            }
            for r in result.requirements
        ],
        "demos": [
            {
                "demo_id": d.demo_id,
                "trace": str(d.trace_path),
                "mp4": str(d.mp4_path),
                "duration_seconds": d.duration_seconds,
                "frames": [str(p) for p in d.frame_paths],
            }
            for d in result.demos
        ],
        "errors": result.errors,
    }
    (output_dir / "breakdown.json").write_text(
        json.dumps(breakdown, indent=2, sort_keys=False)
    )
    (output_dir / "judge_log.json").write_text(
        json.dumps(judge_log, indent=2, sort_keys=False)
    )


# ---------------------------------------------------------------------------
# Safe arithmetic-only formula evaluator
# ---------------------------------------------------------------------------


class FormulaError(RuntimeError):
    """Raised when ``score_formula`` is malformed or references an unknown id."""


_BINOPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.Pow: operator.pow,
}
_UNARYOPS = {
    ast.UAdd: operator.pos,
    ast.USub: operator.neg,
}


def _safe_eval_formula(formula: str, variables: dict[str, float]) -> float:
    """Evaluate ``formula`` with variables. Allows numbers, names, +-*/%**,
    parentheses; rejects everything else (no calls, no attributes, no
    subscripts, no comparisons, no comprehensions)."""
    try:
        tree = ast.parse(formula, mode="eval")
    except SyntaxError as e:
        raise FormulaError(f"could not parse formula: {e}") from e
    return float(_eval_node(tree.body, variables))


def _eval_node(node: ast.AST, variables: dict[str, float]) -> float:
    if isinstance(node, ast.Constant):
        if isinstance(node.value, (int, float)):
            return float(node.value)
        raise FormulaError(f"unsupported constant: {node.value!r}")
    if isinstance(node, ast.Name):
        if node.id not in variables:
            raise FormulaError(f"unknown variable in formula: {node.id!r}")
        return float(variables[node.id])
    if isinstance(node, ast.BinOp):
        op = _BINOPS.get(type(node.op))
        if op is None:
            raise FormulaError(f"unsupported binary operator: {type(node.op).__name__}")
        return float(op(_eval_node(node.left, variables),
                        _eval_node(node.right, variables)))
    if isinstance(node, ast.UnaryOp):
        op = _UNARYOPS.get(type(node.op))
        if op is None:
            raise FormulaError(f"unsupported unary operator: {type(node.op).__name__}")
        return float(op(_eval_node(node.operand, variables)))
    raise FormulaError(f"disallowed expression: {type(node).__name__}")


__all__ = [
    "DemoArtifacts",
    "FormulaError",
    "RequirementScore",
    "ScoreResult",
    "score_project",
]
