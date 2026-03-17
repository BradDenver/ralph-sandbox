# Ralph Sandbox - Development Guide

## Overview

Ralph Sandbox is a Docker sandbox template that pre-installs a Claude Code plugin for autonomous coding loops. The plugin enables plan-driven development where tasks are defined in `prd.json` and executed one at a time with promise tag signaling.

**Shape E (current):** The sandbox runs Claude with the ralph plugin. The host machine runs tmux to wrap the sandbox session via `docker sandbox run ... --`, giving the user easy attach/detach and the host Claude easy monitoring via `tmux capture-pane`.

## Tech Stack

- **Docker**: Sandbox template based on `docker/sandbox-templates:claude-code`
- **Bash**: Scripts for iteration control
- **Markdown**: Plugin definitions (commands, skills, agents, rules)
- **JSON**: Plugin manifests and prd.json task format
- **tmux**: Runs on the HOST for session management (not inside the sandbox)

## Project Structure

```
ralph-sandbox/
├── docker/
│   └── Dockerfile          # Sandbox template - stages plugin, entrypoint installs on startup
├── host/                        # HOST PLUGIN (ralph-host) — installed on user's machine
│   ├── .claude-plugin/
│   │   ├── plugin.json          # Host plugin manifest
│   │   └── marketplace.json     # Host plugin marketplace metadata
│   ├── commands/                # Host-side Claude Code commands (sandbox:*)
│   │   ├── sandbox-ralph-once.md    # Run a single ralph iteration in sandbox
│   │   ├── sandbox-status.md        # Check sandbox session status
│   │   ├── sandbox-setup.md         # Create sandbox and guide auth
│   │   ├── sandbox-build.md         # Build the ralph-template Docker image
│   │   ├── sandbox-cleanup.md       # Kill tmux session, keep sandbox
│   │   └── sandbox-teardown.md      # Destroy sandbox entirely
│   └── skills/                  # Host-side skills (plan management)
│       ├── new-plan/SKILL.md        # Create a new plan folder
│       └── plan-prd/SKILL.md        # Plan a feature and add PRD item
├── plugin/                      # SANDBOX PLUGIN (ralph-sandbox) — installed inside Docker sandbox
│   ├── agents/             # Subagent definitions (Task tool)
│   ├── commands/           # Slash commands (/ralph-once, etc.)
│   ├── skills/             # Skill definitions (workflows, guides)
│   ├── rules/              # Always-on rules
│   └── settings.json       # Permission allowlist
├── scripts/
│   ├── ralph-once.sh       # Standalone single iteration
│   └── ralph-loop.sh       # Standalone loop (sandbox only)
├── .claude-plugin/              # Sandbox plugin manifest (used by Docker template)
│   ├── plugin.json
│   └── marketplace.json
├── CLAUDE.md               # This file
└── README.md               # User documentation
```

## Architecture (Shape E)

### Two Pieces

1. **Sandbox plugin** (`ralph-sandbox`): Root `.claude-plugin/` + `plugin/` + `docker/`. Lives inside the Docker sandbox. Provides `/ralph-once`, `/ralph-loop`, agents, rules, and skills to the Claude instance running in the sandbox. Installed automatically by the Docker template entrypoint.

2. **Host plugin** (`ralph-host`): `host/.claude-plugin/` + `host/commands/`. Installed as a local plugin on the user's machine. Orchestrates the sandbox lifecycle — creating, authenticating, launching ralph-once sessions, monitoring, cleanup. Can be enabled/disabled independently.

### How It Works

```
Host Machine                          Docker Sandbox
┌──────────────────────┐              ┌──────────────────────┐
│ Claude Code (local)  │              │ Claude Code (sandbox) │
│ + host/commands/*    │              │ + plugin/*            │
│                      │  run ... --  │                       │
│ tmux session ────────┼──────────────┼─→ /ralph-once <plan>  │
│ (ralph-once)         │              │   reads plan files    │
│                      │              │   implements task     │
│ capture-pane ←───────┼──────────────┼── output              │
│ (monitoring)         │  bidirectional│                      │
│                      │  file sync   │                       │
│ workspace/ ←─────────┼──────────────┼── prd.json updates    │
└──────────────────────┘              └──────────────────────┘
```

### Key Insight: `run` vs `exec`

- **`docker sandbox run ... --`** activates file sync. Use for launching Claude sessions that need workspace access. The `--` separator passes arguments to the Claude agent.
- **`docker sandbox exec`** does NOT have file sync for `claude` type sandboxes. The workspace directory exists but is empty. Use only for utility commands (auth status, writing config to `~/.claude/`).

### File Sync Behavior (via `run`)

