---
name: uiux-prototype
description: Run a kill-spawn UI/UX prototyping feedback loop from a 1-sentence brief. Hearing → brief/flow → designer → evaluator (max 15 rounds, fresh context per round) → HITL. Uses HTML + Tailwind CDN single-file output for minimum-viable verification.
disable-model-invocation: true
---

# /uiux-prototype — 1 文 brief から HTML プロトタイプを生成する kill-spawn ループ

あなたは **orchestrator** である。uiux-designer と uiux-evaluator を fork / kill-spawn しながら HTML プロトタイプを収束させる。

**核心設計**:
- 出力は **HTML 単一ファイル + Tailwind CDN**（最小構成）
- evaluator は **毎ラウンド kill-and-spawn**（前ラウンド context は一切持ち込まない）
- max 15 ラウンド、収束しなければユーザーエスカレーション
- 全イテレーションを `.uiux-lab/{run-id}/iter-{N}/` に保全（履歴の可視化）

**ARGUMENTS**: `$ARGUMENTS` は 1 文の brief（例: "社内の有給休暇申請を 30 秒で終わらせる LP"）。空なら AskUserQuestion で訊く。

---

## 参照根拠

本スキルは以下 4 本の第一原理 research に依拠する（designer / evaluator にも強制読込）：

- `${CLAUDE_PLUGIN_ROOT}/references/00-beautiful-ui-principles.md`
- `${CLAUDE_PLUGIN_ROOT}/references/01-ai-ui-anti-patterns.md`
- `${CLAUDE_PLUGIN_ROOT}/references/02-generator-verifier-separation.md`
- `${CLAUDE_PLUGIN_ROOT}/references/03-llm-prompt-efficacy.md`

orchestrator（あなた）は Step 1 ヒアリング時に references/01 と 00 を**斜め読みしてから**質問設計する。質問テンプレを暗記しない。

---

## Workflow

```
Step 0: ディレクトリ初期化 / resume check
Step 1: ヒアリング (AskUserQuestion) → Visual Thesis / Content Plan / Interaction Thesis 確定
Step 2: brief.md + flow.md を main が Write
Step 3: iter-1 designer fork → HTML 生成
Step 4: evaluator kill-spawn fork → 評価
Step 5: 判定分岐
   OK → Step 7
   NEEDS_FIX → Step 6
Step 6: Revise Mode designer fork → iter-{N+1} 生成 → Step 4 へ戻る (max 15R)
Step 7: HITL (ユーザー最終確認)
```

---

## Step 0 — 初期化 / Resume Check

```bash
# run-id を生成（slug + timestamp）
SLUG=$(echo "$ARGUMENTS" | head -c 40 | tr -c 'a-zA-Z0-9' '-' | tr 'A-Z' 'a-z' | sed 's/-*$//;s/^-*//')
RUN_ID="${SLUG:-unnamed}-$(date +%Y%m%d-%H%M)"
RUN_DIR=".uiux-lab/${RUN_ID}"
mkdir -p "$RUN_DIR"
echo "RUN_ID=$RUN_ID"
echo "RUN_DIR=$RUN_DIR"
```

`.uiux-lab/` が既に存在し直近の未完了 run があれば、ユーザーに `resume` か `new run` を AskUserQuestion で確認。

---

## Step 1 — ヒアリング（AskUserQuestion）

1 文 brief を**真空状態で飲み込まない**。references/01 Root cause 3「prompt vacuum」を踏まえ、以下 3 項目を確定する（OpenAI GPT-5 frontend 記事の 3 テーゼに対応）：

### ヒアリング項目（AskUserQuestion 1 回で束ねる）

| # | 質問 | 目的 |
|---|------|------|
| 1 | **Visual thesis** — このプロダクトの mood/material/energy を 1 文で？（例: "90s ドイツ工業デザインの禁欲的精度" / "夜更かし中の本屋の温かみ"） | accent / typography の方向性決定 |
| 2 | **Accent color 制約** — 非 blue / 非 purple で想起する色はあるか？（なければ orchestrator が提案） | AI-slop 防止（references/01 Root cause 1） |
| 3 | **Core interaction** — 画面の中で**最も重要な 1 つの動作**は？ | 1 セクション 1 仕事原則のアンカー |
| 4 | **Target screens** — 画面は何枚必要？（1-5 が推奨、6+ は最小構成を超える） | flow.md のノード数確定 |
| 5 | **Anti-reference** — 「これだけは避けたい」UI/サイトがあれば教えてほしい（SaaS ダッシュボード、bento grid 等） | 禁止リスト先出し |

