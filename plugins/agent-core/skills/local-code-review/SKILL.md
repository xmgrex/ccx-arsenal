---
name: local-code-review
description: Reviews uncommitted git changes like a PR review using sub-agents, auto-fixing Critical issues (security, crashes, data loss) with confirmation. Use when you want to review local changes, check code quality, or get feedback before committing. Trigger phrases - "review my changes", "local review", "check my code", "pre-commit review"
disable-model-invocation: true
---

# Local Code Review

Review uncommitted changes like a pull request, using sub-agents for analysis. Critical findings (security, crashes, data loss) are auto-fixed with user confirmation.

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
Also detect the project's verification commands for later use in auto-fix:
- Linter: `.eslintrc` → `npx eslint`, `pyproject.toml` → `ruff check`, etc.
- Type check: `tsconfig.json` → `tsc --noEmit`, `mypy`, `pyright`, etc.
- Build: language-appropriate build command

### 3. Evaluate Scope

```
Changed files count?
    │
    ├─ ≤10 files ───► Single agent review
    ├─ 11-30 files ─► Directory-grouped parallel agents
    └─ >30 files ──► Directory-grouped parallel agents
                     + cross-cutting summary agent
```

**Single agent**: One sub-agent reviews the entire diff.

**Directory-grouped parallel**: Group changed files by top-level directory. Launch one sub-agent per group. Each sub-agent reviews only its group's diff independently.

**Directory-grouped + summary agent**: Same fan-out as above, plus a final `advanced-general-purpose` agent that receives all group reports (not raw diffs) and performs cross-cutting analysis:
- Dependency direction contradictions across groups
- Convention inconsistencies (e.g., different error handling patterns between groups)
- Project-wide impact of changes in shared utilities
- Duplicate findings across groups (deduplicate and consolidate)

### 4. Delegate to Sub-agents

Launch sub-agents with the following structure:

**Sub-agent prompt must include**:
- Diff output (group-scoped for parallel, full for single agent)
- File list with change summary
- Project context (language, framework, conventions detected in Step 2)
- Focus areas from `$ARGUMENTS` (if provided)
- The 8 review categories below

**For directory-grouped parallel (11-30 files)**:
- Group changed files by top-level directory
- Launch all group agents in a single message (parallel execution)
- Each agent receives only its group's diff and file list
- Each agent returns findings in the standard structured output format

**For >30 files (with summary agent)**:
- Same fan-out as 11-30 case
- After all group agents complete, launch one `advanced-general-purpose` summary agent
- Summary agent receives: all group reports, full file list, project context
- Summary agent produces a unified final report

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

### 6. Auto-Fix Critical Findings

After the review report is generated, check for Critical findings.

```
Critical findings?
    │
    ├─ None ──► Output report as-is. Done.
    └─ Found ─► Proceed to auto-fix phase
```

**Critical criteria (exhaustive — nothing else qualifies):**

| Category | Examples |
|----------|----------|
| Security vulnerabilities | SQL injection, secrets/credentials in code, XSS, path traversal |
| Runtime errors / crashes | Null/undefined dereference, type mismatch, missing imports causing crash |
| Data loss / corruption | Write without transaction, race condition on shared state, silent data truncation |

Warnings, Suggestions, and Good Practices are **never** auto-fixed.

**Auto-fix flow:**

1. **Present** — Show the Critical findings list with file paths and line numbers
2. **Confirm** — AskUserQuestion: "N件の Critical issue が見つかりました。自動修正しますか？ (y/n)"。確認なしに修正しない
3. **Fix** — Launch `general-purpose` sub-agent per file (or per finding if files overlap). Each fix prompt includes: the specific finding, relevant code context, instruction to make the minimal change that resolves the issue
4. **Verify** — Run project verification commands detected in Step 2 (linter, type check, build). If verification fails, retry the fix (max 2 attempts). If still failing, report the failure without further attempts
5. **Final report** — Output the enhanced report:

```markdown
## Auto-Fix Summary

### Fixed (Critical)
- [x] Description — `file:line` — Fix: [brief description of change]

### Verification
- [linter]: PASS / FAIL
- [type check]: PASS / FAIL

## Remaining (Report Only)

### Warnings (Should Fix)
- [ ] Description — `file:line`

### Suggestions (Consider)
- [ ] Description — `file:line`

### Good Practices Observed
- Positive observation
```

## Agent Selection

| Signal | Agent |
|--------|-------|
| ≤10 files | `general-purpose` |
| 11-30 files, per group | `general-purpose` × N |
| >30 files, per group | `general-purpose` × N |
| >30 files, cross-cutting summary | `advanced-general-purpose` |
| "thoroughly", deep analysis | `advanced-general-purpose` |
| Auto-fix Critical findings | `general-purpose` per fix |

## Differentiation from simplify

| Aspect | local-code-review | simplify |
|--------|-------------------|----------|
| Purpose | PR-style review report | Auto-fix all issues |
| Auto-fix scope | Critical only (with confirmation) | Everything |
| Review axes | 8 configurable categories | 3 fixed (Reuse/Quality/Efficiency) |
| Project context | Yes (CLAUDE.md, linter configs) | No |
| Focus areas | Configurable via `$ARGUMENTS` | None |
| User confirmation | Required before auto-fix | Not required |

**When to use which:**
- `local-code-review` — comprehensive review with control over what gets fixed
- `simplify` — all issues fixed automatically without a review report

## Integration

- Use after **intent-first** to clarify review scope if request is vague
- Pairs with **complex-orchestrator** for directory-grouped parallel reviews
- Follow **delegation-triggers** guidelines for agent selection
- Pairs with **investigate** when auto-fix verification fails
- Distinct from **simplify** — see differentiation table above
