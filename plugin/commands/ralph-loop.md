---
description: Run autonomous Ralph loop through all prd.json tasks using subagents
---

# Ralph Loop

Run an autonomous loop through all tasks in prd.json, using subagents for context isolation.

## How It Works

1. Detect plan folders under `plans/`
2. If multiple plans, use AskUserQuestion to select
3. Read prd.json and find tasks with `passes: false`
4. For each task (in priority order):
   a. Spawn a Task subagent with fresh context
   b. Subagent implements the task
   c. Monitor for promise tags
   d. Run code review after FEATURE_COMPLETE
   e. Continue to next task
5. Exit when ALL_COMPLETE or BLOCKED

## Execution

**Step 1: Plan Selection**

```bash
# Detect plans
ls plans/*/prd.json 2>/dev/null
```

If multiple plans exist, ask:
```
Which plan should I work on?
- plan-a
- plan-b
```

**Step 2: Task Loop**

For each task with `passes: false`:

1. Build the subagent prompt:
```
You are implementing a task from a PRD.

## Task
Category: {category}
Description: {description}

## Context
Problem: {context.problem}
Solution: {context.solution}

## Files to Modify
{filesToModify}

## Implementation Steps
{steps}

## Rules
- Follow ALL steps exactly
- Run ALL feedback loops before committing
- Update prd.json passes to true when complete
- Commit with descriptive message
- Output promise tag when done:
  - <promise>FEATURE_COMPLETE</promise> - task done
  - <promise>ALL_COMPLETE</promise> - all tasks done
  - <promise>BLOCKED</promise> - need help
```

2. Spawn Task subagent with the prompt
3. Wait for completion
4. Parse result for promise tag
5. If FEATURE_COMPLETE:
   - Run /code-review
   - Continue to next task
6. If BLOCKED:
   - Report blocker
   - Pause for user input
7. If ALL_COMPLETE:
   - Report success
   - Exit

## Promise Tag Handling

| Tag | Action |
|-----|--------|
| FEATURE_COMPLETE | Run code review, continue to next task |
| ALL_COMPLETE | Report success, exit loop |
| BLOCKED | Report blocker, pause |

## Code Review After Each Task

After each FEATURE_COMPLETE, automatically run code review:
- Use code-reviewer agent
- Check for security issues
- Verify code quality
- Report any concerns

## Error Handling

If subagent fails without promise tag:
1. Check logs for error
2. Report the issue
3. Ask user whether to:
   - Retry the task
   - Skip to next task
   - Stop the loop

## Permissions

This command runs with `--dangerously-skip-permissions` for autonomous operation.
Only use inside Docker sandbox.