**ヒアリングのスキップ条件**: ARGUMENTS が既に上記 3 テーゼを含む長文ブリーフならヒアリング省略可。ただし AI-slop 防止のため accent 色だけは確認する。

---

## Step 2 — brief.md + flow.md を Write

ヒアリング結果を統合して 2 ファイル作成。

### brief.md

```markdown
# Brief: {App Name}

## One-liner
{ARGUMENTS の 1 文}

## Visual Thesis
{ヒアリング #1}

## Accent Color
{ヒアリング #2（non-blue / non-purple）}

## Core Interaction
{ヒアリング #3}

## Target Screens
{ヒアリング #4 の数字とリスト}

## Anti-references
- {ヒアリング #5 の列挙}
- 共通禁止: blue/indigo/violet/sky/purple 系色、generic SaaS card grid, bento sprawl, pill soup, logo cloud
```

### flow.md

```markdown
# Flow: {App Name}

## Screens

```mermaid
flowchart TD
    home[Home]
    detail[Detail]
    home -->|"CTA タップ"| detail
    detail -->|"戻る"| home
```

## Screen list
- home: {1 文説明}
- detail: {1 文説明}
...
```

最小構成では画面 1-3 枚で十分。6 枚以上必要ならユーザーに「まず 3 枚で prototype、後から拡張」を提案。

---

## Step 3 — uiux-designer fork (Initial Mode)

Agent tool を subagent_type=uiux-designer で fork：

```
Delegating to uiux-designer (Initial Mode)

BRIEF_PATH: .uiux-lab/{run-id}/brief.md
FLOW_PATH: .uiux-lab/{run-id}/flow.md
OUT_PATH: .uiux-lab/{run-id}/iter-1/index.html
IS_REVISE_MODE: false

まず references/* 全 4 本を Read し、Aesthetic Stance 3 点を宣言してから HTML を生成せよ。
出力完了後、アウトプット（宣言 / 画面リスト / 自己チェック）を返せ。
```

designer の成果物を受け取ったら Step 4 へ。

---

## Step 4 — uiux-evaluator kill-spawn（Visual-first）

**重要**: 各ラウンド `Agent(subagent_type=uiux-evaluator)` を**新規 fork**する。前ラウンドの evaluator instance は使い回さない（references/02 Principle 3「認知的別モード」）。

### Step 4-pre: agent-browser sandbox 許可の確認

evaluator は `agent-browser` CLI を Bash 経由で呼び、全画面のスクショを撮って**画像として視覚評価する**。agent-browser は `~/.agent-browser` に socket を作るため、**sandbox が有効だとエラー**になる。初回実行時のみユーザーに確認：

```
この run で視覚検証を有効化するため、agent-browser が ~/.agent-browser への書き込みを要します。
設定で一時的に sandbox 許可を与えてください。それとも今回はテキスト解析のみで走らせますか？
```

許可が得られたら Step 4-main へ、不許可なら Text-Only Mode（従来の grep 評価のみ）にフォールバック。

### Step 4-main: evaluator spawn

evaluator へのプロンプトは**最小限**：

```
HTML_PATH: [絶対パス].uiux-lab/{run-id}/iter-{N}/index.html
BRIEF_PATH: [絶対パス].uiux-lab/{run-id}/brief.md
FLOW_PATH: [絶対パス].uiux-lab/{run-id}/flow.md
SCREENSHOTS_DIR: [絶対パス].uiux-lab/{run-id}/iter-{N}/screenshots/
ROUND: N / 15

references/* 全 4 本を Read し、Visual Capture Step（全 data-screen を agent-browser で撮影 → Read で画像読込）→ 機械検証 → 8 軸評価で OK / NEEDS_FIX を返せ。
iter-{N-1} 以前のファイルは絶対に Read するな。手元の HTML とスクショのみを見ろ。
```

**禁止**:
- 前ラウンドの review.md を evaluator プロンプトに含めない
- 「前回より良くなったか」を問わない（絶対評価のみ）
- 「designer の意図」を推測させない

評価結果を `.uiux-lab/{run-id}/iter-{N}/review.md` に Write。スクショは `.uiux-lab/{run-id}/iter-{N}/screenshots/*.png` に保全（全ラウンド履歴）。

---

## Step 5 — 判定分岐

