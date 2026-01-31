# Delegation Triggers - Reference

Detailed examples, patterns, and anti-patterns for delegation decisions.

## Agent Details

### Explore Agent

**Use when:**
- Searching for files or patterns across codebase
- Understanding how something works
- Finding all usages of a function/class

**Example:**
```
User: "How does authentication work in this app?"
→ Delegate to Explore: "Find and explain the authentication flow,
   including relevant files, middleware, and session handling"
```

### Plan Agent

**Use when:**
- Task requires architectural decisions
- Implementation spans multiple files
- Trade-offs need to be considered

**Example:**
```
User: "Add user notifications to the app"
→ Delegate to Plan: "Design notification system including
   storage, delivery methods, and UI integration points"
```

### Advanced General Purpose (Opus 4.5)

> **⚠️ Cost Warning:** Significantly more expensive. Use only when deep reasoning justifies the cost.

**Use when:**
- Deep analysis (security, architecture review)
- Quality-critical tasks where errors are costly
- Previous attempts failed (escalation)

**When NOT to use:**
- Multi-file bulk changes (use parallel orchestration)
- Simple exploration (use Explore)
- Speed is priority

**Example:**
```
User: "Thoroughly analyze the security implications of this auth refactor"
→ Delegate to Advanced: deep security analysis considering
   attack vectors, edge cases, and mitigations
```

### Parallel Orchestration

See **complex-orchestrator** skill for full workflow.

**Use when:**
- Task affects multiple independent files
- Same pattern applied across codebase
- Bulk refactoring

**Example:**
```
User: "Add error logging to all API route handlers"
→ Use complex-orchestrator: decompose by file,
   delegate to parallel sub-agents, integrate results
```

## Delegation Depth

| Depth | When | Example |
|-------|------|---------|
| **Shallow** | Quick lookup | "Find the config file" |
| **Medium** | Understand flow | "How does caching work?" |
| **Deep** | Thorough analysis | "Plan REST to GraphQL migration" |

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Delegate everything | Execute simple tasks directly |
| Never delegate | Use agents for exploration/planning |
| Vague prompts | Specific, bounded prompts |
| Chain agents unnecessarily | Combine related work |

## Cost Awareness

| Complexity | Approach |
|------------|----------|
| < 1 minute | Execute directly |
| Needs context | Quick explore, then execute |
| Multiple approaches | Plan first |
| Unknown scope | Explore to bound scope |

## Integration

- **intent-first**: Clarify what needs to be done
- **complex-orchestrator**: Multi-file parallel operations
- **skill-activator**: Find domain-specific skills
