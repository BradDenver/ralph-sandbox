# Sandbox Ralph — Breadboard (Shape D)

## Resolved Questions

- **Q1 Naming:** Per-workspace. Sandbox named `ralph-<workspace-dirname>`.
- **Q2 Auth detection:** `docker sandbox exec <name> /home/agent/.local/bin/claude auth status`
- **Q3 Prompt delivery:** Host-only temp file at `/tmp/ralph-prompt-<workspace-dirname>.txt`, read by host shell via `$(cat ...)`, passed as positional arg to claude. Never enters the workspace.
- **Q4 Auto-poll:** Yes, skill polls tmux session + prd.json after kicking off ralph-once.
- **Q5 tmux on exit:** Session stays open so user can review final output. `sandbox:cleanup` command kills it.

---

## Places

### 1. Local Claude Session
Where the user starts. Running Claude Code on their host machine with the sandbox orchestration commands installed.

### 2. Sandbox Not Exists
No sandbox has been created yet for this workspace.

### 3. Sandbox Exists, Not Authenticated
Sandbox is created and running but Claude inside hasn't been logged in yet.

### 4. Sandbox Ready
Sandbox exists, authenticated, idle — ready to run ralph-once.

### 5. Ralph-Once Running
A ralph-once session is active inside the sandbox, visible in a host tmux session.

### 6. Ralph-Once Complete
The ralph-once session finished (FEATURE_COMPLETE, ALL_COMPLETE, or BLOCKED). tmux session stays open with final output visible.

### 7. Tmux Attached
User is interacting directly with the running sandbox Claude session via tmux.

---

## Flows

### Flow 1: First Run (Happy Path)

```
LOCAL CLAUDE SESSION
  User: "run sandbox:ralph-once for plans/my-feature"
    │
    ├─ [skill detects] workspace directory from current project
    │   → derives sandbox name: ralph-<workspace-dirname>
    │
    ├─ [skill checks] docker sandbox ls
    │   → no sandbox named "ralph-<workspace-dirname>" found
    │
    ├─ [skill checks] plan files exist?
    │   → reads plans/my-feature/prd.json, CLAUDE.md
    │   → yes, found
    │
    ├─ [skill runs] docker sandbox create \
    │     --name ralph-<workspace-dirname> \
    │     -t ralph-template:latest claude <workspace>
    │   → sandbox created
    │
    ├─ SANDBOX EXISTS, NOT AUTHENTICATED
    │
    ├─ [skill checks] docker sandbox exec ralph-<name> \
    │     /home/agent/.local/bin/claude auth status
    │   → not authenticated
    │
    ├─ [skill tells user]
    │   "Sandbox created. You need to authenticate once.
    │    Run in your terminal:
    │      docker sandbox run ralph-<workspace-dirname>
    │    Log in via the browser link, then /exit"
    │
    ├─ [user authenticates in their terminal]
    │
    ├─ SANDBOX READY
    │
    ├─ [user returns to Claude] "done"
    │
    ├─ [skill constructs] ralph-once prompt from prd.json + CLAUDE.md
    │   → writes to /tmp/ralph-prompt-<workspace-dirname>.txt (host only)
    │
    ├─ [skill runs]
    │   tmux new-session -d -s ralph-once \
    │     'docker sandbox exec -it ralph-<workspace-dirname> \
    │      /home/agent/.local/bin/claude \
    │      --permission-mode acceptEdits \
    │      "$(cat /tmp/ralph-prompt-<workspace-dirname>.txt)"'
    │
    ├─ RALPH-ONCE RUNNING
    │
    ├─ [skill tells user]
    │   "Ralph-once is running in tmux session 'ralph-once'.
    │    To interact: tmux attach -t ralph-once
    │    I'll check on progress."
    │
    └─ [skill begins polling] → Flow 3 (auto)
```

### Flow 2: Subsequent Runs (Sandbox Already Ready)

```
LOCAL CLAUDE SESSION
  User: "run sandbox:ralph-once"
    │
    ├─ [skill checks] docker sandbox ls
    │   → "ralph-<workspace-dirname>" exists
    │
    ├─ [skill checks] tmux has-session -t ralph-once
    │   → no session (previous run finished or cleaned up)
    │
    ├─ [skill checks] claude auth status via exec
    │   → authenticated
    │
    ├─ [skill reads] prd.json from workspace
    │   → finds next task with passes: false
    │   → constructs prompt, writes /tmp/ralph-prompt-<workspace-dirname>.txt
    │
    ├─ [skill runs] tmux new-session -d -s ralph-once ...
    │
    ├─ RALPH-ONCE RUNNING
    │
    ├─ [skill tells user] "Ralph-once started on task: <description>"
    │
    └─ [skill begins polling]
```

