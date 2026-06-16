"""Kimi (Moonshot) judge backend.

Moonshot exposes an OpenAI-compatible Chat Completions endpoint, so we
route through the ``openai`` SDK with a custom ``base_url``. Visual input
is via ``image_url`` content parts pointing at base64 data URIs.
"""

from __future__ import annotations

import base64
import os
from pathlib import Path

from . import _common
from .base import JudgeError, JudgeRequest, JudgeResponse, MultimodalJudge

_MAX_FRAMES = 40
_MAX_TOKENS = 2048
_DEFAULT_BASE_URL = "https://api.moonshot.cn/v1"


def _data_uri(path: Path) -> str:
    b64 = base64.standard_b64encode(path.read_bytes()).decode("ascii")
    return f"data:image/png;base64,{b64}"


def _select_frames(frames: list[Path]) -> list[Path]:
    if len(frames) <= _MAX_FRAMES:
        return list(frames)
    step = len(frames) / float(_MAX_FRAMES)
    return [frames[min(int(i * step), len(frames) - 1)] for i in range(_MAX_FRAMES)]


class KimiJudge(MultimodalJudge):
    name = "kimi"
    default_model = "moonshot-v1-32k-vision-preview"

    def score(self, request: JudgeRequest) -> JudgeResponse:
        try:
            from openai import OpenAI
        except ImportError as e:
            raise JudgeError(f"openai SDK not installed: {e}") from e
        try:
            api_key = _common.require_env(
                "GAMECRAFT_BENCH_JUDGE_MOONSHOT_API_KEY", "MOONSHOT_API_KEY"
            )
        except KeyError as e:
            raise JudgeError(str(e)) from e

        if not request.frame_paths:
            raise JudgeError(
                f"no sampled frames available for demo {request.demo_id!r}"
            )

        base_url = (
            _common.get_env("GAMECRAFT_BENCH_JUDGE_MOONSHOT_BASE_URL")
            or os.environ.get("MOONSHOT_BASE_URL", _DEFAULT_BASE_URL)
        )
        client = OpenAI(api_key=api_key, base_url=base_url)

        frames = _select_frames(request.frame_paths)
        content: list[dict] = []
        for idx, fp in enumerate(frames, start=1):
            content.append({
                "type": "image_url",
                "image_url": {"url": _data_uri(fp)},
            })
            content.append({"type": "text", "text": f"(frame {idx}/{len(frames)})"})
        content.append({
            "type": "text",
            "text": _common.build_user_prompt(request.requirements),
        })

        try:
            resp = client.chat.completions.create(
                model=self.model,
                max_tokens=_MAX_TOKENS,
                messages=[
                    {"role": "system", "content": _common.SYSTEM_INSTRUCTION},
                    {"role": "user", "content": content},
                ],
            )
        except Exception as e:
            raise JudgeError(f"moonshot API call failed: {e}") from e

        text = (resp.choices[0].message.content or "") if resp.choices else ""
        try:
            scores, rationales = _common.parse_judge_json(text, request.requirements)
        except ValueError as e:
            raise JudgeError(f"{e}; raw response: {text[:500]!r}") from e
        return JudgeResponse(scores=scores, rationales=rationales, raw=text)
