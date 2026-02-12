---
description: Create a new plan folder
---

# Create New Plan

Guide a user through creating a new plan folder with properly structured files.

## Step 1: Get Plan Name

Ask the user for the plan name (this will be the folder name under `plans/`).

Validation:
1. Check that `plans/{name}` doesn't already exist using Bash `ls plans/{name} 2>/dev/null`
2. Validate the name is a valid folder name (alphanumeric, hyphens, underscores only)
3. If validation fails, explain the issue and ask for a different name

## Step 2: Determine Plan Type

Check if there are existing plans in the project:
```bash
ls plans/ 2>/dev/null | head -5
```

Use AskUserQuestion to ask:
- **First plan in project** - Full project setup with tech stack, testing requirements, feedback loops
- **Feature plan** - A feature or module within an existing project (can inherit from existing plan)

If "Feature plan" is selected and other plans exist, ask which existing plan to use as a reference for inherited settings.

## Step 3: Gather Project Info

### For First Plan (Full Setup)

Use AskUserQuestion to collect the following information. You can ask in batches of 2-4 questions at a time:

**Required Information:**
- Project description (1-2 sentences explaining what this project does)
- Tech stack: runtime (Bun, Node, Deno), framework (React, Preact, Vue, etc.), key libraries
- Unit test location and runner (e.g., `src/__tests__/*.test.ts` with vitest)
- E2E test location and runner (e.g., `e2e/*.spec.ts` with playwright)
- Coverage requirements (e.g., 100% for .ts files, none for .tsx)
- Feedback loop commands (individual commands to run before commit, e.g., `bun run typecheck`, `bun run lint`, `bun run test`)
- Combined test command if it exists (e.g., `bun run test:all`)

**Optional Information:**
- Any project-specific requirements or constraints (e.g., "Target resolution: 1920x1080", "No scrolling allowed")
- Reference project path for patterns (e.g., `~/Documents/gh/some-other-project`)

### For Feature Plan (Inherits from existing)

The new plan will reference the parent plan's CLAUDE.md for shared settings (tech stack, testing, feedback loops).

Collect feature-specific info:
- Feature description (what does this feature/module do?)
- Any feature-specific requirements or constraints
- Any additional documentation needs specific to this feature

## Step 4: Optional Documentation

Ask if the user needs any of these documentation scaffolds:
- **PLAN.md** - Implementation overview (Overview, Architecture, Implementation Phases)
- **DESIGN.md** - Visual specification (Visual Spec, Colors, Typography, Layouts)
- **API.md** - API endpoints documentation (Endpoints, Request/Response Examples)

Use AskUserQuestion with multiSelect: true for this.

## Step 5: Generate Files

Create the plan folder and all required files:

### 5.1 Create folder structure

```bash
mkdir -p plans/{name}
```

### 5.2 Create CLAUDE.md

**For First Plan (Full Setup)** - Generate a complete CLAUDE.md with this template:

```markdown
# {Plan Name}

## Documentation Files (READ THESE FIRST)
- `plans/{name}/PLAN.md` - Project structure and implementation overview (if created)
- `plans/{name}/DESIGN.md` - Visual specification (if created)
- `plans/{name}/API.md` - API endpoints documentation (if created)
- `plans/{name}/prd.json` - Feature list with verification steps
- `plans/{name}/learnings.md` - Decisions, failed approaches, gotchas

## Quick Start
1. Read ALL documentation files above before starting
2. Read prd.json to see all features
3. Read learnings.md (if it exists) for prior decisions and gotchas
4. Pick ONE feature to work on (highest priority with passes: false, by category order)
5. Complete all verification steps for that feature
6. Update prd.json passes to true
7. Commit with descriptive message
8. If there are notable decisions, failed approaches, gotchas, or new packages — append to learnings.md

## Tech Stack
{tech_stack_from_user_input}

## Project Requirements
{project_requirements_if_provided}

## Reference Project
{reference_project_if_provided}

## Rules
- **Never remove or modify features in prd.json** (only change passes field)
- Always verify ALL steps before marking passes: true
- **One feature per session** - do not attempt multiple features
- Always commit working code

## Prioritization
When choosing your next task, prioritize in this order:
1. **Tasks with a `priority` key** - lower number = higher priority (e.g. `priority: 1` before `priority: 2`)
2. **Architectural decisions and core abstractions** (highest)
3. **Integration points between modules**
4. **Standard features and implementation**
5. **Polish, cleanup, and quick wins** (lowest)

Categories provide context, not strict ordering. Always check for explicit priority keys first.

**Note:** When adding new items to prd.json, **omit the `priority` field** unless specifically asked to include it.

## Testing Requirements
{testing_requirements_from_user_input}

### Test Structure
| File Type | Test Type | Location | Enforcement |
|-----------|-----------|----------|-------------|
{test_structure_table}

### When Implementing a Feature
1. Write the implementation code
2. Write unit tests for applicable files
3. Write E2E tests for UI interactions (verification steps from prd.json)
4. Run all feedback loops to verify everything passes
5. Only commit when all tests pass

## Feedback Loops (Run Before Committing)
Before committing any changes, run ALL feedback loops:

{feedback_loop_commands}

Or run all tests at once: `{combined_test_command}`

Do NOT commit if ANY feedback loop fails. Fix issues first.

## Quality Expectations
- This codebase will outlive the current implementation
- Every shortcut becomes technical debt
- Small, focused changes - quality over speed
- One logical change per commit
- Fight entropy - leave the codebase better than you found it

## Completion Promises (IMPORTANT)

When running via ralph.sh, you MUST output one of these promises before finishing:

**After completing a feature and committing:**
```
<promise>FEATURE_COMPLETE</promise>
```

**If ALL features in prd.json are complete:**
```
<promise>ALL_COMPLETE</promise>
```

**If you encounter an unresolvable blocker:**
```
<promise>BLOCKED</promise>
```

Always log blockers to learnings.md before outputting BLOCKED.
```

