# agent-core

## TDD 駆動開発ワークフロー（二重ループ）

### Workflow

```
Phase 0: 設計 + 二段階自動収束レビュー
  /planning → main が orchestrator（インライン）
    │
    ├─ Stage 1: Spec/Flow 収束ループ（最大3ラウンド）
    │   ├─ Agent(planner) → spec.md + flow.md (UI時)
    │   └─ 並列 Agent(spec-reviewer) + Agent(flow-reviewer)
    │
    ├─ Stage 2: UI Design 収束ループ（最大3ラウンド、UI アプリのみ）
    │   ├─ Agent(ui-designer) → screens/*.html + index.html
    │   ├─ 決定論ゲート（リンク整合性 / flow↔screens 整合 / 装飾 pre-scan）
    │   └─ Agent(ui-design-reviewer)
    │
    └─ 両 Stage 収束 → ユーザー承認ゲート（ブラウザ確認案内）→ /create-issue
       3ラウンドで収束せず → ユーザーエスカレーション

  （手動 re-review 用に /plan-review をスタンドアロン提供。screens 存在時は 3 体並列）

内側ループ（Generator = TDD サイクル）:
  /create-issue [spec-path]   ← Spec から Phase 1 の Feature を一括 Issue 化
    → (/tdd-cycle → /verify-local → /smart-commit) × N

外側ループ（Evaluator = E2E/UI 検証）:
  全機能完了 → /e2e-evaluate
    ├─ PASS → /pr-description → ユーザーレビュー → マージ
    └─ ITERATE → 修正指示付きで /tdd-cycle に差し戻し（最大3ラウンド）
```

**アプリ開発の依頼を受けたら、原則 `/planning` から開始する。** Spec と AC が既にある場合のみ Phase 0 をスキップ可能。各スキルは独立しており、途中から開始することもできる。

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
| `/planning` | **起点** — Spec + Flow.md + HTML screens 生成 + 二段階収束ループ（Stage 1: spec/flow / Stage 2: UI design、各最大3ラウンド）+ ユーザー承認ゲート | → `/create-issue` |
| `/plan-review` | スタンドアロン版レビュー — 既存 spec/flow/screens を手動 re-review（収束ループなし、screens 存在時は 3 体並列） | → 手動判断 |
| `/create-issue` | Spec ファイルから Phase 1 Feature を一括 Issue 化 | → `/tdd-cycle` |
| `/tdd-cycle` | fork ベース RED-GREEN-REFACTOR | → `/verify-local` |
| `/verify-local` | ビルド・テスト・lint 検証 | → `/smart-commit` |
| `/smart-commit` | 検証済みコミット | → `/tdd-cycle` or `/e2e-evaluate` |
| `/e2e-evaluate` | E2E + デザイン評価（fork） | → `/pr-description` or ITERATE |
| `/pr-description` | PR 作成 + CI + `/pr-review` | → ユーザーレビュー |
| `/pr-review` | 公式 code-review プラグイン優先 + フォールバック | → ユーザーレビュー |

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
| `planner` | **起点** — Product Spec + Flow.md + Implementation Checklist 生成 / Revise Mode で差分修正 |
| `spec-reviewer` | Spec 品質レビュー（User Story / AC / Feature scope / 粒度 / 欠落）read-only、Anti-Bias Rules 搭載 |
| `flow-reviewer` | Flow.md 評価（到達可能性 / Feature カバレッジ / 退出経路 / トリガラベル）read-only、Anti-Bias Rules 搭載 |
| `ui-designer` | クリッカブル HTML screens 生成（Tailwind layout-only / 装飾禁止 / セマンティック）/ Revise Mode で差分修正 |
| `ui-design-reviewer` | screens HTML 評価（HTML 妥当性 / リンク整合性 / flow ↔ screens 整合 / 装飾過剰検出 / 情報階層 / コンポーネント再利用 / 状態カバレッジ / ネイティブ警告）read-only、Anti-Bias Rules 搭載 |
| `tester` | テスト専門 |
| `test-auditor` | テスト品質監査（読み取り専用） |
| `implementer` | 実装専門 |
| `acceptance-tester` | E2E + デザイン評価 |
| `reviewer` | コードレビュー（読み取り専用、任意） |

### Rules

- **アプリ開発依頼時は原則 `/planning` から開始**（Spec/AC が既にある場合のみスキップ可）
- **Phase 0 は `/planning` の二段階収束ループで完結** → ユーザー承認 → `/create-issue` の順
- Stage 1 (spec/flow) と Stage 2 (UI design) は各最大 3 ラウンド。収束しなければ全ラウンド履歴付きでユーザーエスカレーション
- **Stage 2 は UI アプリのみ実行**。CLI/API/ライブラリは Stage 2 全体をスキップ
- 各ラウンドの planner / spec-reviewer / flow-reviewer / ui-designer / ui-design-reviewer は必ず**fresh spawn**（kill-and-spawn）
- spec-reviewer と flow-reviewer は**同一メッセージ内で並列 spawn**（Agent ツールを2つ同時に call）
- **screens HTML は構造リファレンス**（装飾禁止 / Tailwind layout クラスのみ）— 視覚デザインではない
- ui-design-reviewer の前にスキル側で**決定論ゲート**（リンク整合性 / flow ↔ screens 整合 / 装飾 pre-scan）を実行し結果を注入する
- TDD 必須: RED/GREEN の証拠（テスト出力）を省略不可
- fork スキルはメイン会話から直接呼ぶ場合に有効（サブエージェントのネスト不可）
- Evaluator は Generator とは別コンテキスト（Self-Evaluation Bias 防止）
- E2E で ITERATE → 最大3ラウンド、超過でユーザーにエスカレーション
- AIコードレビューは `/pr-review` で PR 上に投稿（公式 code-review プラグインを優先、未インストール時はフォールバック）
- **決定論ゲートを優先**: 重要な連鎖（PR レビュー等）は `!command` 構文で SKILL.md に埋め込み、Claude の判断スキップを防ぐ。エージェントの裁量で省略すべきでないステップは `!` 構文で固める
- 設計・Issue はユーザー承認を挟む
- 勝手にマージ・push しない
- **バイアスなき品質検証**: 常にレビューはkillしてspawnしながら進める
