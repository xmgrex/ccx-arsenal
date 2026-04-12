---
name: plan-review
description: "既存の spec.md / flow.md / screens (HTML) を spec-reviewer / flow-reviewer / ui-design-reviewer の並列スポーンでレビューする手動 re-review スキル。/planning の収束ループとは独立。手動編集後の再評価や他人の spec の評価に使う。Trigger - /plan-review, spec レビュー, plan review, スペック評価"
disable-model-invocation: false
---

# Plan Review — Spec と Flow を並列レビュー（スタンドアロン版）

## Usage

```
/plan-review                                      # .agent-core/specs/ の最新 Spec を自動検出
/plan-review .agent-core/specs/counter-app-spec.md  # 明示指定
```

このスキルは `/planning` の収束ループ内では使用しない（重複するため）。**手動 re-review** 用途専用:
- spec を手動編集した後にレビューだけ走らせたい
- 他人が書いた spec を評価したい
- ループ外でクイックチェックしたい

ユーザー承認ゲートは持たない（呼び出し元がループの場合は判定だけ返せばよく、手動呼び出しの場合もユーザーが結果を見て次の行動を自分で決める）。

---

## 決定論ゲート（スキルローダー実行）

```!
echo "=== Resolve Spec / Flow / Screens Paths ==="
ARGS="$ARGUMENTS"
if [ -n "$ARGS" ] && [ -f "$ARGS" ]; then
  SPEC_FILE="$ARGS"
else
  SPEC_FILE=$(ls -t .agent-core/specs/*-spec.md 2>/dev/null | head -1)
fi

if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
  echo "SPEC_RESOLVE_RESULT: NOT_FOUND"
  echo "ERROR: No spec file found. Run /planning first or pass an explicit path."
  exit 0
fi

echo "SPEC_RESOLVE_RESULT: OK"
echo "SPEC_FILE: $SPEC_FILE"

FLOW_FILE="${SPEC_FILE%-spec.md}-flow.md"
if [ -f "$FLOW_FILE" ]; then
  echo "FLOW_RESOLVE_RESULT: FOUND"
  echo "FLOW_FILE: $FLOW_FILE"
else
  echo "FLOW_RESOLVE_RESULT: NOT_FOUND"
  echo "FLOW_FILE: (no flow.md - CLI/API app or not yet generated)"
fi

SCREENS_DIR="${SPEC_FILE%-spec.md}-screens"
if [ -d "$SCREENS_DIR" ] && ls "$SCREENS_DIR"/*.html >/dev/null 2>&1; then
  echo "SCREENS_RESOLVE_RESULT: FOUND"
  echo "SCREENS_DIR: $SCREENS_DIR"
  echo "SCREENS_FILES: $(ls "$SCREENS_DIR"/*.html | wc -l | tr -d ' ') files"

  echo ""
  echo "=== Screens Deterministic Check ==="
  echo "--- Broken Link Check ---"
  grep -oh 'href="[^"]*\.html"' "$SCREENS_DIR"/*.html 2>/dev/null | sort -u | while read href; do
    target=$(echo "$href" | sed 's/href="//;s/"$//')
    if [ ! -f "$SCREENS_DIR/$target" ]; then
      echo "BROKEN_LINK: $target"
    fi
  done

  echo "--- Flow vs Screens Reconciliation ---"
  if [ -f "$FLOW_FILE" ]; then
    FLOW_NODES=$(grep -oE '[a-z][a-z0-9-]+' "$FLOW_FILE" 2>/dev/null | grep -vE '^(flowchart|TD|Start)$' | sort -u)
    HTML_NODES=$(ls "$SCREENS_DIR"/*.html 2>/dev/null | xargs -n1 basename | sed 's/\.html$//' | grep -v '^index$' | sort -u)
    comm -23 <(echo "$FLOW_NODES") <(echo "$HTML_NODES") 2>/dev/null | while read m; do
      [ -n "$m" ] && echo "MISSING_SCREEN: $m"
    done
    comm -13 <(echo "$FLOW_NODES") <(echo "$HTML_NODES") 2>/dev/null | while read e; do
      [ -n "$e" ] && echo "EXTRA_SCREEN: $e"
    done
  else
    echo "(flow.md not found, skipping reconciliation)"
  fi

  echo "--- Decoration Violation Pre-scan ---"
  grep -nE 'class="[^"]*\b(bg-(red|blue|green|yellow|purple|pink|indigo|gray|slate|zinc|neutral|stone|orange|teal|cyan|sky|lime|emerald|amber|rose|fuchsia|violet)-[0-9]+|text-(red|blue|green|yellow|purple|pink|indigo|gray|slate|zinc|neutral|stone|orange|teal|cyan|sky|lime|emerald|amber|rose|fuchsia|violet)-[0-9]+|shadow-|hover:|focus:|animate-|transition-)' "$SCREENS_DIR"/*.html 2>/dev/null || echo "(none)"
  grep -n 'style="' "$SCREENS_DIR"/*.html 2>/dev/null && echo "INLINE_STYLE_DETECTED" || true
else
  echo "SCREENS_RESOLVE_RESULT: NOT_FOUND"
  echo "SCREENS_DIR: (no screens dir - CLI/API app or no UI design layer)"
fi
```

