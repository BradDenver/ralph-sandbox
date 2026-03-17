# Sandbox Ralph — Spike Results

All spikes run against Docker Desktop with `docker sandbox` CLI v0.12+.

---

## Spike 1: Docker Sandbox Exec — ALL PASS

**Questions tested:**

| # | Question | Result |
|---|----------|--------|
| S1-Q1 | Does `docker sandbox exec -it <name> bash` give an interactive shell? | ✅ PASS |
| S1-Q2 | Can tmux run inside a Docker sandbox microVM? | ✅ PASS |
| S1-Q3 | Can we start a detached tmux session via exec? | ✅ PASS |
| S1-Q4 | Can we attach to that tmux session from a second exec call? | ✅ PASS |

**Findings:**
- `docker sandbox create` auto-starts the microVM — no separate `run` needed before `exec`
- Non-interactive and shell exec both work (user=agent, pwd=/home/agent/workspace)
- tmux not pre-installed in `shell` template but installs fine via apt
- Detached tmux sessions work — can create, send-keys, and attach from second terminal

**Gotcha:** `((PASS++))` with `set -e` causes script exit when PASS=0 (bash treats `((0++))` as returning exit code 1). Fixed by using `PASS=$((PASS + 1))`.

---

## Spike 2: Workspace and File Sync — PARTIAL

| # | Question | Result |
|---|----------|--------|
| S2-Q1 | Files visible at same absolute path inside sandbox? | ✅ PASS |
| S2-Q2 | Nested directories work? | ✅ PASS |
| S2-Q3 | Sandbox → host changes sync in real-time? | ✅ PASS |
| S2-Q4 | New host files appear inside sandbox? | ✅ PASS |
| S2-Q5 | Host edits to existing files sync to sandbox? | ❌ FAIL |
| S2-Q6 | Multiple workspace paths in create command? | ❌ FAIL |
| S2-Q7 | Stdin piping via exec? | ❌ FAIL |

**Critical finding:** Edits to files that existed when the sandbox was created do NOT propagate into the sandbox, despite docs claiming bidirectional sync. Tested with delays up to 20 seconds — never syncs. New files created on the host DO appear inside the sandbox.

**Implication:** Plan files must exist before sandbox creation (normal workflow). If you edit the PRD on the host while a sandbox is running, the sandbox won't see it — must recreate the sandbox. This is fine for ralph-once: the sandbox itself updates prd.json, and those changes sync back to the host in real-time.

---

## Spike 3: Custom Template Workflow — ALL PASS

| # | Question | Result |
|---|----------|--------|
| S3-Q1 | Does `-t` flag work with locally-built image? | ✅ PASS |
| S3-Q2 | Is the custom template actually used (not silently ignored)? | ✅ PASS (marker file confirmed) |
| S3-Q3 | Does tmux pre-installed via Dockerfile work? | ✅ PASS |
| S3-Q4 | Does the entrypoint script run on creation? | ✅ PASS |
| S3-Q5 | Does `docker sandbox save` exist? | ✅ PASS |
| S3-Q6 | Where is the claude binary? | `/home/agent/.local/bin/claude` |
| S3-Q7 | Does `docker sandbox stop` exist? | ✅ PASS (stop without removing) |

**Findings:**
- `docker sandbox create --name X -t my-template:latest claude <path>` works correctly
- Marker file in template confirmed the custom image is actually used
- Entrypoint runs — plugin files copied from `/opt/` staging to `~/.claude/`
- Claude binary at `/home/agent/.local/bin/claude` (from base image)

---

## Spike 4: Claude Inside Sandbox — PASS (with auth constraint)

| # | Question | Result |
|---|----------|--------|
| S4-Q1 | Claude found and runnable? | ✅ PASS — `/home/agent/.local/bin/claude`, version 2.1.1 |
| S4-Q2 | `--permission-mode acceptEdits` recognized? | ✅ PASS (also: `bypassPermissions`, `default`, `delegate`, `dontAsk`, `plan`) |
| S4-Q3 | Auth via browser login? | ✅ PASS — `docker sandbox run` + browser login, token persists |
| S4-Q4 | Can exec reuse auth after login? | ✅ PASS — exec works without re-authenticating |
| S4-Q5 | Network access in sandbox? | ❌ RESTRICTED — apt-get cannot reach package repos |

