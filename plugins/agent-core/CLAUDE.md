# agent-core

## TDD 駆動開発ワークフロー（二重ループ）

### Workflow（どこからでも開始可能）

```
内側ループ（Generator = TDD サイクル）:
  /create-issue → (/tdd-cycle → /verify-local → /smart-commit) × N

外側ループ（Evaluator = E2E/UI 検証）:
  全機能完了 → /e2e-evaluate
    ├─ PASS → /pr-description → ユーザーレビュー → マージ
    └─ ITERATE → 修正指示付きで /tdd-cycle に差し戻し（最大3ラウンド）
```

各スキルは独立。途中から開始可能。

### Generator（内側ループ）

`/tdd-cycle` は内部で fork ベースのスキルを連鎖:
```
/tdd-cycle
  ├─ /red-test      → fork → tester（テスト作成 & RED 確認）
  ├─ /audit-tests   → fork → test-auditor（AC カバレッジ + 報酬ハック検出）
  ├─ /implement     → fork → implementer（実装）
  ├─ /verify-test   → fork → tester（テスト実行 & GREEN 確認）
  ├─ /simplify      → コード整理（自動リファクタ）
  └─ /verify-test   → fork → tester（simplify で壊れてないか確認）
```

### Evaluator（外側ループ）

```
/e2e-evaluate → fork → acceptance-tester
  ├─ AC 検証（全機能を実動テスト）
  └─ デザイン4軸評価（UI アプリの場合）
      Design Quality / Originality / Craft / Functionality
```

### Skills

| Skill | Role | Next |
|-------|------|------|
| `/create-issue` | Issue 作成 + ブランチ | → `/tdd-cycle` |
| `/tdd-cycle` | fork ベース RED-GREEN-REFACTOR | → `/verify-local` |
| `/verify-local` | ビルド・テスト・lint 検証 | → `/smart-commit` |
| `/smart-commit` | 検証済みコミット | → `/tdd-cycle` or `/e2e-evaluate` |
| `/e2e-evaluate` | E2E + デザイン評価（fork） | → `/pr-description` or ITERATE |
| `/pr-description` | PR 作成 + CI + `/code-review --comment` | → ユーザーレビュー |

### Fork Skills

| Skill | fork 先 | 用途 |
|-------|---------|------|
| `/red-test` | tester | テスト作成 |
| `/audit-tests` | test-auditor | テスト品質監査 |
| `/implement` | implementer | 実装 |
| `/verify-test` | tester | テスト実行 |
| `/e2e-evaluate` | acceptance-tester | E2E + デザイン評価 |
| `/review-impl` | reviewer | コードレビュー（任意） |

### Agents

| Agent | Role |
|-------|------|
| `tester` | テスト専門 |
| `test-auditor` | テスト品質監査（読み取り専用） |
| `implementer` | 実装専門 |
| `acceptance-tester` | E2E + デザイン評価 |
| `reviewer` | コードレビュー（読み取り専用、任意） |
| `planner` | 仕様 + Implementation Checklist（複雑な設計時） |

### Rules

- TDD 必須: RED/GREEN の証拠（テスト出力）を省略不可
- fork スキルはメイン会話から直接呼ぶ場合に有効（サブエージェントのネスト不可）
- Evaluator は Generator とは別コンテキスト（Self-Evaluation Bias 防止）
- E2E で ITERATE → 最大3ラウンド、超過でユーザーにエスカレーション
- AIコードレビューは `/code-review --comment` で PR 上に投稿
- 設計・Issue はユーザー承認を挟む
- 勝手にマージ・push しない
