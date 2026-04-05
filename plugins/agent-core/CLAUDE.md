# agent-core

## Harness Pattern（アプリ開発のデフォルト）

アプリケーション開発を依頼されたら harness パターンを使う。

### Agents

| Agent | Role |
|-------|------|
| `harness-planner` | 短い説明 → 包括的仕様 |
| `harness-generator` | 仕様 → 実装 |
| `harness-evaluator` | 実動アプリを QA（agent-browser CLI） |

### Flow

```
User → spawn planner → Spec → User承認
  → spawn generator → App → spawn evaluator → QA Report
  → PASS? → Yes: 完了 / No: spawn generator (fix) → re-QA (max 3)
```

### Rules

- Generator は自己評価禁止。QA は必ず別の evaluator agent
- Planner 出力は必ずユーザー承認を挟む
- QA 3ラウンドで PASS しなければユーザーにエスカレーション
- 詳細: `/harness-run`
