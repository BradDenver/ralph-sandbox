---
description: Check the status of the running ralph-once sandbox session
---

# sandbox:status

Check the current state of the ralph-once sandbox session and report progress.

## Execution

### Step 1: Determine Sandbox Name

```bash
pwd
```

Derive sandbox name: `ralph-<workspace-dirname>`.

### Step 2: Check Sandbox Exists

```bash
docker sandbox ls 2>/dev/null | grep "ralph-<workspace-dirname>"
```

If no sandbox exists, tell the user: "No sandbox exists for this workspace. Run `sandbox:setup` or `sandbox:ralph-once` to create one."

### Step 3: Check tmux Session

```bash
tmux has-session -t ralph-once 2>/dev/null
echo $?
```

**If no tmux session (exit code 1):**

Check if sandbox is authenticated:
```bash
docker sandbox exec ralph-<workspace-dirname> /home/agent/.local/bin/claude auth status 2>&1
```

Report the sandbox state:
- If authenticated: "Sandbox is ready. No ralph-once session running. Run `sandbox:ralph-once` to start one."
- If not authenticated: "Sandbox exists but isn't authenticated. Run `docker sandbox run ralph-<workspace-dirname>` to log in."

**If tmux session exists:**

Check if the process is still running:
```bash
tmux list-panes -t ralph-once -F '#{pane_dead}'
```

### Step 4a: Session Running (pane_dead = 0)

Read prd.json from the workspace to count task progress:
```bash
cat plans/<plan-name>/prd.json
```

Count tasks with `passes: true` vs total tasks.

Capture recent output:
```bash
tmux capture-pane -t ralph-once -p -S -50
```

Report:
> Ralph-once is running. [N of M] tasks complete.
> Recent activity: [brief summary of captured output]
> To interact: `tmux attach -t ralph-once`

### Step 4b: Session Finished (pane_dead = 1)

Capture the final output:
```bash
tmux capture-pane -t ralph-once -p -S -100
```

Read prd.json for final task state.

Look for promise tags in the captured output and report:

**FEATURE_COMPLETE:**
> Task completed and committed. [N of M] tasks done, [remaining] remaining.
> Run `sandbox:ralph-once` for the next task.
> Run `sandbox:cleanup` to clear the tmux session.

**ALL_COMPLETE:**
> All tasks in the plan are complete!
> Run `sandbox:cleanup` to clear the session.
> Run `sandbox:teardown` if you're done with this sandbox.

**BLOCKED:**
> Ralph-once hit a blocker. [summary of issue from captured output]
> You may want to review and update the PRD, then run `sandbox:ralph-once` again.

**No promise tag found:**
> Ralph-once exited unexpectedly.
> Check the output: `tmux attach -t ralph-once`
> Or run `sandbox:cleanup` and try again.
