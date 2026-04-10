# agent-core

## TDD 駆動開発ワークフロー

アプリケーション開発を依頼されたら `/harness-run` を使う。

### Workflow（スキル組み合わせ型）

```
Plan Mode → /create-issue → Branch
  → (/tdd-cycle → /verify-local → /smart-commit) × N
  → /verify-local --full → /pr-description
  → /local-code-review → ユーザーレビュー → マージ
```

### Skills（単独でも使える）

| Skill | Role |
|-------|------|
| `/create-issue` | Issue 作成 + ブランチ |
| `/tdd-cycle` | RED-GREEN-REFACTOR + 証拠出力 |
| `/verify-local` | ビルド・テスト・lint 検証ゲート |
| `/smart-commit` | 検証済みコミット |
| `/pr-description` | PR 自動生成 |
| `/local-code-review` | AI コードレビュー |

### Agents（大規模開発で使用）

| Agent | Role | 使用条件 |
|-------|------|---------|
| `harness-planner` | 仕様 + Implementation Checklist | 大規模 or 複雑な設計 |
| `harness-generator` | worktree で TDD 実装 | タスク 11+ or Context Degradation |
| `harness-evaluator` | Two-Stage QA | 大規模アプリの品質検証 |

### Rules

- TDD 必須: RED/GREEN の証拠（テスト出力）を省略不可
- Generator は自己評価禁止。QA は必ず別の evaluator agent
- 設計・Issue はユーザー承認を挟む
- QA 3ラウンドで PASS しなければユーザーにエスカレーション
- 勝手にマージ・push しない
- 詳細: `/harness-run`
