---
name: tdd-cycle
description: "RED-GREEN-REFACTOR を fork ベースで実行（Level 3 決定論版）。Phase 1 (RED) と Phase 1.5 (AUDIT) は !構文で必ず実行され、Phase 2 以降は orchestrator が判定ロジックで進行。全ループに明示的な上限あり。"
context: fork
agent: general-purpose
---

# TDD Cycle — Level 3 決定論版

## Usage

```
/tdd-cycle <要件>
```

このスキルは `context: fork` で general-purpose エージェント（TDD orchestrator として動作）として起動する。
スキル本文中の `!` 構文がスキルローダーによって機械的に展開され、Phase 1 (RED) と Phase 1.5 (AUDIT) は**必ず実行された状態**で orchestrator が起動する。

---

## Phase 1 + 1.5: RED & AUDIT (決定論：スキルローダーが実行)

下記のシェルブロックがスキル読み込み時に必ず実行される。Claude 判断によるスキップは不可能。

```!
echo "=== Phase 1: RED ==="
RED_OUTPUT=$(claude -p "/red-test $ARGUMENTS" --max-turns 30 --max-budget-usd 1.00 --permission-mode acceptEdits 2>&1 | tail -300)
echo "$RED_OUTPUT"
echo ""

if ! echo "$RED_OUTPUT" | grep -q "Judgment: RED"; then
  echo "PHASE_1_WARNING: RED phase did not produce 'Judgment: RED' marker"
fi

echo ""
echo "=== Phase 1.5: AUDIT (1st attempt) ==="
AUDIT_OUTPUT=$(claude -p "/audit-tests $ARGUMENTS" --max-turns 20 --max-budget-usd 0.50 --permission-mode acceptEdits 2>&1 | tail -300)
echo "$AUDIT_OUTPUT"
echo ""

if echo "$AUDIT_OUTPUT" | grep -q "Verdict: PASS"; then
  echo "PHASE_1.5_RESULT: PASS"
else
  echo "PHASE_1.5_RESULT: NEEDS_IMPROVEMENT"
fi
```

---

## Task

あなたは TDD orchestrator です。
上記の Phase 1 + 1.5 の出力を解析し、以下の判定ロジックに従って Phase 2 以降を進めてください。

### 共通ルール

- **成功時は自動的に次の Phase に進む**（ユーザー確認を都度挟まない）
- **失敗時のみユーザーに報告して指示を仰ぐ**
- **Skill ツール呼出が失敗した場合（タイムアウト・エラー・想定外フォーマット）、即座にユーザーに報告して中断**
- **テストファイルは変更しない**（tester が書いたテストが正）
- **テストより先に本番コードを書いた場合 → 削除してテストからやり直す**

### Step 1: AUDIT 結果の判定

上記の Phase 1.5 出力を解析し、以下を判定:

#### 1-A. PASS の場合

さらに以下の受理条件をすべて満たしているか確認:

1. **AC Coverage 完全性**: `❌ Missing` が1つもない
2. **意味的分析の実施**: Semantic Analysis Findings セクションが含まれている
3. **Confidence 確認**: Confidence: HIGH または MEDIUM（LOW なら 1-B のループに進む）

すべて満たす → **Step 2 へ進む**
受理条件を満たさない → 1-B のループに進む（試行回数 1 として扱う）

#### 1-B. NEEDS_IMPROVEMENT または受理拒否の場合

**最大3回まで**（既に1回目は !構文で実行済み、2-4回目をエージェントが実行）以下を試行:

```
for 試行 in 2..4:
  Skill ツールで /red-test を再実行（補強指示を $ARGUMENTS に追加）
  Skill ツールで /audit-tests を再実行
  if PASS かつ受理条件を満たす:
    break → Step 2
```

**4回試行（!構文1回 + Skill ツール3回）しても改善しない場合**:
- エスカレーションポリシーに従い、Handoff Document を出力してユーザーにエスカレーション
- 含めるべき情報: 各試行の AUDIT Report、未カバーの AC、検出された報酬ハックパターン、推奨アクション

### Step 2: IMPLEMENT

Skill ツールで `/implement` を呼出（$ARGUMENTS に要件を渡す）。