---

## 指示

`SPEC_RESOLVE_RESULT: NOT_FOUND` が出ている場合は処理を即停止し、ユーザーに `/planning` を促す。

それ以外の場合、以下を実行せよ:

### Step 1 — 並列レビュー spawn（同一メッセージ内で 2 or 3 つの Agent call）

`SCREENS_RESOLVE_RESULT` の値で並列 spawn 数を決定:

- **`FOUND` の場合**: spec-reviewer + flow-reviewer + ui-design-reviewer の **3 体並列**
- **`NOT_FOUND` の場合**: spec-reviewer + flow-reviewer の **2 体並列**（従来通り）

単一のメッセージで Agent ツール call を必要数並列発行する。別々のメッセージで逐次に呼んではならない。

**3 体並列の場合**:

1. Agent(`subagent_type: spec-reviewer`, prompt: `以下の spec をレビューせよ: {SPEC_FILE}`)
2. Agent(`subagent_type: flow-reviewer`, prompt: `以下の flow をレビューせよ: {FLOW_FILE}（存在しない場合は SKIPPED）。対応する spec も参照: {SPEC_FILE}`)
3. Agent(`subagent_type: ui-design-reviewer`, prompt: `screens を評価せよ。SCREENS_DIR: {SCREENS_DIR}, SPEC_PATH: {SPEC_FILE}, FLOW_PATH: {FLOW_FILE}, DETERMINISTIC_CHECK_RESULT: 上記決定論ゲートの "Screens Deterministic Check" セクションをそのまま貼付`)

**2 体並列の場合**:

1. Agent(`subagent_type: spec-reviewer`, ...)
2. Agent(`subagent_type: flow-reviewer`, ...)

全 reviewer は read-only。

### Step 2 — 統合レポート出力

全 reviewer の出力から以下を抽出して統合レポートを生成:

```markdown
## Plan Review Report (standalone)

📄 Spec: {SPEC_FILE}
🔀 Flow: {FLOW_FILE or "N/A (CLI/API)"}
🎨 Screens: {SCREENS_DIR or "N/A (no UI design layer)"}

### Overall: OK / NEEDS_FIX

### Spec Review
- Judgment: {OK / NEEDS_FIX} (Confidence: {level})
- Issues: {Critical/Important のみ要約}

### Flow Review
- Judgment: {OK / NEEDS_FIX / SKIPPED} (Confidence: {level})
- Coverage: {N screens, M reachable, K orphaned, X/Y features covered}
- Issues: {Critical/Important のみ要約}

### UI Design Review (screens がある場合のみ)
- Judgment: {OK / NEEDS_FIX / SKIPPED} (Confidence: {level})
- Coverage: {N HTML files, broken links X, missing Y, extra Z, decoration violations W}
- Issues: {Critical/Important のみ要約}

### Fix Instructions（NEEDS_FIX の場合）
- For planner: {spec-reviewer / flow-reviewer の Fix Instructions を集約}
- For ui-designer: {ui-design-reviewer の Fix Instructions} （screens 存在時）
```

### Step 3 — 終了（ユーザー承認ゲートなし）

レポート出力後は終了する。`/create-issue` への自動誘導はしない。ユーザーが結果を見て次の行動（手動修正 / `/planning` 再ループ / `/create-issue` 進行）を自分で選ぶ。

---

## 原則

- **決定論ゲート優先**: spec/flow/screens パスの解決と存在確認、リンク整合性・装飾検出は `!` 構文で確定。失敗時は処理しない
- **kill-and-spawn**: 毎回 fresh spawn（再利用しない）
- **並列実行**: 2 or 3 reviewer を必ず同一メッセージで発行
- **ユーザー判断を奪わない**: 承認ゲートを持たないことで、ループ内でも単独でも使えるシンプルさを保つ

---

## Next

- NEEDS_FIX → spec/flow/screens を手動編集 or `/planning` で再ループ → `/plan-review` で再検証
- OK → `/create-issue {SPEC_FILE}` で Issue 化（screens がある場合は `open {SCREENS_DIR}/index.html` で視覚確認も推奨）
