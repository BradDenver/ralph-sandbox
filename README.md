# Ralph Sandbox

Autonomous coding loops with Docker AI Sandboxes. A custom sandbox template with pre-installed plugin for plan-driven development.

## What It Does

- **Plan-driven workflow**: Define tasks in `prd.json`, Claude executes them one at a time
- **Promise tags**: `FEATURE_COMPLETE`, `ALL_COMPLETE`, `BLOCKED` signal iteration status
- **Two modes**: Supervised (`/ralph-once`) or autonomous (`/ralph-loop`)
- **Pre-installed tooling**: Code review, TDD, build-fix, verification loops, continuous learning

## Quick Start

```bash
# 1. Build the sandbox template
cd ralph-sandbox
docker build -t ralph-sandbox -f docker/Dockerfile .

# 2. Enter sandbox in your project
docker sandbox run --template ralph-sandbox /path/to/project claude

# 3. Initialize ralph scripts (one time per project)
/ralph-init

# 4. Exit and run interactively from terminal
./ralph/ralph-once.sh
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Docker Sandbox (ralph-sandbox)             │
│                                                         │
│  ~/.claude/commands/  ← Plugin commands auto-installed  │
│  ~/.claude/skills/    ← Plugin skills auto-installed    │
│  ~/.claude/agents/    ← Plugin agents auto-installed    │
│  ~/.claude/rules/     ← Plugin rules auto-installed     │
│                                                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │         Claude (with full plugin tooling)          │ │
│  │                                                    │ │
│  │  /ralph-once  → single task, user approves commit  │ │
│  │  /ralph-loop  → autonomous until complete/blocked  │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Commands

| Command | Description |
|---------|-------------|
| `/ralph-init` | Install ralph scripts to project for terminal use |
| `/ralph-once` | Run single task (supervised, approves commits) |
| `/ralph-loop` | Run autonomous loop until complete or blocked |
| `/health-check` | Verify project has required plan structure |
| `/tdd` | Test-driven development workflow |
| `/code-review` | Run code review on changes |
| `/build-fix` | Fix build/lint/type errors |
| `/verify` | Run verification loop |
| `/learn` | Capture learnings to learnings.md |
| `/refactor-clean` | Refactor and clean code |

## Project Scripts (after /ralph-init)

```bash
./ralph/ralph-once.sh           # Run single iteration (launches sandbox)
./ralph/ralph-once.sh my-plan   # Specify plan name
./ralph/sandbox.sh              # Enter sandbox interactively
```

## Plan Structure

```
your-project/
├── plans/
│   └── <plan-name>/
│       ├── CLAUDE.md      # Project guidance (required)
│       ├── prd.json       # Task definitions (required)
│       ├── learnings.md    # Decisions & context (optional)
│       ├── PLAN.md        # Implementation overview (optional)
│       ├── DESIGN.md      # Visual specs (optional)
│       └── API.md         # API docs (optional)
└── ralph/                 # Created by /ralph-init
    ├── ralph-once.sh
    └── sandbox.sh
```

## prd.json Format

```json
{
  "planName": "my-feature",
  "description": "What this plan accomplishes",
  "tasks": [
    {
      "id": "task-001",
      "category": "feature",
      "description": "What to build",
      "status": "pending",
      "context": "Problem/solution context",
      "filesToModify": ["src/file.ts"],
      "implementation": {
        "approach": "How to implement",
        "considerations": ["Edge cases", "Dependencies"]
      },
      "steps": ["Step 1", "Step 2"],
      "passes": false
    }
  ]
}
```

## Promise Tags

Claude outputs these to signal iteration status:

```xml
<promise>FEATURE_COMPLETE</promise>  <!-- Task done, continue loop -->
<promise>ALL_COMPLETE</promise>       <!-- All tasks done, stop -->
<promise>BLOCKED</promise>            <!-- Need human help, stop -->
```

## Execution Modes

| Mode | How | Permissions | Use Case |
|------|-----|-------------|----------|
| Interactive | `./ralph/ralph-once.sh` | acceptEdits | Terminal, supervised |
| Command | `/ralph-once` | acceptEdits | In sandbox, supervised |
| Autonomous | `/ralph-loop` | dangerously-skip | In sandbox, unattended |

## Plugin Contents

**Agents (9)**
- code-reviewer, security-reviewer, tdd-guide, planner, architect
- build-error-resolver, refactor-cleaner, doc-updater, e2e-runner

**Skills (7)**
- new-plan, plan-prd, tdd-workflow, coding-standards
- security-review, verification-loop, continuous-learning-v2

**Commands (10)**
- /ralph-init, /ralph-once, /ralph-loop, /health-check
- /tdd, /code-review, /build-fix, /verify, /learn, /refactor-clean

**Rules (7)**
- agents, coding-style, commit-conventions, hooks
- patterns, performance, security

## File Structure

```
ralph-sandbox/
├── docker/
│   ├── Dockerfile          # Sandbox template
│   └── entrypoint.sh       # Install script (reference)
├── plugin/
│   ├── agents/             # 9 agent definitions
│   ├── commands/           # 10 command definitions
│   ├── skills/             # 7 skill definitions
│   ├── rules/              # 7 rule definitions
│   └── hooks/              # (empty, for future use)
├── scripts/
│   ├── ralph-once.sh       # Standalone iteration script
│   └── ralph-loop.sh       # Standalone loop script
├── .claude-plugin/
│   ├── plugin.json         # Plugin manifest
│   └── marketplace.json    # Marketplace metadata
└── README.md
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_TEMPLATE` | `ralph-sandbox` | Docker template name |

## License

MIT
