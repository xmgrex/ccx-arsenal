# agent-core

## Harness Pattern（アプリ開発のデフォルト）

アプリケーション開発を依頼されたら harness パターンを使う。

### Agents

| Agent | Role |
|-------|------|
| `harness-planner` | 短い説明 → 設計精錬 → 包括的仕様 + 実装チェックリスト |
| `harness-generator` | 仕様 → TDD で実装（Defense-in-Depth 設計） |
| `harness-evaluator` | 実動アプリを 2段階 QA（Spec Compliance → Code Quality） |

### Flow

```
User → [曖昧?] → Phase 0: Design Refinement → User承認
  → Phase 1: spawn planner → Spec + Checklist → User承認
  → Phase 2: spawn generator (worktree, TDD) → App
  → Phase 3: spawn evaluator → Stage 1: Spec Compliance
      → FAIL? → Phase 4: spawn generator(s) (parallel if independent) → re-QA
      → PASS? → Stage 2: Code Quality
          → ITERATE? → Phase 4 (max 3 rounds)
          → PASS? → Phase 5: /simplify → Phase 6: Final Verification → Delivery
```

### Rules

- Generator は自己評価禁止。QA は必ず別の evaluator agent
- Planner 出力は必ずユーザー承認を挟む
- QA は 2段階: Spec Compliance が PASS してから Code Quality を評価
- QA 3ラウンドで PASS しなければユーザーにエスカレーション
- Generator は TDD 必須（RED-GREEN-REFACTOR）
- 独立した QA issues は並列 Generator で修正
- Simplify 後に Final Verification（証拠なき完了宣言の禁止）
- 詳細: `/harness-run`
