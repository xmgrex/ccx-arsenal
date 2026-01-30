---
name: claude-md-auditor
description: Audit CLAUDE.md files for redundancy, verbosity, and adherence to best practices. This skill should be used when reviewing, improving, or cleaning up CLAUDE.md files to ensure they remain effective and concise.
disable-model-invocation: true
---

# CLAUDE.md Auditor

Audit and improve CLAUDE.md files based on Claude Code Best Practices.

## Audit Process

### Step 1: Read the Target CLAUDE.md

Read the CLAUDE.md file specified by $ARGUMENTS. If no path is provided, look for CLAUDE.md in the current working directory.

### Step 2: Load Best Practices Reference

Read `references/best-practices.md` to understand the evaluation criteria.

### Step 3: Analyze Each Section

For each section in CLAUDE.md, evaluate:

1. **Necessity**: Would removing this cause Claude to make mistakes?
2. **Redundancy**: Can Claude infer this from the codebase?
3. **Accuracy**: Is this still accurate and relevant?
4. **Specificity**: Is this actionable or too vague?
5. **Length**: Is this concise or overly verbose?

### Step 4: Generate Audit Report

Output a structured report in this format:

```markdown
# CLAUDE.md Audit Report

## Summary
- Total lines: X
- Lines to remove: Y
- Lines to improve: Z
- Health score: X/10

## Issues Found

### Redundant Content
[List items that Claude can infer from code]

### Overly Verbose
[List sections that should be condensed]

### Stale/Outdated
[List references to old patterns or removed features]

### Vague Instructions
[List non-actionable guidance]

### Missing Information
[List recommended additions based on codebase analysis]

## Recommended Changes

### Remove
[Specific lines/sections to delete]

### Condense
[Suggestions for making sections more concise]

### Add
[Recommended additions with rationale]
```

### Step 5: Offer to Apply Changes

After presenting the report, ask the user if they want to apply the recommended changes automatically.

## Quality Targets

- **Ideal length**: 50-200 lines
- **Maximum length**: 500 lines (beyond this, Claude may ignore instructions)
- **Focus**: Actionable, specific, non-obvious information only
