---
name: planning
description: "アプリ開発の起点。ユーザーの要求から Product Spec + Flow.md + クリッカブル HTML screens を生成し、二段階収束ループ（Stage 1: spec/flow 並列レビュー / Stage 2: UI design レビュー、各最大3ラウンド）でレビュー収束させる。ユーザー承認後に Issue 化へ進む。Trigger: アプリ作って, 〜を作りたい, 設計して, spec, 仕様"
disable-model-invocation: false
---

## Planning — Spec 生成 + 二段階収束レビューループ

### ユーザーの要求

$ARGUMENTS

---

### 決定論ゲート（スキルローダー実行）

specs ディレクトリ確保: !`mkdir -p .agent-core/specs && echo "ready"`

---

### 指示（main Claude orchestrator 版）

あなたは `/planning` の orchestrator です。以下の**二段階収束ループ**を実行せよ。

**全体構造**:
- **Stage 1**: spec.md + flow.md の収束（最大 3 ラウンド、spec-reviewer + flow-reviewer 並列）
- **Stage 2**: HTML screens の収束（最大 3 ラウンド、ui-designer + ui-design-reviewer、UI アプリのみ）
- 両 Stage 完了 → ユーザー承認ゲート → `/create-issue`

**重要原則（両 Stage 共通）**:
- 各ラウンドの全 agent は必ず**新規 Agent コール**で spawn する（kill-and-spawn / fresh context）
- Round 2 以降の planner / ui-designer は `Revise Mode` で起動（既存ファイルを差分修正）
- 並列可能な reviewer は**同一メッセージ内で並列 spawn**（Agent ツールを1メッセージで複数 call）
- main context を肥大させないため、各 agent 出力から必要な要素のみ抽出する（artifact 本文は保持せずパスのみ）

---

## Stage 1: Spec/Flow 収束ループ

#### Round 1: 初回生成

**Step 1-1 — planner を fresh spawn**:

Agent ツールで `subagent_type: planner` を呼ぶ。prompt には以下を含める:

```
以下の要求から Product Spec を生成せよ:

$ARGUMENTS

必須要件:
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
- 収束成功 → **Stage 2 へ**（IS_UI_APP=true）または **Step 4 へ**（IS_UI_APP=false）
- NEEDS_FIX AND ラウンド N < 3 → **Round N+1 へ**
- NEEDS_FIX AND ラウンド N == 3 → **Step 5（エスカレーション）へ**

---

## Stage 2: UI Design 収束ループ（UI アプリのみ）

**前提**: Stage 1 が収束成功 AND `IS_UI_APP=true` AND `FLOW_PATH` が存在する場合のみ実行。それ以外（CLI/API/ライブラリ）は **Stage 2 全体をスキップ**して Step 4 へ進む。

`SCREENS_DIR` を `${SPEC_PATH%-spec.md}-screens` で導出（例: `.agent-core/specs/todo-spec.md` → `.agent-core/specs/todo-screens`）。

#### Stage 2 - Round 1: HTML 初回生成

**Step S2-1-1 — ui-designer を fresh spawn**:

Agent ツールで `subagent_type: ui-designer` を呼ぶ。prompt に以下を含める:

```
Initial Mode (IS_REVISE_MODE=false)

SPEC_PATH: {SPEC_PATH}
FLOW_PATH: {FLOW_PATH}
SCREENS_DIR: {SCREENS_DIR}

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
- `OK` → Stage 2 脱出 → **Step 4 へ**
- `NEEDS_FIX` → Fix Instructions を集約 → **Stage 2 - Round 2 へ**
- `SKIPPED` → Stage 2 脱出（想定外だがエラー扱いせず Step 4 へ）

#### Stage 2 - Round 2 / Round 3: Revise Mode

**Step S2-N-1 — ui-designer を Revise Mode で fresh spawn**:

```
Revise Mode (IS_REVISE_MODE=true)

SPEC_PATH: {SPEC_PATH}
FLOW_PATH: {FLOW_PATH}
SCREENS_DIR: {SCREENS_DIR}

FIX_INSTRUCTIONS:
（Stage 2 - Round N-1 の ui-design-reviewer から集約した Fix Instructions を全文貼り付ける）

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
- NEEDS_FIX かつ N < 3 → **Stage 2 - Round N+1 へ**
- NEEDS_FIX かつ N == 3 → **Step 5（エスカレーション）へ**（Stage 2 専用エスカレーション）

---

#### Step 4 — ユーザー承認ゲート（収束成功）

以下を提示してユーザーに確認を取る:

```
✅ レビュー収束しました
   Stage 1 (spec/flow): Round {N1} / 3
   Stage 2 (UI design): Round {N2} / 3 （UI アプリのみ / CLI/API なら "skipped"）

