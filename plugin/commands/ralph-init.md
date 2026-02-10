---
description: Initialize ralph scripts in current project for interactive terminal use
---

# Ralph Init

Install ralph scripts into the current project. Scripts run claude inside the sandbox to ensure all plugin tooling is available.

## What It Creates

```
ralph/
├── ralph-once.sh   # Run single iteration (launches sandbox)
└── sandbox.sh      # Launch sandbox interactively
```

## Execution

**Step 1: Create ralph directory**

```bash
mkdir -p ralph
```

**Step 2: Create ralph-once.sh**

Write this file to `ralph/ralph-once.sh`:

```bash
#!/bin/bash
# Ralph Once - Run single iteration inside sandbox
# Launches Docker sandbox with ralph-sandbox template and runs one iteration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="${RALPH_TEMPLATE:-ralph-sandbox}"

# Find plan
PLAN_NAME="${1:-}"
PLANS_DIR="$PROJECT_DIR/plans"

if [[ ! -d "$PLANS_DIR" ]]; then
    echo "Error: No plans/ directory found"
    exit 1
fi

# List available plans
PLANS=($(ls -d "$PLANS_DIR"/*/ 2>/dev/null | xargs -n1 basename))

if [[ ${#PLANS[@]} -eq 0 ]]; then
    echo "Error: No plans found"
    exit 1
fi

# Select plan interactively if not provided
if [[ -z "$PLAN_NAME" ]]; then
    if [[ ${#PLANS[@]} -eq 1 ]]; then
        PLAN_NAME="${PLANS[0]}"
        echo "Using plan: $PLAN_NAME"
    else
        echo "Available plans:"
        select plan in "${PLANS[@]}"; do
            if [[ -n "$plan" ]]; then
                PLAN_NAME="$plan"
                break
            fi
        done
    fi
fi

# Build file references
FILES="@plans/$PLAN_NAME/CLAUDE.md @plans/$PLAN_NAME/prd.json"
[[ -f "$PLANS_DIR/$PLAN_NAME/progress.txt" ]] && FILES="$FILES @plans/$PLAN_NAME/progress.txt"
[[ -f "$PLANS_DIR/$PLAN_NAME/PLAN.md" ]] && FILES="$FILES @plans/$PLAN_NAME/PLAN.md"
[[ -f "$PROJECT_DIR/CLAUDE.md" ]] && FILES="$FILES @CLAUDE.md"

# Build prompt
PROMPT="$FILES

You are implementing this project using the Ralph technique.

YOUR TASK:
1. Read the plan files provided above
2. Find the highest-priority task with status: pending
3. Implement ONLY that one task
4. Run all feedback loops (test, lint, typecheck)
5. Update prd.json status to 'complete' when done
6. Commit with descriptive message
7. Output promise tag and EXIT

PROMISE TAGS:
- <promise>FEATURE_COMPLETE</promise> - Task done
- <promise>ALL_COMPLETE</promise> - All tasks done
- <promise>BLOCKED</promise> - Need help

Begin now."

echo "Launching sandbox for plan: $PLAN_NAME"
echo ""

# Run claude inside sandbox
exec docker sandbox run --template "$TEMPLATE" -w "$PROJECT_DIR" claude --permission-mode acceptEdits "$PROMPT"
```

**Step 3: Create sandbox.sh**

Write this file to `ralph/sandbox.sh`:

```bash
#!/bin/bash
# Launch Docker sandbox with ralph-sandbox template interactively
set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${RALPH_TEMPLATE:-ralph-sandbox}"
echo "Launching sandbox: $TEMPLATE"
exec docker sandbox run --template "$TEMPLATE" -w "$PROJECT_DIR" "${@:-claude}"
```

**Step 4: Make executable**

```bash
chmod +x ralph/*.sh
```

**Step 5: Confirm**

```
Ralph scripts installed!

Usage:
  ./ralph/ralph-once.sh           # Run single iteration (in sandbox)
  ./ralph/ralph-once.sh my-plan   # Specify plan name
  ./ralph/sandbox.sh              # Enter sandbox interactively

Inside sandbox:
  /ralph-once                     # Run via command
  /ralph-loop                     # Run autonomous loop
  /health-check                   # Check project setup
```

## Usage

```
/ralph-init
```