**For Feature Plan (Inherits from existing)** - Generate a simplified CLAUDE.md:

```markdown
# {Plan Name}

## Parent Plan
This plan inherits shared settings from `plans/{parent_plan}/CLAUDE.md`.

For tech stack, testing requirements, feedback loops, and quality expectations, see the parent plan.

## Documentation Files
- `plans/{name}/PLAN.md` - Implementation overview for this feature (if created)
- `plans/{name}/DESIGN.md` - Visual specification for this feature (if created)
- `plans/{name}/API.md` - API endpoints for this feature (if created)
- `plans/{name}/prd.json` - Feature list with verification steps
- `plans/{name}/learnings.md` - Decisions, failed approaches, gotchas

## Feature Description
{feature_description}

## Feature-Specific Requirements
{feature_requirements_if_provided}

## Quick Start
1. Read the parent plan's CLAUDE.md for project-wide settings
2. Read ALL documentation files in this plan folder
3. Read prd.json to see all tasks for this feature
4. Read learnings.md (if it exists) for prior decisions and gotchas
5. Pick ONE task to work on (highest priority with passes: false)
6. Complete all verification steps for that task
7. Update prd.json passes to true
8. Commit with descriptive message
9. If there are notable decisions, failed approaches, gotchas, or new packages — append to learnings.md

## Rules
- **Never remove or modify features in prd.json** (only change passes field)
- Always verify ALL steps before marking passes: true
- **One task per session** - do not attempt multiple tasks
- Always commit working code
- Follow the parent plan's testing and feedback loop requirements

## Completion Promises (IMPORTANT)

After completing a task and committing:
```
<promise>FEATURE_COMPLETE</promise>
```

If ALL tasks in prd.json are complete:
```
<promise>ALL_COMPLETE</promise>
```

If you encounter an unresolvable blocker:
```
<promise>BLOCKED</promise>
```
```

### 5.3 Create prd.json

Create an empty array:

```json
[]
```

### 5.4 Create learnings.md

For first plan:
```markdown
# Learnings

## Plan Created - {current_date}
- {project_description}
```

For feature plan:
```markdown
# Learnings

## Plan Created - {current_date}
- {feature_description} (parent: plans/{parent_plan})
```

Only include sections that have content. If a task had no notable decisions/gotchas/failures, skip the learnings.md update entirely.

Entry template for future tasks:
```markdown
---

## {task description}
**Task:** {task-id} | **Date:** {date}

**Decisions:**
- {why approach X over Y}

**Failed approaches:**
- {what was tried and why it didn't work}

**Gotchas:**
- {library quirks, version issues, non-obvious behavior}

**Installed:**
- {packages added, tools configured}
```

### 5.5 Create optional documentation scaffolds (if requested)

**PLAN.md scaffold:**
```markdown
# {Plan Name} - Implementation Plan

## Overview
{Brief description}

## Architecture
{Describe the high-level architecture}

## Project Structure
```
{folder structure}
```

## Implementation Phases
1. Phase 1: {description}
2. Phase 2: {description}
3. Phase 3: {description}
```

**DESIGN.md scaffold:**
```markdown
# {Plan Name} - Design Specification

## Visual Specification
{Describe the visual layout}

## Color Palette
- **Background**: `#xxx`
- **Primary**: `#xxx`
- **Text**: `#xxx`

## Typography
- **Font family**: {font}
- **Headings**: {size}
- **Body**: {size}

## Layouts
{Describe layouts with ASCII diagrams}
```

**API.md scaffold:**
```markdown
# API Specification

All endpoints are relative to the base API URL.

## GET /api/endpoint

### Request
{Parameters}

### Response
```json
{
  "field": "value"
}
```

## POST /api/endpoint

### Request
```json
{
  "field": "value"
}
```

### Response
```json
{
  "success": true
}
```
```

## Step 6: Offer to Commit

After creating all files, ask the user:
"Plan folder created at `plans/{name}/`. Would you like me to commit this?"

If yes, commit with message: "Add {plan_name} plan folder with initial structure"

## Reference

See `.claude/templates/plan-CLAUDE.md` for the template structure.
