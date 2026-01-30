# CLAUDE.md Best Practices Reference

Based on official Claude Code documentation.

## What to Include

| Category | Examples |
|----------|----------|
| Bash commands Claude can't guess | Build commands, test runners, deployment scripts |
| Code style rules that differ from defaults | Specific linting rules, naming conventions |
| Testing instructions | Preferred test runners, test patterns |
| Repository etiquette | Branch naming, PR conventions, commit message format |
| Architectural decisions | Project-specific patterns, technology choices |
| Developer environment quirks | Required env vars, setup steps |
| Common gotchas | Non-obvious behaviors, known issues |

## What NOT to Include

| Category | Reason |
|----------|--------|
| Anything Claude can figure out by reading code | Redundant, wastes context |
| Standard language conventions | Claude already knows these |
| Detailed API documentation | Link to docs instead |
| Information that changes frequently | Will become stale |
| Long explanations or tutorials | Too verbose |
| File-by-file descriptions | Claude can read the codebase |
| Self-evident practices | "write clean code" is obvious |

## Red Flags

1. **Too long**: If CLAUDE.md > 500 lines, Claude may ignore instructions
2. **Redundant with code**: Information duplicated from codebase
3. **Stale content**: References to removed features or outdated patterns
4. **Vague instructions**: "Be careful" without specific guidance
5. **Over-emphasis**: Excessive use of IMPORTANT/CRITICAL/MUST
6. **Tutorial content**: Step-by-step explanations that should be docs

## Verification Questions

For each line in CLAUDE.md, ask:
- "Would removing this cause Claude to make mistakes?"
- "Can Claude infer this from the codebase?"
- "Is this still accurate and relevant?"

If the answer suggests the line isn't essential, it should be removed.
