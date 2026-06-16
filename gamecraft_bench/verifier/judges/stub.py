"""Stub judge: returns a deterministic constant score per requirement.

Useful for end-to-end pipeline testing when no API key is available, or
when iterating on the verifier itself. Score defaults to 1.0 so an
oracle solution can hit a perfect reward; override via
``GAMECRAFT_BENCH_JUDGE_MODEL`` (parsed as a float).
"""

from __future__ import annotations

from .base import JudgeRequest, JudgeResponse, MultimodalJudge


class StubJudge(MultimodalJudge):
    name = "stub"
    default_model = "1.0"

    def __init__(self, *, model: str | None = None) -> None:
        super().__init__(model=model)
        try:
            self._fixed_score = float(self.model)
        except ValueError:
            self._fixed_score = 1.0
        self._fixed_score = max(0.0, min(1.0, self._fixed_score))

    def score(self, request: JudgeRequest) -> JudgeResponse:
        scores = {r.id: self._fixed_score for r in request.requirements}
        rationales = {
            r.id: f"stub judge returning fixed score {self._fixed_score}"
            for r in request.requirements
        }
        return JudgeResponse(
            scores=scores,
            rationales=rationales,
            raw=f"stub:{self._fixed_score}",
        )
