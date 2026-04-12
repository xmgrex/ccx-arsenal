---
name: red-test
description: "TDD RED phase - テスト作成 & 失敗確認。context:fork で実装コンテキストから分離。"
context: fork
agent: tester
disable-model-invocation: true
---

## Red Phase - テスト作成 & 失敗確認

### Stack 情報

!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

### 要件

$ARGUMENTS

### 指示

上記の要件を元に:

1. 要件から各関数・機能の仕様を把握する
2. 検出された Stack のテストフレームワークでテストファイルを作成する
3. 正常系・境界値・異常系を網羅する
4. テストを実行して **すべて失敗する（RED）** ことを確認する
5. 以下の形式でレポートする

### 出力形式

```markdown
## RED Test Report

### 作成したテストファイル
- [path]: [テスト数]件

### テスト実行結果
[テストランナーの stdout をそのまま表示]

### 失敗テスト一覧
| テスト名 | 期待する動作 |
|---------|------------|
| [test_name] | [このテストが検証する振る舞い] |

### Judgment: RED（全テスト失敗を確認）
Total: [N] tests, Failed: [N]
```
