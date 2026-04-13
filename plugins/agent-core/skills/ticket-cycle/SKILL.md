---
name: ticket-cycle
description: "ローカル JSON チケット（.agent-core/tickets/T-XXXX.json）から AC 駆動で実装するサイクル。TDD に馴染まない削除・リファクタ・インフラ変更・設定変更・ドキュメント更新向け。ticket_id を受け取り、ブランチ作成 → ticket-executor で実装 → /verify-local → /smart-commit まで自動化。gh 依存なし、完全オフライン動作。Trigger: /ticket-cycle <T-XXXX>, ticket 実装, 削除タスク, リファクタタスク, インフラ変更"
---

# Ticket Cycle — ローカル JSON チケットから AC 駆動実装

> ⚠️ **DEPRECATED (1.3.0+)** — 新規プロジェクトでは `/generate <story-id>` を推奨します。
>
> H-Consensus モデルでは、`/tdd-cycle` と `/ticket-cycle` の 2 レーンは `/generate` に統合されました。`/generate` は Sprint Contract の `verifiability / risk_layer / surface` metadata から **決定論的に tier (T1/T2/T3) を判定**し、削除・リファクタ・インフラ系のタスクは T1 で ticket-executor が処理します (本スキルと同等の動作)。
>
> このスキルは **既存プロジェクトの後方互換のためのみ**に残存しています。従来通り `/create-ticket` で生成した ticket に対して動作します。
>
> 新規プロジェクトでは `/planning` → `/generate <story-id>` のフローに切り替えてください。

## Usage

```
/ticket-cycle <T-XXXX>
```

例: `/ticket-cycle T-0003`

---

## いつ使うか

`/tdd-cycle` と `/ticket-cycle` は **sibling** であり、ユーザーが明示的に使い分ける。

### `/ticket-cycle` が適するタスク

- **一括削除 / デッドコード撤去**
- **ファイル・ディレクトリ構造のリファクタ**
- **設定ファイル・依存関係の更新**
- **インフラ・ビルドスクリプトの変更**
- **ドキュメント・マイグレーション作業**
- **その他「テスト先行」が不自然な変更全般**

→ チケット本文に **実行可能な Acceptance Criteria**（`grep` / `find` / `test` / `pnpm test` 等）が書かれていることが前提。

### `/tdd-cycle` が適するタスク

- **新機能の追加**
- **バグ修正**（再現テストを先に書ける）
- **既存機能の振る舞い変更**
- **その他「テスト先行が自然」な変更全般**

判断に迷ったらユーザーに確認すること。勝手に分岐しない。

---

## Workflow Awareness

あなた（メイン Claude）は **agent-core の TDD 駆動開発パイプライン**で `/ticket-cycle` orchestrator として動作する。全体構造:

```
Phase 0: /planning → /create-ticket（ローカル JSON 生成）

Phase 1-N（2 レーン、ユーザーが明示使い分け）:
  ├─ /tdd-cycle <T-ID>        ← テスト先行が自然なタスク
  └─ /ticket-cycle <T-ID>     ← テスト先行が不自然なタスク（削除・リファクタ・インフラ）  ← あなたはここ
       │
       ├─ チケット JSON 読み取り → AC 抽出 → 承認ゲート → ブランチ作成
       ├─ Agent(ticket-executor) で実装 + AC 検証（fork isolation）
       ├─ /verify-local で regression check
       └─ /smart-commit でコミット（Ticket: T-XXXX を trailer に含める）

Phase Publish（opt-in、team 共有時だけ）:
  /ticket-publish → GitHub Issue 化
  /pr-description → PR 作成
  /pr-review → レビュー投稿

Phase Final: /e2e-evaluate → acceptance-tester
```

**重要**: このスキルは **gh を一切呼ばない**。ローカル JSON からすべて完結する。GitHub Issue に push したい場合は別途 `/ticket-publish <T-ID>` を実行する（opt-in）。

orchestrator（あなた）は**親コンテキストに居座り**、executor 側だけを fork する。これにより:
- ユーザーへの途中報告・承認ゲート・割り込みが機能する
- executor の中間思考（grep 結果、影響範囲調査の詳細等）は親に漏れず、レポートのみが返る

