#!/usr/bin/env bash
# Spike 5: Does `claude update` work inside a Docker sandbox?
#
# Questions:
#   S5-Q1: Does `claude update` command exist in the sandbox?
#   S5-Q2: Can it reach the update server (given network restrictions)?
#   S5-Q3: Does it actually update (or report already up-to-date)?
#
# Prerequisites:
#   - Docker Desktop running with `docker sandbox` CLI
#   - ralph-template:latest built (or use stock claude-code template)
#
# Usage:
#   ./docs/shaping/spikes/spike-5-claude-update.sh [workspace-path]
#
# If no workspace-path given, creates a temp directory.

set -euo pipefail

WORKSPACE="${1:-}"
CLEANUP_WORKSPACE=false
SANDBOX_NAME="spike-5-update"
PASS=0
FAIL=0
SKIP=0

cleanup() {
  echo ""
  echo "--- Cleanup ---"
  docker sandbox rm "$SANDBOX_NAME" 2>/dev/null || true
  if [[ "$CLEANUP_WORKSPACE" == true && -n "$WORKSPACE" ]]; then
    rm -rf "$WORKSPACE"
  fi
  echo ""
  echo "=== Results: PASS=$PASS FAIL=$FAIL SKIP=$SKIP ==="
}
trap cleanup EXIT

# Create temp workspace if none provided
if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE=$(mktemp -d "${TMPDIR:-/tmp}/spike5-XXXXXX")
  CLEANUP_WORKSPACE=true
  echo "Created temp workspace: $WORKSPACE"
fi

echo "=== Spike 5: claude update inside Docker sandbox ==="
echo ""

# --- Setup: Create sandbox ---
echo "--- Setup: Creating sandbox ---"
# Try with ralph-template first, fall back to stock
if docker images ralph-template:latest --format '{{.Repository}}' 2>/dev/null | grep -q ralph-template; then
  echo "Using ralph-template:latest"
  docker sandbox create --name "$SANDBOX_NAME" -t ralph-template:latest claude "$WORKSPACE"
else
  echo "ralph-template not found, using stock claude agent"
  docker sandbox create --name "$SANDBOX_NAME" claude "$WORKSPACE"
fi
echo "Sandbox created."
echo ""

# --- S5-Q1: Does claude update command exist? ---
echo "--- S5-Q1: Does 'claude update' command exist? ---"
UPDATE_HELP=$(docker sandbox exec "$SANDBOX_NAME" /home/agent/.local/bin/claude update --help 2>&1) || true
echo "$UPDATE_HELP"
echo ""

if echo "$UPDATE_HELP" | grep -qi "update\|upgrade\|version"; then
  echo "Q1: PASS — claude update command exists"
  PASS=$((PASS + 1))
else
  echo "Q1: FAIL — claude update command not recognized"
  FAIL=$((FAIL + 1))
  echo ""
  echo "=== Stopping early — update command doesn't exist ==="
  exit 0
fi
echo ""

# --- S5-Q2: Get current version before update ---
echo "--- S5-Q2: Current version before update ---"
VERSION_BEFORE=$(docker sandbox exec "$SANDBOX_NAME" /home/agent/.local/bin/claude --version 2>&1) || true
echo "Version before: $VERSION_BEFORE"
echo ""

# --- S5-Q3: Run claude update — does it work or hit network restriction? ---
echo "--- S5-Q3: Run 'claude update' — does network work? ---"
echo "(This may take a moment...)"
echo ""

# Run with a timeout via background + wait
UPDATE_OUTPUT_FILE=$(mktemp)
docker sandbox exec "$SANDBOX_NAME" /home/agent/.local/bin/claude update 2>&1 > "$UPDATE_OUTPUT_FILE" &
UPDATE_PID=$!

# Wait up to 60 seconds
WAITED=0
while kill -0 "$UPDATE_PID" 2>/dev/null && [[ $WAITED -lt 60 ]]; do
  sleep 2
  WAITED=$((WAITED + 2))
done

if kill -0 "$UPDATE_PID" 2>/dev/null; then
  echo "Update command timed out after 60s — killing"
  kill "$UPDATE_PID" 2>/dev/null || true
  wait "$UPDATE_PID" 2>/dev/null || true
  UPDATE_OUTPUT=$(cat "$UPDATE_OUTPUT_FILE")
  echo "$UPDATE_OUTPUT"
  echo ""
  echo "Q3: FAIL — timed out (likely network restriction)"
  FAIL=$((FAIL + 1))
else
  wait "$UPDATE_PID" 2>/dev/null
  UPDATE_EXIT=$?
  UPDATE_OUTPUT=$(cat "$UPDATE_OUTPUT_FILE")
  echo "$UPDATE_OUTPUT"
  echo ""

  if echo "$UPDATE_OUTPUT" | grep -qi "already.*up.to.date\|updated\|success\|latest"; then
    echo "Q3: PASS — update command completed successfully"
    PASS=$((PASS + 1))
  elif echo "$UPDATE_OUTPUT" | grep -qi "error\|fail\|network\|connect\|refused\|timeout"; then
    echo "Q3: FAIL — update command failed (likely network restriction)"
    FAIL=$((FAIL + 1))
  else
    echo "Q3: UNCLEAR — exit code $UPDATE_EXIT, output above. Manual review needed."
    SKIP=$((SKIP + 1))
  fi
fi
rm -f "$UPDATE_OUTPUT_FILE"
echo ""

# --- S5-Q4: Version after update ---
echo "--- S5-Q4: Version after update ---"
VERSION_AFTER=$(docker sandbox exec "$SANDBOX_NAME" /home/agent/.local/bin/claude --version 2>&1) || true
echo "Version after: $VERSION_AFTER"
echo ""

if [[ "$VERSION_BEFORE" == "$VERSION_AFTER" ]]; then
  echo "Version unchanged: $VERSION_BEFORE"
  echo "(Either already latest, or update failed)"
else
  echo "Version changed: $VERSION_BEFORE → $VERSION_AFTER"
  echo "Q4: PASS — update actually changed the version"
  PASS=$((PASS + 1))
fi
echo ""

echo "=== Spike 5 Complete ==="
