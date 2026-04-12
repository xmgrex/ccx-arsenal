---
name: audit-tests
description: "テストの報酬ハックを検出し、AC カバレッジを確認する。context:fork で実装者から独立。"
context: fork
agent: test-auditor
disable-model-invocation: true
---

## Test Audit — 報酬ハック検出 & AC カバレッジ確認

### Stack 情報

!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

### テストファイル一覧

!`${CLAUDE_PLUGIN_ROOT}/scripts/list-test-files.sh`

### Acceptance Criteria

$ARGUMENTS

### 指示

1. **AC カバレッジ確認**: 上記の Acceptance Criteria とテストファイルを照合し、各 AC に対応するテストが存在するか確認する
2. **報酬ハック検出（構文パターン）**: エージェントが持つ報酬ハックパターン知識（14パターン）に基づいてテストコードをスキャンする
3. **意味的分析**: 構文パターンでは検出できない意味レベルの問題（Implementation Mirroring, Setup Dominance, Snapshot Overfit, Redundant Coverage, Integration Gap）を分析する
4. 以下の形式でレポートする

### 出力形式

```markdown
## Test Audit Report

### AC Coverage
| AC | テスト | Status |
|----|--------|--------|
| AC-1: [名前] | [テスト名 or ???] | ✅ Covered / ❌ Missing / ⚠️ Partial |

### Reward Hack Findings（構文パターン）
| Severity | Pattern | File:Line | Detail |
|----------|---------|-----------|--------|
| CRITICAL/WARNING/INFO | [PATTERN_ID] | [path:line] | [何が問題か] |

### Semantic Analysis Findings（意味的分析）
| Severity | Pattern | Detail |
|----------|---------|--------|
| CRITICAL/WARNING | [PATTERN_ID] | [分析結果の自由記述] |

### Verdict: PASS / NEEDS_IMPROVEMENT (Confidence: HIGH/MEDIUM/LOW)
PASS: AC 全カバー AND CRITICAL 0件（構文+意味的分析の両方）
NEEDS_IMPROVEMENT: AC 未カバーあり OR CRITICAL 1件以上

### Improvement Instructions（NEEDS_IMPROVEMENT の場合）
1. [具体的な修正指示: 何のテストを追加/強化すべきか]
```
