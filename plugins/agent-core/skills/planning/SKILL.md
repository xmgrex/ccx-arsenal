---
name: planning
description: "アプリ開発の起点。ユーザーの要求から KPI → Spec → Story → (UI screens) の 4 段収束レビューループで設計ドキュメント一式を生成する。Ticket は作らず、/generate が lazy materialization する。Trigger: アプリ作って, 〜を作りたい, 設計して, spec, 仕様, 企画"
disable-model-invocation: false
---

## Planning — KPI/Spec/Story/UI の 4 段収束レビューループ

### ユーザーの要求

$ARGUMENTS

---

### 決定論ゲート（スキルローダー実行）

specs ディレクトリ確保: !`mkdir -p .agent-core/specs && echo "ready"`

---

### 指示（main Claude orchestrator 版）

あなたは `/planning` の orchestrator です。以下の **4 段収束ループ**を実行せよ。

**全体構造**:
- **Stage 0**: KPI.md の収束（最大 3 ラウンド、planner(KPI Mode) + spec-reviewer(KPI Mode)）
- **Stage 1**: spec.md + flow.md の収束（最大 3 ラウンド、planner(Spec Mode) + spec-reviewer + flow-reviewer 並列）
- **Stage 2**: story.md の収束（最大 3 ラウンド、planner(Story Mode) + spec-reviewer(Story Mode) + flow-reviewer(Story Mode) 並列）
- **Stage 3**: HTML screens の収束（最大 3 ラウンド、ui-designer + ui-design-reviewer、UI アプリのみ）
- 全 Stage 完了 → ユーザー承認ゲート → **`/generate` で Sprint Contract 単位に lazy ticket 化**

**重要原則（全 Stage 共通）**:
- 各ラウンドの全 agent は必ず**新規 Agent コール**で spawn する（kill-and-spawn / fresh context）
- Round 2 以降の planner / ui-designer は `Revise Mode` で起動（既存ファイルを差分修正）
- 並列可能な reviewer は**同一メッセージ内で並列 spawn**（Agent ツールを1メッセージで複数 call）
- main context を肥大させないため、各 agent 出力から必要な要素のみ抽出する（artifact 本文は保持せずパスのみ）
- **Doc 階層の依存**: KPI → Spec → Story → (UI) の順に上流が下流を制約する。前 stage 収束なしに次 stage に進んではならない
- **Ticket は作らない**: `/create-ticket` は呼ばない。Ticket は `/generate` が Sprint Contract 交渉時に 1 つずつ lazy 生成する

---

## Stage 0: KPI 収束ループ

**目的**: Spec より 1 段上の抽象で、プロジェクトの**成功定義**と**撤退条件**を確定する。KPI.md は後段 Spec/Story の意思決定ガードレールとして機能する。

#### Stage 0 - Round 1: 初回生成

**Step 0-1-1 — planner(KPI Mode) を fresh spawn**:

Agent ツールで `subagent_type: planner` を呼ぶ。prompt に以下を含める:

```
MODE: KPI

以下の要求から KPI (成功定義 + 撤退条件 + 対象ユーザー + Non-Goals) を生成せよ:

$ARGUMENTS

## Workflow Context
あなたは agent-core の Phase 0 Stage 0 を担当する。このステップでは実装詳細・技術スタック・UI の話を一切書かない。「何を達成するか」のみ記述する。

詳細は planner.md の `## KPI Mode` セクションを参照せよ。

## 必須要件
- KPI を `.agent-core/specs/{slug}-kpi.md` に Write で保存する (slug は App Name の kebab-case)
- 保存後、以下を返す:
  - KPI_PATH: 保存先のフルパス
  - APP_SLUG: slug 文字列
```

planner の返答から `KPI_PATH` と `APP_SLUG` を抽出する。

**Step 0-1-2 — spec-reviewer(KPI Mode) を fresh spawn**:

Agent ツールで `subagent_type: spec-reviewer` を単独呼び出し (flow-reviewer は Stage 0 では使わない):

```
MODE: KPI

以下の KPI をレビューせよ: {KPI_PATH}