📄 Spec: {SPEC_PATH}
🔀 Flow: {FLOW_PATH} （UI アプリのみ / CLI/API 時は "N/A（CLI/API アプリ）"）
🎨 Screens: {SCREENS_DIR}/index.html （UI アプリのみ）

📊 最終 judgment:
- spec-reviewer: OK (Confidence: {level})
- flow-reviewer: OK / SKIPPED (Confidence: {level})
- ui-design-reviewer: OK / SKIPPED (Confidence: {level})

🌐 ブラウザで触れる spec を確認:
   open {SCREENS_DIR}/index.html
   （macOS / Linux なら xdg-open / Windows なら start）
   ※ UI アプリの場合のみ。クリックで画面間を遷移して導線を体感してください

次のステップ: `/create-issue {SPEC_PATH}` で Phase 1 の Feature を Issue 化します。

進めてよろしいですか？
```

**重要**: ユーザーの明示承認なしに `/create-issue` を自動実行してはならない。CLI/API の場合は「ブラウザで触れる spec」セクションを省略する。

---

#### Step 5 — エスカレーション（3ラウンドで収束せず）

どの Stage で収束失敗したかに応じて以下を提示する:

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

**Stage 2 失敗の場合**:
```
⚠️ Stage 2 (UI design) が 3 ラウンドで収束しませんでした。
※ Stage 1 (spec/flow) は収束済みです。

📄 Spec: {SPEC_PATH} ✅
🔀 Flow: {FLOW_PATH} ✅
🎨 Screens: {SCREENS_DIR}/ ❌

📊 Stage 2 全ラウンド history:
- Round 1: {ui-design judgment}
- Round 2: {ui-design judgment}
- Round 3: {ui-design judgment}

❌ 未解決の指摘（Round 3 最終）:
{ui-design-reviewer Issues の Critical/Important}

選択肢:
1. screens を手動修正 → `/plan-review` で再検証
2. 追加の修正指示をもらって Stage 2 を再ループ
3. 現状で承認し /create-issue に進む（自己責任）
4. screens を破棄して spec/flow だけで /create-issue に進む
5. 中止する

どれにしますか？
```

---

### ファイル保存ルール

| Artifact | パス | 責務 |
|----------|------|------|
| Spec | `.agent-core/specs/{slug}-spec.md` | planner |
| Flow | `.agent-core/specs/{slug}-flow.md`（UI アプリのみ） | planner |
| Screens dir | `.agent-core/specs/{slug}-screens/` | ui-designer |
| Index | `.agent-core/specs/{slug}-screens/index.html` | ui-designer |
| Per-screen HTML | `.agent-core/specs/{slug}-screens/{screen-id}.html` | ui-designer |

- slug: App Name を kebab-case に変換（小文字、記号は `-` に）
- 同名ファイルが既存でも上書き確認なし（Revise Mode 前提）
- ラウンドごとのスナップショットは保存しない（git 履歴で追跡可）

### コンテキスト肥大化対策（main の責務）

各ラウンドで main context に保持するもの:
- ✅ SPEC_PATH / FLOW_PATH / SCREENS_DIR（文字列）
- ✅ 各 reviewer の Judgment 行
- ✅ 各 reviewer の Fix Instructions セクション
- ✅ DETERMINISTIC_CHECK_RESULT（Stage 2 のリンク整合性チェック出力）
- ❌ spec / flow / HTML 本文（agent が Read で読むのでディスク経由、main は保持不要）
- ❌ reviewer 出力の冗長セクション（Anti-Bias 説明部分等）

両 Stage 計 6 ラウンドまで走らせても main の追加使用量を 25k tokens 以内に抑える。

---

## Next

→ ユーザー承認後: `/create-issue {SPEC_PATH}` で Phase 1 の Feature を一括 Issue 化
→ Issue 化後: `/tdd-cycle` で Implementation Checklist を1つずつ消化
→ 全機能完了後: `/e2e-evaluate` で受け入れテスト

手動で spec を再レビューしたい場合: `/plan-review {SPEC_PATH}` （収束ループなしでレビューのみ）