**Auth workflow:** Interactive browser login via `docker sandbox run` works. Auth token persists in the sandbox and `docker sandbox exec` can use claude without re-authenticating. NOT tested: whether `ANTHROPIC_API_KEY` env var passes through (would enable fully headless workflows). Only browser OAuth path is proven.

**Network restriction:** The `claude` agent sandbox type restricts network access. `apt-get` cannot reach package repos at runtime. Dependencies must be baked into the custom template image.

**Gotchas:**
- `timeout` command not available on macOS — had to use background process + manual poll/kill
- apt lock held by background process on sandbox startup — needed `wait_for_apt` helper
- `bash -c 'claude ...'` fails because non-login shell doesn't have `/home/agent/.local/bin/` in PATH — must use full path
- `context canceled` output when claude process is killed mid-execution (not an error, just killed)
- `/tmp` cannot be used as workspace path — "file sharing directories are invalid"

---

## End-to-End Interactive Test — PASS

Full Shape A workflow verified manually:
1. Built custom template (claude-code base + tmux)
2. Created sandbox with `-t` custom template
3. Authenticated via `docker sandbox run` + browser login
4. From host, kicked off Claude in detached tmux inside sandbox
5. Attached interactively from second terminal
6. Successfully interacted with the Claude session running inside the sandbox

This proved the core mechanism. Shape D refines it by moving tmux to the host for simpler interaction and monitoring.

---

## Spike 5: claude update Inside Sandbox — MISLEADING (revised)

| # | Question | Result |
|---|----------|--------|
| S5-Q1 | Does `claude update` command exist? | ✅ PASS |
| S5-Q2 | Can it reach the update server (despite sandbox network restrictions)? | ⚠️ MISLEADING |
| S5-Q3 | Does it report success? | ⚠️ MISLEADING — only tested "already up to date" path |

**Original finding (incorrect):** Reported ALL PASS — `claude update` appeared to work inside the sandbox.

**Revised finding:** The spike ran against a sandbox that already had the latest version (2.1.74). `claude update` checked, found nothing to do, and returned "already up to date" immediately. The spike **never tested an actual upgrade**. When tested against a sandbox with an older version (2.1.1), `claude update` hangs indefinitely because the base image's install method is "unknown".

**Root cause:** The `docker/sandbox-templates:claude-code` base image installs Claude Code in a way that leaves the install method config as "unknown". The `claude update` command doesn't know how to perform the update and hangs at "Checking for updates...".

**Actual solution:** Reinstall Claude Code via the native installer (`curl -fsSL https://claude.ai/install.sh | bash`) during the Docker build. This bakes in the latest version and sets up proper install config. The `sandbox:build` command uses `--no-cache` to ensure the installer always fetches the latest version.

**Post-fix confirmation:** After rebuilding with the native installer, `claude update` works correctly at runtime inside the sandbox (version 2.1.74 confirmed). The native installer sets the install method properly, so future runtime updates are viable. The build-time install remains the primary mechanism, but `claude update` is no longer broken.

---

## Spike 6: `exec` vs `run` File Sync — Manual Testing

| # | Question | Result |
|---|----------|--------|
| S6-Q1 | Is workspace empty via `docker sandbox exec`? | ✅ CONFIRMED — `ls /home/agent/workspace/` returns empty |
| S6-Q2 | Is workspace populated via `docker sandbox run`? | ✅ CONFIRMED — files visible, `/ralph-once` can read plan files |
| S6-Q3 | Does `exec` work for non-workspace operations? | ✅ PASS — `ls /home/agent/` shows `bin` and `workspace` dirs, auth status works |

**Tested against:** `ralph-meq-insights-v2-web` sandbox, `claude` agent type, with `ralph-template:latest` custom image.

**Key finding:** `docker sandbox exec` does NOT activate file sync for `claude` type sandboxes. The `/home/agent/workspace/` directory exists but is empty. `docker sandbox run` activates file sync — all workspace files are visible. This is the fundamental issue that broke Shape D.

