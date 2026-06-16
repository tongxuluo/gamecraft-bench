"""Command-line entry point for the verifier.

Typical usage from a task's ``tests/test.sh``:

    python -m gamecraft_bench.verifier \\
        --project /workspace/game \\
        --rubric  /tests/rubric.json \\
        --output  /logs/verifier

Side effects:

- Writes ``<output>/reward.txt``  — single float in [0, 1] (Harbor reads this).
- Writes ``<output>/breakdown.json`` — full per-requirement / per-demo dump.
- Writes ``<output>/judge_log.json`` — one entry per (demo, requirement) call.
- Writes ``<output>/build.log`` — captured output of the build_check command.
- Writes ``<output>/demos/<id>/<id>.mp4`` and ``frames/`` for each demo.
- Writes ``<output>/ctrf.json`` — minimal CTRF report so existing pytest-based
  test runners can show this run alongside others.

Exit status mirrors reward thresholding: ``0`` if reward >= ``--pass-threshold``
(default 0.5), ``1`` otherwise. Hard internal failures still raise.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .. import config as cfg
from .judges import get_judge
from .score import ScoreResult, score_project


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m gamecraft_bench.verifier",
        description="Replay demo traces and score the recordings against a rubric.",
    )
    parser.add_argument("--project", type=Path, required=True,
                        help="Path to the Godot project directory.")
    parser.add_argument("--rubric", type=Path, required=True,
                        help="Path to the rubric JSON file.")
    parser.add_argument("--output", type=Path, required=True,
                        help="Directory for reward/breakdown/replay artifacts.")
    parser.add_argument("--judge", default=None,
                        help="Override GAMECRAFT_BENCH_JUDGE for this run.")
    parser.add_argument("--judge-model", default=None,
                        help="Override GAMECRAFT_BENCH_JUDGE_MODEL for this run.")
    parser.add_argument("--fps", type=int, default=30,
                        help="Replay framerate (default: 30).")
    parser.add_argument("--width",  type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--record-width",  type=int, default=854,
                        help="MP4 encode width  (defaults to 854 = 480p 16:9; "
                             "set equal to --width to keep native).")
    parser.add_argument("--record-height", type=int, default=480,
                        help="MP4 encode height (defaults to 480 = 480p 16:9; "
                             "set equal to --height to keep native).")
    parser.add_argument("--frame-interval-seconds", type=float, default=0.5,
                        help="Sampling cadence for still frames passed to the judge.")
    parser.add_argument("--max-demo-seconds", type=float, default=None,
                        help="Per-demo length cap (seconds). Recordings longer "
                             "than this are sampled from a random window of this "
                             "length (deterministic per demo_id). Defaults to the "
                             "rubric's max_demo_seconds, falling back to 20.")
    parser.add_argument("--max-demos", type=int, default=None,
                        help="Cap on the number of traces processed per project. "
                             "Defaults to the rubric's max_demos, falling back to 10.")
    parser.add_argument("--pass-threshold", type=float, default=0.5,
                        help="Reward >= threshold => exit 0 (default: 0.5).")
    args = parser.parse_args(argv)

    args.output.mkdir(parents=True, exist_ok=True)

    judge = get_judge(backend=args.judge, model=args.judge_model)

    print(f"[verifier] project   = {args.project}", flush=True)
    print(f"[verifier] rubric    = {args.rubric}", flush=True)
    print(f"[verifier] output    = {args.output}", flush=True)
    print(f"[verifier] judge     = {type(judge).__name__}(model={judge.model!r})",
          flush=True)
    print(f"[verifier] godot_bin = {cfg.GODOT_BIN}", flush=True)

    result = score_project(
        project_dir=args.project,
        rubric_path=args.rubric,
        output_dir=args.output,
        judge=judge,
        fps=args.fps,
        viewport=(args.width, args.height),
        record_size=(args.record_width, args.record_height),
        frame_interval_seconds=args.frame_interval_seconds,
        max_demo_seconds=args.max_demo_seconds,
        max_demos=args.max_demos,
    )

    _print_summary(result)
    _write_reward(args.output, result)
    _write_ctrf(args.output, result)

    return 0 if result.reward >= args.pass_threshold else 1


def _print_summary(result: ScoreResult) -> None:
    print("", flush=True)
    print(f"[verifier] reward        = {result.reward:.3f}", flush=True)
    print(f"[verifier] build_ok      = {result.build_ok}", flush=True)
    print(f"[verifier] num_demos     = {len(result.demos)}", flush=True)
    print(f"[verifier] num_errors    = {len(result.errors)}", flush=True)
    if result.errors:
        for e in result.errors:
            print(f"[verifier]   ! {e}", flush=True)
    print("[verifier] requirements (id  agg  per_demo):", flush=True)
    for r in result.requirements:
        per = ", ".join(f"{d}={s:.2f}" for d, s in r.per_demo.items()) or "-"
        print(f"[verifier]   {r.requirement_id:<5} {r.aggregated:.2f}  [{per}]",
              flush=True)


def _write_reward(output_dir: Path, result: ScoreResult) -> None:
    """Harbor reads the trial reward from ``reward.txt`` next to the verifier
    artifacts. Match that path so this CLI drops in cleanly."""
    (output_dir / "reward.txt").write_text(f"{result.reward:.6f}\n")


def _write_ctrf(output_dir: Path, result: ScoreResult) -> None:
    """Emit a minimal CTRF v0.0.0 report — one test per requirement, plus
    one for the build check. Lets pytest-style report tooling display the
    run even though we're not using pytest."""
    tests = [{
        "name": "build_check",
        "status": "passed" if result.build_ok else "failed",
        "duration": 0,
        "rawStatus": "passed" if result.build_ok else "failed",
    }]
    for r in result.requirements:
        passed = r.aggregated >= 0.5
        tests.append({
            "name": f"requirement::{r.requirement_id}",
            "status": "passed" if passed else "failed",
            "duration": 0,
            "rawStatus": "passed" if passed else "failed",
            "message": r.description,
            "extra": {
                "aggregated": r.aggregated,
                "per_demo": r.per_demo,
            },
        })
    summary = {
        "tests": len(tests),
        "passed": sum(1 for t in tests if t["status"] == "passed"),
        "failed": sum(1 for t in tests if t["status"] == "failed"),
        "pending": 0,
        "skipped": 0,
        "other": 0,
        "start": 0,
        "stop": 0,
    }
    ctrf = {
        "results": {
            "tool": {"name": "gamecraft-bench-verifier"},
            "summary": summary,
            "tests": tests,
            "extra": {
                "reward": result.reward,
                "formula": result.formula,
                "judge": {
                    "name": result.judge_name,
                    "model": result.judge_model,
                },
                "errors": result.errors,
            },
        }
    }
    (output_dir / "ctrf.json").write_text(json.dumps(ctrf, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())