---

## Task

あなた（メイン Claude）は Ticket Cycle orchestrator です。
以下のステップを順に実行し、各ステップの結果を判定して次に進んでください。

### 共通ルール

- **成功時は自動的に次の Step に進む**（Step 2 の承認ゲートのみ例外）
- **失敗時は即座にユーザーに報告して指示を仰ぐ**
- **チケット JSON を書き換えない**ほうが安全だが、`status` と `branch` と `updated_at` の更新だけはこのスキルの責務として行う（Step 3 と Step 6 後）
- **スコープ遵守**: チケットに書かれていない変更を加えない
- **勝手に push しない / マージしない**
- **勝手にブランチを切り替えない**（Step 3 で新規作成するのみ）
- **gh を呼ばない**（このスキルは fully offline）

---

### Step 1: チケット読み込み（決定論ゲート）

以下の `!` 構文ブロックがスキル読み込み時に必ず実行され、チケット JSON と現在の git 状態が注入された状態で orchestrator が起動する。

チケット ID の正規化（`T-0003`, `t-0003`, `3`, `#3` などを受理）:

!`echo "$ARGUMENTS" | grep -oE '[0-9]+' | head -1 | awk '{printf "T-%04d\n", $1}'`

チケット JSON を読む（`!` 構文で context に注入）:

!`TID=$(echo "$ARGUMENTS" | grep -oE '[0-9]+' | head -1 | awk '{printf "T-%04d\n", $1}'); if [ -z "$TID" ]; then echo "TICKET_ID_PARSE_FAILED: '$ARGUMENTS' から数値を抽出できません"; elif [ ! -f ".agent-core/tickets/${TID}.json" ]; then echo "TICKET_NOT_FOUND: .agent-core/tickets/${TID}.json が存在しません"; else echo "=== TICKET FILE ==="; cat ".agent-core/tickets/${TID}.json"; fi`

現在の git 状態:

!`git status --short`

!`git branch --show-current`

modified tracked ファイルのみ抽出（untracked は新ブランチ作成に影響しないので通過させる）:

!`git status --porcelain | grep -E '^[ MADRU]+ ' || echo "(no modified tracked files)"`

#### 1-A. 取得失敗の場合

上記出力に `TICKET_ID_PARSE_FAILED` / `TICKET_NOT_FOUND` が含まれる場合 → **即停止**。以下をユーザーに報告:

- 引数に渡された内容: `$ARGUMENTS`
- 解決できた ticket_id（あれば）
- `.agent-core/tickets/` に存在するチケット一覧（`ls .agent-core/tickets/*.json` を実行して提示）
- 対処案: 「正しいチケット ID を指定してください」「`/create-ticket` でまだ作っていない場合は先に実行してください」

#### 1-B. チケットの status が `done` の場合

JSON の `status` が既に `done` → **停止してユーザーに確認**:
- 「このチケットは既に done です。再実装しますか？」
- 明示承認があれば続行、なければ中止

#### 1-C. working tree が dirty（modified tracked ファイルあり）の場合

modified tracked ファイルがある場合 → **停止してユーザーに確認**:
- 現在の変更内容を要約表示
- 選択肢: 「stash して続行」「既に staging している場合はそのまま続行（非推奨）」「中止」
- ユーザーの明示選択を待つ

**untracked ファイル**（`??` マーク）は新ブランチ作成に影響しないため**通過**させる（ブロックしない）。

---

### Step 2: AC 抽出 + 計画提示（ユーザー承認ゲート）

Step 1 で読み込んだチケット JSON を解析し、以下を抽出する:

