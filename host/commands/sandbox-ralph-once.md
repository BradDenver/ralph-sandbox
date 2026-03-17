---
description: Run a single ralph-once iteration inside a Docker sandbox
---

# sandbox:ralph-once

Run a single ralph-once task iteration inside a Docker sandbox, with tmux on the host for interaction and monitoring.

## Prerequisites

- Docker Desktop with `docker sandbox` CLI (v0.12+)
- `ralph-template:latest` Docker image built (`sandbox:build`)
- tmux installed on the host machine
- A `plans/<plan-name>/` directory with `prd.json` and `CLAUDE.md`

## Execution

### Step 1: Determine Workspace and Sandbox Name

```bash
# Get the current workspace directory (absolute path)
pwd
```

Derive the sandbox name: `ralph-<workspace-dirname>` where `<workspace-dirname>` is the basename of the current working directory.

### Step 2: Detect State

Run these checks in order:

```bash
# Check if sandbox exists
docker sandbox ls 2>/dev/null | grep "ralph-<workspace-dirname>"

# Check if a tmux session is already running
tmux has-session -t ralph-once 2>/dev/null
```

**If tmux session exists:**

Check if the process is still alive:
```bash
tmux list-panes -t ralph-once -F '#{pane_dead}' 2>/dev/null
```

- **pane_dead = 0 (running):** Tell the user a ralph-once session is already running. Suggest `sandbox:status` to check progress or `tmux attach -t ralph-once` to interact. Stop here.
- **pane_dead = 1 (exited):** Tell the user the previous session finished but hasn't been cleaned up. Suggest `sandbox:cleanup` first. Stop here.

### Step 3: Create Sandbox (if needed)

If no sandbox exists:

```bash
docker sandbox create --name ralph-<workspace-dirname> -t ralph-template:latest claude "$(pwd)"
```

Then check authentication:

```bash
docker sandbox exec ralph-<workspace-dirname> /home/agent/.local/bin/claude auth status 2>&1
```

If not authenticated, tell the user:
> Sandbox created. You need to authenticate once.
> Run in your terminal: `docker sandbox run ralph-<workspace-dirname>`
> Log in via the browser link, then type `/exit` to return.

Wait for the user to confirm they've authenticated before proceeding.

After authentication is confirmed, pre-accept workspace trust:

```bash
docker sandbox exec ralph-<workspace-dirname> bash -c \
  'mkdir -p ~/.claude && touch ~/.claude/.allowedDirectories && \
   grep -qxF "/home/agent/workspace" ~/.claude/.allowedDirectories 2>/dev/null || \
   echo "/home/agent/workspace" >> ~/.claude/.allowedDirectories'
```

### Step 4: Select Plan

```bash
# List available plans
ls plans/*/prd.json 2>/dev/null
```

If the user specified a plan name, use it. If only one plan exists, auto-select it. If multiple plans exist and none specified, ask the user which plan to use.

### Step 5: Launch in tmux

```bash
tmux new-session -d -s ralph-once \
  "docker sandbox run ralph-<workspace-dirname> \
   -- --permission-mode acceptEdits \
   '/ralph-once <plan-name>' \
   || { echo '--- RALPH-ONCE FAILED (see above) ---'; sleep 300; }"
```

**Key details:**
- Uses `docker sandbox run ... --` which activates file sync (unlike `exec` which has no file sync for `claude` type sandboxes).
- `acceptEdits` auto-approves file edits. The sandbox plugin's `settings.json` pre-approves common bash commands for autonomous operation.
- The sandbox `/ralph-once` command handles everything: reads plan files, picks a task, implements, tests, commits, outputs promise tags.
- The `|| { echo ...; sleep 300; }` error trap keeps the tmux pane alive for 5 minutes on failure so you can read the error output.

### Step 6: Report and Monitor

Tell the user:
> Ralph-once is running. To interact: `tmux attach -t ralph-once` (detach with Ctrl-b d)

Wait 30 seconds before the first poll, then begin polling:

```bash
# Check if still running
tmux has-session -t ralph-once 2>/dev/null && \
  tmux list-panes -t ralph-once -F '#{pane_dead}' 2>/dev/null
```

Capture recent output:
```bash
tmux capture-pane -t ralph-once -p -S -30
```

**Note:** `capture-pane` may return empty output during the first 30-60 seconds of startup. This is normal — the sandbox is booting and Claude is initializing. Do not treat empty output as an error. Continue polling.

If still running, read prd.json from the workspace to report task progress (sandbox writes sync back to host in real-time).

Report progress and continue polling every 30-60 seconds until the session finishes.

When the session finishes, follow the completion logic from `sandbox:status`.