spec-reviewer.md の `## KPI Mode Rules` に従って評価すること (評価軸 KPI-1 〜 KPI-5)。Spec Mode の評価軸 1-6 は適用しない。
```

**Step 0-1-3 — 判定集約**:

spec-reviewer の出力から以下のみ抽出:
- `Judgment` 行 (OK / NEEDS_FIX)
- `Issues` (Critical/Important のみ)
- `### Fix Instructions (for planner)` 全文

判定ロジック:
- `OK` → **Stage 1 へ**
- `NEEDS_FIX` → Fix Instructions 集約 → **Stage 0 - Round 2 へ**

#### Stage 0 - Round 2 / Round 3: Revise Mode

**Step 0-N-1 — planner を KPI Revise Mode で fresh spawn**:

```
MODE: KPI
Revise Mode.

PREVIOUS KPI PATH: {KPI_PATH}

FIX INSTRUCTIONS:
（Round N-1 の spec-reviewer から集約した Fix Instructions を全文貼り付ける）

指示:
- 前 KPI.md を Read して既存内容を確認する
- Fix Instructions に従って該当箇所のみ Edit で修正する
- ゼロから再生成はしない
- 同じパスに Write で上書き保存
- 変更サマリーを short list で返す
```

**Step 0-N-2 — spec-reviewer(KPI Mode) 再 spawn**: Step 0-1-2 と同じ手順。

**Step 0-N-3 — 判定**:
- OK → **Stage 0 - Step 0-G: HITL 承認ゲート へ**
- NEEDS_FIX かつ N < 3 → **Stage 0 - Round N+1 へ**
- NEEDS_FIX かつ N == 3 → **Step 5 (エスカレーション) へ**

#### Step 0-G: Stage 0 承認ゲート (HITL)

Stage 0 収束後、次 Stage に進む前にユーザー確認を取る:

```
✅ Stage 0 (KPI) 収束しました (Round {N}/3)

📄 KPI: {KPI_PATH}

主要な Success Metrics:
- {metric 1}
- {metric 2}
- {metric 3}

主要な Exit Criteria:
- {撤退条件 1}
- {撤退条件 2}

Non-Goals:
- {やらないこと 1}
- {やらないこと 2}

この KPI で Stage 1 (Spec 生成) に進んでよろしいですか？
(修正したい場合は具体的な指示をください)
```

ユーザー承認を得てから Stage 1 へ。

---

## Stage 1: Spec/Flow 収束ループ

**目的**: Stage 0 の KPI を達成する Feature 群と画面遷移を定義する。

#### Round 1: 初回生成

**Step 1-1 — planner(Spec Mode) を fresh spawn**:

Agent ツールで `subagent_type: planner` を呼ぶ。prompt には以下を含める:

```
MODE: SPEC

以下の要求から Product Spec を生成せよ。KPI.md が既に承認済みなので、Feature は KPI Success Metrics を達成する手段として定義すること:

$ARGUMENTS

## KPI Reference
KPI_PATH: {KPI_PATH}
→ Read してから Feature 定義を始めること。KPI と矛盾する Feature は書かない。

## Workflow Context（agent-core pipeline）

あなたは TDD 駆動パイプラインの Phase 0 を担当する。全体構造:
- Phase 0（あなた）: 設計 + HTML screens
- 内側ループ: TDD cycle（unit / integration のみ）
- 外側ループ: /e2e-evaluate → acceptance-tester が agent-browser / mobile-mcp / Bash で E2E 実行

### スコープ境界（厳守）
- Implementation Checklist の "Write test" は **unit / integration のみ**
- E2E / Playwright / Cypress / Puppeteer / Selenium / ブラウザ自動化 / Acceptance test 環境構築を checklist に含めない
- 具体的なテストフレームワーク名を spec に書かない
- 既存プロジェクトに Playwright 等の設定があっても引きずられない（agent-core のワークフローが優先）
- 違反すると後段 spec-reviewer が Critical NEEDS_FIX で差し戻す

詳細は planner.md の Workflow Awareness セクションを参照せよ。

## 必須要件
- Product Spec を `.agent-core/specs/{slug}-spec.md` に Write で保存する
  （slug は App Name の kebab-case 変換）
- UI アプリと判定されたら `.agent-core/specs/{slug}-flow.md` も生成する（planner.md の Flow.md 生成ルール参照）
- UI アプリでなければ Flow.md は生成しない
- 保存後、以下を返す:
  - SPEC_PATH: 保存先のフルパス
  - FLOW_PATH: 保存先のフルパス（UI アプリの場合のみ）
  - IS_UI_APP: true / false
```

