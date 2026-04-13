---
name: generate
description: "自律開発 harness の内側ループ orchestrator。Story から lazy に Sprint Contract を交渉し、決定論 tier 判定 (T1/T2/T3) で fork 構成を選択、atomic skill 群をチェインして 1 sprint を完遂する。旧 /tdd-cycle と /ticket-cycle を統合。Trigger: /generate <story-id>, /generate --dry-run, sprint実行"
---

# Generate — Tiered Static Fork Orchestrator (H-Consensus)

## Usage

```
/generate <story-id> [--dry-run] [--force-tier=T1|T2|T3]
/generate                              # 次の未完了 Story を決定論で選ぶ
```

### Arguments

| 引数 | 必須 | 意味 |
|------|-----|------|
| `<story-id>` | 任意 | 実行対象 Story (例: `S-01`)。省略時は Story.md から未完了 Story を順に選ぶ |
| `--dry-run` | 任意 | Step 4 (tier 判定) まで実行し、実装はスキップ。契約内容と tier 分岐を事前確認できる |
| `--force-tier=T1\|T2\|T3` | 任意 | cold-start 中や特殊ケースで tier 判定を手動上書き。通常は使用しない |

---

## 指示（main Claude orchestrator 版）

あなたは `/generate` の orchestrator です。このスキルは旧 `/tdd-cycle` と `/ticket-cycle` を **Tiered Static Fork** 設計で統合したものです。

### 設計原理 (H-Consensus 合意事項)

- **Sprint Contract は 1 sprint 単位で lazy 生成**: Spec/Story は事前に確定済みだが、Ticket は sprint 開始時に 1 つずつ作る
- **fork 構成は Sprint 開始時に静的決定**: classify-tier.sh の出力で T1/T2/T3 のいずれかに確定、sprint 中は変更しない
- **全 tier 共通の不可侵**: test-writer (tester fork) ≠ implementer、evaluator (acceptance-tester fork) ≠ generator
- **コールドスタート保護**: post-mortem 10 件 or sprint 20 件の閾値前は強制 T2
- **HITL は最小限**: Sprint Contract 交渉時の異常のみ人間判断、通常は自律進行

### 共通ルール

- 各フェーズは Skill ツール or Agent ツールで fork spawn する (main orchestrator は親コンテキストに居座る)
- 成功時は自動で次 Step、失敗時のみユーザー報告
- Skill ツール呼出失敗 (タイムアウト/例外/フォーマット不正) は即中断してユーザー報告
- sprint 中はブランチ切替しない (Step 2-B で作成済みのブランチ上で継続)

---

## 決定論ゲート (スキルローダー実行)

以下を `!` 構文で事前実行し、結果を context に注入せよ:

### ゲート 1: ランタイムディレクトリ確保

必須ディレクトリ作成: !`mkdir -p .agent-core/tickets .agent-core/sprints .agent-core/gotchas .agent-core/gotchas/archive && echo "ready"`

### ゲート 2: Cold-Start 判定

Cold-start 状態確認: !`${CLAUDE_PLUGIN_ROOT}/scripts/cold-start-check.sh`

**重要**: 上記スクリプトの stdout に含まれる `COLD_START_ACTIVE` と `FORCED_TIER` の値を厳守すること。LLM 判断で上書きしてはならない。

### ゲート 3: 既存 ticket の最大 ID 取得 (新規 ID 採番用)

既存 ticket max ID: !`ls .agent-core/tickets/T-*.json 2>/dev/null | sed 's/.*T-\([0-9]*\)\.json/\1/' | sort -n | tail -1 | awk '{if($0=="") print "0"; else print $0}'`

### ゲート 4: 既存 sprint の最大 ID 取得 (sprint 記録採番用)

既存 sprint max ID: !`ls .agent-core/sprints/S-*.json 2>/dev/null | sed 's/.*S-\([0-9]*\)\.json/\1/' | sort -n | tail -1 | awk '{if($0=="") print "0"; else print $0}'`

### ゲート 5: 現在日付 (Gotcha timestamp 用)

