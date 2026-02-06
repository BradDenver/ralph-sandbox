#!/usr/bin/env bash
# ralph-loop.sh - Run continuous Ralph loop until complete or blocked
#
# Usage: ./scripts/ralph-loop.sh [--plan <name>] [--max-iterations <n>]
#
# Arguments:
#   --plan <name>           Specify plan name
#   --max-iterations <n>    Maximum iterations (default: 10)
#
# Note: This script requires Docker sandbox (uses --dangerously-skip-permissions)

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
  exit 1
fi

LOG_DIR="$PROJECT_DIR/ralph-logs"
LOG_FILE="$LOG_DIR/ralph-loop.log"

# Ensure logs directory exists
mkdir -p "$LOG_DIR"

# Docker sandbox detection
is_sandboxed() {
  [[ -f /.dockerenv ]] || \
  [[ -f /run/.containerenv ]] || \
  [[ "${DOCKER_SANDBOX:-}" == "1" ]] || \
  grep -q docker /proc/1/cgroup 2>/dev/null
}

# Require sandbox for loop mode
if ! is_sandboxed; then
  echo "Error: ralph-loop.sh requires Docker sandbox for autonomous execution."
  echo "Run via 'docker sandbox run' or use ralph-once.sh for supervised mode."
  exit 1
fi

# Parse arguments
PLAN_NAME=""
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      PLAN_NAME="$2"
      shift 2
      ;;
    --max-iterations)
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Detect available plans
PLAN_DIRS=()
for dir in "$PLANS_DIR"/*/; do
  if [[ -f "$dir/prd.json" ]]; then
    PLAN_DIRS+=("$(basename "$dir")")
  fi
done

if [[ ${#PLAN_DIRS[@]} -eq 0 ]]; then
  echo "Error: No plan folders found"
  exit 1
fi

# Plan selection
if [[ -n "$PLAN_NAME" ]]; then
  VALID=false
  for p in "${PLAN_DIRS[@]}"; do
    [[ "$p" == "$PLAN_NAME" ]] && VALID=true && break
  done
  [[ "$VALID" == false ]] && echo "Error: Invalid plan '$PLAN_NAME'" && exit 1
elif [[ ${#PLAN_DIRS[@]} -eq 1 ]]; then
  PLAN_NAME="${PLAN_DIRS[0]}"
  echo "Auto-selecting plan: $PLAN_NAME"
else
  echo "Error: Multiple plans found, specify with --plan"
  echo "Available: ${PLAN_DIRS[*]}"
  exit 1
fi

# Log function
log_event() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

echo "=== Ralph Loop Starting ==="
echo "Plan: $PLAN_NAME"
echo "Max iterations: $MAX_ITERATIONS"
echo "Log file: $LOG_FILE"
echo "==="

log_event "=== Ralph loop started: plan=$PLAN_NAME, max_iter=$MAX_ITERATIONS ==="

# Main loop
ITERATION=0
EXIT_REASON=""

while [[ $ITERATION -lt $MAX_ITERATIONS ]]; do
  ((++ITERATION))

  log_event "--- Iteration $ITERATION started ---"
  echo ""
  echo "=== Iteration $ITERATION of $MAX_ITERATIONS ==="
  echo ""

  # Run ralph-once.sh with skip-permissions
  set +e
  "$SCRIPT_DIR/ralph-once.sh" --plan "$PLAN_NAME" --skip-permissions 2>&1 | tee -a "$LOG_FILE"
  RALPH_EXIT=$?
  set -e

  log_event "--- Iteration $ITERATION completed (exit code: $RALPH_EXIT) ---"

  # Check exit code
  if [[ $RALPH_EXIT -ne 0 ]]; then
    log_event "ERROR: ralph-once.sh exited with code $RALPH_EXIT"
    EXIT_REASON="ERROR"
    break
  fi

  # Check log for promise tags
  if grep -q '<promise>ALL_COMPLETE</promise>' "$LOG_FILE" 2>/dev/null; then
    log_event "ALL_COMPLETE detected"
    EXIT_REASON="ALL_COMPLETE"
    break
  fi

  if grep -q '<promise>BLOCKED</promise>' "$LOG_FILE" 2>/dev/null; then
    log_event "BLOCKED detected"
    EXIT_REASON="BLOCKED"
    break
  fi
done

# Final summary
echo ""
echo "=== Ralph Loop Finished ==="

case "$EXIT_REASON" in
  "ALL_COMPLETE")
    echo "✓ All tasks complete!"
    log_event "=== Loop ended: ALL_COMPLETE ==="
    ;;
  "BLOCKED")
    echo "⚠ Blocked - check log for details"
    log_event "=== Loop ended: BLOCKED ==="
    ;;
  "ERROR")
    echo "✗ Error occurred"
    log_event "=== Loop ended: ERROR ==="
    ;;
  "")
    echo "Max iterations reached ($MAX_ITERATIONS)"
    log_event "=== Loop ended: max iterations ==="
    ;;
esac

echo "Completed $ITERATION iteration(s)"
echo "Log file: $LOG_FILE"
