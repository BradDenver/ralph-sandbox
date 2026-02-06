---
description: Run single Ralph iteration (one task) with user approval for commits
---

# Ralph Once

Run a single Ralph iteration - implement one task from prd.json using a subagent.

## How It Works

1. Detect plan folders under `plans/`
2. If multiple plans, use AskUserQuestion to select
3. Read prd.json and find the highest priority task with `passes: false`
4. Spawn a Task subagent to implement it
5. When subagent completes:
   - Run code review
   - Show proposed commit
   - Wait for user approval
6. Report result

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

**Step 2: Task Selection**

Read prd.json and select highest priority task:
1. Tasks with explicit `priority` key (lower = higher priority)
2. Architectural/core tasks
3. Integration tasks
4. Standard features
5. Polish/cleanup

**Step 3: Run Subagent**

Build prompt for the selected task:
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
- PROPOSE a commit (do not auto-commit)
- Output promise tag when done:
  - <promise>FEATURE_COMPLETE</promise> - task done
  - <promise>ALL_COMPLETE</promise> - all tasks done
  - <promise>BLOCKED</promise> - need help
```

Spawn Task subagent with the prompt.

**Step 4: Review & Approve**

When subagent completes:
1. Run code review
2. Show summary of changes
3. Ask user to approve commit

```
Task completed: {description}

Changes:
- {file1}: {change description}
- {file2}: {change description}

Proposed commit message:
  {commit_message}

Approve this commit?
- Yes, commit
- No, review changes first
- Cancel
```

**Step 5: Report Result**

Report the promise tag and outcome:
- FEATURE_COMPLETE: Task done, committed
- ALL_COMPLETE: All tasks done!
- BLOCKED: Show blocker reason

## Difference from /ralph-loop

| Aspect | /ralph-once | /ralph-loop |
|--------|-------------|-------------|
| Tasks | One task | All tasks |
| Commits | User approves | Auto-commit |
| Permissions | acceptEdits | dangerously-skip |
| Use case | Supervised | Autonomous |

## Permissions

This command runs with `--permission-mode acceptEdits`.
User must approve bash commands but edits are auto-accepted.