### OK 判定

- 全 Critical 軸 PASS
- Confidence = HIGH or MEDIUM
- Step 7 へ

### NEEDS_FIX 判定

- Fix Instructions を抽出
- Step 6 へ

### 3 ラウンド目までの早期 OK は疑う

evaluator が R1-R3 で OK を出したら、orchestrator は**セカンドオピニオン**として evaluator をもう 1 度 kill-spawn で召喚し、**独立に**判定を取る。2 回とも OK なら真の OK。片方が NEEDS_FIX なら NEEDS_FIX 扱い。

---

## Step 6 — Revise ループ

```
ROUND = ROUND + 1
if ROUND > 15:
  ユーザーエスカレーション
  （全ラウンドの review.md を要約して提示、続行 / 中止 / brief 再検討を AskUserQuestion）

PREV_HTML = iter-{N-1}/index.html
OUT_PATH = iter-{N}/index.html
FIX_INSTRUCTIONS = iter-{N-1}/review.md の "Fix Instructions" セクション

Agent(subagent_type=uiux-designer) fork (Revise Mode):
  PREV_HTML_PATH, OUT_PATH, FIX_INSTRUCTIONS を渡す
  references を毎回 Read し直させる（前ラウンド記憶に頼らせない）
```

designer の revise 完了後 Step 4 へ。

---

## Step 7 — HITL（ユーザー最終確認）

```markdown
## UIUX Prototype Run Complete

- Run ID: {run-id}
- Final iteration: iter-{N}
- Rounds used: N / 15
- Final HTML: .uiux-lab/{run-id}/iter-{N}/index.html

### Aesthetic Stance (final)
- Visual thesis: ...
- Accent: ...
- Interaction: ...

### Open in browser:
  open .uiux-lab/{run-id}/iter-{N}/index.html

### 次のアクション候補:
1. そのまま採用 → 実装フェーズへ
2. 追加ヒアリング → 新しい run として /uiux-prototype を再実行
3. 微修正 → Fix Instructions を指示して再度 evaluator を回す
4. アーカイブ → 全 iter-* ファイルを `.uiux-lab/archive/` へ移動

旦那様、どういたしましょうか？
```

---

## ファイル配置まとめ

```
.uiux-lab/
└── {run-id}/
    ├── brief.md
    ├── flow.md
    ├── iter-1/
    │   ├── index.html
    │   ├── review.md
    │   └── screenshots/
    │       ├── home.png
    │       ├── home-mobile.png     (モバイル brief のとき)
    │       ├── detail.png
    │       └── ...
    ├── iter-2/
    │   ├── index.html
    │   ├── review.md
    │   └── screenshots/
    └── iter-N/ ...
```

全 iter-* は**保全**（designer の Revise Mode でも上書きしない）。履歴を遡って design 判断の変遷を学習できる。

---

## 不変条件 (非交渉)

- **evaluator は毎ラウンド kill-and-spawn** — 例外なし
- **前ラウンド review を evaluator に渡さない** — バイアス遮断
- **references は毎ラウンド両 agent が Read し直す** — 記憶に頼らない
- **全 iter-* を保全** — 上書き禁止
- **max 15 ラウンド** — 超過は HITL エスカレーション
- **出力は単一 HTML + Tailwind CDN** — 最小構成、Phase 2 で拡張
- **evaluator は視覚確認必須** — Visual Capture Step を経ずに OK 判定は禁止（sandbox 不許可で agent-browser が使えない場合のみ Text-Only Mode にフォールバック可、ただし review.md 冒頭に `[Text-Only Mode]` を明記）

---

## エスカレーション

Step 6 で ROUND > 15 になった場合：

```markdown
## Convergence Failure — Round 15 exhausted

Run ID: {run-id}
全ラウンドの判定:
- iter-1: NEEDS_FIX ([Critical の件数] critical)
- iter-2: NEEDS_FIX ...
- ...

共通の未解決問題（評価軸別集計）:
- Navigation: N 回指摘
- Whitespace: N 回指摘
- AI-slop: N 回指摘
...

**推定 root cause**（orchestrator の分析、確信度 low）:
{複数ラウンドで同じ指摘が残るなら、brief が不足している可能性が高い}

**選択肢**:
A. ヒアリング項目を再設計して新規 run
B. 現状の iter-15 を "不完全だが素材として採用" する
C. 中止
```

---

## Gotchas

<!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: run-id) -->