**Implication:** `exec` is still useful for utility commands (auth status, writing config to `~/.claude/`), but any operation that needs workspace files must use `run`.

---

## Spike 7: File Sync via `run` — Manual Testing

| # | Question | Result |
|---|----------|--------|
| S7-Q1 | Host files visible inside sandbox via `run`? | ✅ PASS — plan files, source code, all visible |
| S7-Q2 | Sandbox-created files appear on host? | ✅ PASS — file created inside sandbox via `-p` prompt appeared on host |
| S7-Q3 | `/ralph-once` can read and execute against plan files? | ✅ PASS — ran successfully against `ins-1160-projects-list` plan |
| S7-Q4 | Host edits to existing files visible in sandbox? | ✅ PASS — edited file on host, sandbox saw the change via `run` |

**Key difference from Spike 2:** Spike 2 found that host edits to existing files did NOT sync via `exec` on `shell` type sandboxes. With `run` on `claude` type sandboxes, host edits DO sync. This means `sandbox:rebuild` may not be needed for Shape E — editing plan files on the host while the sandbox exists should just work.

---

## Spike 8: `docker sandbox run` in tmux — Manual Testing

| # | Question | Result |
|---|----------|--------|
| S8-Q1 | Can `run ... -- args` launch inside detached tmux? | ✅ PASS |
| S8-Q2 | Can we capture output via `tmux capture-pane`? | ✅ PASS |
| S8-Q3 | Can we attach and interact with the Claude session? | ✅ PASS |
| S8-Q4 | Does the error trap keep the pane alive on failure? | ✅ PASS |

**Launch command that works:**
```bash
tmux new-session -d -s ralph-once \
  "docker sandbox run ralph-<name> \
   -- --permission-mode acceptEdits \
   '/ralph-once <plan-name>' \
   || { echo '--- RALPH-ONCE FAILED ---'; sleep 300; }"
```

**Key findings:**
- `docker sandbox run ... --` passes args after `--` to the Claude agent
- Works inside tmux — session stays alive, attachable, capture-pane works
- `-p` flag is print-and-exit mode, not suitable for interactive sessions
- Positional arg after `--` starts an interactive session with the prompt
- `--append-system-prompt-file` can load extra context but isn't needed when `/ralph-once` command is available in the sandbox
- `-it` flag not needed (and causes issues in tmux)

**Also confirmed:**
- Image reference needs `docker.io/library/` prefix in some Docker Desktop configs, or just use the full tag
- Auth persists across `run` invocations for the same sandbox (but lost on `sandbox rm` + recreate)
- Empty `capture-pane` output is normal during first ~30s of startup

---

## Spike 9: PreToolUse Hook for Auto-Approving Commands — PASS

| # | Question | Result |
|---|----------|--------|
| S9-Q1 | Can a plugin ship a `hooks/hooks.json` file? | ✅ PASS — auto-discovered by Claude Code |
| S9-Q2 | Does the PreToolUse hook receive bash commands and return allow decisions? | ✅ PASS |
| S9-Q3 | Do auto-approved commands run without permission prompts? | ✅ PASS |
| S9-Q4 | Do non-matching commands still go through normal permission handling? | ✅ PASS |

**Implementation:** Plugin ships `hooks/hooks.json` registering a `PreToolUse` hook with `"matcher": "Bash"`. The hook script (`hooks/approve-ralph-commands.sh`) reads the command from stdin JSON, checks against allowlist patterns (docker sandbox, tmux, ls, cat, pwd, etc.), and returns `{"permissionDecision": "allow"}` for matches. Non-matching commands fall through to normal handling.

**Key finding:** `${CLAUDE_PLUGIN_ROOT}` works as an env variable in the hook command path, resolving to the plugin's install directory. The `hooks/hooks.json` file is auto-discovered — no need to reference it in plugin.json.

**Implication:** The dead `settings.permissions.allow` block in plugin.json (which was silently ignored) can be replaced entirely by the hook. This is the correct way for plugins to manage permissions.
