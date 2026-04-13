---
name: implement
description: "TDD GREEN phase - テストを通す実装を作成。context:fork で tester コンテキストから分離。"
context: fork
agent: implementer
disable-model-invocation: true
---

## Implement Phase - テストを通す実装

### Stack 情報

!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

### テストファイル一覧

!`${CLAUDE_PLUGIN_ROOT}/scripts/list-test-files.sh`

### 要件

$ARGUMENTS

### 指示

1. テストファイルを読み、各テストが検証する振る舞いを把握する
2. テストを通す**最小限**のソースコードを実装する
3. テストを実行して全 PASS（GREEN）を確認する
4. 以下の形式でレポートする

### 出力形式

```markdown
## Implementation Report

### 変更ファイル
| ファイル | 変更内容 |
|---------|---------|
| [path] | [何を実装したか] |

### テスト実行結果
[テストランナーの stdout をそのまま表示]

### Judgment: GREEN / RED
Total: [N] tests, Passed: [N], Failed: [N]

### Failure Details（RED の場合）
| テスト名 | エラー内容 | 原因分析 |
|---------|----------|---------|
| [test_name] | [エラーメッセージ] | [なぜ通らないか] |
```

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
