"""Pluggable multimodal judge backends.

Each backend is a subclass of ``MultimodalJudge`` and is responsible for
turning ``(video_path, frame_paths, prompt) -> float in [0, 1]`` for a
single requirement.

The active backend is chosen at import time by ``get_judge()`` based on
``gamecraft_bench.config.JUDGE_BACKEND``. Adding a new backend means: drop a
file in this package, register it in ``_REGISTRY`` below.
"""

from __future__ import annotations

from ... import config as cfg
from .base import JudgeError, MultimodalJudge

# Registry maps the lowercase backend name (env var value) to its
# implementation class. Imports are lazy so a missing optional SDK only
# blows up if someone actually selects that backend.

_REGISTRY: dict[str, str] = {
    "stub":    "gamecraft_bench.verifier.judges.stub:StubJudge",
    "claude":  "gamecraft_bench.verifier.judges.claude:ClaudeJudge",
    "opus":    "gamecraft_bench.verifier.judges.claude:ClaudeOpusJudge",
    "kimi":    "gamecraft_bench.verifier.judges.kimi:KimiJudge",
    "openai":  "gamecraft_bench.verifier.judges.openai_gpt:OpenAIJudge",
    "gemini":  "gamecraft_bench.verifier.judges.gemini:GeminiJudge",
}


def _import_class(spec: str) -> type[MultimodalJudge]:
    module_path, _, name = spec.partition(":")
    mod = __import__(module_path, fromlist=[name])
    return getattr(mod, name)


def get_judge(backend: str | None = None, model: str | None = None) -> MultimodalJudge:
    """Construct the configured judge. Falls back to ``cfg.JUDGE_BACKEND``
    / ``cfg.JUDGE_MODEL`` when args are omitted."""
    name = (backend or cfg.JUDGE_BACKEND).strip().lower()
    if name not in _REGISTRY:
        raise JudgeError(
            f"unknown judge backend {name!r}; known: {sorted(_REGISTRY)}"
        )
    cls = _import_class(_REGISTRY[name])
    return cls(model=model or cfg.JUDGE_MODEL)


__all__ = ["MultimodalJudge", "JudgeError", "get_judge"]
