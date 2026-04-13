---
name: pr-review
description: "PR コードレビュー（Level 3 決定論版）。!構文で PR データを取得 + サブプロセスで公式 code-review プラグインを試行 + 失敗時は ccx-arsenal の reviewer エージェント（Anti-Bias Rules 搭載）でフォールバック実行する。Trigger: PRレビュー, pr review, コードレビュー, PR確認"
context: fork
agent: reviewer
---

# PR Review — Level 3 決定論版

## Usage

```
/pr-review              # 現在のブランチの PR をレビュー
```

このスキルは `context: fork` で reviewer エージェントとして起動する。
スキル本文中の `!` 構文がスキルローダーによって機械的に展開され、PR 情報・diff・公式プラグイン試行結果が**全て事前注入された状態**で reviewer エージェントが起動する。

---

## PR Context（決定論：スキルローダーが実行）

PR Number: !`gh pr view --json number -q .number 2>/dev/null || echo "NO_PR"`

PR Title: !`gh pr view --json title -q .title 2>/dev/null || echo ""`

PR URL: !`gh pr view --json url -q .url 2>/dev/null || echo ""`

Head Branch: !`gh pr view --json headRefName -q .headRefName 2>/dev/null || echo ""`

Base Branch: !`gh pr view --json baseRefName -q .baseRefName 2>/dev/null || echo ""`

---

## Existing PR Comments（決定論：二重投稿チェック用）

```!
gh pr view --json comments -q '.comments[] | select(.body | contains("Code Review") or contains("Code review") or contains("code-review")) | "\(.author.login): \(.body | .[0:200])"' 2>/dev/null || echo "NO_COMMENTS_FOUND"
```

---

## PR Diff（決定論：スキルローダーが実行）

```!
gh pr diff 2>/dev/null || echo "ERROR: PR diff not available"
```

---

## 公式 code-review プラグインの試行（決定論：サブプロセス実行）

下記の `!` ブロックは、公式 `code-review@claude-plugins-official` プラグインがインストールされていれば呼び出してレビューを実行する。失敗時は `FALLBACK_TRIGGERED` を出力する。

```!
claude -p "/code-review" \
  --max-turns 10 \
  --max-budget-usd 1.00 \
  --permission-mode acceptEdits \
  2>&1 | head -300 || echo "FALLBACK_TRIGGERED: official code-review plugin not available or failed"
```

---

## Task

あなたは ccx-arsenal の reviewer エージェント（Anti-Bias Rules 搭載）です。
上記の決定論セクションで取得した情報を元に、以下の判定ロジックに従って動作してください。

### Step 1: PR 番号の確認

`PR Context` セクションの `PR Number` を確認:

- `NO_PR` であれば → 現在のブランチに PR が無い旨をユーザーに報告し、PR 番号を確認するか中止する
- 数字であれば → Step 2 へ

### Step 2: 公式プラグイン試行結果の判定

`公式 code-review プラグインの試行` セクションの出力を確認:

**フォールバック判定の基準:**
- `FALLBACK_TRIGGERED` を含む
- `Unknown command` を含む
- `command not found` を含む
- `code-review` プラグイン未インストールを示すメッセージ
- 出力が空、もしくは明らかにレビュー結果でないエラーログのみ

**フォールバック判定なら → Step 3 (フォールバックモード) へ**

**そうでなければ（公式プラグインが正常に実行された）:**
1. `Existing PR Comments` セクションを確認し、公式プラグインがコメント投稿していることを確認
2. ユーザーに「公式 code-review プラグインがレビューを完了しました」と報告
3. PR URL を提示して終了

### Step 3: フォールバックモード（ccx-arsenal reviewer による懐疑的レビュー）

公式プラグインが使えない場合、以下を実施せよ。

#### 3-1. Anti-Bias Rules を厳守してレビュー

`PR Diff` セクションの diff 内容を、以下の観点でレビューする:

