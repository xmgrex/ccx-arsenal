# Complex Orchestrator - Examples & Reference

Detailed examples, templates, and troubleshooting for parallel orchestration.

## Example: Add Logging to All Routes

**Request:** "Add logging to all API endpoints"

### Decomposition
```
├─ Unit 1: routes/users.ts
├─ Unit 2: routes/orders.ts
├─ Unit 3: routes/products.ts
└─ Unit 4: lib/logger.ts (shared - must be first)

Strategy: Staged Parallel
```

### Wave 1 (Sequential)
```typescript
Task({
  subagent_type: "general-purpose",
  description: "Setup logger",
  prompt: `Create structured logger in lib/logger.ts with info/error methods.`
})
```

### Wave 2 (Parallel)
```typescript
Task({
  subagent_type: "general-purpose",
  description: "Add logging to users.ts",
  prompt: `Add structured logging to all endpoints in routes/users.ts.
           Use logger from lib/logger.ts.
           Pattern: logger.info({ endpoint, method, userId })`
})

Task({
  subagent_type: "general-purpose",
  description: "Add logging to orders.ts",
  prompt: `Add structured logging to all endpoints in routes/orders.ts.
           Use logger from lib/logger.ts.
           Pattern: logger.info({ endpoint, method, orderId })`
})

Task({
  subagent_type: "general-purpose",
  description: "Add logging to products.ts",
  prompt: `Add structured logging to all endpoints in routes/products.ts.
           Use logger from lib/logger.ts.
           Pattern: logger.info({ endpoint, method, productId })`
})
```

## Example: Rename Field Across Codebase

**Request:** "Rename `userId` to `accountId` across the codebase"

### Analysis
```
Files:
├─ models/user.ts (type definition - must be first)
├─ routes/auth.ts
├─ routes/profile.ts
├─ services/userService.ts
└─ tests/user.test.ts

Strategy: Staged Parallel
- Wave 1: models/user.ts
- Wave 2: All others in parallel
```

### Execution
```typescript
// Wave 1
Task({
  subagent_type: "general-purpose",
  description: "Rename userId in model",
  prompt: `In models/user.ts, rename 'userId' to 'accountId'.
           Update type definition and related interfaces.`
})

// Wave 2 (after Wave 1 completes)
Task({ description: "Update auth.ts", prompt: "Rename userId to accountId in routes/auth.ts" })
Task({ description: "Update profile.ts", prompt: "Rename userId to accountId in routes/profile.ts" })
Task({ description: "Update userService.ts", prompt: "Rename userId to accountId in services/userService.ts" })
Task({ description: "Update user.test.ts", prompt: "Rename userId to accountId in tests/user.test.ts" })
```

## Delegation Prompt Template

```markdown
## Scope
File: [specific file path]
Task: [what to do in THIS file only]

## Context (Minimal)
- Related files: [only what's needed]
- Pattern to follow: [consistent approach]

## Constraints
- Only modify [file path]
- Follow existing code style
- [Specific requirements]

## Expected Output
- Summary of changes made
- Any issues encountered
```

## Benefits

| Benefit | How |
|---------|-----|
| **Context savings** | Each sub-agent loads only relevant files |
| **Time savings** | Parallel execution |
| **Consistency** | Manager enforces common patterns |
| **Error isolation** | Failure in one doesn't block others |

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Delegate tightly-coupled files separately | Handle together or sequentially |
| Skip dependency analysis | Identify waves before delegating |
| Vague prompts | Specific, file-scoped instructions |
| Forget integration verification | Always validate after parallel work |

## Integration Verification

```typescript
Bash({ command: "npm run typecheck" })
Bash({ command: "npm run test" })
```

## Conflict Resolution

If sub-agents produce conflicts:
1. Identify conflict source
2. Determine correct resolution
3. Apply fix or re-delegate with clearer constraints
4. Re-verify integration
