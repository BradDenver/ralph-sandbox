---
shaping: true
---

# Sandbox Ralph — Shaping

## Frame

**Source:** Brad has a working "Ralph Wiggum technique" — plan-driven Claude development where Claude executes tasks from a prd.json one at a time, with promise tags for iteration control. This currently runs inside a Docker sandbox via a custom template (`ralph-sandbox`). The Docker sandbox CLI has changed significantly since the original implementation, so all the old commands need verification.

**Problem:** Brad wants to run Claude "raw" on his local machine (minimal setup, always latest version) but trigger sandboxed ralph-once sessions via a skill/command when needed. Currently there's no clean way to go from "I'm in a local Claude session with a PRD ready" to "ralph-once is running in a sandbox and I can interact with it."

**Outcome:** A Claude Code skill on the host machine that orchestrates Docker sandbox lifecycle and ralph-once sessions, with tmux-based interaction when the user wants to get hands-on.

---

## Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| R0 | From a local Claude session, trigger a ralph-once session that runs inside a Docker sandbox | Core goal |
| R1 | Sandbox comes preloaded with the ralph plugin (commands, skills, agents, rules) | Must-have |
| R2 | Can interact with the running ralph-once session when needed (tmux is acceptable extra step) | Must-have |
| R3 | Minimal Claude Code setup on host — just the orchestration skill, no heavy plugin installation | Must-have |
| R4 | Sandbox gets Claude Code updates naturally — not pinned to a version baked into a Docker image | Nice-to-have |
| R5 | Works with current Docker sandbox CLI (`docker sandbox create/run/exec/ls/rm`) | Must-have |
| R6 | Everything must be proven to work — no trusting docs at face value | Must-have |
| R7 | The PRD/plan files on the host are accessible inside the sandbox | Must-have |

---

## Shapes

### A: Custom Template + Exec Orchestration

Build a custom Docker image (like the current ralph-sandbox) but updated for the new `docker sandbox` CLI. The host skill manages lifecycle and kicks off ralph-once via `docker sandbox exec`.

| Part | Mechanism | Flag |
|------|-----------|:----:|
| A1 | Custom Dockerfile extending `docker/sandbox-templates:claude-code` that pre-installs ralph plugin + tmux | |
| A2 | Host skill checks sandbox state via `docker sandbox ls`, creates with `docker sandbox create --name ralph --template <custom-image> claude <workspace>` if needed | ✅ proven |
| A3 | Host skill starts ralph-once inside sandbox: `docker sandbox exec ralph tmux new-session -d -s ralph-once 'claude "<ralph-prompt>"'` | ✅ proven |
| A4 | User interacts via: `docker sandbox exec -it ralph tmux attach -t ralph-once` | ✅ proven |
| A5 | Ralph-once prompt constructed from prd.json + CLAUDE.md on the host, passed as argument | |

### B: Base Template + Runtime Plugin Install

Use the stock `docker/sandbox-templates:claude-code` template (always latest Claude). On first creation, exec into the sandbox to install the ralph plugin. No custom image to maintain.

| Part | Mechanism | Flag |
|------|-----------|:----:|
| B1 | Host skill creates sandbox with stock template: `docker sandbox create --name ralph claude <workspace>` | ✅ proven |
| B2 | Host skill runs setup via exec: `docker sandbox exec ralph bash -c 'cp -r /path/to/plugin/* ~/.claude/ && sudo apt-get install -y tmux'` | ⚠️ fragile |
| B3 | Plugin files synced to sandbox via workspace mount (plugin source lives in workspace or a mounted path) | ✅ proven |
| B4 | Host skill starts ralph-once inside sandbox: `docker sandbox exec ralph tmux new-session -d -s ralph-once 'claude "<ralph-prompt>"'` | ✅ proven |
| B5 | User interacts via: `docker sandbox exec -it ralph tmux attach -t ralph-once` | ✅ proven |

### C: Saved Sandbox Snapshot

Use `docker sandbox save` to snapshot a configured sandbox. Set up once interactively, save it, reuse forever. No Dockerfile, no runtime setup.