planner の返答から `SPEC_PATH` / `FLOW_PATH` / `IS_UI_APP` を抽出する。

**Step 1-2 — 並列レビュー spawn（同一メッセージ内で2つの Agent call）**:

単一のメッセージで**2つの Agent ツール call を並列発行**せよ:

1. Agent(`subagent_type: spec-reviewer`, prompt: `以下の spec をレビューせよ: {SPEC_PATH}`)
2. Agent(`subagent_type: flow-reviewer`, prompt: `以下の flow をレビューせよ: {FLOW_PATH}（存在しない場合は SKIPPED を返せ）。対応する spec も参照: {SPEC_PATH}`)

**重要**: この2つは**必ず同一メッセージ内**で発行せよ。別々のメッセージで逐次に呼んではならない（並列性が失われる）。

**Step 1-3 — 判定集約**:

両 reviewer の出力から以下のみ抽出（本文は読み捨て）:
- `Judgment` 行（OK / NEEDS_FIX / SKIPPED）
- `Issues` セクションの要約（Critical/Important のみ）
- `### Fix Instructions (for planner)` セクションの全文

判定ロジック:
- `spec: OK` AND (`flow: OK` OR `flow: SKIPPED`) → **収束成功 → Step 4 へ**
- いずれかが `NEEDS_FIX` → Fix Instructions を集約 → **Round 2 へ**

---

#### Round 2 / Round 3: Revise Mode

**Step 2-1 — planner を Revise Mode で fresh spawn**:

Agent ツールで新規に `subagent_type: planner` を呼ぶ（前ラウンドと同じ subagent でも内部的には新規 context）。prompt には以下を含める:

```
Revise Mode.

PREVIOUS SPEC PATH: {SPEC_PATH}
PREVIOUS FLOW PATH: {FLOW_PATH}（UI アプリの場合）

FIX INSTRUCTIONS:
（Round N-1 の spec-reviewer と flow-reviewer から集約した Fix Instructions を全文貼り付ける）

## Workflow Context Reminder

Phase 0 のスコープ境界を再確認せよ:
- Implementation Checklist の "Write test" は unit / integration のみ
- E2E / Playwright / Cypress / ブラウザ自動化 / Acceptance test を含めない
- 外側ループ（/e2e-evaluate → acceptance-tester）が agent-browser 等で E2E 実行する
- 詳細は planner.md の Workflow Awareness セクション

指示:
- 前 spec / 前 flow を Read して既存内容を確認する
- Fix Instructions に従って該当箇所のみ Edit で修正する
- ゼロから再生成はしない
- 指摘されていない箇所は変更しない
- 同じパスに Write で上書き保存
- 変更サマリー（どの Fix Instruction をどう反映したか）を short list で返す
```

**Step 2-2 — 並列レビュー spawn**: Round 1 Step 1-2 と同じ手順で spec-reviewer と flow-reviewer を並列 spawn。

**Step 2-3 — 判定集約**:
- 収束成功 → **Step 1-G: Stage 1 HITL ゲートへ**
- NEEDS_FIX AND ラウンド N < 3 → **Round N+1 へ**
- NEEDS_FIX AND ラウンド N == 3 → **Step 5（エスカレーション）へ**

#### Step 1-G: Stage 1 承認ゲート (HITL)

Stage 1 収束後、Stage 2 (Story) に進む前にユーザー確認:

```
✅ Stage 1 (Spec/Flow) 収束しました (Round {N}/3)

📄 Spec: {SPEC_PATH}
🔀 Flow: {FLOW_PATH} (UI アプリの場合)

主要 Feature:
- {Feature 1 name}
- {Feature 2 name}
- {Feature 3 name}

この Spec で Stage 2 (Story 分割) に進んでよろしいですか？
```

ユーザー承認を得てから Stage 2 へ。

---

## Stage 2: Story 収束ループ

**目的**: Spec の Feature を **Value 単位の Story** に再集約する。各 Story は 3-10 sprint 規模、lazy ticket 化の単位となる。

#### Stage 2 - Round 1: 初回生成