今日の日付: !`date +%Y-%m-%d`

---

## Step 1: Story Pick

### Step 1-A: Story.md の読み込み

Story.md のパスを推定:
- 引数に story-id が明示されている場合 → `.agent-core/specs/` 配下から `*-story.md` を探す
- 見つからない場合 → ユーザーに Story.md のパスを確認

Story.md を Read し、全 Story 一覧と依存関係を把握する。

### Step 1-B: 次 Story の決定

引数 `<story-id>` がある場合:
- 該当 Story が存在するか確認。なければエラー報告で停止
- `Depends On` の前提 Story が全て完了済みか確認 (ticket JSON で status=done を確認)
- 未完了の前提があれば、ユーザーに確認してから続行 or 中断

引数がない場合:
- Story.md の Execution Order 順に未完了 Story を探す
- ticket JSON 全件を Read し、各 Story の完了状況を判定
- 次の開始可能 Story を提示してユーザー承認を取る (initial selection のみ HITL)

選択した Story を `SELECTED_STORY` として context に保持。

---

## Step 2: Sprint Contract 交渉 (fork)

**目的**: 実装前に「done の定義」を握る。harness blog の核心原則。

### Step 2-A: planner(Contract Mode) を fork spawn

Agent ツールで `subagent_type: planner` を呼ぶ。prompt に以下を含める:

```
MODE: CONTRACT

SELECTED_STORY: <Story 本文を抜粋>
KPI_PATH: .agent-core/specs/{slug}-kpi.md
SPEC_PATH: .agent-core/specs/{slug}-spec.md
STORY_PATH: .agent-core/specs/{slug}-story.md
EXISTING_TICKETS:
  <このStory配下で既に done になっている ticket のタイトルリスト>

## 指示
あなたは Sprint Contract 提案者です。選択された Story のうち、まだ未達成の DoD 項目を 1 つ選び、
それを達成する atomic な Sprint Contract を提案してください。

### 必須出力フィールド (JSON 相当のブロックで返す)

```yaml
ticket_id: T-XXXX                   # 新規採番 (ゲート 3 の max ID + 1)
story_id: <SELECTED_STORY の ID>
title: <1 行、value-oriented>
scope:
  - <1-3 の箇条書き、"ついでに" 禁止>
acceptance_criteria:
  - exec: "<Bash コマンド、exit code で pass/fail 判定可能>"   # 複数可
  - assert: "<意味的 assertion、読み上げで判定可能>"            # 複数可
tier_metadata:
  verifiability: exec | manual
  risk_layer: doc | rename | config | logic | ui | api | auth | db | migration | security
  surface: <変更予定 file 数の概算 integer>
estimated_sprints: 1                # 常に 1
story_progress: "Story <ID> DoD の <X> がこの sprint で達成される"
```

### 制約
- 1 Contract = 1 sprint = 1 PR 相当。大きすぎると contract-reviewer が reject する
- AC は最低 2 件。exec 形式が 1 件以上あると verifiability=exec 判定になる
- tier_metadata.risk_layer は scope と整合させる (lie にしない)
- scope に実装詳細 (関数名・クラス名) を書かない。value 単位で記述
```

planner の出力から JSON 相当ブロックを抽出して `PROPOSED_CONTRACT` として保持する。

### Step 2-B: contract-reviewer で検証 (fork)

Agent ツールで `subagent_type: contract-reviewer` を呼ぶ。prompt に以下を含める:

```
以下の Sprint Contract 提案を 5 評価軸で検証せよ:

PROPOSED_CONTRACT:
<Step 2-A の出力ブロック>

親 Story/Spec/KPI も Read で参照し、atomicity / AC testability / Story Advancement / Tier Metadata / KPI Alignment を評価せよ。
```

contract-reviewer の出力から Judgment / Issues / Fix Instructions を抽出。

### Step 2-C: 判定