1. **正しさ** — diff のロジックが目的を達成しているか
2. **セキュリティ** — OWASP Top 10（インジェクション、認証バイパス、データ露出、XSS、CSRF、安全でない依存）
3. **構造** — 責務分離、命名の一貫性、不要な複雑性
4. **エッジケース** — テストでカバーされていない危険なケース
5. **Defense-in-Depth** — 入力バリデーション、状態遷移の防御、環境設定の検証

**Anti-Bias Rules を厳守:**
- 「動いているから OK」と判断しない
- NEEDS_FIX を出すことを躊躇しない
- 疑わしきは NEEDS_FIX
- 実装量に同情しない
- 問題を見つけることが仕事

#### 3-2. 指摘のフィルタリング

PR コメント投稿対象は以下の条件を満たすもののみ:
- Severity: **Critical** または **Important**
- Confidence: **HIGH** または **MEDIUM**
- Minor 指摘や Confidence: LOW は除外（コメントの最後に「参考情報」として記載するのは可）

#### 3-3. 二重投稿チェック

`Existing PR Comments` セクションを確認:
- ccx-arsenal fallback コメントが既に存在する → ユーザーに既存コメントの存在を報告し、上書き投稿するか確認
- 公式 code-review プラグインのコメントが既に存在する → 二重投稿を避けるため投稿をスキップしてユーザーに報告

#### 3-4. ユーザー確認 → PR コメント投稿

投稿前に、ユーザーに以下を提示して確認を取る:
1. 検出した Critical / Important の指摘リスト
2. 投稿予定のコメント本文（下記テンプレート）

ユーザーの承認を得てから、以下のコマンドで PR にコメント投稿する:

```bash
gh pr review <PR Number> --comment --body "$(cat <<'EOF'
## Code Review — ccx-arsenal fallback

**Reviewed by**: `reviewer` agent (ccx-arsenal, Anti-Bias Rules enabled)
**Judgment**: NEEDS_FIX (Confidence: HIGH/MEDIUM)

### Issues Found

1. **[Critical]** \`path/to/file.ts:42\` — [指摘内容]
   → 修正案: [具体的な修正方向]

2. **[Important]** \`path/to/other.ts:77\` — [指摘内容]
   → 修正案: [具体的な修正方向]

---

*For full multi-agent review (4 parallel agents + confidence scoring), install:*
\`claude plugin install code-review@claude-plugins-official\`

🤖 Reviewed by [agent-core](https://github.com/xmgrex/ccx-arsenal) reviewer
EOF
)"
```

#### 3-5. OK 判定の場合

レビューの結果、Critical / Important の指摘が無い場合（NEEDS_FIX に該当しない）:
- PR コメント投稿はスキップ
- ユーザーに「レビュー完了。Critical / Important の指摘なし」と報告
- 任意で Minor 指摘や Confidence: LOW の参考情報をローカルで提示

---

## 原則

- **決定論ゲート優先**: PR 情報・diff・公式試行結果は `!` 構文で必ず取得済み。データ欠落は起こらない
- **公式プラグインが最優先**: 4エージェント並列 + 信頼度スコアリングは単一エージェントより堅牢
- **フォールバックは Anti-Bias Rules を活かす**: ccx-arsenal の reviewer エージェントの懐疑性を PR レビューに応用
- **投稿前に必ずユーザー確認**: PR への公開コメント投稿は blast radius が大きいため、内容確認を経てから投稿する
- **Critical / Important のみ投稿**: ノイズを避け、本当に重要な指摘だけを PR に残す
- **二重投稿を避ける**: 既存コメントを `Existing PR Comments` セクションで事前確認

## Attribution

このフォールバック実装の4エージェント並列 + 信頼度フィルタリングのアイデアは、公式 `code-review` プラグイン（Apache License 2.0、著者: Boris Cherny / Anthropic）の設計を参考にしている:

- 公式プラグイン: https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-review
- License: Apache License 2.0

ccx-arsenal のフォールバック実装はゼロから書かれた独自実装であり、公式プラグインのコード自体は複製していない。公式プラグインが利用可能な環境では常に公式が優先される。

## Next

→ 指摘された Critical / Important を修正 → 追加コミット → 再度 `/pr-review`
→ 全指摘が解消されたら → ユーザーレビュー → マージ

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