**Step 2S-1-1 — planner(Story Mode) を fresh spawn**:

```
MODE: STORY

前段 KPI と Spec を参照して、Feature を Value 単位の Story に再集約せよ:

KPI_PATH: {KPI_PATH}
SPEC_PATH: {SPEC_PATH}
FLOW_PATH: {FLOW_PATH} (存在する場合)

## 指示
- KPI.md と spec.md を Read して前提を把握
- planner.md の `## Story Mode` セクションに従って story.md を生成
- 各 Story は 3-10 sprint 規模、KPI Contribution を必須記載
- Story → Feature Mapping 表を末尾に付ける
- `.agent-core/specs/{slug}-story.md` に Write で保存し、STORY_PATH を返せ
```

planner の返答から `STORY_PATH` を抽出する。

**Step 2S-1-2 — 並列レビュー spawn (spec-reviewer Story Mode + flow-reviewer Story Mode)**:

単一メッセージで 2 つの Agent call を並列発行:

1. Agent(`subagent_type: spec-reviewer`, prompt: `MODE: STORY\n\n story.md をレビューせよ: {STORY_PATH}\nKPI_PATH: {KPI_PATH}\nSPEC_PATH: {SPEC_PATH}\n\nspec-reviewer.md の Story Mode Rules に従え (STORY-1 〜 STORY-6)。\n\n※ sprint は 1 PR 相当の作業単位であり時間枠ではない。sprint × 週 / sprint × 日 等の時間換算を根拠にした NEEDS_FIX は Anti-Bias 違反として自動却下される (詳細は spec-reviewer.md の Sprint セマンティクス防衛セクション参照)。`)
2. Agent(`subagent_type: flow-reviewer`, prompt: `MODE: STORY\n\n story.md の依存 DAG をレビューせよ: {STORY_PATH}\nKPI_PATH: {KPI_PATH}\nSPEC_PATH: {SPEC_PATH}\n\nflow-reviewer.md の Story Mode Rules に従え (STORY-DAG-1 〜 STORY-DAG-5)。\n\n※ sprint は 1 PR 相当の作業単位であり時間枠ではない。sprint × 週 / sprint × 日 等の時間換算を根拠にした NEEDS_FIX は Anti-Bias 違反として自動却下される (詳細は flow-reviewer.md の Sprint セマンティクス防衛セクション参照)。`)

**Step 2S-1-3 — 判定集約**:

両 reviewer の Judgment / Issues / Fix Instructions を抽出:
- 両方 `OK` → **Step 2S-G: Stage 2 HITL ゲートへ**
- いずれか `NEEDS_FIX` → Fix Instructions 集約 → **Stage 2 - Round 2 へ**

#### Stage 2 - Round 2 / Round 3: Revise Mode

**Step 2S-N-1 — planner(Story Mode) を Revise で fresh spawn**:

```
MODE: STORY
Revise Mode.

PREVIOUS STORY PATH: {STORY_PATH}
KPI_PATH: {KPI_PATH}
SPEC_PATH: {SPEC_PATH}

FIX INSTRUCTIONS:
（Round N-1 の spec-reviewer + flow-reviewer から集約した Fix Instructions を全文貼り付ける）

指示:
- 前 story.md を Read
- Fix Instructions に従って該当箇所のみ Edit
- 循環依存を発生させない
- 同じパスに上書き保存
- 変更サマリーを返す
```

**Step 2S-N-2 — 並列レビュー spawn**: Step 2S-1-2 と同じ手順。

**Step 2S-N-3 — 判定**:
- 両方 OK → **Step 2S-G: Stage 2 HITL ゲートへ**
- NEEDS_FIX かつ N < 3 → **Stage 2 - Round N+1 へ**
- NEEDS_FIX かつ N == 3 → **Step 5 (エスカレーション) へ**

#### Step 2S-G: Stage 2 承認ゲート (HITL)

```
✅ Stage 2 (Story) 収束しました (Round {N}/3)

📄 Story: {STORY_PATH}

Story 一覧:
- S-01: {Story 1 title} ({expected_sprints} sprint, depends on: none)
- S-02: {Story 2 title} ({expected_sprints} sprint, depends on: S-01)
- S-03: {Story 3 title} ({expected_sprints} sprint, depends on: S-01)