### Flow 3: Check Status / Auto-Poll

```
LOCAL CLAUDE SESSION (or auto-poll)
  User: "how's the ralph-once going?" (or skill polls automatically)
    │
    ├─ [skill checks] tmux has-session -t ralph-once
    │
    ├─ SESSION EXISTS (still running):
    │   ├─ [skill reads] prd.json from workspace
    │   │   → "3 of 7 tasks complete"
    │   │
    │   ├─ [skill runs] tmux capture-pane -t ralph-once -p -S -50
    │   │   → captures last 50 lines of output
    │   │
    │   └─ [skill tells user]
    │       "Ralph-once is running. 3 of 7 tasks complete.
    │        Current activity: [summary of captured output]"
    │
    └─ SESSION DOES NOT EXIST (finished):
        → Flow 4
```

### Flow 4: Ralph-Once Finishes

```
RALPH-ONCE COMPLETE (tmux session still open, claude exited)
    │
    ├─ [skill checks] tmux has-session -t ralph-once
    │   → session exists BUT no running process
    │   (tmux stays open after claude exits)
    │
    ├─ [skill runs] tmux capture-pane -t ralph-once -p -S -100
    │   → captures final output including promise tag
    │
    ├─ [skill reads] prd.json from workspace
    │   → checks task completion status
    │
    ├─ [skill detects promise tag from captured output]:
    │
    │   FEATURE_COMPLETE:
    │   └─ "Task X completed and committed.
    │       4 of 7 tasks done. 3 remaining.
    │       Run sandbox:ralph-once for the next task.
    │       Run sandbox:cleanup to clear the tmux session."
    │
    │   ALL_COMPLETE:
    │   └─ "All tasks in the plan are complete!
    │       Run sandbox:cleanup to clear the session.
    │       Run sandbox:teardown if you're done with this sandbox."
    │
    │   BLOCKED:
    │   └─ "Ralph-once hit a blocker on task X.
    │       [summary of issue from captured output]
    │       You may want to review and update the PRD,
    │       then run sandbox:ralph-once again."
    │
    └─ NO PROMISE TAG (crashed/unexpected exit):
        └─ "Ralph-once exited unexpectedly.
            Check the output: tmux attach -t ralph-once
            Or run sandbox:cleanup and try again."
```

### Flow 5: User Wants to Interact

```
LOCAL CLAUDE SESSION
  User: "I want to interact with the ralph session"
    │
    ├─ [skill checks] tmux has-session -t ralph-once
    │   → yes
    │
    └─ [skill tells user]
        "Run this in your terminal:
           tmux attach -t ralph-once
         Detach with Ctrl-b d when done."
```

### Flow 6: Session Already Running

```
LOCAL CLAUDE SESSION
  User: "run sandbox:ralph-once"
    │
    ├─ [skill checks] tmux has-session -t ralph-once
    │   → yes, session exists
    │
    ├─ [skill checks] is there a running process in the pane?
    │   tmux list-panes -t ralph-once -F '#{pane_dead}'
    │
    ├─ PROCESS RUNNING:
    │   └─ "A ralph-once session is already running.
    │       To check progress: sandbox:status
    │       To interact: tmux attach -t ralph-once"
    │
    └─ NO PROCESS (session open but claude exited):
        └─ "Previous ralph-once finished. The tmux session
            is still open with the final output.
            Run sandbox:cleanup first, then sandbox:ralph-once."
```

### Flow 7: Cleanup

```
LOCAL CLAUDE SESSION
  User: "sandbox:cleanup"
    │
    ├─ [skill runs] tmux kill-session -t ralph-once
    │   (silently succeeds or fails if no session)
    │
    ├─ [skill removes] /tmp/ralph-prompt-<workspace-dirname>.txt
    │
    └─ [skill tells user] "Cleaned up. Ready for next ralph-once."
```

### Flow 8: Teardown

```
LOCAL CLAUDE SESSION
  User: "sandbox:teardown"
    │
    ├─ [skill runs] tmux kill-session -t ralph-once (if exists)
    ├─ [skill removes] /tmp/ralph-prompt-<workspace-dirname>.txt
    ├─ [skill runs] docker sandbox rm ralph-<workspace-dirname>
    │
    └─ [skill tells user]
        "Sandbox removed. You'll need to authenticate again
         on the next sandbox:ralph-once.
         Your workspace files are still on the host."
```

### Flow 9: Rebuild (PRD Changed)

