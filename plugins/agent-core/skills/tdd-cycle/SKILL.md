---
name: tdd-cycle
description: "RED-GREEN-REFACTOR を fork ベースで実行。/red-test → /implement → /verify-test のサイクル。"
---

# TDD Cycle — fork ベース RED-GREEN-REFACTOR

## Usage

```
/tdd-cycle <要件>
```

## Workflow

### Step 1: RED

Skill ツールで `red-test` を呼び出す（$ARGUMENTS に要件を渡す）。
tester エージェントが fork された独立コンテキストでテストを作成し、全テスト失敗（RED）を確認する。

### Step 1.5: AUDIT

Skill ツールで `audit-tests` を呼び出す（$ARGUMENTS に AC を渡す）。
test-auditor エージェントが fork された独立コンテキストで以下を確認する:

1. **AC カバレッジ**: 各 Acceptance Criteria に対応するテストが存在するか
2. **報酬ハック検出**: テストが甘くないか（14 パターン検出）

- **PASS** → Step 2 へ（下記の受理条件を満たす場合のみ）
- **NEEDS_IMPROVEMENT** →
  - AC 未カバー → `/red-test` に追加テスト指示を渡して再実行
  - 報酬ハック検出 → `/red-test` にテスト強化指示を渡して再実行
  - 修正後、再度 `/audit-tests` で確認（最大2回）

#### Audit 結果の受理条件（オーケストレーターが検証）

test-auditor が PASS を返しても、以下を満たさなければ **PASS を受理しない**:

1. **AC Coverage 完全性**: `❌ Missing` が1つでもあれば拒否
2. **意味的分析の実施**: Semantic Analysis Findings セクションが含まれていなければ拒否
3. **Confidence 確認**: `Confidence: LOW` の場合、再監査を検討

受理拒否時: `/audit-tests` を再実行し、不足箇所を指定して補完を要求。

### Step 2: IMPLEMENT

Skill ツールで `implement` を呼び出す（$ARGUMENTS に要件を渡す）。
implementer エージェントが fork された独立コンテキストでテストを通す最小限の実装を作成する。

### Step 3: VERIFY

Skill ツールで `verify-test` を呼び出す。
tester エージェントが fork された独立コンテキストで全テストを実行し、PASS/FAIL を判定する。

- **PASS** → Step 4 へ
- **FAIL** → `/implement` を再度呼び出し（失敗テスト情報を $ARGUMENTS に追加）→ 再度 `verify-test`（最大3回）

### Step 4: SIMPLIFY（inline 実行）

`/simplify` をオーケストレーター自身のコンテキストで実行する（fork ではない。コード変更を直接行うため）。
テストが通っている状態なので、安全にリファクタリングできる。

### Step 5: VERIFY（再確認）

Skill ツールで `verify-test` を再度呼び出す。
simplify で壊れていないことを確認する。

- **PASS** → 完了
- **FAIL** → simplify の変更を revert して再試行

## ルール

- **テストファイルは変更しない**（tester が書いたテストが正）
- 各 Skill の結果を必ず確認してから次のステップに進む
- 最大3回修正しても FAIL → ユーザーにエスカレーション
- テストより先に本番コードを書いた場合 → 削除してテストからやり直す

## Rules

- **Git commit per feature** — `feat: [Feature Name]` 形式
- テストを通す実装ができたら即コミット。大きな変更をためない
- 全テスト PASS を確認してからコミット

## Context Degradation — 監視

長時間の実装セッションで以下の兆候が出たら、現在のタスクを完了後に停止する:

- **Repetition** — 同じコードの再生成、同じ説明の繰り返し
- **Skipping** — 仕様にある機能のスキップ
- **Quality drop** — エラーハンドリングの欠落、命名の不統一
- **Premature completion** — 「完了」宣言だが未実装機能が残っている

検知時は以下の Handoff Document を出力してユーザーに報告:

```markdown
## Context Handoff
### Progress
- [x] Feature 1 — committed
- [ ] Feature 3 — IN PROGRESS: [state]
- [ ] Feature 4 — NOT STARTED
### Remaining Tasks
[未完了のタスク一覧]
### Build Status / Known Issues
```

## Iteration Mode（QA 修正フロー）

acceptance-tester やレビューから修正指示を受けた場合の手順:

1. **根本原因調査** — QA Report の issue を読み、まず原因を特定する
2. **修正計画** — 場当たり修正ではなく、根本的な修正を設計する
3. **TDD で修正** — 再発防止テストを先に書いてから修正（/red-test → 修正 → /verify-test）
4. **回帰チェック** — 全テスト実行の出力を表示。テスト数が減少していないことを確認
5. **Critical Issues first** → Improvements → Minor
6. **既存機能をリグレッションしない**

### 回帰ベースライン

修正前のテスト実行結果（テスト数・成功数）を記録しておく。
修正後の `/verify-test` で以下を確認:

- テスト数が減少していないこと
- 前回 PASS だったテストが FAIL になっていないこと

回帰発見時は修正を中止し、根本原因を再調査する。

## Final Output

全機能実装完了後の出力:

1. File tree
2. `git log --oneline`
3. Build status（clean であること）
4. Test results — 全テスト実行の完全な出力（テスト数・成功数・失敗数）
5. Run instructions（アプリの起動方法）

## Inline Fallback

サブエージェント内では `context: fork` が使えない（サブエージェントのネスト不可）。
その場合は以下のインライン TDD を実行する:

1. **RED** — テストを書く → テスト実行 → **失敗出力を表示**（RED 証拠）
2. **GREEN** — 最小限の実装 → テスト実行 → **成功出力を表示**（GREEN 証拠）
3. **REFACTOR** — テスト PASS を維持しながら整理

RED/GREEN の証拠（テストランナー stdout）を省略した場合、レビューで TDD 未実施と判定される。

## Next

→ `/verify-local` → `/smart-commit` → 次の機能があれば `/tdd-cycle`、全機能完了なら `/e2e-evaluate`