推奨実行順序:
1. S-01 → 2. S-02 (or S-03 parallel) → 3. S-03

この Story 分割で Stage 3 (UI design) に進んでよろしいですか？
(UI アプリでない場合は Stage 3 をスキップして承認ゲートへ)
```

ユーザー承認を得てから Stage 3 (UI) へ、または IS_UI_APP=false なら Step 4 へ。

---

## Stage 3: UI Design 収束ループ（UI アプリのみ）

**前提**: Stage 0/1/2 が全て収束成功 AND `IS_UI_APP=true` AND `FLOW_PATH` が存在する場合のみ実行。それ以外（CLI/API/ライブラリ）は **Stage 3 全体をスキップ**して Step 4 へ進む。

`SCREENS_DIR` を `${SPEC_PATH%-spec.md}-screens` で導出（例: `.agent-core/specs/todo-spec.md` → `.agent-core/specs/todo-screens`）。

#### Stage 3 - Round 1: HTML 初回生成

**Step S2-1-1 — ui-designer を fresh spawn**:

Agent ツールで `subagent_type: ui-designer` を呼ぶ。prompt に以下を含める:

```
Initial Mode (IS_REVISE_MODE=false)

SPEC_PATH: {SPEC_PATH}
FLOW_PATH: {FLOW_PATH}
SCREENS_DIR: {SCREENS_DIR}

## Workflow Context

あなたは agent-core の Phase 0 Stage 3。screens HTML は**構造リファレンスのみ**で、視覚デザインでもテスト対象でもない。後段 acceptance-tester（外側ループ）は agent-browser / mobile-mcp / Bash で独立に E2E 実行する。

スコープ境界（厳守）:
- テストフレームワーク（Playwright / Cypress / Testing Library 等）の <script> や import を HTML に入れない
- data-testid / data-cy / data-test 等のテスト用属性を付けない
- HTML コメントに E2E 手順を書かない
- Tailwind CDN + Mermaid CDN + 状態切替 inline script 以外の外部 script を追加しない
- 既存プロジェクトに Playwright 等の設定があっても引きずられない

詳細は ui-designer.md の Workflow Awareness セクションを参照せよ。

指示:
- spec.md と flow.md を Read で読む
- flow.md の全画面ノードに対応する HTML を {SCREENS_DIR} に Write
- {SCREENS_DIR}/index.html も Write（目次 + Mermaid 埋込）
- ui-designer.md の HTML 制約（Tailwind layout-only / 装飾禁止 / セマンティック HTML）を厳守
- 完了後、生成ファイルのリストとサマリーを返す
```

ui-designer の返答からファイルリストを抽出。

**Step S2-1-2 — 決定論ゲート（リンク整合性 機械検証）**:

ui-design-reviewer を起動する前に、以下の `!` 構文ブロックをスキル経由で実行し、結果を reviewer プロンプトに埋め込む準備をする。**main Claude は以下のスクリプトを Bash ツールで実行**して結果を捕捉せよ:

```bash
SCREENS_DIR="{SCREENS_DIR}"
FLOW_PATH="{FLOW_PATH}"