implementer エージェントが fork された独立コンテキストでテストを通す最小限の実装を作成する。

### Step 3: VERIFY

Skill ツールで `/verify-test` を呼出。
tester エージェントが fork された独立コンテキストで全テストを実行し、PASS/FAIL を判定する。

#### 3-A. PASS の場合
**Step 4 へ進む**。

#### 3-B. FAIL の場合

**最大3回まで**以下を試行:

```
for 試行 in 1..3:
  Skill ツールで /implement を再実行（失敗テスト情報を $ARGUMENTS に追加）
  Skill ツールで /verify-test を再実行
  if PASS:
    break → Step 4
```

**3回試行しても FAIL の場合**:
- エスカレーションポリシーに従い、Handoff Document を出力
- 含めるべき情報: 失敗したテスト一覧、各試行の実装内容、推測される根本原因、推奨アクション

### Step 4: SIMPLIFY (inline 実行)

`/simplify` をオーケストレーター自身のコンテキストで実行する（fork ではない、コード変更を直接行うため）。
テストが通っている状態なので、安全にリファクタリングできる。

### Step 5: VERIFY (再確認)

Skill ツールで `/verify-test` を再度呼出。simplify で壊れていないことを確認する。

#### 5-A. PASS の場合
**完了**。Final Output を出力する。

#### 5-B. FAIL の場合

**最大2回まで**以下を試行:

```
for 試行 in 1..2:
  simplify の変更を git で revert
  別のリファクタリング戦略で再度 /simplify を試行
  Skill ツールで /verify-test を再実行
  if PASS:
    break → 完了
```

**2回試行しても FAIL の場合**:
- すべての simplify 変更を revert（テストが通る状態に戻す）
- エスカレーションポリシーに従い、Handoff Document を出力
- 含めるべき情報: simplify で何を試したか、なぜ FAIL したかの推測、推奨アクション

---

## エスカレーションポリシー

すべてのループ上限到達時、以下の Handoff Document を出力してユーザー判断を仰ぐ:

```markdown
## TDD Cycle Escalation
### Phase: [どのフェーズで止まったか]
### Attempts: [何回試行したか]
### Failures
- 試行1: [何を試したか] → [結果]
- 試行2: ...
### Root Cause Hypothesis
[なぜ全部失敗したかの推測]
### Recommended Action
[ユーザーに何をしてほしいか]
```

ユーザーからの明示的な指示があるまで続行しない。

---

## Skill ツールエラー処理

各 Skill ツール呼出（`/red-test`, `/audit-tests`, `/implement`, `/verify-test`）が以下のいずれかの場合:
- タイムアウト
- 例外エラー
- 想定外の出力フォーマット
- 結果が空

→ **即座にユーザーに報告して中断**。再試行を勝手に繰り返さない。

理由: Skill ツール自体のエラーは TDD ロジックの問題ではなく、環境やインフラの問題の可能性が高い。エージェントが判断で再試行するのは無駄。

---

## Rules

- **Git commit per feature** — `feat: [Feature Name]` 形式
- テストを通す実装ができたら即コミット。大きな変更をためない
- 全テスト PASS を確認してからコミット
- すべてのループに明示的な上限あり。暗黙の無限ループは存在しない

---

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

---

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

---

## Final Output

全機能実装完了後の出力:

1. File tree
2. `git log --oneline`
3. Build status（clean であること）
4. Test results — 全テスト実行の完全な出力（テスト数・成功数・失敗数）
5. Run instructions（アプリの起動方法）

---

## Inline Fallback

サブエージェント内では `context: fork` が使えない（サブエージェントのネスト不可）場合のフォールバック。
その場合は以下のインライン TDD を実行する:

1. **RED** — テストを書く → テスト実行 → **失敗出力を表示**（RED 証拠）
2. **GREEN** — 最小限の実装 → テスト実行 → **成功出力を表示**（GREEN 証拠）
3. **REFACTOR** — テスト PASS を維持しながら整理

RED/GREEN の証拠（テストランナー stdout）を省略した場合、レビューで TDD 未実施と判定される。

---

## Next

→ `/verify-local` → `/smart-commit` → 次の機能があれば `/tdd-cycle`、全機能完了なら `/e2e-evaluate`