- `OK` → **Step 2-D へ (契約確定)**
- `NEEDS_FIX` AND round < 3 → Fix Instructions を planner prompt に追加して **Step 2-A から再試行**
- `NEEDS_FIX` AND round == 3 → **エスカレーション** (ユーザー判断: 手動修正 / 強制進行 / 中断)

### Step 2-D: 契約確定 → ticket JSON 生成

確定した Contract を `.agent-core/tickets/T-XXXX.json` として Write する (lazy materialization):

```json
{
  "ticket_id": "T-XXXX",
  "story_id": "S-YY",
  "title": "...",
  "body": "## Scope\n- ...\n\n## Acceptance Criteria\n- exec: ...\n- assert: ...\n\n## Story Progress\n...",
  "status": "open",
  "phase": "lazy",
  "labels": [],
  "branch": null,
  "github_issue_number": null,
  "created_at": "<ISO 8601>",
  "updated_at": "<ISO 8601>",
  "spec_reference": "<STORY_PATH>",
  "tier_metadata": {
    "verifiability": "exec|manual",
    "risk_layer": "...",
    "surface": N
  },
  "estimated_sprints": 1,
  "gotcha_entries": []
}
```

---

## Step 3: Tier 判定 (決定論)

**LLM 判断を挟まず**、`classify-tier.sh` の出力を尊重せよ。

### Step 3-A: classify-tier.sh 実行

`!` 構文で以下を実行し、結果を context に注入する:

```bash
!${CLAUDE_PLUGIN_ROOT}/scripts/classify-tier.sh \
  --verifiability=${PROPOSED_CONTRACT.tier_metadata.verifiability} \
  --risk=${PROPOSED_CONTRACT.tier_metadata.risk_layer} \
  --surface=${PROPOSED_CONTRACT.tier_metadata.surface}
```

stdout の `TIER=` 行から `T1` / `T2` / `T3` を抽出、`DETERMINED_TIER` として保持。

### Step 3-B: Cold-Start 上書き

ゲート 2 で `COLD_START_ACTIVE=true` の場合、**`DETERMINED_TIER` を強制的に `T2` に上書き**し、context に以下を記録:

```
COLD_START_OVERRIDE: DETERMINED_TIER=T2 (original=<classify-tier output>, reason=<ゲート2 REASON>)
```

### Step 3-C: `--force-tier` 上書き (明示指定時のみ)

引数に `--force-tier=TX` が与えられた場合、`DETERMINED_TIER` を `TX` に上書きし、context に明示ログ:

```
MANUAL_FORCE: DETERMINED_TIER=TX (reason=user explicit override)
```

### Step 3-D: `--dry-run` 分岐

`--dry-run` 指定時は以下を表示して**終了**:

```
## /generate --dry-run Report

### Selected Story
- <SELECTED_STORY.id>: <title>

### Proposed Sprint Contract (T-XXXX)
- Scope: ...
- AC: ...
- tier_metadata: verifiability=..., risk_layer=..., surface=...

### Tier Decision (deterministic)
- classify-tier.sh output: <TIER=Tx, REASON=...>
- COLD_START_ACTIVE: true/false
- Final DETERMINED_TIER: <Tx>

### What would happen next (if run for real)
- Tier <Tx> の fork 構成: <各 step の atomic skill 名>

実行する場合は --dry-run を外して再度 /generate <story-id> を実行してください。
```

ticket JSON は dry-run でも Write する (lazy 生成なので残しておく)。

---

## Step 4: ブランチ準備

### Step 4-A: ブランチ名決定

```
ticket-<TICKET_ID>-<slug>
```

slug は title から kebab-case 変換 (最大 30 文字)。

### Step 4-B: ブランチ作成

```bash
git checkout -b <branch-name>
```

既に同名ブランチがあればユーザー確認。

### Step 4-C: ticket JSON 更新

ticket JSON の `branch` フィールドと `status` を update:
- `branch`: <branch-name>
- `status`: "open" → "in_progress"
- `updated_at`: 現在時刻

---

## Step 5: Tier 別 Fork 実行

`DETERMINED_TIER` に従って分岐する。**fork 構成は sprint 中に変更禁止**。