- **title**: JSON の `title` フィールド
- **body**: JSON の `body` フィールド（Markdown）
- **labels**: JSON の `labels` フィールド
- **Acceptance Criteria**: body の `## Acceptance Criteria` セクション配下のチェックボックス行
- **実行可能コマンド AC のマーク**: 各 AC を走査し、以下のパターンを含むものを「実行可能」としてマーク:
  - `` `grep ...` `` / `` `find ...` `` / `` `ls ...` ``
  - `` `pnpm test` `` / `` `npm test` `` / `` `pytest` `` / `` `cargo test` `` / 他のテストコマンド
  - `` `test -f ...` `` / `` `[ -f ... ]` ``
  - 任意のコード fence 内シェルコマンド
- **自然言語 AC**: 実行可能コマンドを含まない AC は別リストにする（後段で executor が可能な限り検証、不可能なら Manual 扱い）

ブランチ名を生成:
- フォーマット: `ticket-<T-ID>-<slug>`
- slug: title から「`feat: `」「`fix: `」等のプレフィックスを除いてラテン文字・数字・ハイフン部分を抽出し kebab-case 化（日本語は除外）
- 例:
  - `feat: ユーザー認証機能` + `T-0003` → `ticket-T-0003` (日本語のみで slug 不能)
  - `refactor: remove dead auth code` + `T-0007` → `ticket-T-0007-remove-dead-auth-code`
  - 日本語のみで slug 生成困難な場合: `ticket-T-XXXX` で統一

以下を**ユーザーに提示**し、明示承認を待つ:

```
📋 Ticket Cycle Plan

Ticket: <T-ID> <title>
Status: open (from local JSON)
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

計画するブランチ: ticket-<T-ID>-<slug>

作業サマリー（body からの推測）:
- [変更対象と方向性]

この計画で進めてよろしいですか？ (yes / no / 修正指示)
```

**重要**: ユーザーの明示 `yes` なしに Step 3 以降に進んではならない。

---

### Step 3: ブランチ作成 + チケット状態更新

ユーザー承認後、Bash ツールで以下を実行:

```bash
git checkout -b ticket-<T-ID>-<slug>
```

#### 3-A. ブランチ作成失敗の場合

- 既存ブランチ名衝突（`already exists`）→ ユーザーに確認:
  - 「既存ブランチに switch する」「別名で作成する」「中止」
- その他の失敗 → 停止してエラー表示

#### 3-B. チケット JSON の更新

ブランチ作成成功後、`.agent-core/tickets/<T-ID>.json` の以下のフィールドを Edit で更新:
- `status`: `"open"` → `"in_progress"`
- `branch`: `null` → `"ticket-<T-ID>-<slug>"`
- `updated_at`: 現在の ISO 8601 UTC 時刻（`date -u +"%Y-%m-%dT%H:%M:%SZ"` の出力）

---

### Step 4: ticket-executor に実装を委譲

**Agent ツール**で `subagent_type: "ticket-executor"` を呼び出す。prompt には以下を含める:

```
TICKET_ID: <T-ID>
TICKET_TITLE: <title>
TICKET_BODY:
<JSON の body フィールド全文>

ACCEPTANCE_CRITERIA:
🔧 実行可能コマンド AC:
1. [command 1] → expect [expected]
2. [command 2] → expect [expected]
...

📝 自然言語 AC:
- ...
- ...

CURRENT_BRANCH: ticket-<T-ID>-<slug>

指示:
- チケットの要求を実装し、各 AC コマンドを順次実行して検証せよ
- ticket-executor.md の Workflow (Step 1-6) に従え
- 完了したら Output Format の Report を返せ
- 勝手にコミットせず、変更内容のレポートのみ返せ
- gh / GitHub API を一切呼ぶな（fully offline）
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

### Step 6: Commit + チケット状態更新

**Skill ツール**で `/smart-commit` を呼出。コミットメッセージとして以下を指示する:

```
Type: <fix / refactor / chore / docs のいずれか、title から推定>
Scope: <title から推定、または省略>
Summary: <title から生成>

Body:
- [変更サマリー]
- [AC 検証結果サマリー]

Ticket: <T-ID>

