"""Claude (Anthropic) judge backend.

Sends the sampled frames of a demo replay (image blocks, base64-encoded
PNGs) to a Claude model along with the batch of requirement prompts,
and parses a strict-JSON reply. Two subclasses pin ``default_model`` to
specific Claude SKUs:
  - ``ClaudeJudge``: claude-sonnet-4-6
  - ``ClaudeOpusJudge``: claude-opus-4-7
"""

from __future__ import annotations

import base64
from pathlib import Path

from . import _common
from .base import JudgeError, JudgeRequest, JudgeResponse, MultimodalJudge

# How many sampled frames to attach. Anthropic accepts up to 100 image
# blocks per request; we cap lower to keep token use sane.
_MAX_FRAMES = 40
_MAX_TOKENS = 2048


def _read_png_b64(path: Path) -> str:
    return base64.standard_b64encode(path.read_bytes()).decode("ascii")


def _select_frames(frames: list[Path]) -> list[Path]:
    if len(frames) <= _MAX_FRAMES:
        return list(frames)
    step = len(frames) / float(_MAX_FRAMES)
    picked: list[Path] = []
    for i in range(_MAX_FRAMES):
        idx = min(int(i * step), len(frames) - 1)
        picked.append(frames[idx])
    return picked


class ClaudeJudge(MultimodalJudge):
    """Claude Sonnet 4.6 (default). Override model with --judge-model."""

    name = "claude"
    default_model = "claude-sonnet-4-6"

    def score(self, request: JudgeRequest) -> JudgeResponse:
        try:
            from anthropic import Anthropic
        except ImportError as e:
            raise JudgeError(f"anthropic SDK not installed: {e}") from e
        # Anthropic SDK accepts either api_key (x-api-key header) or
        # auth_token (Authorization: Bearer header). Third-party
        # proxies typically use the bearer-token form, so try AUTH_TOKEN
        # first; fall through to API_KEY if only that is set.
        try:
            auth_token = _common.require_env(
                "GAMECRAFT_BENCH_JUDGE_ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_AUTH_TOKEN"
            )
            client_credential = {"auth_token": auth_token}
        except KeyError:
            try:
                api_key = _common.require_env(
                    "GAMECRAFT_BENCH_JUDGE_ANTHROPIC_API_KEY", "ANTHROPIC_API_KEY"
                )
                client_credential = {"api_key": api_key}
            except KeyError as e:
                raise JudgeError(str(e)) from e

        if not request.frame_paths:
            raise JudgeError(
                f"no sampled frames available for demo {request.demo_id!r}"
            )

        client_kwargs: dict[str, object] = {**client_credential}
        import os
        base_url = (
            _common.get_env("GAMECRAFT_BENCH_JUDGE_ANTHROPIC_BASE_URL")
            or os.environ.get("ANTHROPIC_BASE_URL")
        )
        if base_url:
            client_kwargs["base_url"] = base_url
        client = Anthropic(**client_kwargs)

        frames = _select_frames(request.frame_paths)
        content: list[dict] = []
        for idx, fp in enumerate(frames, start=1):
            content.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": _read_png_b64(fp),
                },
            })
            content.append({
                "type": "text",
                "text": f"(frame {idx}/{len(frames)})",
            })
        content.append({
            "type": "text",
            "text": _common.build_user_prompt(request.requirements),
        })

        try:
            msg = client.messages.create(
                model=self.model,
                max_tokens=_MAX_TOKENS,
                system=_common.SYSTEM_INSTRUCTION,
                messages=[{"role": "user", "content": content}],
            )
        except Exception as e:
            raise JudgeError(f"anthropic API call failed: {e}") from e

        text = "".join(
            block.text for block in msg.content
            if getattr(block, "type", None) == "text"
        )
        try:
            scores, rationales = _common.parse_judge_json(
                text, request.requirements,
            )
        except ValueError as e:
            raise JudgeError(f"{e}; raw response: {text[:500]!r}") from e
        return JudgeResponse(scores=scores, rationales=rationales, raw=text)


class ClaudeOpusJudge(ClaudeJudge):
    """Claude Opus 4.7 — same plumbing, beefier model."""

    name = "opus"
    default_model = "claude-opus-4-7"