### Step 5-T1: Low Risk パス (2 fork)

対象: doc / rename / config 変更、verifiability=exec、surface<=3

```
┌─ fork: ticket-executor ─┐
│  .agent-core/tickets/   │
│  T-XXXX.json を渡す     │
└─────────────────────────┘
         ↓
  ┌─ /verify-local ─┐
  │  (親 context)    │
  └──────────────────┘
```

**Step T1-1**: Agent(`subagent_type: ticket-executor`) を fork spawn。prompt:

```
TICKET_PATH: .agent-core/tickets/<T-XXXX>.json
BRANCH: <branch-name>
MODE: Initial

以下を実行せよ:
1. ticket JSON を Read で読む
2. scope と acceptance_criteria を把握
3. Edit / Write / Bash で scope を実装
4. 各 exec AC を Bash で実行し、exit code を確認
5. assert AC は意味的に assertion を満たすか確認
6. ticket-executor.md の Output Format で報告
```

**Step T1-2**: Skill ツール `/verify-local` を呼び出し、ビルド・テスト・lint の regression を確認。

- PASS → **Step 6 へ**
- FAIL → T1-1 を再 spawn (最大 3 round、Fix Instructions を prompt に追加)
- 3 round 超 → **エスカレーション**

post-mortem は T1 ではスキップ (軽量タスクで学習対象が少ないため)。

---

### Step 5-T2: Medium Risk パス (4 fork)

対象: feature 追加、bug fix、UI 変更、risk_layer が中程度

```
┌─ /red-test ─┐      ┌─ /implement ─┐      ┌─ /verify-test ─┐      ┌─ /e2e-evaluate ─┐
│  fork:       │ →    │  fork:         │ →   │  fork:          │ →   │  fork:           │
│  tester      │      │  implementer   │     │  tester          │     │  acceptance-test │
└──────────────┘      └────────────────┘     └─────────────────┘     └──────────────────┘
```

**Step T2-1**: Skill(`/red-test`) → tester fork でテスト作成 + RED 確認

**Step T2-2**: Skill(`/implement`) → implementer fork で最小実装

**Step T2-3**: Skill(`/verify-test`) → tester fork で GREEN 確認
- FAIL なら T2-2 に戻って最大 3 round リトライ
- 3 round 超 → エスカレーション

**Step T2-4**: Skill(`/e2e-evaluate`) → acceptance-tester fork で E2E + デザイン評価
- PASS → **Step 6 へ**
- ITERATE → T2-2 から再実行 (最大 3 round)
- 3 round 超 → エスカレーション

post-mortem は T2 では原則スキップだが、**ITERATE が 2 round 以上発生した場合は T2 でも post-mortem を呼ぶ** (失敗学習の価値が高い)。

---

### Step 5-T3: High Risk パス (7-8 fork)

対象: auth / db schema / migration / api contract / security 変更、surface>=10

```
 ┌─ contract-reviewer ─┐    (Step 2-B で既に fork 実行済み、T3 では結果を明示再参照)
          ↓ (既に検証済みの契約)
 ┌─ /red-test ─┐ →  ┌─ /audit-tests ─┐ → ┌─ /implement ─┐ → ┌─ /verify-test ─┐
 │  tester     │    │  test-auditor  │   │  implementer │   │  tester         │
 └─────────────┘    └────────────────┘   └──────────────┘   └─────────────────┘
      ↓
 ┌─ /review-impl ─┐ → ┌─ /e2e-evaluate ─┐ → ┌─ fork: post-mortem ─┐
 │  reviewer      │   │  acceptance-test │   │  Gotcha 抽出        │
 └────────────────┘   └──────────────────┘   └─────────────────────┘
```

**Step T3-1**: Skill(`/red-test`) → tester fork

**Step T3-2**: Skill(`/audit-tests`) → test-auditor fork (AC カバレッジ + 報酬ハック検出)
- NEEDS_IMPROVEMENT → T3-1 に戻って補強、最大 3 round

**Step T3-3**: Skill(`/implement`) → implementer fork