Co-Authored-By: Claude Code <noreply@anthropic.com>
```

**Type の推定ガイド**:
- 削除・リファクタ・依存整理 → `refactor`
- 設定変更・CI/ビルド設定 → `chore`
- ドキュメントのみ → `docs`
- バグ修正の一環の削除 → `fix`
- 迷ったら `refactor`

`Ticket: <T-ID>` trailer を必ず含めること（後で PR 化時に `/pr-description` がこれを読み取って関連チケットを表示する）。

#### コミット成功後、チケット JSON の更新

`.agent-core/tickets/<T-ID>.json` の以下のフィールドを Edit で更新:
- `status`: `"in_progress"` → `"done"`
- `updated_at`: 現在の ISO 8601 UTC 時刻

---

### Step 7: サマリー出力 / エスカレーション

#### 7-A. 全 Step 成功（Commit まで完了）

```markdown
✅ Ticket Cycle Complete

Ticket: <T-ID> <title>
Status: done (local)
Branch: ticket-<T-ID>-<slug>
Commit: <hash> <subject>
Files changed: K files (+X −Y)

### AC 検証結果
| # | Criterion | Status |
|---|-----------|--------|
| 1 | ... | ✅ PASS |
| 2 | ... | ✅ PASS |

### Regression
- /verify-local: ✅ PASS

### Next（optional）
- GitHub に共有: /ticket-publish <T-ID>
- PR 化: /pr-description
- レビュー投稿: /pr-review
```

#### 7-B. エスカレーション（いずれかの Step でループ上限到達 or BLOCKED）

```markdown
⚠️ Ticket Cycle Escalation

### Phase: [どの Step で止まったか]
### Attempts: [何回試行したか]

### 各試行の結果
- 試行 1: <summary>
- 試行 2: <summary>
- 試行 3: <summary>

### Root Cause Hypothesis
[なぜ全部失敗したかの推測]

### Current State
- Ticket: <T-ID>
- Status (JSON): <現在の status>
- Branch: ticket-<T-ID>-<slug>
- Uncommitted changes: [あり/なし、あれば内容]

### Recommended Action
- [ユーザーに何をしてほしいか]
- 選択肢: 手動修正 / ブランチ破棄 / 別のアプローチで再試行 / チケットの status を手動で戻す
```

**ユーザーからの明示指示があるまで続行しない。**

エスカレーション時、チケット JSON の `status` は `in_progress` のままにしておく（`done` に進めない）。ユーザーが手動で対処した後、再試行できるようにする。

---

## Skill ツールエラー処理

各 Skill ツール呼出（`/verify-local`, `/smart-commit`）または Agent ツール呼出（`ticket-executor`）が以下の場合:
- タイムアウト
- 例外エラー
- 想定外の出力フォーマット
- 結果が空

→ **即座にユーザーに報告して中断**。勝手に再試行しない（executor の Revise Mode は "失敗した" ではなく "想定内の NEEDS_FIX" の場合のみ）。

理由: インフラ起因のエラーはロジックの問題ではなく、エージェント判断での再試行は無駄。

---

## 原則

- **ローカル JSON が Single Source of Truth** — スキルは JSON を読むが、`status` / `branch` / `updated_at` の必要最小限のみ更新する
- **スコープ遵守** — チケットに書かれていない変更は加えない（executor に対しても同じ規約）
- **既存機能を壊さない** — `/verify-local` regression check は省略不可
- **1 チケット = 1 ブランチ = 1 コミット**（複数コミットが必要な粒度ならチケット分割をユーザーに提案）
- **ユーザー承認ゲート**: Step 2 の計画承認、Step 3-A の衝突時確認、Step 1-B の done 再実装確認
- **gh を一切呼ばない**（GitHub 連携は別スキル `/ticket-publish` の責務）
- **勝手に push しない / マージしない / PR 化しない**（PR 化は `/pr-description` の責務）

---

## Rules

- すべてのループに明示的な上限あり（executor 最大 3 回、verify-local 最大 3 回）
- 暗黙の無限ループは存在しない
- executor は毎回 **fresh spawn**（前回の context を引きずらない）

---

## Next

→ （optional）`/ticket-publish <T-ID>` で GitHub に共有
→ `/pr-description` で PR 化 → `/pr-review` でレビュー → ユーザー承認 → マージ

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