- Host → sandbox: files visible inside sandbox (bidirectional)
- Sandbox → host: changes sync in real-time (prd.json updates, commits)
- Host edits to existing files: sync into sandbox (unlike `exec` where they don't)
- New host files created after sandbox start: appear inside sandbox

### Key Paths

| What | Where |
|------|-------|
| Claude binary (sandbox) | `/home/agent/.local/bin/claude` |
| Plugin staging (sandbox) | `/opt/ralph-plugin/` |
| Plugin installed (sandbox) | `~/.claude/commands/`, `~/.claude/skills/`, etc. |
| tmux session (host) | `ralph-once` |
| Sandbox name | `ralph-<workspace-dirname>` |

## Key Concepts

### Promise Tags
Claude outputs these to signal iteration status:
- `<promise>FEATURE_COMPLETE</promise>` - Task done, continue loop
- `<promise>ALL_COMPLETE</promise>` - All tasks done, stop
- `<promise>BLOCKED</promise>` - Need human help, stop

### Plan Structure
Projects using Ralph have a `plans/<name>/` folder with:
- `CLAUDE.md` - Project-specific guidance
- `prd.json` - Task definitions with status tracking
- `learnings.md` - Decisions, failed approaches, gotchas

### Execution Modes
- `sandbox:ralph-once` - Host command: launches sandbox + single task iteration
- `sandbox:status` - Host command: checks progress
- `/ralph-once` - In-sandbox command: runs one task (used internally)
- `/ralph-loop` - In-sandbox command: autonomous loop until complete/blocked

## Development Tasks

### Building the Template

```bash
# From the ralph-sandbox repo root
docker build -t ralph-template:latest -f docker/Dockerfile .
```

### Installing the Host Plugin

**For development/testing** — load directly without installing:
```bash
claude --plugin-dir /path/to/ralph-sandbox/host
```

**For permanent installation** — add as a local marketplace, then install:
```
/plugin marketplace add /path/to/ralph-sandbox/host
/plugin install ralph-host@ralph-host
```

This registers `ralph-host` as a plugin you can enable/disable. The sandbox:* commands become available in any project.

To uninstall:
```
/plugin uninstall ralph-host@ralph-host
```

After making changes to the host plugin source, bump the version in `host/.claude-plugin/plugin.json`, then run `/reload-plugins` inside Claude Code to pick up updates.

### Testing

```bash
# Build the template
docker build -t ralph-template:latest -f docker/Dockerfile .

# Create a sandbox for a test project
docker sandbox create --name ralph-test -t ralph-template:latest claude ~/my-test-project

# Authenticate
docker sandbox run ralph-test
# (log in via browser, then /exit)

# Run ralph-once via host tmux
tmux new-session -d -s ralph-once \
  "docker sandbox run ralph-test -- --permission-mode acceptEdits '/ralph-once <plan-name>'"

# Check progress
tmux capture-pane -t ralph-once -p -S -30

# Attach to interact
tmux attach -t ralph-once
```

### Adding a New Command
1. Create `plugin/commands/<name>.md` with YAML frontmatter
2. Include `description` in frontmatter
3. Document execution steps in markdown
4. Rebuild Docker image

### Adding a New Agent
1. Create `plugin/agents/<name>.md`
2. Define the agent's role and capabilities
3. Agents are invoked via Task tool by commands

### Adding a New Skill
1. Create `plugin/skills/<name>/SKILL.md`
2. Can include additional files (scripts, configs)
3. Skills provide workflows and domain knowledge

### Adding a New Rule
1. Create `plugin/rules/<name>.md`
2. Rules are always-on guidance
3. Keep rules focused and actionable

## Known Limitations

1. **`exec` has no file sync**: `docker sandbox exec` does NOT provide file sync for `claude` type sandboxes. Always use `docker sandbox run ... --` for Claude sessions that need workspace files. `exec` is fine for utility commands only.

2. **Auth requires browser login**: The first time a sandbox is created, the user must run `docker sandbox run <name>` and log in via browser. The token persists until the sandbox is removed.

3. **Network restricted in sandbox**: The `claude` agent sandbox type restricts general network access. Dependencies must be baked into the template image, not installed at runtime via apt. The Dockerfile reinstalls Claude Code via the native installer (replacing the base image's broken "unknown" install method), and `sandbox:build` uses `--no-cache` to ensure it always fetches the latest version. After this fix, `claude update` also works at runtime inside the sandbox.

4. **Volume mounting**: `~/.claude/` is mounted fresh on sandbox start, so plugin must be copied via entrypoint, not baked into the image at that path.

5. **User is `agent`**: The sandbox runs as user `agent` in `/home/agent/`.

## Feedback Loops

When modifying the sandbox plugin:
1. Rebuild Docker image (`sandbox:build`)
2. Remove old sandbox (`sandbox:teardown`)
3. Create new sandbox and re-authenticate (`sandbox:setup`)
4. Test with a demo project

When modifying the host plugin:
1. Bump version in `host/.claude-plugin/plugin.json`
2. Run `/reload-plugins` in Claude Code
