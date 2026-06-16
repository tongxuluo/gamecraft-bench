"""Centralized configuration for GameCraft-Bench.

All user-tunable paths and defaults are concentrated here. Each setting is
read from an environment variable so it can be overridden at runtime
without touching code or task definitions.

Anything in this module is also the source of truth for the README's
"Configuration" table - keep them in sync.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

# Repository root. Computed relative to this file so it works regardless
# of how the package is imported.
REPO_ROOT: Path = Path(__file__).resolve().parent.parent


def _env(name: str, default: str | None = None) -> str | None:
    """Read an environment variable with no legacy-name fallback."""
    value = os.environ.get(name)
    if value:
        return value
    return default


def _path_from_env(name: str, default: Path | None) -> Path | None:
    """Read a path from $name. Relative paths are resolved against REPO_ROOT
    so the same .env works no matter what cwd the process started in."""
    raw = _env(name)
    if not raw:
        return default
    p = Path(raw)
    return p if p.is_absolute() else (REPO_ROOT / p).resolve()

# ---------------------------------------------------------------------------
# Tunables (env-var driven)
# ---------------------------------------------------------------------------

# Path to the Godot 4 binary. Verifier tests skip Godot-dependent checks
# when this is None or unresolvable.
GODOT_BIN: str | None = _env("GAMECRAFT_BENCH_GODOT_BIN") or shutil.which("godot")

# Where LocalSubprocessEnvironment puts per-session sandbox dirs. Each trial
# gets its own subdir (named after the session id). Cleaned up on stop().
# When None, the env class places the runtime sandbox under /tmp while
# keeping /workspace at <trial_dir>/sandbox/workspace for inspection next
# to the trial logs.
SANDBOX_ROOT: Path | None = _path_from_env("GAMECRAFT_BENCH_SANDBOX_ROOT", None)

# pytest binary used by tests/test.sh. Empty / "pytest" means rely on PATH.
# Set this if you need to point at a specific venv's pytest.
PYTEST_BIN: str = _env("GAMECRAFT_BENCH_PYTEST_BIN", "pytest") or "pytest"

# Container-style absolute path the agent must produce its game project at.
# This is the contract between instruction.md, solve.sh, and the verifier
# tests. Override only if you also update those files together.
GAME_PROJECT_PATH: str = os.environ.get("GAME_PROJECT_PATH", "/workspace/game")

# Absolute paths the LocalSubprocessEnvironment will redirect to its sandbox
# by symlinking from the host filesystem root. The set must include every
# container-style absolute path that task scripts hardcode. The first five
# are Harbor's contracts (Verifier and Trial code expect these to exist
# at known locations); the asset-library and tools mountpoints get added
# automatically below.
PATH_REWRITE_PATTERNS: tuple[str, ...] = (
    "/workspace",
    "/tests",
    "/logs",
    "/solution",
    "/installed_agent",
)

# Subdirs of a task that are copied into the sandbox's /workspace at env
# start, providing the agent with starter assets / scaffold. Convention
# parallels proposal.md §3 (assets/, starter/). Override with
# `GAMECRAFT_BENCH_WORKSPACE_TEMPLATE_DIRS` (comma-separated).
WORKSPACE_TEMPLATE_DIRS: tuple[str, ...] = tuple(
    d.strip()
    for d in (_env("GAMECRAFT_BENCH_WORKSPACE_TEMPLATE_DIRS", "workspace") or "workspace").split(",")
    if d.strip()
)

# Shared read-only asset library (Kenney CC0 packs etc.) exposed to every
# task at /workspace/assets/library/. Populated by `scripts/fetch_assets.py`.
# Set to empty string to disable.
ASSET_LIBRARY: Path | None = _path_from_env(
    "GAMECRAFT_BENCH_ASSET_LIBRARY", REPO_ROOT / "assets" / "library"
)
if ASSET_LIBRARY is not None and not ASSET_LIBRARY.exists():
    ASSET_LIBRARY = None  # treat missing dir as disabled

# Where the asset library is exposed inside the sandbox (container view).
ASSET_LIBRARY_MOUNTPOINT: str = (
    _env("GAMECRAFT_BENCH_ASSET_LIBRARY_MOUNTPOINT", "/workspace/assets/library")
    or "/workspace/assets/library"
)

# Second asset library: OpenGameArt CC0/CC-BY entries. Populated by
# `scripts/fetch_oga_assets.py`. Kept separate from the Kenney pool so the
# agent can see provenance and the licenses (CC0 vs CC-BY 4.0) per dir.
OGA_LIBRARY: Path | None = _path_from_env(
    "GAMECRAFT_BENCH_OGA_LIBRARY", REPO_ROOT / "assets" / "library-oga"
)
if OGA_LIBRARY is not None and not OGA_LIBRARY.exists():
    OGA_LIBRARY = None

# Where the OGA library is exposed inside the sandbox (container view).
OGA_LIBRARY_MOUNTPOINT: str = (
    _env("GAMECRAFT_BENCH_OGA_LIBRARY_MOUNTPOINT", "/workspace/assets/library-oga")
    or "/workspace/assets/library-oga"
)

# Shared GDScript / shell helpers exposed at /tools/ inside the sandbox
# (e.g. screenshot.gd). Sourced from the repo's `tools/` dir.
TOOLS_DIR: Path | None = _path_from_env("GAMECRAFT_BENCH_TOOLS_DIR", REPO_ROOT / "tools")
if TOOLS_DIR is not None and not TOOLS_DIR.exists():
    TOOLS_DIR = None

# Where the tools dir is exposed inside the sandbox (container view).
TOOLS_MOUNTPOINT: str = _env("GAMECRAFT_BENCH_TOOLS_MOUNTPOINT", "/tools") or "/tools"

# ---------------------------------------------------------------------------
# Verifier judge selection
# ---------------------------------------------------------------------------

# Which multimodal judge backend the verifier uses to score requirements.
# Recognised values: claude, opus, kimi, openai, gemini, stub.
# Defaults to openai (frame-sampling chat completions); set to "stub" in
# .env to bypass the network entirely.
JUDGE_BACKEND: str = (_env("GAMECRAFT_BENCH_JUDGE", "openai") or "openai").strip().lower()

# Model id passed to the chosen backend. Each backend has its own default
# (defined in gamecraft_bench/verifier/judges); this overrides it.
JUDGE_MODEL: str | None = _env("GAMECRAFT_BENCH_JUDGE_MODEL") or None


def _top_level(path: str) -> str | None:
    """Return the first path segment of an absolute path, e.g. /a/b -> /a."""
    if not path.startswith("/"):
        return None
    parts = path.strip("/").split("/", 1)
    return "/" + parts[0] if parts and parts[0] else None


# Make sure the asset-library and tools mountpoints are reachable through
# our path rewriting even if the user sets them to a directory outside the
# default PATH_REWRITE_PATTERNS list.
for _mp in (ASSET_LIBRARY_MOUNTPOINT, OGA_LIBRARY_MOUNTPOINT, TOOLS_MOUNTPOINT):
    _top = _top_level(_mp)
    if _top and _top not in PATH_REWRITE_PATTERNS:
        PATH_REWRITE_PATTERNS = PATH_REWRITE_PATTERNS + (_top,)


def env_for_subprocess() -> dict[str, str]:
    """Env vars to inject into every subprocess spawned by an env's exec().

    The custom Harbor environment surfaces these into the agent / verifier
    process so test scripts can read them without any wiring.
    """
    e: dict[str, str] = {
        "GAME_PROJECT_PATH": GAME_PROJECT_PATH,
        "GODOT_SILENCE_ROOT_WARNING": os.environ.get("GODOT_SILENCE_ROOT_WARNING", "1"),
    }
    if GODOT_BIN:
        e["GAMECRAFT_BENCH_GODOT_BIN"] = GODOT_BIN
    if PYTEST_BIN:
        e["GAMECRAFT_BENCH_PYTEST_BIN"] = PYTEST_BIN
    # Forward the verifier judge selection so the test script in the
    # sandbox uses the same backend / model as the host config.
    e["GAMECRAFT_BENCH_JUDGE"] = JUDGE_BACKEND
    if JUDGE_MODEL:
        e["GAMECRAFT_BENCH_JUDGE_MODEL"] = JUDGE_MODEL
    # Vendor API keys / base-url overrides. Standard names so users can
    # source a single .env and use the same vars as any other tool. Only
    # forward what is actually set; leave everything else unset.
    #
    # Use GAMECRAFT_BENCH_JUDGE_* when the judge needs a different key/url
    # than the agent.
    for var in (
        "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
        "OPENAI_API_KEY", "OPENAI_BASE_URL", "OPENAI_EXTRA_HEADERS_JSON",
        "KIMI_API_KEY", "KIMI_BASE_URL",
        "MOONSHOT_API_KEY", "MOONSHOT_BASE_URL",
        "GEMINI_API_KEY", "GOOGLE_API_KEY", "GEMINI_BASE_URL",
        "GAMECRAFT_BENCH_JUDGE_ANTHROPIC_API_KEY",
        "GAMECRAFT_BENCH_JUDGE_ANTHROPIC_AUTH_TOKEN",
        "GAMECRAFT_BENCH_JUDGE_ANTHROPIC_BASE_URL",
        "GAMECRAFT_BENCH_JUDGE_OPENAI_API_KEY",
        "GAMECRAFT_BENCH_JUDGE_OPENAI_BASE_URL",
        "GAMECRAFT_BENCH_JUDGE_MOONSHOT_API_KEY",
        "GAMECRAFT_BENCH_JUDGE_MOONSHOT_BASE_URL",
        "GAMECRAFT_BENCH_JUDGE_GEMINI_API_KEY",
        "GAMECRAFT_BENCH_JUDGE_GOOGLE_API_KEY",
        "GAMECRAFT_BENCH_JUDGE_GEMINI_BASE_URL",
    ):
        val = _env(var)
        if val:
            e[var] = val
    return e
