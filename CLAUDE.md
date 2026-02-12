# Ralph Sandbox - Development Guide

## Overview

Ralph Sandbox is a Docker sandbox template that pre-installs a Claude Code plugin for autonomous coding loops. The plugin enables plan-driven development where tasks are defined in `prd.json` and executed one at a time with promise tag signaling.

## Tech Stack

- **Docker**: Sandbox template based on `docker/sandbox-templates:claude-code`
- **Bash**: Scripts for iteration control
- **Markdown**: Plugin definitions (commands, skills, agents, rules)
- **JSON**: Plugin manifests and prd.json task format

## Project Structure

```
ralph-sandbox/
├── docker/
│   └── Dockerfile          # Sandbox template - AUTO-INSTALLS plugin on startup
├── plugin/
│   ├── agents/             # Subagent definitions (Task tool)
│   ├── commands/           # Slash commands (/ralph-once, etc.)
│   ├── skills/             # Skill definitions (workflows, guides)
│   ├── rules/              # Always-on rules
│   └── hooks/              # (unused, for future)
├── scripts/
│   ├── ralph-once.sh       # Standalone single iteration
│   └── ralph-loop.sh       # Standalone loop (sandbox only)
├── .claude-plugin/
│   ├── plugin.json         # Plugin manifest
│   └── marketplace.json    # Marketplace metadata
├── CLAUDE.md               # This file
└── README.md               # User documentation
```

## Key Concepts

### Promise Tags
Claude outputs these to signal iteration status:
- `<promise>FEATURE_COMPLETE</promise>` - Task done, continue loop
- `<promise>ALL_COMPLETE</promise>` - All tasks done, stop
- `<promise>BLOCKED</promise>` - Need human help, stop

### Plan Structure
Projects using Ralph have a `plans/<name>/` folder with:
- `CLAUDE.md` - Project-specific guidance
- `prd.json` - Task definitions with status tracking
- `learnings.md` - Decisions, failed approaches, gotchas

### Execution Modes
- `/ralph-once` - Single task, user approves commits
- `/ralph-loop` - Autonomous loop until complete/blocked
- `./ralph/ralph-once.sh` - Terminal script (launches sandbox)

## How the Sandbox Template Works

The Dockerfile:
1. Copies plugin to `/opt/ralph-plugin/`
2. Creates entrypoint that copies to `~/.claude/` on startup
3. This happens AFTER volumes are mounted (key insight)

```dockerfile
USER root
COPY plugin /opt/ralph-plugin/plugin
RUN printf '...' > /usr/local/bin/ralph-entrypoint.sh
USER agent
ENTRYPOINT ["/usr/local/bin/ralph-entrypoint.sh"]
CMD ["claude"]
```

## Development Tasks

### Adding a New Command
1. Create `plugin/commands/<name>.md` with YAML frontmatter
2. Include `description` in frontmatter
3. Document execution steps in markdown
4. Rebuild Docker image

### Adding a New Agent
1. Create `plugin/agents/<name>.md`
2. Define the agent's role and capabilities
3. Agents are invoked via Task tool by commands

### Adding a New Skill
1. Create `plugin/skills/<name>/SKILL.md`
2. Can include additional files (scripts, configs)
3. Skills provide workflows and domain knowledge

### Adding a New Rule
1. Create `plugin/rules/<name>.md`
2. Rules are always-on guidance
3. Keep rules focused and actionable

## Testing

```bash
# Build the template
docker build -t ralph-sandbox -f docker/Dockerfile .

# Test in demo project
docker sandbox run --template ralph-sandbox ../ralph-sandbox-demo claude

# Verify commands are available
/health-check
```

## Demo Project

A demo project exists at `../ralph-sandbox-demo/` with:
- Simple TypeScript greeting utility plan
- Two tasks (create function, add tests)
- Ready for testing the workflow

## Known Limitations

1. **Non-interactive bash**: The `!` command in Claude runs non-interactively, so scripts can't use `read` or `select` for user input. Use CLI args instead.

2. **Volume mounting**: `~/.claude/` is mounted fresh on sandbox start, so plugin must be copied via entrypoint, not baked into image at that path.

3. **User is `agent`**: The sandbox runs as user `agent` in `/home/agent/`.

## Future Improvements

- [ ] Add hooks for pre/post task execution
- [ ] Improve continuous learning instincts integration
- [ ] Add more specialized agents (database, API, frontend)
- [ ] Create project templates for common setups
- [ ] Add metrics/logging for iteration tracking

## Feedback Loops

When modifying the plugin:
1. Rebuild Docker image
2. Test in sandbox with demo project
3. Verify commands appear and work
4. Test both `/ralph-once` and `./ralph/ralph-once.sh` flows