**Step T3-4**: Skill(`/verify-test`) → tester fork
- FAIL → T3-3 に戻る、最大 3 round

**Step T3-5**: Skill(`/review-impl`) → reviewer fork (コードレビュー、diff のみ見る)
- NEEDS_FIX → T3-3 に戻る、最大 2 round

**Step T3-6**: Skill(`/e2e-evaluate`) → acceptance-tester fork
- PASS → T3-7 へ
- ITERATE → T3-3 に戻る、最大 3 round
- 3 round 超 → エスカレーション

**Step T3-7**: Agent(`subagent_type: post-mortem`) fork spawn。prompt:

```
SPRINT_ID: <new sprint ID>
TICKET_ID: <T-XXXX>
STORY_ID: <S-YY>
TIER: T3
SPRINT_LOG_PATH: .agent-core/sprints/<S-XXXX>.json  (Step 6 で生成予定だが、ここでは実行ログを in-memory で渡す)
CONTRACT_PATH: .agent-core/tickets/<T-XXXX>.json
AFFECTED_AGENTS: tester, test-auditor, implementer, reviewer, acceptance-tester
AFFECTED_SKILLS: red-test, audit-tests, implement, verify-test, review-impl, e2e-evaluate
ITERATIONS:
  red-test: N round
  audit-tests: N round
  implement: N round
  verify-test: N round
  review-impl: N round
  e2e-evaluate: N round

post-mortem.md の Workflow に従って Gotcha 抽出せよ。Allowed Write Paths を厳守。
```

post-mortem が Edit した paths を記録する (後段の境界外書き込み検出に使用)。

---

## Step 6: Sprint 記録の永続化

### Step 6-A: Sprint ID 採番

ゲート 4 の `sprint max ID + 1` を新 `SPRINT_ID` とする。

### Step 6-B: `.agent-core/sprints/S-XXXX.json` を Write

```json
{
  "sprint_id": "S-XXXX",
  "ticket_id": "T-YYYY",
  "story_id": "S-NN",
  "tier": "T1|T2|T3",
  "cold_start_override": true/false,
  "manual_force": null | "Tx",
  "started_at": "<ISO 8601>",
  "completed_at": "<ISO 8601>",
  "iterations": {
    "<phase>": <N round>
  },
  "verdict": "PASS | ESCALATED",
  "affected_files": [<変更ファイル一覧 (git diff --stat ベース)>],
  "post_mortem_executed": true/false,
  "gotcha_entries_added": [<HASH8 のリスト>]
}
```

### Step 6-C: ticket JSON を更新

- `status`: "in_progress" → "done"
- `updated_at`: 現在時刻

### Step 6-D: `/smart-commit` を呼び出し

Skill ツール `/smart-commit` で Ticket trailer 付きコミットを作成:

```
<type>: <title>

...

Ticket: T-XXXX
Sprint: S-XXXX
Co-Authored-By: Claude Code <noreply@anthropic.com>
```

---

## Step 7: Boundary Check (post-mortem 実行時のみ)

post-mortem が実行された場合、終了後に境界外書き込みを検出:

```bash
# Before post-mortem: git diff --stat でファイル一覧を取得
# After post-mortem: もう一度 git diff --stat で取得
# 差分から post-mortem が触ったファイルを特定
# Allowed Write Paths に含まれないものがあれば警告
```

境界外違反があれば `⚠️ post-mortem wrote outside allowed paths` をユーザー報告し、git 変更を確認するよう促す。

---

## Step 8: Loop 制御

### Step 8-A: 次アクションの決定

Sprint 完了後、以下のいずれかを選択:

1. **同じ Story の次 sprint に進む**: `SELECTED_STORY` の DoD がまだ未達成なら Step 2 に戻る
2. **次 Story に進む**: `SELECTED_STORY` の全 DoD が達成されたら Step 1-B に戻って次 Story 選択
3. **全 Story 完了**: `/e2e-evaluate` もしくは手動 QA フェーズへ案内

### Step 8-B: 進捗表示

各 sprint 完了時に以下を表示:

