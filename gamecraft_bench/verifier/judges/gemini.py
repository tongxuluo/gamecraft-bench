"""Gemini (google-genai) judge backend.

Sends the full demo replay mp4 (recorded at the size set by the
verifier's ``--record-width``/``--record-height``, default 854x480)
to the model and asks it to score every requirement in one batched
JSON response. The whole video goes to the model — no frame sampling —
so temporal logic (turn order, animations, attack timing) is observable.

Inline-data path: the mp4 is read into memory and attached as a
``Part.from_bytes(...)`` block. Works against both the official Gemini
endpoint and third-party OpenAI-/Gemini-compatible proxies that don't
implement the Files API. Caps at ~18 MiB to leave headroom under the
20 MiB inline-payload limit; if a recording is larger we fall back to
the Files API and surface a JudgeError if that also fails.

Honours ``GEMINI_API_KEY`` / ``GOOGLE_API_KEY`` and an optional
``GEMINI_BASE_URL`` for routing through a proxy.
"""

from __future__ import annotations

import os
import time
from pathlib import Path

from . import _common
from .base import JudgeError, JudgeRequest, JudgeResponse, MultimodalJudge

_MAX_OUTPUT_TOKENS = 2048
_INLINE_MAX_BYTES = 18 * 1024 * 1024
_UPLOAD_POLL_INTERVAL_S = 1.5
_UPLOAD_POLL_TIMEOUT_S = 120


class GeminiJudge(MultimodalJudge):
    name = "gemini"
    default_model = "gemini-3.0"

    def score(self, request: JudgeRequest) -> JudgeResponse:
        try:
            from google import genai
            from google.genai import types as genai_types
        except ImportError as e:
            raise JudgeError(f"google-genai SDK not installed: {e}") from e
        try:
            api_key = _common.require_env(
                "GAMECRAFT_BENCH_JUDGE_GEMINI_API_KEY",
                "GAMECRAFT_BENCH_JUDGE_GOOGLE_API_KEY",
                "GEMINI_API_KEY",
                "GOOGLE_API_KEY",
            )
        except KeyError as e:
            raise JudgeError(str(e)) from e

        if not request.video_path.exists():
            raise JudgeError(f"video missing: {request.video_path}")

        client_kwargs: dict[str, object] = {"api_key": api_key}
        base_url = (
            _common.get_env("GAMECRAFT_BENCH_JUDGE_GEMINI_BASE_URL")
            or os.environ.get("GEMINI_BASE_URL")
        )
        if base_url:
            client_kwargs["http_options"] = genai_types.HttpOptions(
                base_url=base_url,
            )
        client = genai.Client(**client_kwargs)

        size = request.video_path.stat().st_size
        prompt = _common.build_user_prompt(request.requirements)

        if size <= _INLINE_MAX_BYTES:
            video_part = genai_types.Part.from_bytes(
                data=request.video_path.read_bytes(),
                mime_type="video/mp4",
            )
            uploaded = None
        else:
            uploaded = _upload_via_files_api(client, genai_types, request.video_path)
            video_part = genai_types.Part.from_uri(
                file_uri=uploaded.uri,
                mime_type=uploaded.mime_type,
            )

        try:
            resp = client.models.generate_content(
                model=self.model,
                contents=[video_part, prompt],
                config=genai_types.GenerateContentConfig(
                    system_instruction=_common.SYSTEM_INSTRUCTION,
                    response_mime_type="application/json",
                    max_output_tokens=_MAX_OUTPUT_TOKENS,
                ),
            )
        except Exception as e:
            if uploaded is not None:
                _safe_delete(client, uploaded)
            raise JudgeError(f"Gemini generate_content failed: {e}") from e

        if uploaded is not None:
            _safe_delete(client, uploaded)
        text = getattr(resp, "text", "") or ""
        try:
            scores, rationales = _common.parse_judge_json(text, request.requirements)
        except ValueError as e:
            raise JudgeError(f"{e}; raw response: {text[:500]!r}") from e
        return JudgeResponse(scores=scores, rationales=rationales, raw=text)


def _upload_via_files_api(client: object, genai_types: object, path: Path) -> object:
    try:
        uploaded = client.files.upload(
            file=str(path),
            config=genai_types.UploadFileConfig(mime_type="video/mp4"),
        )
    except Exception as e:
        raise JudgeError(
            f"Gemini Files API upload failed (and the file is too large for "
            f"inline submission, {path.stat().st_size} bytes): {e}"
        ) from e
    return _wait_active(client, uploaded)


def _wait_active(client: object, file_obj: object) -> object:
    name = getattr(file_obj, "name", None)
    deadline = time.time() + _UPLOAD_POLL_TIMEOUT_S
    cur = file_obj
    while time.time() < deadline:
        state = getattr(cur, "state", None)
        state_name = getattr(state, "name", None) or str(state or "")
        if state_name == "ACTIVE":
            return cur
        if state_name == "FAILED":
            raise JudgeError(f"Gemini file processing failed for {name!r}")
        time.sleep(_UPLOAD_POLL_INTERVAL_S)
        try:
            cur = client.files.get(name=name)
        except Exception as e:
            raise JudgeError(f"Gemini files.get failed: {e}") from e
    raise JudgeError(
        f"Gemini file did not become ACTIVE within {_UPLOAD_POLL_TIMEOUT_S}s"
    )


def _safe_delete(client: object, file_obj: object) -> None:
    name = getattr(file_obj, "name", None)
    if not name:
        return
    try:
        client.files.delete(name=name)
    except Exception:
        pass
