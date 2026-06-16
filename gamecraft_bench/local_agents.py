"""Local-friendly Harbor agent subclasses.

Harbor's stock ``ClaudeCode`` agent always runs an install step that pulls
``https://claude.ai/install.sh``. That URL is region-blocked from this
host, so Harbor aborts before the agent ever runs. The host already has
``claude`` on ``$PATH`` (system-wide nvm install), so the install step is
unnecessary - we skip it when the binary is already callable.

We also re-implement ``run()`` so we can retry on transient upstream API
errors. Proxies occasionally return 5xx/429, and some model gateways can
emit a spurious ``model_not_found`` 404 mid-trial even after earlier turns
for the same model succeeded. Claude prints the error as a final assistant
message and exits non-zero, so Harbor surfaces it as
``NonZeroAgentExitCodeError`` without ever retrying. We catch that, detect
the retryable API error in the log, and re-invoke claude with
``--resume <session-id>`` to continue from the last successful turn instead
of restarting from scratch.

Usage::

    harbor run --agent-import-path gamecraft_bench.local_agents:LocalClaudeCode
    harbor run --agent-import-path gamecraft_bench.local_agents:LocalCodex
    harbor run --agent-import-path gamecraft_bench.local_agents:LocalKimiCli
"""

from __future__ import annotations

import asyncio
import json
import os
import shlex

from harbor.agents.installed.base import (
    NonZeroAgentExitCodeError,
    with_prompt_template,
)
from harbor.agents.installed.claude_code import ClaudeCode
from harbor.agents.installed.codex import Codex
from harbor.agents.installed.kimi_cli import KimiCli
from harbor.environments.base import BaseEnvironment
from harbor.models.agent.context import AgentContext
from harbor.models.agent.name import AgentName
from harbor.models.trial.paths import EnvironmentPaths


_NON_INTERACTIVE_CLAUDE_PROMPT = (
    "Do not use Plan Mode, EnterPlanMode, ExitPlanMode, or AskUserQuestion. "
    "Implement directly and finish the requested files."
)


