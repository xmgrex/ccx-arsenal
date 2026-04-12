---
name: planning
description: "アプリ開発の起点。ユーザーの要求から Product Spec + Acceptance Criteria + Implementation Checklist を生成する。context:fork で独立コンテキストで実行。Trigger: アプリ作って, 〜を作りたい, 設計して, spec, 仕様"
context: fork
agent: planner
disable-model-invocation: false
---

## Planning — Product Spec & Implementation Checklist 生成

### ユーザーの要求

$ARGUMENTS

### 指示

上記の要求を元に:

1. **要求の精錬** — 入力が曖昧な場合、対象ユーザー・コア価値・利用シーンをヒアリングして確定させる
2. **Product Spec を作成** — Vision / Target User / Features（User Story + Testable Acceptance Criteria）
3. **Phase 分け** — Phase 1 = Core MVP、Phase 2+ = 拡張
4. **Implementation Checklist を生成** — 各 Feature を「1タスク=1アクション」に分解し、TDD サイクルを明示する

### 出力形式

```markdown
# Product Spec: [App Name]

## Product Vision
[1-2 sentences. What makes this special?]

## Target User
[Who is this for? What problem does it solve?]

## Features

### Feature 1: [Name]
- **User Story**: As a [user], I can [action] so that [benefit]
- **Acceptance Criteria**:
  - [ ] [Testable criterion 1]
  - [ ] [Testable criterion 2]
  - [ ] [Testable criterion 3]
- **Phase**: 1

## Development Phases
- **Phase 1 (Core)**: [Feature list] — MVP
- **Phase 2 (Enhanced)**: [Feature list]

## UI/UX Direction
[Design tone, interaction patterns. Skip for CLI/API.]

## AI Integration Points
[Skip if not applicable.]

## Implementation Checklist

### Phase 1

#### Feature 1: [Name]
- [ ] Write test: [what to test]
- [ ] Run test → verify RED (fails)
- [ ] Implement: [what to build]
- [ ] Run test → verify GREEN (passes)
- [ ] Commit: `feat: [Feature Name]`

#### Feature 2: [Name]
- [ ] Write test: [what to test]
- [ ] Run test → verify RED
- [ ] Implement: [what to build]
- [ ] Run test → verify GREEN
- [ ] Commit: `feat: [Feature Name]`

### Phase 2
[Same format...]
```

### Checklist ルール

- **1 task = 1 action** — 「テストを書いて実装する」は 2 タスクに分ける
- **TDD サイクルを明示** — Write test → RED → Implement → GREEN → Commit
- **ゼロコンテキストで実行可能** — 各タスクに「何を」が明記されていること
- **ビジュアル系の例外** — UI コンポーネントは「実装 → 目視確認 → Commit」でも可

## Next

→ 生成した Spec の Feature ごとに `/create-issue` で GitHub Issue 化
→ `/tdd-cycle` で Implementation Checklist を1つずつ消化
→ 全機能完了後 `/e2e-evaluate` で受け入れテスト
