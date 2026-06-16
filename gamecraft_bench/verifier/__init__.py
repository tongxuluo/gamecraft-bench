"""Verifier package: replays demo traces against a Godot project, scores
the recording against a rubric, emits a final reward in [0, 1].

Top-level pieces:
- ``replay``: drives Godot under Xvfb, posts mouse/key events from a
  trace JSON, records to mp4.
- ``judges``: pluggable multimodal judge backends. Selected via
  ``GAMECRAFT_BENCH_JUDGE`` (see ``gamecraft_bench.config``).
- ``score``: glues a rubric, a list of demos, and a judge into a single
  per-task score.
- ``cli``: command-line entry point.
"""
