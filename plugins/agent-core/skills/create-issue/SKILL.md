---
name: create-issue
description: Spec ファイル（.agent-core/specs/*-spec.md）から Phase 1 の Feature を読み取り、GitHub Issue を一括作成する。Trigger - "/create-issue", "issue 作成", "issue 化", "Feature を Issue に"
---

# Create Issue — Spec から Feature 単位で Issue 一括生成

## Usage

```
/create-issue                                      # .agent-core/specs/ の最新 Spec を自動検出
/create-issue .agent-core/specs/counter-app-spec.md  # 明示指定
```

## Workflow

### 1. Spec ファイルの特定（決定論ゲート：スキルローダーが実行）

下記のシェルブロックがスキル読み込み時に必ず実行され、`SPEC_FILE` が確定した状態で orchestrator が起動する。

```!
echo "=== Resolve Spec File ==="
ARGS="$ARGUMENTS"
if [ -n "$ARGS" ] && [ -f "$ARGS" ]; then
  SPEC_FILE="$ARGS"
else
  SPEC_FILE=$(ls -t .agent-core/specs/*-spec.md 2>/dev/null | head -1)
fi

if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
  echo "SPEC_RESOLVE_RESULT: NOT_FOUND"
  echo "ERROR: No spec file found. Run /planning first or pass an explicit path."
else
  echo "SPEC_RESOLVE_RESULT: OK"
  echo "SPEC_FILE: $SPEC_FILE"
fi
```

`SPEC_RESOLVE_RESULT: NOT_FOUND` が出た場合は処理を即停止し、ユーザーに `/planning` を促す。

### 2. Spec 読み込み & Feature 抽出

Read ツールで `$SPEC_FILE` の内容を読み、以下を行う：

1. `## Features` セクション配下の `### Feature N: <Name>` ブロックを全て抽出
2. 各 Feature から以下を取得：
   - **User Story** — `- **User Story**: ...` 行
   - **Acceptance Criteria** — `- **Acceptance Criteria**:` 配下のチェックボックス行
   - **Phase** — `- **Phase**: N` の値
3. **`Phase == 1` の Feature のみ**を Issue 化対象とする
4. 対応する `## Implementation Checklist` 内の `#### Feature N: <Name>` ブロックも取得

Phase 1 の Feature が 0 個だった場合は「Phase 1 Feature が見つかりませんでした」と報告して停止。

### 3. Issue 作成ループ

抽出した各 Feature について、Bash ツールで以下を順次実行する。Issue 本文は HEREDOC で渡す：

```bash
gh issue create \
  --title "feat: <Feature Name>" \
  --body "$(cat <<'EOF'
## 概要
<User Story>

## Acceptance Criteria
<Acceptance Criteria をそのままチェックボックスで列挙>

## Implementation Checklist
<Implementation Checklist の該当 Feature ブロックをそのまま転記>

## Spec Reference
`<SPEC_FILE のパス>` — Feature <N>: <Feature Name>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- 各 Issue 作成の成否を確認（gh の exit code）
- 作成された Issue 番号・URL を収集
- 途中で失敗しても残りの Feature は続行し、最後にまとめて報告

### 4. 結果サマリー

全 Feature の Issue 作成後、以下を会話に出力：

```
Created N issues from <SPEC_FILE>:
  - #<number> feat: <Feature 1 Name>  → <url>
  - #<number> feat: <Feature 2 Name>  → <url>
  ...
Skipped: <Phase 2+ の Feature 数> (Phase 2 以降)
Failed:  <失敗した Feature があれば列挙、無ければ "none">
```

## 原則

- **Spec ファイルが Single Source of Truth** — create-issue は Spec の忠実な Issue 化のみ担い、内容の再解釈や追加判断はしない
- **Phase 1 のみ対象** — Phase 2 以降は将来の拡張 or 手動対応
- **ブランチは作成しない** — ブランチ作成は `/tdd-cycle` 側の責務
- **Acceptance Criteria は Spec の記述をそのまま転記** — 「入力・操作・期待値」への変換は planner 側で完了している前提
- **1 Feature = 1 Issue** — Feature の粒度が大きすぎる場合は planner に戻って Spec を分割する

## Next

→ `/tdd-cycle` で各 Issue を順に実装（ブランチ作成もそちらで実施）
