---
description: Show combined timeline of plan activity (tasks, commits, learnings)
---

# Ralph Plan Log

Stitch together prd.json tasks, git commits, and learnings into a single timeline view.

## Execution

**Step 1: Plan Selection**

```bash
ls plans/*/prd.json 2>/dev/null
```

- If no plans found, report "No plans found" and stop.
- If exactly one plan, auto-select it.
- If multiple, use AskUserQuestion to pick one.

Extract `<plan-name>` from the path `plans/<plan-name>/prd.json`.

**Step 2: Read prd.json**

Read `plans/<plan-name>/prd.json`. Handle both formats:
- Object with `tasks` array: use `.tasks`
- Root-level array: use directly

For each task, capture: `id`, `category`, `description`, `passes`.

Separate into two lists: completed (`passes: true`) and pending (`passes: false`).

**Step 3: Read learnings.md (optional)**

Read `plans/<plan-name>/learnings.md` if it exists. If missing, skip — this is not an error.

Parse entries by splitting on `---` separators. For each entry, look for a `**Task:**` line to extract the task id. Build a map of `task-id → learning content`.

**Step 4: Git History**

Get commits that touched the plan folder:

```bash
git log --oneline --name-only -- plans/<plan-name>/
```

For each commit that modified `plans/<plan-name>/prd.json` (these mark task completion boundaries), get the full diff stat:

```bash
git show --stat <hash>
```

Extract the commit hash, message, and list of changed files. Exclude `prd.json` and `learnings.md` from the changed-files list since those are bookkeeping.

Build a list of these "task completion commits" with their changed files.

**Step 5: Commit-to-Task Matching**

Match commits to completed tasks using order: the most recent prd.json-touching commit corresponds to the most recently completed task. If commit messages contain a task id or task description keywords, prefer that match.

Any commits that don't match a specific task get listed under a general "Other Commits" section.

**Step 6: Output**

Print the following, completed tasks first, then pending:

```
# Plan Log: {plan-name}

## ✓ {task description}
**Category:** {category}

**Commit:** {hash} {message}
**Changed:** {file1}, {file2}, ...

**Learnings:**
- {matched learning content from learnings.md}

---

## ✓ {another completed task}
**Category:** {category}

**Commit:** {hash} {message}
**Changed:** {file1}, {file2}, ...

---

## ○ {pending task description}
**Category:** {category}

---

## ○ {another pending task}
**Category:** {category}

---

{n} complete, {m} pending
```

Rules for output:
- Omit **Commit:** section if no matching commit found for a completed task
- Omit **Changed:** if no files changed (besides prd.json/learnings.md)
- Omit **Learnings:** section if no matching learning entry exists
- If there are unmatched learnings (not tied to any task), append them at the end under `## Other Learnings`
- The final summary line uses counts: e.g. `2 complete, 3 pending`

## Edge Cases

- **No learnings.md**: Works fine — just skip learnings sections
- **No completed tasks**: Show all tasks as pending, no commit sections
- **No git history**: Show tasks without commit info
- **prd.json is a root array (no .tasks key)**: Use the array directly
- **Tasks without ids**: Match learnings by description keywords instead

## Usage

```
/ralph-plan-log              # Auto-select if one plan
/ralph-plan-log my-feature   # Specific plan
```
