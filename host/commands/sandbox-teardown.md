---
description: Fully remove the Docker sandbox (requires re-auth on next use)
---

# sandbox:teardown

Kill any tmux session and destroy the Docker sandbox entirely. The user will need to re-authenticate on the next `sandbox:setup` or `sandbox:ralph-once`.

## Execution

### Step 1: Determine Sandbox Name

```bash
pwd
```

Derive sandbox name: `ralph-<workspace-dirname>`.

### Step 2: Kill tmux Session

```bash
tmux kill-session -t ralph-once 2>/dev/null
```

### Step 3: Remove Sandbox

```bash
docker sandbox rm ralph-<workspace-dirname>
```

If the sandbox doesn't exist, that's fine — report success either way.

### Step 4: Report

> Sandbox removed. You'll need to authenticate again on the next `sandbox:ralph-once`.
> Your workspace files are still on the host — nothing was deleted locally.
