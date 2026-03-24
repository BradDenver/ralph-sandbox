---
description: Clean up the tmux session from a finished ralph-once run
---

# sandbox:cleanup

Kill the tmux session. Does NOT remove the sandbox — it stays ready for the next `sandbox:ralph-once`.

## Execution

### Step 1: Kill tmux Session

```bash
tmux kill-session -t ralph-once 2>/dev/null
```

This silently succeeds even if no session exists.

### Step 2: Report

> Cleaned up. Sandbox is still running and authenticated — ready for the next `sandbox:ralph-once`.
