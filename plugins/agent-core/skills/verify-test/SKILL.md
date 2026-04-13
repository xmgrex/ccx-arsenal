---
name: verify-test
description: "TDD GREEN verification - テスト実行 & PASS/FAIL 判定。context:fork で独立検証。"
context: fork
agent: tester
disable-model-invocation: true
---

## Green Phase - テスト実行 & 通過確認

### Stack 情報

!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

### テストファイル一覧

!`${CLAUDE_PLUGIN_ROOT}/scripts/list-test-files.sh`

### 指示

1. 全テストを実行する
2. 全テストが通過したか（GREEN）、まだ失敗があるか（RED）を判定する
3. 失敗がある場合は、具体的なエラー内容と修正のヒントを報告する
4. 以下の形式でレポートする

### 出力形式

```markdown
## Verify Test Report

### テスト実行結果
[テストランナーの stdout をそのまま表示]

### Judgment: PASS / FAIL
Total: [N] tests, Passed: [N], Failed: [N]

### Failure Details（FAIL の場合）
| テスト名 | エラー内容 | 修正のヒント |
|---------|----------|------------|
| [test_name] | [エラーメッセージ] | [考えられる原因と修正方向] |
```

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
