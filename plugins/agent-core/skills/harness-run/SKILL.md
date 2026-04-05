---
name: harness-run
description: Application development using Planner→Generator→Evaluator multi-agent harness with QA-verified quality. Trigger phrases: "アプリ作って", "harness run", "開発して", "アプリ開発", "full app", "作って"
disable-model-invocation: true
---

# Harness Run — Multi-Agent Application Development

Generator-Evaluator 分離パターンでアプリ開発を行う。

**解決する問題:**
- **Self-Evaluation Bias** — Generator は自分の成果物を過大評価する → Evaluator を分離
- **Context Degradation** — 長時間タスクで品質が劣化する → Phase 間でコンテキストリセット

## Prerequisites — Stack Detection

開始前に確定。既存プロジェクトならマーカーファイルから検出、新規なら質問:

| Marker | Stack | Build | Run | Test |
|--------|-------|-------|-----|------|
| package.json | Node.js | `npm run build` | `npm run dev` | `npm test` |
| pubspec.yaml | Flutter | `flutter build` | `flutter run` | `flutter test` |
| Package.swift | Swift | `swift build` | `swift run` | `swift test` |
| pyproject.toml | Python | `pip install -e .` | `python main.py` | `pytest` |
| Cargo.toml | Rust | `cargo build` | `cargo run` | `cargo test` |
| go.mod | Go | `go build` | `go run .` | `go test ./...` |

### QA Tool（Evaluator が使用）

| App Type | Tool |
|----------|------|
| Web app | **agent-browser CLI**（Bash 経由、200-400 tokens/page） |
| Mobile | mobile-mcp |
| CLI / API | Bash |

agent-browser 未インストール時: `npm install -g agent-browser && agent-browser install`

---

## Phase 1: Plan

**spawn `harness-planner`** に以下を渡す:
- ユーザーの説明（`$ARGUMENTS`）
- 検出した Stack 情報

Planner が仕様を返したら**ユーザーに提示して承認を得る**。承認後のみ Phase 2 へ。

---

## Phase 2: Build

**spawn `harness-generator`** に以下を渡す:
- 承認済み仕様の全文
- Stack 情報（Build/Run/Test コマンド）

Generator が完了報告（file tree, git log, build status, run instructions）を返したら Phase 3 へ。

### Context Reset

Generator がコンテキスト劣化の兆候を報告した場合:
1. Handoff Document を受け取る
2. **新しい** `harness-generator` を spawn し、Handoff + 残 Feature を渡す

---

## Phase 3: QA

**spawn `harness-evaluator`** に以下を渡す:
- 承認済み仕様（Acceptance Criteria が評価基準）
- Run instructions（Phase 2 の出力）
- プロジェクトパス

**Generator とは別のエージェント**であること。同一エージェントに評価させない。

Evaluator は 4軸で評価し Verdict を返す:

| Criterion | Weight |
|-----------|--------|
| Product Depth | 30% |
| Functionality | 30% |
| Visual/UX | 20% |
| Code Quality | 20% |

- **PASS**: Weighted total >= 7.0 AND Critical issues = 0
- **ITERATE**: それ以外

---

## Phase 4: Iterate

ITERATE の場合:

1. QA Report を**無編集で**新しい `harness-generator` に渡す（フィルタリング禁止）
2. 併せて渡す: 承認済み仕様（原本）、全 QA Report、git log
3. Generator が修正完了 → 新しい `harness-evaluator` で再 QA
4. **最大 3 ラウンド**。超過時はユーザーにエスカレーション

---

## Final Delivery

PASS 後にユーザーへ報告:

1. 実装 Feature 一覧（仕様との対応）
2. 起動方法
3. 最終 QA スコア
4. 既知の制限事項
5. 次のステップ提案

---

## Integration

| Situation | Route to |
|-----------|----------|
| 説明が曖昧 | `intent-first` → 明確化してから Phase 1 |
| Build 中にエラー | `investigate` |
| Build 3-strike | delegation-triggers → GPT escalation |
| QA issues 多数 | `complex-orchestrator` で並列修正 |
| 完了後レビュー | `local-code-review` |
