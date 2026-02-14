---
name: local-code-review
description: Reviews uncommitted git changes like a PR review using sub-agents. Use when you want to review local changes, check code quality, or get feedback before committing. Trigger phrases - "review my changes", "local review", "check my code", "pre-commit review"
disable-model-invocation: true
---

# Local Code Review

Review uncommitted changes like a pull request, using sub-agents for analysis.

## Usage

```
/local-code-review                        # Review all changes
/local-code-review security, performance  # Focus on specific areas
```

Focus areas via `$ARGUMENTS`: `security`, `performance`, `architecture`, `readability`, `error-handling`, `testing`

## Workflow

### 1. Gather Changes (parallel)

Run in parallel via Bash:
- `git status` — changed files overview
- `git diff` — unstaged changes
- `git diff --cached` — staged changes
- `git log -5 --oneline` — recent commits for context

If no changes found, report "No uncommitted changes to review" and stop.

### 2. Detect Project Context

Auto-detect project conventions by checking for:
- `CLAUDE.md` (project root and `.claude/` directory)
- `docs/` or `doc/` directory for architecture docs
- Linter/formatter configs (`.eslintrc`, `pyproject.toml`, `analysis_options.yaml`, etc.)
- Package manifests (`package.json`, `pubspec.yaml`, `Cargo.toml`, `go.mod`, etc.)

Read available files to understand project language, framework, and conventions.

### 3. Evaluate Scope

```
Changed files count?
    │
    ├─ ≤10 files ──► Single agent review
    └─ >10 files ──► Staged review by directory
```

**Staged review**: Group files by top-level directory, launch one sub-agent per group.

### 4. Delegate to Sub-agent

Launch Task with the following:

| Scenario | Agent |
|----------|-------|
| Standard review (≤10 files) | `general-purpose` |
| Deep analysis or complex logic | `advanced-general-purpose` |

**Sub-agent prompt must include**:
- Full diff output
- File list with change summary
- Project context (language, framework, conventions detected in Step 2)
- Focus areas from `$ARGUMENTS` (if provided)
- The 8 review categories below

### Review Categories

1. **Correctness** — Logic errors, edge cases, off-by-one, null/undefined handling
2. **Security** — Injection, auth issues, secrets exposure, OWASP Top 10
3. **Readability** — Naming, complexity, dead code, unclear intent
4. **Architecture** — Separation of concerns, dependency direction, project conventions
5. **Error Handling** — Missing catches, swallowed errors, unclear error messages
6. **Performance** — N+1 queries, unnecessary allocations, blocking operations
7. **Testing** — Missing test coverage for changed logic, test quality
8. **Project Conventions** — Style guide compliance, patterns used elsewhere in codebase

If `$ARGUMENTS` specifies focus areas, prioritize those categories but still scan all.

### 5. Structured Output

The sub-agent must return this format:

```markdown
## Review Summary

**Files Changed**: N files
**Language/Framework**: [detected]
**Overall Assessment**: Approved / Changes Requested / Needs Major Revision

## Findings

### Critical (Must Fix)
- [ ] Description — `file:line`

### Warnings (Should Fix)
- [ ] Description — `file:line`

### Suggestions (Consider)
- [ ] Description — `file:line`

### Good Practices Observed
- Positive observation

## Recommendations
- Actionable next steps
```

## Agent Selection

| Signal | Agent |
|--------|-------|
| Standard review | `general-purpose` |
| >10 files, staged | `general-purpose` per group |
| "thoroughly", deep analysis | `advanced-general-purpose` |

## Integration

- Use after **intent-first** to clarify review scope if request is vague
- Pairs with **complex-orchestrator** for staged reviews of large changesets
- Follow **delegation-triggers** guidelines for agent selection