class LocalClaudeCode(ClaudeCode):
    """Claude Code that trusts a pre-installed ``claude`` CLI on PATH and
    retries the agent invocation on retryable upstream API errors via
    ``--resume``.
    """

    MAX_RETRIES = 3
    RETRY_BACKOFF_SEC = 60
    IDLE_TIMEOUT_SEC = 300  # kill claude if its log file goes silent this long

    @staticmethod
    def name() -> str:
        return AgentName.CLAUDE_CODE.value

    async def install(self, environment: BaseEnvironment) -> None:
        result = await environment.exec(
            command='export PATH="$HOME/.local/bin:$PATH"; command -v claude && claude --version',
        )
        stdout = (result.stdout or "") if result is not None else ""
        if result is not None and result.return_code == 0 and "claude" in stdout.lower():
            return
        await super().install(environment)

    @with_prompt_template
    async def run(
        self, instruction: str, environment: BaseEnvironment, context: AgentContext
    ) -> None:
        escaped_instruction = shlex.quote(instruction)

        env = self._build_claude_env()
        config_dir = env["CLAUDE_CONFIG_DIR"]

        setup_command = self._build_setup_command()
        await self.exec_as_agent(environment, command=setup_command, env=env)

        cli_flags = self.build_cli_flags()
        extra_flags = (cli_flags + " ") if cli_flags else ""
        log_path = (EnvironmentPaths.agent_dir / "claude-code.txt").as_posix()

        last_exc: NonZeroAgentExitCodeError | None = None
        for attempt in range(self.MAX_RETRIES):
            if attempt == 0:
                claude_cmd = self._build_claude_cmd(
                    extra_flags=extra_flags,
                    instruction_arg=f"-- {escaped_instruction}",
                    log_path=log_path,
                )
            else:
                session_id = await self._latest_session_id(environment, config_dir)
                if not session_id:
                    self.logger.warning(
                        "Cannot retry: no claude session id found under %s",
                        config_dir,
                    )
                    raise last_exc  # type: ignore[misc]
                resume_prompt = shlex.quote(
                    "Continue from where you left off. The previous turn was "
                    "interrupted by an upstream API error; resume the task."
                )
                claude_cmd = self._build_claude_cmd(
                    extra_flags=f"--resume {shlex.quote(session_id)} {extra_flags}",
                    instruction_arg=f"-- {resume_prompt}",
                    log_path=log_path,
                )
                self.logger.info(
                    "Retrying claude (attempt %d/%d) via --resume %s after backoff %ds",
                    attempt + 1,
                    self.MAX_RETRIES,
                    session_id,
                    self.RETRY_BACKOFF_SEC,
                )
                await asyncio.sleep(self.RETRY_BACKOFF_SEC)

            try:
                await self.exec_as_agent(environment, command=claude_cmd, env=env)
                return
            except NonZeroAgentExitCodeError as exc:
                last_exc = exc
                if not await self._claude_log_has_retryable_api_error(
                    environment, log_path
                ):
                    raise
                if attempt == self.MAX_RETRIES - 1:
                    self.logger.warning(
                        "claude failed with retryable API errors after %d attempts; giving up",
                        self.MAX_RETRIES,
                    )
                    raise

    def _build_claude_env(self) -> dict[str, str]:
        """Reproduce the env construction from ClaudeCode.run().

        Kept in sync with harbor.agents.installed.claude_code.ClaudeCode.run.
        """
        use_bedrock = self._is_bedrock_mode()

        env: dict[str, str | None] = {
            "ANTHROPIC_API_KEY": os.environ.get("ANTHROPIC_API_KEY")
            or os.environ.get("ANTHROPIC_AUTH_TOKEN")
            or "",
            "ANTHROPIC_BASE_URL": os.environ.get("ANTHROPIC_BASE_URL", None),
            "CLAUDE_CODE_OAUTH_TOKEN": os.environ.get("CLAUDE_CODE_OAUTH_TOKEN", ""),
            "CLAUDE_CODE_MAX_OUTPUT_TOKENS": os.environ.get(
                "CLAUDE_CODE_MAX_OUTPUT_TOKENS", None
            ),
            "FORCE_AUTO_BACKGROUND_TASKS": "0",
            "ENABLE_BACKGROUND_TASKS": "0",
        }

        if use_bedrock:
            env["CLAUDE_CODE_USE_BEDROCK"] = "1"
            bedrock_token = os.environ.get("AWS_BEARER_TOKEN_BEDROCK", "")
            if bedrock_token:
                env["AWS_BEARER_TOKEN_BEDROCK"] = bedrock_token
            for aws_var in (
                "AWS_ACCESS_KEY_ID",
                "AWS_SECRET_ACCESS_KEY",
                "AWS_SESSION_TOKEN",
                "AWS_PROFILE",
            ):
                val = os.environ.get(aws_var, "")
                if val:
                    env[aws_var] = val
            env["AWS_REGION"] = os.environ.get("AWS_REGION", "us-east-1")
            small_model_region = os.environ.get(
                "ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION", ""
            )
            if small_model_region:
                env["ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION"] = small_model_region
            if os.environ.get("DISABLE_PROMPT_CACHING", "").strip() == "1":
                env["DISABLE_PROMPT_CACHING"] = "1"

        env = {k: v for k, v in env.items() if v}

        if self.model_name:
            if use_bedrock:
                if "/" in self.model_name:
                    env["ANTHROPIC_MODEL"] = self.model_name.split("/", 1)[-1]
                else:
                    env["ANTHROPIC_MODEL"] = self.model_name
            elif "ANTHROPIC_BASE_URL" in env:
                env["ANTHROPIC_MODEL"] = self.model_name
            else:
                env["ANTHROPIC_MODEL"] = self.model_name.split("/")[-1]
        elif "ANTHROPIC_MODEL" in os.environ:
            env["ANTHROPIC_MODEL"] = os.environ["ANTHROPIC_MODEL"]

        if "ANTHROPIC_BASE_URL" in env and "ANTHROPIC_MODEL" in env:
            env["ANTHROPIC_DEFAULT_SONNET_MODEL"] = env["ANTHROPIC_MODEL"]
            env["ANTHROPIC_DEFAULT_OPUS_MODEL"] = env["ANTHROPIC_MODEL"]
            env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = env["ANTHROPIC_MODEL"]
            env["CLAUDE_CODE_SUBAGENT_MODEL"] = env["ANTHROPIC_MODEL"]

        if os.environ.get("CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING", "").strip() == "1":
            env["CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING"] = "1"

        env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"
        env["IS_SANDBOX"] = "1"

        env.update(self._resolved_env_vars)
        env["CLAUDE_CONFIG_DIR"] = (EnvironmentPaths.agent_dir / "sessions").as_posix()

        return {k: str(v) for k, v in env.items()}

    def _build_setup_command(self) -> str:
        setup_command = (
            "mkdir -p $CLAUDE_CONFIG_DIR/debug $CLAUDE_CONFIG_DIR/projects/-app "
            "$CLAUDE_CONFIG_DIR/shell-snapshots $CLAUDE_CONFIG_DIR/statsig "
            "$CLAUDE_CONFIG_DIR/todos $CLAUDE_CONFIG_DIR/skills && "
            "if [ -d ~/.claude/skills ]; then "
            "cp -r ~/.claude/skills/. $CLAUDE_CONFIG_DIR/skills/ 2>/dev/null || true; "
            "fi"
        )
        for extra in (
            self._build_register_skills_command(),
            self._build_register_memory_command(),
            self._build_register_mcp_servers_command(),
        ):
            if extra:
                setup_command += f" && {extra}"
        return setup_command

    @staticmethod
    def _build_claude_cmd(
        *, extra_flags: str, instruction_arg: str, log_path: str
    ) -> str:
        # tee -a so the log accumulates across retry attempts; each claude
        # invocation already emits a {"type":"system","subtype":"init",...}
        # event at the top of its stream, which delimits attempts unambiguously.
        return (
            'export PATH="$HOME/.local/bin:$PATH"; '
            f"claude --verbose --output-format=stream-json "
            f"--permission-mode=bypassPermissions "
            f"--disallowedTools EnterPlanMode,ExitPlanMode,AskUserQuestion "
            f"--append-system-prompt {shlex.quote(_NON_INTERACTIVE_CLAUDE_PROMPT)} "
            f"{extra_flags}"
            f"--print {instruction_arg} 2>&1 | tee -a {shlex.quote(log_path)}"
        )

    @staticmethod
    async def _claude_log_has_retryable_api_error(
        environment: BaseEnvironment, log_path: str
    ) -> bool:
        result = await environment.exec(
            command=(
                f"grep -iE 'API Error: 5[0-9]{{2}}|api_error_status.: ?(429|404)|"
                f"rate_limit|model_not_found' {shlex.quote(log_path)} "
                f"| tail -1 || true"
            ),
        )
        return bool((result.stdout or "").strip())

    @staticmethod
    async def _latest_session_id(
        environment: BaseEnvironment, config_dir: str
    ) -> str | None:
        cmd = (
            f"ls -t {shlex.quote(config_dir)}/projects/*/*.jsonl 2>/dev/null "
            f"| head -1"
        )
        result = await environment.exec(command=cmd)
        path = (result.stdout or "").strip().splitlines()
        if not path:
            return None
        basename = os.path.basename(path[0])
        if not basename.endswith(".jsonl"):
            return None
        return basename[: -len(".jsonl")]


