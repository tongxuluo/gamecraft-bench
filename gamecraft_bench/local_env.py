"""Local subprocess Harbor environment.

A drop-in replacement for the Docker environment that runs everything as
host subprocesses inside a per-trial **rootless mount namespace**.

Each session gets a runtime sandbox dir at
``$GAMECRAFT_BENCH_SANDBOX_ROOT/<session_id>`` or
``/tmp/gamecraft-bench-sandboxes/<session_id>``. The generated ``/workspace`` is
kept under the Harbor trial directory so it can be inspected next to the
logs without putting the whole sandbox tree under ``gamecraft-bench-jobs``.
Every ``exec()`` wraps the command in ``unshare --user --map-root-user
--mount --propagation private`` and bind-mounts the sandbox's
``workspace/``, ``tools/``, ``tests/``, ``solution/``, ``logs/`` subdirs
onto the container-style root paths the agent and verifier scripts expect
(``/workspace``, ``/tests``, ...). The mount namespace is private, so
multiple trials can run concurrently without their ``/tests`` /
``/workspace`` views colliding on the host.

Optional bind sources (``tests/``, ``solution/``, ``installed_agent/``)
are only mounted when they already exist in the sandbox at exec time.
Harbor populates those dirs only at the verifier phase; during the agent
phase the agent's namespace genuinely does not see them.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging
import os
import signal
import shlex
import shutil
import subprocess
from pathlib import Path

from harbor.environments.base import BaseEnvironment, ExecResult
from harbor.environments.capabilities import EnvironmentCapabilities
from harbor.models.task.config import EnvironmentConfig
from harbor.models.trial.paths import TrialPaths

from gamecraft_bench import config


class LocalSubprocessEnvironment(BaseEnvironment):
    """Run task commands as host subprocesses inside a sandbox dir."""

    def __init__(
        self,
        environment_dir: Path,
        environment_name: str,
        session_id: str,
        trial_paths: TrialPaths,
        task_env_config: EnvironmentConfig,
        logger: logging.Logger | None = None,
        sandbox_root: str | Path | None = None,
        **kwargs,
    ):
        # Pop kwargs we don't use to avoid surprising the base.
        kwargs.pop("override_cpus", None)
        kwargs.pop("override_memory_mb", None)
        kwargs.pop("override_storage_mb", None)
        kwargs.pop("override_gpus", None)
        kwargs.pop("suppress_override_warnings", None)
        kwargs.pop("extra_docker_compose", None)
        super().__init__(
            environment_dir=environment_dir,
            environment_name=environment_name,
            session_id=session_id,
            trial_paths=trial_paths,
            task_env_config=task_env_config,
            logger=logger,
            **kwargs,
        )

        # Runtime sandbox location preference order:
        #   1. explicit kwarg
        #   2. GAMECRAFT_BENCH_SANDBOX_ROOT env var (config.SANDBOX_ROOT)
        #   3. /tmp/gamecraft-bench-sandboxes/<session_id>
        # /workspace is special: keep it beside the trial logs so the
        # generated game can be inspected without VS Code/file watchers
        # traversing the runtime sandbox internals.
        # We always resolve to an absolute path so the subprocess shell
        # (which gets a resolved-absolute cwd) can interpret rewritten
        # commands consistently. Logging is filtered separately so user
        # paths don't end up in trial logs.
        if sandbox_root:
            self._sandbox = (Path(sandbox_root) / session_id).resolve()
        elif config.SANDBOX_ROOT is not None:
            self._sandbox = (config.SANDBOX_ROOT / session_id).resolve()
        else:
            self._sandbox = (Path("/tmp/gamecraft-bench-sandboxes") / session_id).resolve()
        self._workspace_host = (
            Path(trial_paths.trial_dir).resolve() / "sandbox" / "workspace"
        )
        self._sandbox.parent.mkdir(parents=True, exist_ok=True)
        self._sandbox.mkdir(parents=True, exist_ok=True)
        self._workspace_host.mkdir(parents=True, exist_ok=True)
        for sub in config.PATH_REWRITE_PATTERNS:
            self._host_path_for_prefix(sub).mkdir(parents=True, exist_ok=True)
        self._runtime_tmp = self._make_runtime_tmp()

        self.logger.info("Local subprocess sandbox: %s", self._short(self._sandbox))
        self.logger.info("Local subprocess workspace: %s", self._short(self._workspace_host))
        self._started = False
        self._watchdog_task: asyncio.Task | None = None
        self._active_exec_pids: set[int] = set()

    # ------------------------------------------------------------------
    # Required identity / capabilities
    # ------------------------------------------------------------------

    @staticmethod
    def type() -> str:
        return "local-subprocess"

    @property
    def capabilities(self) -> EnvironmentCapabilities:
        return EnvironmentCapabilities(mounted=True)

    # ------------------------------------------------------------------
    # Logging helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _short(path: str | os.PathLike) -> str:
        """Strip the repo root prefix off a path so trial.log doesn't
        record host-specific absolute paths (privacy + portability).
        Replaces all occurrences so command strings (which embed the path
        multiple times) are also scrubbed."""
        s = str(path)
        prefix = str(config.REPO_ROOT) + os.sep
        return s.replace(prefix, "")

    # ------------------------------------------------------------------
    # Path translation
    # ------------------------------------------------------------------

    def _to_host(self, path: str | os.PathLike) -> Path:
        """Translate a container-style absolute path into the sandbox dir.

        Used by file-transfer helpers (upload_file etc.) that need to
        resolve a container path to a host path *outside* the mount ns.
        Inside the ns, paths resolve directly via the bind mounts set up
        by ``_wrap_in_namespace``.
        """
        p = str(path)
        if not p.startswith("/"):
            return self._sandbox / p
        for prefix in config.PATH_REWRITE_PATTERNS:
            if p == prefix or p.startswith(prefix + "/"):
                root = self._host_path_for_prefix(prefix)
                return root / p[len(prefix):].lstrip("/")
        # Fallback: stash unknown absolute paths under sandbox/_root/...
        return self._sandbox / "_root" / p.lstrip("/")

    def _host_path_for_prefix(self, prefix: str) -> Path:
        if prefix == "/workspace":
            return self._workspace_host
        return self._sandbox / prefix.lstrip("/")

    def _make_runtime_tmp(self) -> Path:
        """Create the per-trial /tmp backing dir inside the runtime sandbox."""
        path = self._sandbox / "_tmp"
        path.mkdir(parents=True, exist_ok=True)
        os.chmod(path, 0o1777)
        return path

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def _validate_definition(self) -> None:
        # Nothing required - we don't read the Dockerfile.
        return

    @staticmethod
    def _preflight_unshare() -> None:
        """Verify that ``unshare --user --map-root-user --mount`` works.

        On hosts where unprivileged user namespaces are disabled
        (`kernel.unprivileged_userns_clone=0`, certain SELinux/AppArmor
        policies, or restricted seccomp), the wrapper would silently
        return rc=1/2 from every exec. Catch it here with a clear error.
        """
        try:
            r = subprocess.run(
                ["unshare", "--user", "--map-root-user", "--mount",
                 "bash", "-c", "mount --make-rprivate / && true"],
                capture_output=True, text=True, timeout=10,
            )
        except FileNotFoundError as e:
            raise RuntimeError(
                "`unshare` not found on PATH; install util-linux."
            ) from e
        except subprocess.TimeoutExpired as e:
            raise RuntimeError("unshare preflight timed out") from e
        if r.returncode != 0:
            raise RuntimeError(
                "Rootless user+mount namespace is not available on this host. "
                "LocalSubprocessEnvironment requires unprivileged user "
                "namespaces. Check `sysctl kernel.unprivileged_userns_clone` "
                "and any SELinux/AppArmor policy. "
                f"unshare stderr: {r.stderr.strip()!r}"
            )

    async def start(self, force_build: bool) -> None:
        # Preflight: rootless user-namespace + mount-namespace must
        # actually work on this host. If unprivileged userns is disabled
        # in the kernel, fail loud here instead of letting every later
        # exec() return rc=2 with no diagnostic.
        self._preflight_unshare()

        # /logs/{verifier,agent,artifacts} -> host trial dirs so writes like
        # /logs/verifier/reward.txt land where Harbor reads them. The symlinks
        # live in the runtime sandbox and resolve to the job directory through
        # the /logs bind mount.
        logs = self._sandbox / "logs"
        logs.mkdir(parents=True, exist_ok=True)
        for name, host_dir in (
            ("verifier", self.trial_paths.verifier_dir),
            ("agent", self.trial_paths.agent_dir),
            ("artifacts", self.trial_paths.artifacts_dir),
        ):
            link = logs / name
            Path(host_dir).mkdir(parents=True, exist_ok=True)
            if link.is_symlink() or link.exists():
                if link.is_symlink():
                    link.unlink()
                else:
                    shutil.rmtree(link)
            link.symlink_to(Path(host_dir).resolve())

        self._started = True
        self._populate_workspace_template()
        self._watchdog_task = asyncio.create_task(self._stuck_godot_watchdog())
        self.logger.info("Local subprocess env ready (sandbox=%s)", self._short(self._sandbox))

    # ------------------------------------------------------------------
    # Stuck-godot watchdog
    # ------------------------------------------------------------------
    #
    # Why this exists: agents routinely write `godot --headless ... --
    # --scenario X --quit-after 5` where `--quit-after` lands AFTER the
    # `--` separator. Engine flags after `--` are ignored (they go to
    # OS.get_cmdline_user_args() instead), so godot never quits and the
    # agent's Bash tool waits forever. The verifier's own godot calls
    # are bounded (build_check has subprocess timeout=60, replay_trace
    # caps total wall-clock at max_replay_seconds=90), so any godot
    # whose elapsed time exceeds STUCK_GODOT_KILL_SEC is by definition
    # not us — it's an agent invocation that hung. We SIGTERM only that
    # godot pid; the agent's shell sees a non-zero exit and recovers.
    STUCK_GODOT_KILL_SEC = 300
    WATCHDOG_POLL_SEC = 30

    async def _stuck_godot_watchdog(self) -> None:
        try:
            while True:
                await asyncio.sleep(self.WATCHDOG_POLL_SEC)
                self._kill_stuck_godot_once()
        except asyncio.CancelledError:
            return

    def _kill_stuck_godot_once(self) -> None:
        try:
            proc = subprocess.run(
                ["ps", "-eo", "pid,etimes,comm,args", "--no-headers"],
                capture_output=True, text=True, timeout=5,
            )
        except Exception as exc:  # noqa: BLE001
            self.logger.debug("watchdog ps failed: %s", exc)
            return
        for line in (proc.stdout or "").splitlines():
            parts = line.strip().split(None, 3)
            if len(parts) < 4:
                continue
            pid_s, etimes_s, comm, args = parts
            if "godot" not in comm:
                continue
            try:
                pid = int(pid_s); etimes = int(etimes_s)
            except ValueError:
                continue
            if etimes < self.STUCK_GODOT_KILL_SEC:
                continue
            self.logger.warning(
                "watchdog killing stuck godot pid=%d etime=%ds args=%s",
                pid, etimes, args,
            )
            try:
                os.kill(pid, 15)  # SIGTERM
            except ProcessLookupError:
                continue
            except Exception as exc:  # noqa: BLE001
                self.logger.warning("watchdog SIGTERM pid=%d failed: %s", pid, exc)

    def _populate_workspace_template(self) -> None:
        """Copy task-provided workspace templates (assets, starter scaffold,
        ...) into the host-backed /workspace. The task's root dir is one level
        above environment_dir.
        """
        task_root = self.environment_dir.parent
        sandbox_workspace = self._workspace_host
        sandbox_workspace.mkdir(parents=True, exist_ok=True)
        for name in config.WORKSPACE_TEMPLATE_DIRS:
            src = task_root / name
            if not src.is_dir():
                continue
            # Copy children of src directly into /workspace/ so that
            # `tasks/<task>/workspace/assets` lands at /workspace/assets,
            # not /workspace/workspace/assets.
            for child in src.iterdir():
                dst = sandbox_workspace / child.name
                if dst.exists():
                    if dst.is_dir():
                        shutil.rmtree(dst)
                    else:
                        dst.unlink()
                if child.is_dir():
                    shutil.copytree(child, dst)
                else:
                    shutil.copy2(child, dst)
        self.logger.info("Copied workspace template '%s' from %s into sandbox",
                         name, self._short(src))

    async def stop(self, delete: bool) -> None:
        for pid in list(self._active_exec_pids):
            await self._terminate_process_group(pid)

        if self._watchdog_task is not None:
            self._watchdog_task.cancel()
            try:
                await self._watchdog_task
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                pass
            self._watchdog_task = None

        self._started = False
        shutil.rmtree(self._runtime_tmp, ignore_errors=True)
        if delete and self._sandbox.exists():
            shutil.rmtree(self._sandbox, ignore_errors=True)

    # ------------------------------------------------------------------
    # File transfer
    # ------------------------------------------------------------------

    async def upload_file(self, source_path, target_path: str) -> None:
        dst = self._to_host(target_path)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(source_path), dst)

    async def upload_dir(self, source_dir, target_dir: str) -> None:
        dst = self._to_host(target_dir)
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(str(source_dir), dst)

    async def download_file(self, source_path: str, target_path) -> None:
        src = self._to_host(source_path)
        target_path = Path(target_path)
        target_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, target_path)

    async def download_dir(self, source_dir: str, target_dir) -> None:
        src = self._to_host(source_dir)
        target_dir = Path(target_dir)
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.copytree(src, target_dir)

    # ------------------------------------------------------------------
    # Exec
    # ------------------------------------------------------------------

    # Bind-mount plan inside each exec's private mount namespace.
    # Each entry: (sandbox_subdir, mount_target).
    # Sources that don't yet exist in the sandbox are skipped — that's how
    # we preserve the agent-phase invisibility of /tests and /solution
    # (Harbor only populates those during the verifier phase).
    _BIND_PLAN: tuple[tuple[str, str], ...] = (
        ("workspace",       "/workspace"),
        ("logs",            "/logs"),
        ("tests",           "/tests"),
        ("solution",        "/solution"),
        ("installed_agent", "/installed_agent"),
    )

    def _build_ns_command(self, inner_cmd: str, inner_cwd: str) -> list[str]:
        """Wrap ``inner_cmd`` in unshare --user --map-root-user --mount.

        Inside the namespace we make / private (so binds don't propagate
        out), bind-mount each sandbox subdir onto its container path,
        and finally exec the user's command. ``inner_cwd`` is a
        container-style absolute path (e.g. /workspace/game).
        """
        steps: list[str] = ["mount --make-rprivate /"]

        # 1. Top-level container paths: pre-create as host dirs (idempotent
        #    across trials), then bind sandbox subdirs onto them. The
        #    `mkdir -p` leaves an empty dir on the host fs; the bind
        #    overlays it inside the ns. Sources that don't exist yet in
        #    the sandbox are skipped — preserves the agent-phase
        #    invisibility of /tests and /solution.
        for sub, target in self._BIND_PLAN:
            src = self._workspace_host if sub == "workspace" else self._sandbox / sub
            steps.append(f"mkdir -p {shlex.quote(target)}")
            if not src.exists():
                continue
            steps.append(
                f"mount --bind {shlex.quote(str(src))} {shlex.quote(target)}"
            )

        # 2. Per-trial private /tmp. Keep the backing dir off the job tree:
        #    Xvfb creates UNIX sockets under /tmp/.X11-unix, and putting
        #    those sockets on the job tree's FUSE/quarkfs backing store can
        #    make stat/probe calls hang.
        self._runtime_tmp.mkdir(parents=True, exist_ok=True)
        steps.append(f"mount --bind {shlex.quote(str(self._runtime_tmp))} /tmp")

        # NOTE: godot user:// isolation is handled via XDG_DATA_HOME in
        # the merged env (see exec()), not via a bind mount. Earlier we
        # bound a per-trial dir over /root/.local/share/godot, but that
        # required hard-coding HOME=/root and only worked because the
        # venv's uv-managed python lives elsewhere under /root. The XDG
        # env var route works for any user/HOME and doesn't shadow
        # anything on disk.

        # 3. Shared read-only assets / tools. These mountpoints may live
        #    inside an already-bound dir (e.g. /workspace/assets/library
        #    inside the just-bound /workspace), so the mkdir must run
        #    AFTER the parent bind.
        for cfg_src, target in (
            (config.ASSET_LIBRARY,     config.ASSET_LIBRARY_MOUNTPOINT),
            (config.OGA_LIBRARY,       config.OGA_LIBRARY_MOUNTPOINT),
            (config.TOOLS_DIR,         config.TOOLS_MOUNTPOINT),
        ):
            if cfg_src is None:
                continue
            steps.append(f"mkdir -p {shlex.quote(target)}")
            steps.append(
                f"mount --bind -o ro {shlex.quote(str(cfg_src.resolve()))} {shlex.quote(target)}"
            )

        steps.append(f"cd {shlex.quote(inner_cwd)}")
        # Use `eval` rather than `exec` because the caller's command may
        # contain shell constructs (subshells, redirections, pipelines)
        # that `exec` rejects. eval re-parses through the shell. The bind
        # script itself doesn't trap on errors so each `&&` chains fine.
        steps.append(f"eval {shlex.quote(inner_cmd)}")

        bind_script = " && ".join(steps)
        return [
            "unshare", "--user", "--map-root-user", "--mount",
            "bash", "-c", bind_script,
        ]

    async def exec(
        self,
        command: str,
        cwd: str | None = None,
        env: dict[str, str] | None = None,
        timeout_sec: int | None = None,
        user: str | int | None = None,
    ) -> ExecResult:
        # Inside the namespace, container-style paths are real, so the
        # caller's command runs unmodified. cwd is taken as-is (defaulting
        # to /workspace when unspecified), with sandbox fallback if the
        # path doesn't exist inside the ns.
        inner_cwd = cwd if cwd else "/workspace"

        # Per-trial XDG_DATA_HOME so godot user:// (which resolves to
        # $XDG_DATA_HOME/godot/app_userdata/<project>/) lands in a
        # sandbox dir, not the shared host one. Picking XDG_DATA_HOME
        # over a bind mount keeps us free of HOME-path assumptions.
        xdg_data = self._sandbox / "_xdg_data"
        xdg_data.mkdir(parents=True, exist_ok=True)

        merged_env = os.environ.copy()
        merged_env["GAMECRAFT_BENCH_SANDBOX"] = str(self._sandbox)
        merged_env.update(config.env_for_subprocess())
        merged_env["GAME_PROJECT_PATH"] = config.GAME_PROJECT_PATH
        merged_env["XDG_DATA_HOME"] = str(xdg_data)
        if env:
            merged_env.update(env)

        argv = self._build_ns_command(command, inner_cwd)
        self.logger.debug("exec> %s (cwd=%s)", self._short(command), inner_cwd)

        proc = await asyncio.create_subprocess_exec(
            *argv,
            env=merged_env,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            start_new_session=True,
        )
        self._active_exec_pids.add(proc.pid)
        try:
            if timeout_sec:
                stdout_b, stderr_b = await asyncio.wait_for(
                    proc.communicate(), timeout=timeout_sec
                )
            else:
                stdout_b, stderr_b = await proc.communicate()
        except asyncio.TimeoutError:
            await self._terminate_process_group(proc.pid)
            stdout_b, stderr_b = await proc.communicate()
            return ExecResult(
                stdout=stdout_b.decode(errors="replace"),
                stderr=stderr_b.decode(errors="replace"),
                return_code=124,
            )
        except asyncio.CancelledError:
            await self._terminate_process_group(proc.pid)
            raise
        finally:
            self._active_exec_pids.discard(proc.pid)

        return ExecResult(
            stdout=stdout_b.decode(errors="replace") if stdout_b else None,
            stderr=stderr_b.decode(errors="replace") if stderr_b else None,
            return_code=proc.returncode or 0,
        )

    async def _terminate_process_group(
        self,
        pid: int,
        *,
        term_timeout: float = 5.0,
    ) -> None:
        with contextlib.suppress(ProcessLookupError):
            os.killpg(pid, signal.SIGTERM)
        deadline = asyncio.get_running_loop().time() + term_timeout
        while asyncio.get_running_loop().time() < deadline:
            try:
                os.killpg(pid, 0)
            except ProcessLookupError:
                return
            await asyncio.sleep(0.1)
        with contextlib.suppress(ProcessLookupError):
            os.killpg(pid, signal.SIGKILL)