| Part | Mechanism | Flag |
|------|-----------|:----:|
| C1 | One-time manual setup: create sandbox, exec in, install plugin + tmux, configure everything | |
| C2 | Save configured sandbox: `docker sandbox save ralph ralph-snapshot.tar` | ⚠️ untested |
| C3 | Host skill creates from snapshot when needed | ⚠️ untested |
| C4 | Host skill starts ralph-once same as A3/B4 | ✅ proven |
| C5 | User interacts same as A4/B5 | ✅ proven |

### D: Custom Template + Host-Side tmux (SELECTED)

Same as Shape A but tmux runs on the host instead of inside the sandbox. The host skill starts a local tmux session that contains the `docker sandbox exec` process running claude.

| Part | Mechanism | Flag |
|------|-----------|:----:|
| D1 | Custom Dockerfile extending `docker/sandbox-templates:claude-code` that pre-installs ralph plugin + bun + playwright (NO tmux needed) | ✅ proven |
| D2 | Host skill checks sandbox state via `docker sandbox ls`, creates if needed (same as A2) | ✅ proven |
| D3 | Host skill starts ralph-once: `tmux new-session -d -s ralph-once 'docker sandbox exec -it ralph /home/agent/.local/bin/claude "<prompt>"'` | ✅ proven |
| D4 | User interacts via: `tmux attach -t ralph-once` (plain local tmux, no docker exec wrapper) | ✅ proven |
| D5 | Host Claude monitors via: `tmux capture-pane -t ralph-once -p` (local command, no exec needed) | ✅ proven |
| D6 | Ralph-once prompt constructed from prd.json + CLAUDE.md on the host, passed as argument | ✅ implemented |

**Advantages over A:**
- Simpler Dockerfile — no tmux to install, one less moving part in the image
- Simpler interaction — user just does `tmux attach`, no `docker sandbox exec -it ... tmux attach` nesting
- Host Claude can monitor the session with plain `tmux capture-pane` — no docker exec needed for observability
- tmux is already on most Macs (or trivially available via homebrew)

**Trade-off vs A:**
- If the `docker sandbox exec` process dies (e.g., Docker Desktop restarts), the claude process inside the sandbox also dies. With A's approach (tmux inside sandbox), claude survives independently of the exec connection. In practice this is unlikely — the host tmux session keeps exec alive, and if Docker Desktop crashes the sandbox is gone anyway.

**Prerequisite:** tmux installed on the host machine.

**DEPRECATED:** Testing revealed that `docker sandbox exec` does NOT have file sync for `claude` agent type sandboxes. The workspace directory exists but is empty. Shape D's core mechanism is broken — see Shape E.

### E: Custom Template + Host-Side tmux + Run (SELECTED)

Evolved from Shape D after discovering that `docker sandbox exec` lacks file sync for `claude` type sandboxes. Uses `docker sandbox run ... --` instead of `exec` to launch Claude sessions, which activates the built-in file sync. tmux still runs on the host.

| Part | Mechanism | Flag |
|------|-----------|:----:|
| E1 | Custom Dockerfile extending `docker/sandbox-templates:claude-code` that pre-installs ralph plugin + bun + playwright (same as D1) | ✅ proven |
| E2 | Host skill checks sandbox state via `docker sandbox ls`, creates if needed (same as D2) | ✅ proven |
| E3 | Host skill starts ralph-once: `tmux new-session -d -s ralph-once 'docker sandbox run ralph-<name> -- --permission-mode acceptEdits "/ralph-once <plan-name>"'` | ✅ proven |
| E4 | User interacts via: `tmux attach -t ralph-once` (same as D4) | ✅ proven |
| E5 | Host Claude monitors via: `tmux capture-pane -t ralph-once -p` (same as D5) | ✅ proven |
| E6 | No prompt construction needed — sandbox has `/ralph-once` command and file sync provides access to plan files | ✅ proven |

**Key difference from D:** `docker sandbox run ... --` instead of `docker sandbox exec`. This is what activates file sync — `exec` connects to the sandbox but the workspace is empty. `run` sets up the full agent environment including file sync.

