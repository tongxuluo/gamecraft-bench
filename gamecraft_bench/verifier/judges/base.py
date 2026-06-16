"""Multimodal judge ABC.

A judge takes a recording (video + sampled frames) and a *list* of
requirement descriptions for one demo, and returns a per-requirement
score in [0, 1] indicating how clearly each requirement is demonstrated.

Batching by demo (one call per demo, all requirements at once) keeps
vendor API costs and latency low. Each backend implementation lives in
a sibling module and is registered in ``__init__.py``.
"""

from __future__ import annotations

import abc
from dataclasses import dataclass, field
from pathlib import Path


class JudgeError(RuntimeError):
    """Raised when a judge cannot produce scores (missing key, API
    failure, malformed response, etc.). The verifier records the error
    and treats every requirement in the failed batch as 0 for that demo.
    """


@dataclass(frozen=True)
class RequirementSpec:
    """One requirement entry in a batch."""
    id: str
    description: str


@dataclass(frozen=True)
class JudgeRequest:
    """One scoring request: all requirements for a single demo."""
    demo_id: str
    video_path: Path
    frame_paths: list[Path]
    requirements: list[RequirementSpec]


@dataclass(frozen=True)
class JudgeResponse:
    """Scores for every requirement in the request, keyed by id."""
    scores: dict[str, float]                       # rid -> 0..1
    rationales: dict[str, str] = field(default_factory=dict)
    raw: str = ""                                  # raw model output, for the audit log


class MultimodalJudge(abc.ABC):
    """Base class for all backends.

    Subclasses must implement ``score()``. The constructor takes an
    optional ``model`` override; backends should fall back to their own
    sensible default when that is None.
    """

    name: str = "base"
    default_model: str = ""

    def __init__(self, *, model: str | None = None) -> None:
        self.model = model or self.default_model

    @abc.abstractmethod
    def score(self, request: JudgeRequest) -> JudgeResponse:
        """Return scores for every requirement in ``request``. Raise
        ``JudgeError`` to signal a hard failure (key missing, network
        down, response unparsable). Returning a response is the success
        path; missing requirement ids in ``response.scores`` are treated
        as 0 by the caller."""

    def __repr__(self) -> str:
        return f"{type(self).__name__}(model={self.model!r})"
