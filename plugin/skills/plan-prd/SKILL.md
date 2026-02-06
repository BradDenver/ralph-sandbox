---
description: Plan a feature and create a PRD item
---

# Plan to PRD

Guide a planning session and create a comprehensive PRD item.

## Step 1: Identify Target Plan

If there are multiple plan directories under `plans/`, ask which plan this PRD item is for.
If the user hasn't specified and multiple exist, use AskUserQuestion to clarify.
If only one plan exists, use that one automatically.

## Step 2: Research Phase (Read-Only)

Before making any changes:
1. Use Explore agents to understand relevant code areas
2. Read existing files that will be modified
3. Read `plans/<plan>/progress.txt` for learnings from similar past implementations
4. Use AskUserQuestion to clarify ambiguous requirements
5. Do NOT make any edits yet

## Step 3: Draft the Plan

Write your plan to `.claude/plans/current-prd-draft.md`. Include:
- Problem being solved
- Proposed solution and benefit
- Files to modify (with descriptions)
- Implementation approach with code snippets where helpful
- Step-by-step implementation instructions

Iterate with the user until they're satisfied with the plan.

## Step 4: Convert to PRD Item

When the user approves the plan, format it as a PRD item with this structure:

```json
{
  "category": "<use existing categories as guide (foundation, auth, integration, bugfix, performance, testing, refactor, styling, mocks, tooling) - prefer general categories, new ones can be added if needed>",
  "description": "<brief description of the feature/fix>",
  "requiredPackages": ["<package-name>"],
  "context": {
    "problem": "<what problem this solves>",
    "solution": "<how it solves it>",
    "benefit": "<why this matters>"
  },
  "filesToModify": [
    "<file path> - <what changes>"
  ],
  "implementation": {
    "<file or component>": {
      "<aspect>": "<details>",
      "code": "<code snippet if helpful>"
    }
  },
  "steps": [
    "<detailed step 1>",
    "<detailed step 2 with line numbers if known>"
  ],
  "passes": false
}
```

## Important Rules

1. **Never add a `priority` field** unless the user explicitly requests it
2. **Prefer general categories** - use existing ones as a guide, new ones can be added if needed
3. **Steps should be detailed enough** to implement without re-reading the plan
4. **Include code snippets** in implementation when the exact code is known
5. **Include line numbers** in steps when you know them from exploration

## Writing for ralph.sh Automation

PRD items are consumed by ralph.sh which runs Claude autonomously to implement features.
The PRD must be self-contained and unambiguous for automated implementation.

### What ralph.sh expects:
- Picks highest priority feature with `passes: false`
- Implements following the steps exactly
- Runs `bun run test:all` (typecheck, lint, unit tests, E2E, build)
- Updates `passes: true` and commits
- Logs learnings to progress.txt
- Outputs `<promise>FEATURE_COMPLETE</promise>` when done

### PRD items MUST include:

1. **Required packages** - If the feature needs any packages not already in package.json:
   - List each package with exact name: `"requiredPackages": ["@tanstack/react-query", "zod"]`
   - ralph.sh will BLOCK if it needs a package not specified here
   - Check package.json first to see what's already installed
2. **Specific file paths** - exact paths, not vague references
3. **Line numbers when known** - "In src/main.tsx line 44" not "In main.tsx"
4. **Complete code snippets** - working code, not pseudocode or hints
5. **Testing requirements**:
   - For `.ts` files: "Add unit tests in src/__tests__/<name>.test.ts"
   - For `.tsx` files: "Add E2E tests in e2e/<name>.spec.ts"
   - What specific behaviors to test
6. **Verification steps** that match test:all expectations:
   - "Run bun run typecheck to verify no type errors"
   - "Run bun run test:all to ensure all tests pass"
7. **References to design docs** when relevant:
   - "See plans/<plan>/DESIGN.md for visual spec"
   - "See plans/<plan>/API.md for endpoint details"
8. **Clear success criteria** - how to know it's done

### PRD items should NOT include:
- Vague instructions like "update as needed"
- Missing context that requires asking questions
- Incomplete code that needs filling in
- Steps that depend on human judgment

### Reference past implementations:
Check progress.txt for similar features. If a past session solved a related problem,
reference the learnings. Example: "Similar to Session 47 approach for formatMetricValue"

## Step 5: Add to prd.json

Append the PRD item to `plans/<plan-name>/prd.json`.

## Step 6: Offer to Commit

After adding the PRD item, ask the user:
"PRD item added. Would you like me to commit this update?"

If yes, commit using user's preferred commit message conventions.
