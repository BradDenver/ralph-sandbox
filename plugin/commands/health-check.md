---
description: Verify project is properly configured for Ralph workflows
---

# Health Check

Verify a project has everything needed for Ralph workflows.

## What It Checks

### Required Files

| File | Purpose | Required |
|------|---------|----------|
| `plans/<name>/CLAUDE.md` | Project guidance | ✓ |
| `plans/<name>/prd.json` | Task definitions | ✓ |
| `plans/<name>/progress.txt` | Session learnings | ✓ |

### Optional Files

| File | Purpose |
|------|---------|
| `plans/<name>/PLAN.md` | Implementation overview |
| `plans/<name>/DESIGN.md` | Visual specification |
| `plans/<name>/API.md` | API documentation |

### CLAUDE.md Contents

Check that CLAUDE.md includes:
- [ ] Tech stack definition
- [ ] Testing requirements (unit, e2e locations)
- [ ] Feedback loop commands
- [ ] Promise tag instructions
- [ ] Quality expectations

### prd.json Format

Verify each task has:
- [ ] `category` - task category
- [ ] `description` - what to build
- [ ] `context` - problem/solution/benefit
- [ ] `steps` - implementation steps
- [ ] `passes` - completion status (boolean: `true` or `false`, NOT an array)

**Type Validation**:
- `passes` MUST be a boolean (`true` or `false`)
- If `passes` is an array, string, or any other type, report an error
- Error message: "Invalid passes type: expected boolean, got <actual-type>"

### Project Setup

Check project has:
- [ ] `package.json` exists
- [ ] Test command defined (`test`, `test:all`, etc.)
- [ ] Lint command defined (`lint`, `check`, etc.)
- [ ] Build command defined (if applicable)

## Execution

**Step 1: Find Plans**

```bash
ls plans/*/prd.json 2>/dev/null
```

**Step 2: Check Each Plan**

For each plan directory:

1. Check required files exist
2. Validate CLAUDE.md contents
3. Parse and validate prd.json
4. Report findings

**Step 3: Check Project Setup**

```bash
# Check package.json
cat package.json | jq '.scripts | keys'
```

**Step 4: Report**

Output a health report:

```
# Ralph Health Check Report

## Plan: my-feature

### Required Files
✓ CLAUDE.md exists
✓ prd.json exists
✓ progress.txt exists

### Optional Files
✓ PLAN.md exists
✗ DESIGN.md missing
✗ API.md missing

### CLAUDE.md Contents
✓ Tech stack defined
✓ Testing requirements defined
✓ Feedback loops defined
✗ Promise tags not mentioned

### prd.json Validation
✓ Valid JSON
✓ 3 tasks defined
✓ All tasks have required fields
  - 2 tasks pending (passes: false)
  - 1 task complete (passes: true)

### Project Setup
✓ package.json exists
✓ test command: bun run test
✓ lint command: bun run lint
✓ build command: bun run build

## Summary
- 1 issue found
- Recommendation: Add promise tag instructions to CLAUDE.md
```

## Fix Suggestions

For each issue found, provide a fix suggestion:

| Issue | Fix |
|-------|-----|
| Missing CLAUDE.md | Run `/new-plan` to create plan structure |
| Missing prd.json | Run `/plan-prd` to create first task |
| Missing progress.txt | Create empty file with header |
| No tech stack | Add `## Tech Stack` section to CLAUDE.md |
| No feedback loops | Add `## Feedback Loops` section |
| Invalid prd.json | Show specific validation errors |
| `passes` is not a boolean | Change `"passes": [...]` to `"passes": false` or `"passes": true` |

## Usage

```
/health-check              # Check all plans
/health-check my-feature   # Check specific plan
```
