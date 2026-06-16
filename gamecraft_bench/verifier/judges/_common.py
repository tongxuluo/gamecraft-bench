"""Shared helpers for multimodal judge backends.

Every backend prompts the model with the same structure (system instruction
+ batch of requirements, in JSON-out format), and parses the response the
same way. Centralizing here keeps the per-vendor modules focused on
just the API plumbing.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

from .base import RequirementSpec


# ---------------------------------------------------------------------------
# Prompt construction
# ---------------------------------------------------------------------------


SYSTEM_INSTRUCTION = (
    "You are a strict but fair video-game evaluator. Given a short "
    "playthrough recording of a Godot 2D game, decide how clearly each "
    "listed requirement is demonstrated. Score every requirement on a "
    "0.0 to 1.0 scale where 0.0 = not demonstrated at all (or contradicted), "
    "0.5 = partially demonstrated / ambiguous, and 1.0 = clearly and "
    "unambiguously demonstrated by what is visible in the recording. "
    "Reply with strict JSON only, no prose, no markdown, no code fences."
)


def build_user_prompt(requirements: list[RequirementSpec]) -> str:
    """Return the user-facing prompt for one demo's batch of requirements.

    The model must answer with a JSON object whose top-level key is
    ``scores`` mapping requirement id to a 0..1 number, and an optional
    ``rationales`` map keyed the same way.
    """
    lines = [
        "Evaluate the recording against each of the following requirements.",
        "",
        "Requirements:",
    ]
    for r in requirements:
        lines.append(f"- {r.id}: {r.description}")
    lines += [
        "",
        "Return JSON in exactly this shape (no extra keys, no markdown):",
        '{',
        '  "scores": {' + ", ".join(f'"{r.id}": <0..1>' for r in requirements) + "},",
        '  "rationales": {' + ", ".join(f'"{r.id}": "<one short sentence>"' for r in requirements) + "}",
        "}",
    ]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Response parsing
# ---------------------------------------------------------------------------


_JSON_FENCE_RE = re.compile(r"```(?:json)?\s*(.+?)\s*```", re.DOTALL)


def parse_judge_json(
    text: str,
    requirements: list[RequirementSpec],
) -> tuple[dict[str, float], dict[str, str]]:
    """Best-effort parse of the model's JSON response.

    Tolerates: stray markdown fences, leading/trailing prose, missing
    rationales. Missing requirement ids are filled with 0.0.

    Raises ``ValueError`` if no JSON object can be located at all — the
    caller should turn that into a JudgeError.
    """
    payload = _extract_json_object(text)
    if payload is None:
        raise ValueError("no JSON object found in judge response")
    try:
        data = json.loads(payload)
    except json.JSONDecodeError as e:
        raise ValueError(f"could not parse judge JSON: {e}") from e

    raw_scores = data.get("scores") if isinstance(data, dict) else None
    if not isinstance(raw_scores, dict):
        raise ValueError("judge response missing 'scores' object")
    raw_rats = data.get("rationales") if isinstance(data, dict) else None
    if not isinstance(raw_rats, dict):
        raw_rats = {}

    scores: dict[str, float] = {}
    rationales: dict[str, str] = {}
    for r in requirements:
        v = raw_scores.get(r.id, 0.0)
        try:
            f = float(v)
        except (TypeError, ValueError):
            f = 0.0
        scores[r.id] = max(0.0, min(1.0, f))
        rat = raw_rats.get(r.id, "")
        rationales[r.id] = str(rat) if rat is not None else ""
    return scores, rationales


def _extract_json_object(text: str) -> str | None:
    """Return the first JSON object substring in ``text``.

    Tries, in order: a fenced ```json ...``` block, then the substring
    between the first ``{`` and its matching ``}``.
    """
    if not text:
        return None
    m = _JSON_FENCE_RE.search(text)
    if m:
        candidate = m.group(1).strip()
        if candidate.startswith("{"):
            return candidate
    start = text.find("{")
    if start < 0:
        return None
    depth = 0
    in_str = False
    esc = False
    for i in range(start, len(text)):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            continue
        if c == '"':
            in_str = True
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    return None


# ---------------------------------------------------------------------------
# API key helper
# ---------------------------------------------------------------------------


def require_env(*candidates: str) -> str:
    """Return the first non-empty env var among ``candidates``.

    Raises ``KeyError`` (with a list of names tried) if none set. Backends
    catch this and convert to ``JudgeError``."""
    for name in candidates:
        v = os.environ.get(name)
        if v:
            return v
    raise KeyError(f"none of {candidates} set in environment")


def get_env(name: str, default: str | None = None) -> str | None:
    """Read an environment variable with no legacy-name fallback."""
    return os.environ.get(name, default)
