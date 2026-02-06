#!/bin/bash
# Ralph v2 Install Script
# Copies plugin to ~/.claude after the volume is mounted

# Ensure ~/.claude directories exist
mkdir -p ~/.claude/commands ~/.claude/skills ~/.claude/agents ~/.claude/rules

# Copy plugin components to user's claude config
cp -r /opt/ralph-plugin/plugin/commands/* ~/.claude/commands/ 2>/dev/null || true
cp -r /opt/ralph-plugin/plugin/skills/* ~/.claude/skills/ 2>/dev/null || true
cp -r /opt/ralph-plugin/plugin/agents/* ~/.claude/agents/ 2>/dev/null || true
cp -r /opt/ralph-plugin/plugin/rules/* ~/.claude/rules/ 2>/dev/null || true

# Make scripts available in PATH
mkdir -p ~/bin
cp /opt/ralph-plugin/scripts/*.sh ~/bin/ 2>/dev/null || true
chmod +x ~/bin/*.sh 2>/dev/null || true

echo "Ralph v2 installed! Commands: /ralph-once, /ralph-loop, /health-check"