```
✅ Sprint <SPRINT_ID> 完了 (Tier: <Tx>, Rounds: <N>)
   Ticket: T-XXXX
   Story S-YY 進捗: <M>/<Total> DoD 達成

次アクション:
  1. 同 Story 継続 → /generate (引数なしで自動選択)
  2. 別 Story 指定 → /generate S-ZZ
  3. E2E 検証フェーズへ → /e2e-evaluate
  4. team 共有へ (opt-in) → /ticket-publish T-XXXX
```

---

## エスカレーションポリシー

各 Step / 各 round 上限到達時、以下の Handoff Document をユーザーに提示:

```markdown
## /generate Escalation

### Sprint: <SPRINT_ID (採番済み)> Tier: <Tx>
### Ticket: T-XXXX (<title>)
### Story: S-YY

### Failure Phase
[どの Step の何 round で止まったか]

### History
- Round 1: [何を試したか] → [失敗理由]
- Round 2: ...
- Round 3: ...

### Root Cause Hypothesis
[なぜ全部失敗したか]

### Current State
- branch: <branch-name>
- git diff: <変更の要約>
- ticket status: in_progress

### Recommended Action
1. 手動修正 → /verify-local → /smart-commit で完了
2. Sprint Contract を作り直す → /generate --dry-run S-YY で再交渉
3. この Story を skip して次へ → /generate <other-story-id>
4. 中断 → ticket status を open に戻して終了
```

ユーザーからの明示指示があるまで続行しない。

---

## Skill ツールエラー処理

各 Skill / Agent ツール呼出 (`/red-test`, `/implement`, `/verify-test`, `/audit-tests`, `/review-impl`, `/e2e-evaluate`, `subagent_type: planner`, `subagent_type: contract-reviewer`, `subagent_type: ticket-executor`, `subagent_type: post-mortem`) が以下のいずれかの場合:

- タイムアウト
- 例外エラー
- 想定外の出力フォーマット
- 結果が空

→ **即座にユーザーに報告して中断**。再試行を勝手に繰り返さない。

---

## Context Degradation 監視

長時間実行で以下の兆候が出たら、現在の sprint を完了後に停止:

- **Repetition**: 同じコードの再生成、同じ説明の繰り返し
- **Skipping**: Sprint Contract にある AC のスキップ
- **Quality drop**: エラーハンドリングの欠落、命名の不統一
- **Premature completion**: 「完了」宣言だが AC 未検証

検知時は Handoff Document でユーザーに報告。

---

## コンテキスト肥大化対策 (main の責務)

各 sprint で main context に保持するもの:
- ✅ SELECTED_STORY.id / ticket_id / sprint_id (文字列)
- ✅ DETERMINED_TIER / PROPOSED_CONTRACT の tier_metadata のみ
- ✅ 各 fork の Verdict / Issues / Fix Instructions セクション
- ❌ Contract 本文 / ticket body / sprint log / 各 fork の詳細推論プロセス
- ❌ diff 本文 (ファイルリストのみ)

1 sprint あたり main 追加使用量を 15k tokens 以内に抑える。

---

## Next

→ 同 Story 継続: `/generate` (引数なし)
→ 別 Story 指定: `/generate S-<id>`
→ 全 Story 完了後の検証: `/e2e-evaluate`
→ team 共有 (opt-in): `/ticket-publish <T-XXXX>` → `/pr-description` → `/pr-review`

---

## 旧ワークフローとの互換性

- 既存の `.agent-core/tickets/T-XXXX.json` (旧 `/create-ticket` で生成) も読み込み可能。`tier_metadata` フィールドが無ければ `tier=T2` にフォールバック
- `/tdd-cycle` / `/ticket-cycle` / `/create-ticket` は **deprecated alias** として存置されており、旧フローはそのまま動作する
- `/generate` は **新規の設計プロジェクト向け** の統合入口。混在利用は可能だが、推奨は新規プロジェクトは `/generate` に統一すること

## Gotchas

<!-- post-mortem agent appends entries here -->
<!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