echo "=== HTML Files ==="
ls "$SCREENS_DIR"/*.html 2>/dev/null

echo ""
echo "=== Broken Link Check ==="
if ls "$SCREENS_DIR"/*.html >/dev/null 2>&1; then
  grep -oh 'href="[^"]*\.html"' "$SCREENS_DIR"/*.html 2>/dev/null | sort -u | while read href; do
    target=$(echo "$href" | sed 's/href="//;s/"$//')
    # 相対パスは SCREENS_DIR からの相対として解決
    if [ ! -f "$SCREENS_DIR/$target" ]; then
      echo "BROKEN_LINK: $target"
    fi
  done
fi

echo ""
echo "=== Flow vs Screens Reconciliation ==="
# flow.md から画面ノードを抽出（kebab-case ID、Start/[*] を除く）
FLOW_NODES=$(grep -oE '[a-z][a-z0-9-]+' "$FLOW_PATH" 2>/dev/null | grep -v '^flowchart$\|^TD$\|^Start$' | sort -u)
# HTML ファイル名（拡張子なし、index 除く）
HTML_NODES=$(ls "$SCREENS_DIR"/*.html 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.html$//' | grep -v '^index$' | sort -u)

# flow にあるが HTML にない
comm -23 <(echo "$FLOW_NODES") <(echo "$HTML_NODES") 2>/dev/null | while read missing; do
  [ -n "$missing" ] && echo "MISSING_SCREEN: $missing"
done

# HTML にあるが flow にない
comm -13 <(echo "$FLOW_NODES") <(echo "$HTML_NODES") 2>/dev/null | while read extra; do
  [ -n "$extra" ] && echo "EXTRA_SCREEN: $extra"
done

echo ""
echo "=== Decoration Violation Pre-scan ==="
grep -nE 'class="[^"]*\b(bg-(red|blue|green|yellow|purple|pink|indigo|gray|slate|zinc|neutral|stone|orange|teal|cyan|sky|lime|emerald|amber|rose|fuchsia|violet)-[0-9]+|text-(red|blue|green|yellow|purple|pink|indigo|gray|slate|zinc|neutral|stone|orange|teal|cyan|sky|lime|emerald|amber|rose|fuchsia|violet)-[0-9]+|shadow-|hover:|focus:|animate-|transition-)' "$SCREENS_DIR"/*.html 2>/dev/null || echo "(none)"

grep -n 'style="' "$SCREENS_DIR"/*.html 2>/dev/null && echo "INLINE_STYLE_DETECTED" || true
```

スクリプト出力を `DETERMINISTIC_CHECK_RESULT` 変数に格納する（main がコンテキストに保持する）。

**Step S2-1-3 — ui-design-reviewer fresh spawn（単独）**:

Agent ツールで `subagent_type: ui-design-reviewer` を呼ぶ。prompt:

```
SCREENS_DIR: {SCREENS_DIR}
SPEC_PATH: {SPEC_PATH}
FLOW_PATH: {FLOW_PATH}

DETERMINISTIC_CHECK_RESULT:
{Step S2-1-2 で取得した出力をそのまま貼り付け}

指示:
- ui-design-reviewer.md の 8 評価軸で screens を評価せよ
- 決定論ゲートで既に検出された問題（BROKEN_LINK / MISSING_SCREEN / EXTRA_SCREEN / 装飾検出）を Issues に転記し、それ以上の人間的判断（情報階層・コンポーネント再利用・状態カバレッジ・ネイティブ警告）を加えよ
- Judgment + Issues + Fix Instructions を返せ
```

**Step S2-1-4 — 判定**:

ui-design-reviewer の出力から:
- `Judgment` 行
- `Issues` セクション要約
- `### Fix Instructions (for ui-designer)` セクション全文

判定ロジック:
- `OK` → Stage 3 脱出 → **Step 4 へ**
- `NEEDS_FIX` → Fix Instructions を集約 → **Stage 3 - Round 2 へ**
- `SKIPPED` → Stage 3 脱出（想定外だがエラー扱いせず Step 4 へ）

#### Stage 3 - Round 2 / Round 3: Revise Mode

**Step S2-N-1 — ui-designer を Revise Mode で fresh spawn**:

```
Revise Mode (IS_REVISE_MODE=true)

SPEC_PATH: {SPEC_PATH}
FLOW_PATH: {FLOW_PATH}
SCREENS_DIR: {SCREENS_DIR}

FIX_INSTRUCTIONS:
（Stage 3 - Round N-1 の ui-design-reviewer から集約した Fix Instructions を全文貼り付ける）

指示:
- 既存 HTML ファイルを Read で読む
- Fix Instructions に従って該当箇所のみ Edit で修正する
- 新規画面が必要なら追加 Write、不要画面があれば Bash rm
- ゼロから再生成は禁止
- 指摘されていない箇所は変更しない
- 修正サマリー（どの Fix Instruction をどう反映したか）を返せ
```

**Step S2-N-2 — 決定論ゲート再実行**: Step S2-1-2 と同じスクリプトを再実行し、新しい `DETERMINISTIC_CHECK_RESULT` を得る。

**Step S2-N-3 — ui-design-reviewer fresh spawn**: Step S2-1-3 と同じ手順で再起動。

**Step S2-N-4 — 判定**:
- OK → **Step 4 へ**
- NEEDS_FIX かつ N < 3 → **Stage 3 - Round N+1 へ**
- NEEDS_FIX かつ N == 3 → **Step 5（エスカレーション）へ**（Stage 3 専用エスカレーション）

---

#### Step 4 — 最終承認ゲート (全 Stage 収束完了)

4 Stage 全て収束した後、`/generate` に進む前に最終確認を取る:

```
✅ Phase 0 (設計) 完了しました

Stage 収束状況:
   Stage 0 (KPI):      Round {N0} / 3 ✅
   Stage 1 (Spec/Flow): Round {N1} / 3 ✅
   Stage 2 (Story):    Round {N2} / 3 ✅
   Stage 3 (UI Design): Round {N3} / 3 ✅ (UI アプリのみ / CLI/API なら "skipped")

📄 Artifacts:
   KPI:     {KPI_PATH}
   Spec:    {SPEC_PATH}
   Story:   {STORY_PATH}
   Flow:    {FLOW_PATH} (UI アプリのみ)
   Screens: {SCREENS_DIR}/index.html (UI アプリのみ)

📊 最終 judgment:
- Stage 0 spec-reviewer (KPI):   OK (Confidence: {level})
- Stage 1 spec-reviewer + flow-reviewer: OK
- Stage 2 spec-reviewer + flow-reviewer (Story): OK
- Stage 3 ui-design-reviewer:    OK / SKIPPED

🌐 ブラウザで触れる設計を確認 (UI アプリのみ):
   open {SCREENS_DIR}/index.html

📌 次のステップ:
   /generate S-01    ← 1 つ目の Story から Sprint Contract 交渉を開始
                       Ticket は 1 sprint ずつ lazy 生成されます

進めてよろしいですか？
```

**重要**:
- ユーザーの明示承認なしに `/generate` を自動実行してはならない
- CLI/API の場合は「ブラウザで触れる設計」セクションを省略する
- `/create-ticket` は呼ばない (lazy materialization のため)

---

#### Step 5 — エスカレーション（3ラウンドで収束せず）

どの Stage で収束失敗したかに応じて以下を提示する。**Stage 0 (KPI) または Stage 2 (Story) 失敗の場合も同様の形式**でユーザーに選択肢を提示すること (どの artifact で失敗したかを明示):

**Stage 0 (KPI) 失敗の場合**:
```
⚠️ Stage 0 (KPI) が 3 ラウンドで収束しませんでした。

📄 最終 KPI: {KPI_PATH}

📊 全ラウンド history:
- Round 1: {spec-reviewer judgment}
- Round 2: {spec-reviewer judgment}
- Round 3: {spec-reviewer judgment}

❌ 未解決の指摘 (Round 3 最終):
{spec-reviewer Issues (KPI-1 〜 KPI-5 のどれで失敗したか)}

選択肢:
1. KPI.md を手動で修正する → 再度 /planning で Stage 0 から
2. 追加の修正指示をもらって再ループ
3. 現状で承認し Stage 1 に進む (自己責任)
4. 中止する

どれにしますか？
```

**Stage 1 失敗の場合**:
```
⚠️ Stage 1 (spec/flow) が 3 ラウンドで収束しませんでした。

📄 最終 Spec: {SPEC_PATH}
🔀 最終 Flow: {FLOW_PATH}

📊 全ラウンド history:
- Round 1: {spec judgment}, {flow judgment}
- Round 2: {spec judgment}, {flow judgment}
- Round 3: {spec judgment}, {flow judgment}

❌ 未解決の指摘（Round 3 最終）:
{spec-reviewer Issues の Critical/Important}
{flow-reviewer Issues の Critical/Important}

選択肢:
1. spec / flow を手動で修正する → その後 `/plan-review` で再検証
2. 追加の修正指示をもらって再度 /planning でループを回す
3. 現状で承認し Stage 2 に進む（自己責任）
4. 中止する

どれにしますか？
```

**Stage 2 (Story) 失敗の場合**:
```
⚠️ Stage 2 (Story) が 3 ラウンドで収束しませんでした。
※ Stage 0/1 (KPI/Spec) は収束済みです。

📄 KPI: {KPI_PATH} ✅
📄 Spec: {SPEC_PATH} ✅
📄 Story: {STORY_PATH} ❌

📊 全ラウンド history:
- Round 1: {spec-reviewer + flow-reviewer judgment}
- Round 2: {judgment}
- Round 3: {judgment}

❌ 未解決の指摘 (Round 3 最終):
{Story Mode Issues (STORY-1〜STORY-6 / STORY-DAG-1〜STORY-DAG-5 のどれで失敗したか)}

選択肢:
1. Story.md を手動で修正する → `/plan-review` で再検証
2. 追加の修正指示をもらって Stage 2 を再ループ
3. 現状で承認し Stage 3 (UI) もしくは最終承認ゲートへ進む (自己責任)
4. 中止する

どれにしますか？
```

**Stage 3 (UI design) 失敗の場合**:
```
⚠️ Stage 3 (UI design) が 3 ラウンドで収束しませんでした。
※ Stage 0/1/2 (KPI/Spec/Story) は収束済みです。

📄 KPI: {KPI_PATH} ✅
📄 Spec: {SPEC_PATH} ✅
📄 Story: {STORY_PATH} ✅
🔀 Flow: {FLOW_PATH} ✅
🎨 Screens: {SCREENS_DIR}/ ❌

📊 Stage 3 全ラウンド history:
- Round 1: {ui-design judgment}
- Round 2: {ui-design judgment}
- Round 3: {ui-design judgment}

❌ 未解決の指摘（Round 3 最終）:
{ui-design-reviewer Issues の Critical/Important}

選択肢:
1. screens を手動修正 → `/plan-review` で再検証
2. 追加の修正指示をもらって Stage 3 を再ループ
3. 現状で承認し /generate に進む（自己責任）
4. screens を破棄して KPI/Spec/Story だけで /generate に進む
5. 中止する

どれにしますか？
```

---

### ファイル保存ルール

| Artifact | パス | 責務 | Stage |
|----------|------|------|-------|
| KPI | `.agent-core/specs/{slug}-kpi.md` | planner(KPI Mode) | 0 |
| Spec | `.agent-core/specs/{slug}-spec.md` | planner(Spec Mode) | 1 |
| Flow | `.agent-core/specs/{slug}-flow.md`（UI アプリのみ） | planner(Spec Mode) | 1 |
| Story | `.agent-core/specs/{slug}-story.md` | planner(Story Mode) | 2 |
| Screens dir | `.agent-core/specs/{slug}-screens/` | ui-designer | 3 |
| Index | `.agent-core/specs/{slug}-screens/index.html` | ui-designer | 3 |
| Per-screen HTML | `.agent-core/specs/{slug}-screens/{screen-id}.html` | ui-designer | 3 |

- slug: App Name を kebab-case に変換（小文字、記号は `-` に）
- 同名ファイルが既存でも上書き確認なし（Revise Mode 前提）
- ラウンドごとのスナップショットは保存しない（git 履歴で追跡可）

### コンテキスト肥大化対策（main の責務）

各ラウンドで main context に保持するもの:
- ✅ KPI_PATH / SPEC_PATH / FLOW_PATH / STORY_PATH / SCREENS_DIR（文字列）
- ✅ 各 reviewer の Judgment 行
- ✅ 各 reviewer の Fix Instructions セクション
- ✅ DETERMINISTIC_CHECK_RESULT（Stage 3 のリンク整合性チェック出力）
- ❌ KPI / Spec / Story / flow / HTML 本文（agent が Read で読むのでディスク経由、main は保持不要）
- ❌ reviewer 出力の冗長セクション（Anti-Bias 説明部分等）

4 Stage 計 12 ラウンドまで走らせても main の追加使用量を 40k tokens 以内に抑える。

---

## Next

→ ユーザー承認後: `/generate S-01` で 1 つ目の Story から Sprint Contract 交渉を開始
   - Ticket は Sprint Contract 合意時に 1 つずつ lazy 生成される
   - `/generate --dry-run S-01` で Sprint Contract 提案 + tier 判定のみ確認可能
→ Story 完了後: 次 Story へ (`/generate S-02`)
→ 全 Story 完了後: `/e2e-evaluate` で受け入れテスト
→ team 共有時 (opt-in): `/ticket-publish <T-ID>` → `/pr-description` → `/pr-review`

手動で各 doc を再レビューしたい場合: `/plan-review {PATH}` （収束ループなしでレビューのみ）

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
