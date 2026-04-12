---
name: issue-cycle
description: "GitHub issue から AC 駆動で実装するサイクル。TDD に馴染まない削除・リファクタ・インフラ変更・設定変更・ドキュメント更新向け。issue 番号を受け取り、ブランチ作成 → issue-executor で実装 → /verify-local → /smart-commit まで自動化。Trigger: /issue-cycle <issue番号>, issue 実装, 削除タスク, リファクタタスク, インフラ変更"
---

# Issue Cycle — AC 駆動実装オーケストレーター

## Usage

```
/issue-cycle <issue-number>
```

例: `/issue-cycle 3`

---

## いつ使うか

`/tdd-cycle` と `/issue-cycle` は **sibling** であり、ユーザーが明示的に使い分ける。

### `/issue-cycle` が適するタスク

- **一括削除 / デッドコード撤去**（例: `feat: F0-1 デッドルート 8 領域の一括削除`）
- **ファイル・ディレクトリ構造のリファクタ**
- **設定ファイル・依存関係の更新**
- **インフラ・ビルドスクリプトの変更**
- **ドキュメント・マイグレーション作業**
- **その他「テスト先行」が不自然な変更全般**

→ issue 本文に**実行可能な Acceptance Criteria**（`grep` / `find` / `test` / `pnpm test` 等）が書かれていることが前提。

### `/tdd-cycle` が適するタスク

- **新機能の追加**
- **バグ修正**（再現テストを先に書ける）
- **既存機能の振る舞い変更**
- **その他「テスト先行が自然」な変更全般**

判断に迷ったら旦那様にお尋ねすること。勝手に分岐しない。

---

## Workflow Awareness

あなた（メイン Claude）は **agent-core の TDD 駆動開発パイプライン**で `/issue-cycle` orchestrator として動作する。全体構造:

```
Phase 0: 設計（/planning）
  └─ ユーザー承認 → /create-issue

Phase 1-N（2 つのレーン、明示使い分け）:
  ├─ /tdd-cycle        ← テスト先行が自然なタスク
  └─ /issue-cycle      ← テスト先行が不自然なタスク（削除・リファクタ・インフラ）  ← あなたはここ
       │
       ├─ issue 取得 → AC 抽出 → 承認ゲート → ブランチ作成
       ├─ Agent(issue-executor) で実装 + AC 検証（fork isolation）
       ├─ /verify-local で regression check
       └─ /smart-commit でコミット（closes #N 含む）

Phase Final: /e2e-evaluate → acceptance-tester
```

orchestrator（あなた）は**親コンテキストに居座り**、executor 側だけを fork する。これにより:
- ユーザーへの途中報告・承認ゲート・割り込みが機能する
- executor の中間思考（grep 結果、影響範囲調査の詳細等）は親に漏れず、レポートのみが返る

---

## Task

あなた（メイン Claude）は Issue Cycle orchestrator です。
以下のステップを順に実行し、各ステップの結果を判定して次に進んでください。

### 共通ルール

- **成功時は自動的に次の Step に進む**（Step 2 の承認ゲートのみ例外）
- **失敗時は即座にユーザーに報告して指示を仰ぐ**
- **issue body を書き換えない**（Single Source of Truth）
- **スコープ遵守**: issue に書かれていない変更を加えない
- **勝手に push しない / マージしない**
- **勝手にブランチを切り替えない**（Step 3 で新規作成するのみ）

---

### Step 1: Issue 取得（決定論ゲート）

以下の `!` 構文ブロックがスキル読み込み時に必ず実行され、issue メタ情報と現在の git 状態が注入された状態で orchestrator が起動する。

!`gh issue view $ARGUMENTS --json number,title,body,state,labels 2>&1 || echo "ISSUE_FETCH_FAILED"`

!`git status --short`

!`git branch --show-current`

!`git rev-parse --abbrev-ref HEAD 2>/dev/null`

#### 1-A. 取得失敗の場合

上記出力に `ISSUE_FETCH_FAILED` / `could not find` / `Not Found` が含まれる場合 → **即停止**。以下をユーザーに報告:

- 引数に渡された issue 番号: `$ARGUMENTS`
- `gh` のエラーメッセージ
- 対処案: 「正しい issue 番号を指定してください」「`gh auth status` で認証状態を確認してください」

#### 1-B. issue が OPEN でない場合

issue の `state` が `OPEN` 以外（`CLOSED` / `MERGED` 等）→ **停止してユーザーに確認**:

- 「この issue は既に {state} です。本当に再実装しますか？」
- 明示承認があれば続行、なければ中止

#### 1-C. working tree が dirty の場合

`git status --short` に出力がある（uncommitted changes あり）→ **停止してユーザーに確認**:

- 現在の変更内容を要約表示
- 選択肢: 「stash して続行」「既に staging している場合はそのまま続行（非推奨）」「中止」
- ユーザーの明示選択を待つ

---

### Step 2: AC 抽出 + 計画提示（ユーザー承認ゲート）

Step 1 で取得した issue body を解析し、以下を抽出する:

- **タイトル**: コミットメッセージの summary に使用
- **Phase / カテゴリラベル**: `labels` フィールドから取得
- **Acceptance Criteria**: `## Acceptance Criteria` セクション配下のチェックボックス行（`- [ ] ...`）
- **実行可能コマンド AC のマーク**: 各 AC を走査し、以下のパターンを含むものを「実行可能」としてマーク:
  - `` `grep ...` `` / `` `find ...` `` / `` `ls ...` ``
  - `` `pnpm test` `` / `` `npm test` `` / `` `pytest` `` / `` `cargo test` `` / 他のテストコマンド
  - `` `test -f ...` `` / `` `[ -f ... ]` ``
  - 任意のコード fence 内シェルコマンド
- **自然言語 AC**: 実行可能コマンドを含まない AC は別リストにする（後段で executor が可能な限り検証、不可能なら Manual 扱い）

ブランチ名を生成:
- フォーマット: `issue-<N>-<slug>`
- slug: issue タイトルの**先頭の `FN-N` / `feat:` / `fix:` 等のプレフィックス**と**ラテン文字・数字・ハイフン**部分を抽出し kebab-case 化（日本語は除外、代替として `issue-<N>` のみでも可）
- 例:
  - `feat: F0-1 デッドルート 8 領域の一括削除` → `issue-3-f0-1-dead-route-cleanup`（日本語部分は英訳推測または省略）
  - `fix: auth token expiry` → `issue-7-auth-token-expiry`
  - 日本語のみで生成困難な場合: `issue-<N>` で統一

以下を**ユーザーに提示**し、明示承認を待つ:

```
📋 Issue Cycle Plan

Issue: #<N> <title>
State: OPEN
Labels: <labels>
Current branch: <current-branch>

Acceptance Criteria:
  🔧 実行可能コマンド AC (N 件):
    1. [command 1] → expect [expected]
    2. [command 2] → expect [expected]
    ...
  📝 自然言語 AC (M 件):
    - ...
    - ...

計画するブランチ: issue-<N>-<slug>

作業サマリー（issue body からの推測）:
- [変更対象と方向性]

この計画で進めてよろしいですか？ (yes / no / 修正指示)
```

**重要**: ユーザーの明示 `yes` なしに Step 3 以降に進んではならない。

---

### Step 3: ブランチ作成

ユーザー承認後、Bash ツールで以下を実行:

```bash
git checkout -b issue-<N>-<slug>
```

#### 3-A. ブランチ作成失敗の場合

- 既存ブランチ名衝突（`already exists`）→ ユーザーに確認:
  - 「既存ブランチに switch する」「別名で作成する」「中止」
- その他の失敗（uncommitted changes のロック等）→ 停止してエラー表示

#### 3-B. 作成確認

```bash
git branch --show-current
```

期待するブランチ名になっていることを確認してから Step 4 へ。

---

### Step 4: issue-executor に実装を委譲

**Agent ツール**で `subagent_type: "issue-executor"` を呼び出す。prompt には以下を含める:

```
ISSUE_NUMBER: <N>
ISSUE_TITLE: <title>
ISSUE_BODY:
<issue body 全文>

ACCEPTANCE_CRITERIA:
🔧 実行可能コマンド AC:
1. [command 1] → expect [expected]
2. [command 2] → expect [expected]
...

📝 自然言語 AC:
- ...
- ...

CURRENT_BRANCH: issue-<N>-<slug>

指示:
- issue の要求を実装し、各 AC コマンドを順次実行して検証せよ
- issue-executor.md の Workflow (Step 1-6) に従え
- 完了したら Output Format の Report を返せ
- 勝手にコミットせず、変更内容のレポートのみ返せ
```

#### 4-A. `Verdict: PASS` の場合
→ **Step 5 へ進む**

#### 4-B. `Verdict: NEEDS_FIX` の場合

executor の `Fix Needed` セクションを読み、**再度 executor を fresh spawn**（Agent ツールを新規 call）して修正指示を Revise Mode として渡す:

```
FIX_INSTRUCTIONS:
<前回の Fix Needed 内容をそのまま貼付>

指示:
- Revise Mode で上記の Fix Instructions に従って修正せよ
- 前回の変更を踏まえて差分修正する。ゼロから再実装しない
```