class LocalCodex(Codex):
    """Codex that trusts a pre-installed ``codex`` CLI on PATH and retries
    the agent invocation on upstream 5xx errors."""

    MAX_RETRIES = 3
    RETRY_BACKOFF_SEC = 60

    @staticmethod
    def name() -> str:
        return AgentName.CODEX.value

    async def install(self, environment: BaseEnvironment) -> None:
        result = await environment.exec(
            command="command -v codex && codex --version",
        )
        stdout = (result.stdout or "") if result is not None else ""
        if result is not None and result.return_code == 0 and "codex" in stdout.lower():
            return
        await super().install(environment)

    @with_prompt_template
    async def run(
        self, instruction: str, environment: BaseEnvironment, context: AgentContext
    ) -> None:
        last_exc: NonZeroAgentExitCodeError | None = None
        for attempt in range(self.MAX_RETRIES):
            if attempt > 0:
                self.logger.info(
                    "Retrying codex (attempt %d/%d) after backoff %ds",
                    attempt + 1,
                    self.MAX_RETRIES,
                    self.RETRY_BACKOFF_SEC,
                )
                await asyncio.sleep(self.RETRY_BACKOFF_SEC)
            try:
                await Codex.run(self, instruction, environment, context)
                return
            except NonZeroAgentExitCodeError as exc:
                last_exc = exc
                log_path = EnvironmentPaths.agent_dir / "codex.txt"
                if not await self._codex_log_has_5xx(environment, log_path.as_posix()):
                    raise
                if attempt == self.MAX_RETRIES - 1:
                    self.logger.warning(
                        "codex failed with upstream 5xx after %d attempts; giving up",
                        self.MAX_RETRIES,
                    )
                    raise

    @staticmethod
    async def _codex_log_has_5xx(
        environment: BaseEnvironment, log_path: str
    ) -> bool:
        result = await environment.exec(
            command=(
                f"grep -iE '5[0-9]{{2}}|server.error|internal.error' "
                f"{shlex.quote(log_path)} | tail -1 || true"
            ),
        )
        return bool((result.stdout or "").strip())


class LocalKimiCli(KimiCli):
    """Kimi Code CLI that trusts a pre-installed ``kimi`` binary on PATH.

    Harbor's stock KimiCli install step downloads uv and installs kimi-cli
    inside the environment. On this benchmark host, ``kimi`` is already
    installed under ``~/.local/bin``, so using it directly avoids a networked
    setup phase before every run.
    """

    _DEFAULT_MAX_CONTEXT_SIZE = 262144

    def __init__(self, *args, thinking: bool | str = True, **kwargs):
        self._thinking = self._coerce_bool(thinking)
        super().__init__(*args, **kwargs)

    @staticmethod
    def name() -> str:
        return AgentName.KIMI_CLI.value

    def get_version_command(self) -> str | None:
        return 'export PATH="$HOME/.local/bin:$PATH"; kimi --version'

    @staticmethod
    def _coerce_bool(value: bool | str) -> bool:
        if isinstance(value, bool):
            return value
        return value.strip().lower() not in {"0", "false", "no", "off", "disabled"}

    def _build_config_json(self, provider: str, model: str) -> str:
        config = json.loads(super()._build_config_json(provider, model))
        config["default_thinking"] = self._thinking
        return json.dumps(config)

    async def install(self, environment: BaseEnvironment) -> None:
        result = await environment.exec(
            command=(
                'export PATH="$HOME/.local/bin:$PATH"; '
                "command -v kimi && kimi --version"
            ),
        )
        stdout = (result.stdout or "") if result is not None else ""
        if result is not None and result.return_code == 0 and "kimi" in stdout.lower():
            return
        await super().install(environment)