**Advantages over D:**
- Actually works — `exec` doesn't have file sync for `claude` type sandboxes
- Much simpler — no prompt construction on the host, no prompt files, no cleanup
- The host just picks a plan and tells the sandbox `/ralph-once <plan-name>`
- The sandbox plugin handles all the complexity (task selection, implementation, testing, commits, promise tags)

**What we keep from D:**
- Custom Dockerfile with ralph plugin baked in
- Host-side tmux for interaction and monitoring
- Host plugin for sandbox lifecycle orchestration
- `docker sandbox exec` is still useful for utility commands (auth status, writing config) — it just can't launch Claude sessions that need workspace files

**What changes from D:**
- `exec` → `run ... --` for launching Claude
- Prompt construction steps removed from host command
- No `.ralph-prompt.txt` files to create or clean up
- `--append-system-prompt-file` available if extra context needed, but not required since `/ralph-once` reads plan files directly

**Prerequisite:** tmux installed on the host machine.

---

## Fit Check

| Req | Requirement | Status | A | B | C | D | E |
|-----|-------------|--------|---|---|---|---|---|
| R0 | Trigger ralph-once from local Claude session | Core goal | ✅ | ✅ | ✅ | ✅ | ✅ |
| R1 | Sandbox preloaded with ralph plugin | Must-have | ✅ | ✅ | ✅ | ✅ | ✅ |
| R2 | Interact with session via tmux | Must-have | ✅ | ✅ | ✅ | ✅ | ✅ |
| R3 | Minimal host setup | Must-have | ✅ | ✅ | ✅ | ✅ | ✅ |
| R4 | Claude Code updates naturally | Nice-to-have | ~ | ~ | ❌ | ~ | ✅ |
| R5 | Works with current Docker sandbox CLI | Must-have | ✅ | ✅ | ✅ | ❌ | ✅ |
| R6 | Everything proven | Must-have | ✅ | ✅ | ✅ | ❌ | ✅ |
| R7 | PRD/plan files accessible in sandbox | Must-have | ✅ | ✅ | ✅ | ❌ | ✅ |

**Notes:**

- **D fails R5/R6/R7**: `docker sandbox exec` does not have file sync for `claude` type sandboxes. The workspace directory exists but is empty. This was not caught in spikes because the spikes used `shell` type sandboxes where exec behavior differs. D's core mechanism is broken.
- **E fixes D**: Replaces `exec` with `run ... --` for launching Claude sessions. `run` activates file sync. Also much simpler — no prompt construction, the sandbox `/ralph-once` command handles everything.
- **E gets ✅ on R4**: The Dockerfile reinstalls Claude Code via the native installer, fixing the "unknown" install method. `claude update` works at runtime after this fix. `sandbox:build` uses `--no-cache` to always get the latest version at build time.
- **D gets ~ on R4 (revised)**: Spike 5 was misleading — it only tested the "already up to date" path. `claude update` hangs when it actually needs to upgrade from the base image's broken "unknown" install method.
- **A-C unchanged**: Previous assessments still hold. A/B/C all used `exec` which has the same file sync issue, but since they were never implemented, the practical impact wasn't discovered.

---

## Current Recommendation

**Shape E (Custom Template + Host-Side tmux + Run)** is the selected approach. It evolved from Shape D after real-world testing revealed that `docker sandbox exec` lacks file sync for `claude` type sandboxes.

Shape E is simpler than D in every way: no prompt construction on the host, no prompt files to manage, no cleanup steps. The host plugin just picks a plan and tells the sandbox to run `/ralph-once <plan-name>`. All the complexity lives in the sandbox plugin where it belongs.

The key insight: `docker sandbox run ... --` is the correct way to launch Claude sessions that need workspace access. `exec` is fine for utility commands (checking auth, writing config) but doesn't set up file sync.

**All spikes complete (6-8).** `run` vs `exec` file sync confirmed, bidirectional sync confirmed via `run`, tmux launch + attach + capture confirmed. See spike-results.md for details.
