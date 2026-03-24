---
description: Build (or rebuild) the ralph-template Docker image
---

# sandbox:build

Build the `ralph-template:latest` Docker image from the ralph-sandbox repo. Run this after cloning the repo or after updating the plugin/Dockerfile.

## Execution

### Step 1: Locate the ralph-sandbox repo

The Dockerfile and plugin source live in the ralph-sandbox repo. The host plugin was installed from `<repo>/host/`, so the repo root is one level up from the plugin's install path.

Look for the Dockerfile at common locations:

```bash
# Check if we're inside the ralph-sandbox repo
ls docker/Dockerfile 2>/dev/null

# Check relative to this plugin's known install location
# The plugin was installed from <repo>/host/, so repo is ../
# Try the path stored in the plugin registry
claude plugin list 2>/dev/null
```

If the Dockerfile can't be found automatically, ask the user for the path to the ralph-sandbox repo.

### Step 2: Build the image

```bash
docker build --no-cache -t ralph-template:latest -f docker/Dockerfile <repo-root>
```

`--no-cache` ensures the Claude Code native installer step fetches the latest version rather than reusing a cached layer. The build context must be the repo root (not `docker/`) because the Dockerfile COPYs from `.claude-plugin/`, `plugin/`, and `scripts/`.

### Step 3: Report

On success:
> `ralph-template:latest` built successfully.
> Any existing sandboxes still use the old image — run `sandbox:teardown` then `sandbox:setup` to recreate.

On failure, show the Docker build output so the user can diagnose.
