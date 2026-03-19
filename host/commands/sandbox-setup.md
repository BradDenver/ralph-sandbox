---
description: Create and prepare a Docker sandbox for ralph-once (without starting a session)
---

# sandbox:setup

Create a Docker sandbox for the current workspace and guide the user through authentication. Does NOT start a ralph-once session.

## Prerequisites

- Docker Desktop with `docker sandbox` CLI (v0.12+)
- `ralph-template:latest` Docker image built

## Execution

### Step 1: Determine Sandbox Name

```bash
pwd
```

Derive sandbox name: `ralph-<workspace-dirname>`.

### Step 2: Check if Sandbox Already Exists

```bash
docker sandbox ls 2>/dev/null | grep "ralph-<workspace-dirname>"
```

If sandbox already exists, tell the user and check auth status instead of creating a new one.

### Step 3: Verify Template Image

```bash
docker images ralph-template:latest --format '{{.Repository}}:{{.Tag}}'
```

If the image doesn't exist, tell the user:
> The `ralph-template:latest` image hasn't been built yet.
> Run from the ralph-sandbox repo:
> ```
> docker build -t ralph-template:latest -f docker/Dockerfile .
> ```

### Step 4: Create Sandbox

```bash
docker sandbox create --name ralph-<workspace-dirname> -t ralph-template:latest claude "$(pwd)"
```

### Step 5: Ensure .syncignore Exists

Create or update `.syncignore` in the workspace root so platform-specific artifacts don't sync back from the sandbox (Linux) to the host (macOS). This prevents broken `node_modules/` after sandbox sessions.

```bash
touch .syncignore
```

Ensure these patterns are present (append any that are missing):
```
**/node_modules
.pnpm-store
```

Do NOT overwrite the file — it may contain user-added patterns. Only append missing lines.

### Step 6: Check Authentication

```bash
docker sandbox exec ralph-<workspace-dirname> /home/agent/.local/bin/claude auth status 2>&1
```

If not authenticated, tell the user:
> Sandbox created successfully. You need to authenticate Claude once.
> Run in your terminal:
> ```
> docker sandbox run ralph-<workspace-dirname>
> ```
> Log in via the browser link, then type `/exit` to return.

If already authenticated (e.g. reusing a sandbox), proceed to Step 7.

### Step 7: Pre-accept Workspace Trust

On first run in a new workspace, Claude shows a "Do you trust this workspace?" prompt that consumes the session. Pre-accept it by writing to the allowlist inside the sandbox:

```bash
docker sandbox exec ralph-<workspace-dirname> bash -c \
  'mkdir -p ~/.claude && touch ~/.claude/.allowedDirectories && \
   grep -qxF "/home/agent/workspace" ~/.claude/.allowedDirectories 2>/dev/null || \
   echo "/home/agent/workspace" >> ~/.claude/.allowedDirectories'
```

Report:
> Sandbox is ready. Run `sandbox:ralph-once` to start a session.