**最大 3 回まで**再実行する。3 回後も PASS しなければ Step 7（エスカレーション）へ。

#### 4-C. `Verdict: BLOCKED` の場合

→ **即停止、Step 7（エスカレーション）へ**。executor の Blockers 内容をユーザーに提示し、判断を仰ぐ。

---

### Step 5: Regression Check

**Skill ツール**で `/verify-local` を呼出。既存ビルド・テスト・lint が通ることを確認する。

#### 5-A. `Verdict: PASS` の場合
→ **Step 6 へ進む**

#### 5-B. `Verdict: FAIL` の場合

`/verify-local` の失敗内容を executor に再委譲:

```
FIX_INSTRUCTIONS:
/verify-local が以下の理由で FAIL しました:
<verify-local の FAIL 内容>

指示:
- Revise Mode で regression を修正せよ
- AC を再検証してから返せ
```

**最大 3 回まで**再試行。3 回後も FAIL なら Step 7 へ。

---

### Step 6: Commit

**Skill ツール**で `/smart-commit` を呼出。コミットメッセージとして以下を指示する:

```
Type: <fix / refactor / chore / docs のいずれか、issue タイトルから推定>
Scope: <issue タイトルから推定、または省略>
Summary: <issue タイトルから生成>

Body:
- [変更サマリー]
- [AC 検証結果サマリー]

closes #<N>

Co-Authored-By: Claude Code <noreply@anthropic.com>
```

**Type の推定ガイド**:
- 削除・リファクタ・依存整理 → `refactor`
- 設定変更・CI/ビルド設定 → `chore`
- ドキュメントのみ → `docs`
- バグ修正の一環の削除 → `fix`
- 迷ったら `refactor`

`closes #<N>` を必ず含めること（PR マージ時に issue 自動クローズ）。

---

### Step 7: サマリー出力 / エスカレーション

#### 7-A. 全 Step 成功（Commit まで完了）

```markdown
✅ Issue Cycle Complete

Issue: #<N> <title>
Branch: issue-<N>-<slug>
Commit: <hash> <subject>
Files changed: K files (+X −Y)

### AC 検証結果
| # | Criterion | Status |
|---|-----------|--------|
| 1 | ... | ✅ PASS |
| 2 | ... | ✅ PASS |

### Regression
- /verify-local: ✅ PASS

### Next
→ `/pr-description` で PR 化
```

#### 7-B. エスカレーション（いずれかの Step でループ上限到達 or BLOCKED）

```markdown
⚠️ Issue Cycle Escalation

### Phase: [どの Step で止まったか]
### Attempts: [何回試行したか]

### 各試行の結果
- 試行 1: <summary>
- 試行 2: <summary>
- 試行 3: <summary>

### Root Cause Hypothesis
[なぜ全部失敗したかの推測]

### Current State
- Branch: issue-<N>-<slug>
- Uncommitted changes: [あり/なし、あれば内容]
- Issue: まだクローズされていない

### Recommended Action
- [ユーザーに何をしてほしいか]
- 選択肢: 手動修正 / ブランチ破棄 / 別のアプローチで再試行
```

**ユーザーからの明示指示があるまで続行しない。**

---

## Skill ツールエラー処理

各 Skill ツール呼出（`/verify-local`, `/smart-commit`）または Agent ツール呼出（`issue-executor`）が以下の場合:
- タイムアウト
- 例外エラー
- 想定外の出力フォーマット
- 結果が空

→ **即座にユーザーに報告して中断**。勝手に再試行しない（executor の Revise Mode は "失敗した" ではなく "想定内の NEEDS_FIX" の場合のみ）。

理由: インフラ起因のエラーは TDD ロジックの問題ではなく、エージェント判断での再試行は無駄。

---

## 原則

- **Issue が Single Source of Truth** — スキルは issue body を書き換えない
- **スコープ遵守** — issue に書かれていない変更は加えない（executor に対しても同じ規約）
- **既存機能を壊さない** — `/verify-local` regression check は省略不可
- **1 issue = 1 ブランチ = 1 コミット**（複数コミットが必要な粒度なら issue 分割をユーザーに提案）
- **ユーザー承認ゲート**: Step 2 の計画承認、Step 3-A の衝突時確認、Step 1-B の CLOSED 再実装確認
- **勝手に push しない / マージしない / PR 化しない**（PR 化は `/pr-description` の責務）

---

## Rules

- すべてのループに明示的な上限あり（executor 最大 3 回、verify-local 最大 3 回）
- 暗黙の無限ループは存在しない
- executor は毎回 **fresh spawn**（前回の context を引きずらない）

---

## Next

→ `/pr-description` で PR 化 → `/pr-review` でレビュー → ユーザー承認 → マージ
