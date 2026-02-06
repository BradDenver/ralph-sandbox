# Commit Conventions

## Format

```
type[optional scope][optional !]: description

[optional body]

[optional footer(s)]
```

## Requirements

**Type** (required): feat, fix, chore, docs, test, style, refactor, perf, build, ci

**Scope** (optional but preferred): Part/feature being changed (e.g., "Demo", "Auth", "API")

**Breaking Change**: Add `!` after scope: `feat(api)!: description`

**Description**:
- Max 50 characters
- Imperative mood ("add" not "added")
- Present tense ("fix" not "fixed")

**Body** (optional):
- Blank line after description
- Explain "what" and "why", not "how"
- Wrap at 72 characters

**Footer**:
- Blank line after body
- Format: `Token: value`
- **Always include `Refs: INS-XXX`** if ticket found in branch name (e.g., `chore/INS-123`)
- Breaking changes: `BREAKING CHANGE: description`

## Type Guide

| Type | Purpose | SemVer |
|------|---------|--------|
| feat | New feature | MINOR |
| fix | Bug fix | PATCH |
| chore | Maintenance, non-functional |  |
| docs | Documentation |  |
| test | Test additions/updates |  |
| style | Formatting (no code change) |  |
| refactor | Code change (no bug/feature) |  |
| perf | Performance improvement |  |
| build | Build system/dependencies |  |
| ci | CI configuration |  |

## Example

```bash
git commit -m "$(cat <<'EOF'
feat(auth): add OAuth2 login flow

Replaces basic auth with OAuth2 for improved security.
Users can now login via Google or GitHub.

BREAKING CHANGE: Basic auth endpoints removed
Refs: INS-456
EOF
)"
```
