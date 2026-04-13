---
name: review-impl
description: "実装レビュー - git diff を元に実装品質を確認。OK/NEEDS_FIX を判定。"
context: fork
agent: reviewer
disable-model-invocation: true
---

## Implementation Review - 実装品質レビュー

### 要件

$ARGUMENTS

### 変更差分 & ステータス

!`${CLAUDE_PLUGIN_ROOT}/scripts/git-diff.sh`

### テストファイル一覧

!`${CLAUDE_PLUGIN_ROOT}/scripts/list-test-files.sh`

### 指示

上記の diff を読み、以下の観点でレビューし、出力形式に従ってレポートする:

1. **正しさ** — テストが通る実装が要件を満たしているか
2. **セキュリティ** — 入力バリデーション、インジェクション対策
3. **構造** — 責務分離、命名の一貫性、不要な複雑性
4. **エッジケース** — テストでカバーされていない危険なケース

### 出力形式

```markdown
## Review Report

### Judgment: OK / NEEDS_FIX (Confidence: HIGH/MEDIUM/LOW)

### Issues（NEEDS_FIX の場合）
| Severity | ファイル:行 | 指摘内容 | 修正案 |
|----------|-----------|---------|--------|
| Critical/Important/Minor | [path:line] | [何が問題か] | [どう直すか] |
```

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