```
LOCAL CLAUDE SESSION
  User: "I updated the PRD, rebuild the sandbox"
    │
    ├─ [skill runs] tmux kill-session -t ralph-once (if exists)
    ├─ [skill runs] docker sandbox rm ralph-<workspace-dirname>
    ├─ [skill runs] docker sandbox create ... (new sandbox)
    │
    ├─ SANDBOX EXISTS, NOT AUTHENTICATED
    │
    └─ [skill tells user]
        "Sandbox rebuilt with updated files.
         You'll need to authenticate again:
           docker sandbox run ralph-<workspace-dirname>"
```

**Why Flow 9 exists:** Spike 2 proved that edits to files that existed when the sandbox was created don't sync into the sandbox. New files DO appear, but edits to existing ones are invisible inside. So if you revise prd.json or CLAUDE.md on the host mid-flight, the sandbox won't see it. Rebuild tears down and recreates to pick up the changes. Note: the sandbox itself writing to prd.json (marking tasks done) syncs back to the host in real-time — normal ralph-once operation doesn't require rebuilds.

---

## Affordances by Place

### Local Claude Session
| Affordance | Connection |
|-----------|------------|
| `sandbox:ralph-once [plan-name]` | → Flow 1, 2, or 6 depending on state |
| `sandbox:status` | → Flow 3 or 4 |
| `sandbox:setup [workspace]` | → Creates sandbox, prompts auth (Flow 1, setup steps only) |
| `sandbox:cleanup` | → Flow 7 |
| `sandbox:teardown` | → Flow 8 |
| `sandbox:rebuild` | → Flow 9 |

### Tmux Attached (user's terminal)
| Affordance | Connection |
|-----------|------------|
| Interact with sandbox Claude | User types in the Claude session |
| `Ctrl-b d` | Detach, return to their terminal |

### Ralph-Once Running (background)
| Affordance | Connection |
|-----------|------------|
| (automatic) claude exits with promise tag | → Ralph-Once Complete (Flow 4) |
| Host Claude auto-polls | → Flow 3 |

---

## State Detection Logic

```
Is there a sandbox? ─── docker sandbox ls | grep ralph-<workspace-dirname>
│
├─ NO → SANDBOX NOT EXISTS
│    Action: create sandbox, prompt auth
│
└─ YES
    │
    Is there a tmux session? ─── tmux has-session -t ralph-once 2>/dev/null
    │
    ├─ YES
    │   │
    │   Is claude still running? ─── tmux list-panes -t ralph-once -F '#{pane_dead}'
    │   │
    │   ├─ RUNNING → RALPH-ONCE RUNNING
    │   │   Action: report status, user can attach
    │   │
    │   └─ DEAD → RALPH-ONCE COMPLETE
    │       Action: report result, suggest cleanup
    │
    └─ NO
        │
        Is claude authenticated? ─── docker sandbox exec ralph-<name> \
        │                             /home/agent/.local/bin/claude auth status
        │
        ├─ YES → SANDBOX READY
        │   Action: can start ralph-once
        │
        └─ NO → SANDBOX EXISTS, NOT AUTHENTICATED
            Action: prompt user to authenticate
```

---

## Prompt Construction

The skill builds the ralph-once prompt on the host by reading plan files from the workspace:

```
Inputs read from workspace:
  - plans/<plan-name>/CLAUDE.md     (project guidance)
  - plans/<plan-name>/prd.json      (task definitions)
  - plans/<plan-name>/learnings.md  (if exists)

Output written to host only:
  - /tmp/ralph-prompt-<workspace-dirname>.txt

Prompt structure:
  [contents of CLAUDE.md]
  [contents of prd.json]
  [contents of learnings.md if exists]

  You are implementing this project using the Ralph Wiggum technique.
  [task selection instructions]
  [implementation rules]
  [promise tag definitions]
```

The prompt is read by the host shell at tmux session creation time:
```bash
tmux new-session -d -s ralph-once \
  "docker sandbox exec -it ralph-<name> \
   /home/agent/.local/bin/claude \
   --permission-mode acceptEdits \
   \"$(cat /tmp/ralph-prompt-<workspace-dirname>.txt)\""
```

The prompt file never enters the workspace or the sandbox filesystem.

---

## Naming Convention

| Thing | Name |
|-------|------|
| Docker template image | `ralph-template:latest` |
| Sandbox instance | `ralph-<workspace-dirname>` |
| tmux session | `ralph-once` |
| Host-only prompt file | `/tmp/ralph-prompt-<workspace-dirname>.txt` |
| Host commands | `sandbox:ralph-once`, `sandbox:status`, `sandbox:setup`, `sandbox:cleanup`, `sandbox:teardown`, `sandbox:rebuild` |
