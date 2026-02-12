#!/usr/bin/env bash
# ralph-once.sh - Run one Ralph iteration (non-interactive, for use with ! command)
#
# Usage: ./scripts/ralph-once.sh [--plan <name>] [--skip-permissions]
#
# Arguments:
#   --plan <name>       Specify plan name (required if multiple plans exist)
#   --skip-permissions  Use --dangerously-skip-permissions (requires sandbox)

set -e

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if we're inside the plugin or a project
if [[ -d "$PROJECT_DIR/plans" ]]; then
  PLANS_DIR="$PROJECT_DIR/plans"
elif [[ -d "$(pwd)/plans" ]]; then
  PLANS_DIR="$(pwd)/plans"
  PROJECT_DIR="$(pwd)"
else
  echo "Error: No plans/ directory found"
  echo "Run this from a project directory with plans/"
  exit 1
fi

# Docker sandbox detection
is_sandboxed() {
  [[ -f /.dockerenv ]] || \
  [[ -f /run/.containerenv ]] || \
  [[ "${DOCKER_SANDBOX:-}" == "1" ]] || \
  grep -q docker /proc/1/cgroup 2>/dev/null
}

# Parse arguments
PLAN_NAME=""
SKIP_PERMISSIONS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      PLAN_NAME="$2"
      shift 2
      ;;
    --skip-permissions|-s)
      SKIP_PERMISSIONS=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--plan <name>] [--skip-permissions]"
      exit 1
      ;;
  esac
done

# Validate skip-permissions requires sandbox
if [[ "$SKIP_PERMISSIONS" == true ]]; then
  if ! is_sandboxed; then
    echo "Error: --skip-permissions requires Docker sandbox."
    echo "Run via 'docker sandbox run' or set DOCKER_SANDBOX=1"
    exit 1
  fi
  PERMISSION_MODE="--dangerously-skip-permissions"
else
  PERMISSION_MODE="--permission-mode acceptEdits"
fi

# Detect available plans (directories with prd.json)
PLAN_DIRS=()
for dir in "$PLANS_DIR"/*/; do
  if [[ -f "$dir/prd.json" ]]; then
    PLAN_DIRS+=("$(basename "$dir")")
  fi
done

# Check if any plans exist
if [[ ${#PLAN_DIRS[@]} -eq 0 ]]; then
  echo "Error: No plan folders found under $PLANS_DIR"
  echo "A plan folder must contain a prd.json file"
  echo "Run /new-plan to create one"
  exit 1
fi

# Plan selection (non-interactive)
if [[ -n "$PLAN_NAME" ]]; then
  # Validate provided plan name
  VALID=false
  for p in "${PLAN_DIRS[@]}"; do
    if [[ "$p" == "$PLAN_NAME" ]]; then
      VALID=true
      break
    fi
  done
  if [[ "$VALID" == false ]]; then
    echo "Error: Invalid plan name '$PLAN_NAME'"
    echo "Available plans: ${PLAN_DIRS[*]}"
    exit 1
  fi
elif [[ ${#PLAN_DIRS[@]} -eq 1 ]]; then
  # Auto-select if only one plan
  PLAN_NAME="${PLAN_DIRS[0]}"
  echo "Auto-selecting plan: $PLAN_NAME"
else
  # Multiple plans, no selection provided
  echo "Error: Multiple plans found, please specify one with --plan"
  echo "Available plans: ${PLAN_DIRS[*]}"
  exit 1
fi

PLAN_PATH="$PLANS_DIR/$PLAN_NAME"

# Build file references for Claude
FILE_REFS="@plans/$PLAN_NAME/CLAUDE.md @plans/$PLAN_NAME/prd.json"

# Add learnings.md if it exists
if [[ -f "$PLAN_PATH/learnings.md" ]]; then
  FILE_REFS="$FILE_REFS @plans/$PLAN_NAME/learnings.md"
fi

# Add optional files if they exist
for optional in PLAN.md DESIGN.md API.md; do
  if [[ -f "$PLAN_PATH/$optional" ]]; then
    FILE_REFS="$FILE_REFS @plans/$PLAN_NAME/$optional"
  fi
done

# Build the prompt
PROMPT="$FILE_REFS You are implementing this project using the Ralph Wiggum technique.

YOUR TASK:
1. Read the documentation files provided above carefully
2. Read learnings.md (if it exists) for prior decisions and gotchas
3. Choose the highest-priority task with passes: false
   Priority order:
   - FIRST: Tasks with a 'priority' key (lower number = higher priority)
   - THEN: Architectural decisions and core abstractions (highest)
   - Integration points between modules
   - Standard features and implementation
   - Polish, cleanup, and quick wins (lowest)
4. Implement ONLY that ONE task. Follow all steps exactly.
5. Write tests for the feature (follow CLAUDE.md testing requirements)
6. Run ALL feedback loops before committing
7. When the task is complete and ALL verification steps pass:
   - Update prd.json to set passes: true
   - If there are notable decisions, failed approaches, gotchas, or new packages — append to learnings.md. Skip if the task was straightforward.
   - Propose a commit with a descriptive message
8. After the commit:
   - Output the appropriate promise tag
   - EXIT immediately

PROMISE TAGS:
- <promise>FEATURE_COMPLETE</promise> - Task done, committed
- <promise>ALL_COMPLETE</promise> - All tasks in prd.json complete
- <promise>BLOCKED</promise> - Need human help (explain why)

RULES:
- ONE task per iteration
- Small, focused changes - quality over speed
- Do NOT modify other features in prd.json
- Do NOT skip verification steps
- NEVER add packages unless explicitly listed in requiredPackages

Begin now."

echo "Running Ralph iteration for plan: $PLAN_NAME"
echo "Permission mode: $PERMISSION_MODE"
echo "---"

# Change to project directory and run Claude
cd "$PROJECT_DIR"

# Run claude with the prompt
# shellcheck disable=SC2086
exec claude $PERMISSION_MODE "$PROMPT"
