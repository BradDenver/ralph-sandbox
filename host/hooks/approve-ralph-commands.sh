#!/bin/bash
# PreToolUse hook: auto-approve bash commands used by ralph host plugin
# Receives JSON on stdin: {"tool_name": "Bash", "tool_input": {"command": "..."}}
# Returns allow decision for known-safe commands, falls through otherwise.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# If we can't parse the command, fall through
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

allow() {
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "ralph-host: auto-approved"}}'
  exit 0
}

# Shell basics
echo "$COMMAND" | grep -qE '^(pwd|basename |ls |cat |echo |grep )' && allow

# Docker sandbox commands
echo "$COMMAND" | grep -qE '^docker (sandbox (ls|create|exec|rm|run)|images|build) ' && allow
echo "$COMMAND" | grep -qE '^docker sandbox ls$' && allow

# tmux commands
echo "$COMMAND" | grep -qE '^tmux (has-session|new-session|kill-session|capture-pane|list-panes|attach) ' && allow

# Claude CLI
echo "$COMMAND" | grep -qE '^claude (plugin list|auth status)' && allow

# Everything else — fall through to normal permission handling
exit 0
