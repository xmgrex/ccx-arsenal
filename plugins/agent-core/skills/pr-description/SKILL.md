---
name: pr-description
description: コミット履歴から PR を自動生成する。変更サマリー、テスト計画、レビュー観点を含む。
---

# PR Description — PR 自動生成

## Usage

```
/pr-description
/pr-description main
```

`$ARGUMENTS` でベースブランチを指定（デフォルト: main）。

## Workflow

### 1. 変更分析

```bash
git log main..HEAD --oneline       # コミット一覧
git diff main..HEAD --stat         # 変更ファイル統計
git diff main..HEAD                # 全差分
```

全コミットを読み、変更の全体像を把握する。

### 1.5 関連チケットの解決（agent-core 特有）

コミットメッセージから `Ticket: T-XXXX` trailer を探し、対応するローカル JSON チケットを解決する:

```bash
# コミット一覧から Ticket: trailer を抽出
TICKET_IDS=$(git log main..HEAD --format="%b" | grep -oE 'Ticket: T-[0-9]+' | awk '{print $2}' | sort -u)

# 各チケット JSON を読む
for tid in $TICKET_IDS; do
  if [ -f ".agent-core/tickets/${tid}.json" ]; then
    cat ".agent-core/tickets/${tid}.json"
  fi
done
```

各チケットについて:

- `github_issue_number` が set されていれば → PR 本文に `Fixes #<N>` を含める（GitHub 側で PR マージ時に issue 自動クローズ）
- `github_issue_number` が null → PR 本文に `Ticket: <T-ID>` のみ含める（ローカルチケット参照、GitHub には issue なし）

ブランチ名が `ticket-T-XXXX-...` パターンなら、そのチケット ID も別途確認する。

### 2. PR 作成

```bash
gh pr create --title "<summary>" --body "$(cat <<'EOF'
## この PR で何が変わるか（専門用語なし）

**変更前**: <ユーザーから見た現状の動作を日常語で>
**変更後**: <ユーザーから見た変更後の動作を日常語で>

## 関連チケット

<以下のいずれかを含める（Step 1.5 の解決結果に応じて）>

- publish 済みチケット: `Fixes #<github_issue_number>` （マージで自動クローズ）
- ローカルチケットのみ: `Ticket: <T-XXXX>` （GitHub issue 未作成、ローカル JSON が SoT）
- 該当チケットなし: このセクションを省略

## 設計判断（なぜこうしたか）

| やったこと | なぜ | 他の方法を使わなかった理由 |
|-----------|------|------------------------|
| <変更内容を平易に> | <目的> | <却下した代替案と理由> |

## 変更ファイル

<変更内容をファイル/機能単位で説明>

## テスト計画
- [ ] <テスト手順 1>
- [ ] <テスト手順 2>

## 特に見てほしい箇所
- `<ファイル:行番号>` — <何を確認してほしいか、なぜ重要か>

## リスク・気をつけること
- <この変更で起こりうる問題、調整が必要になりそうな点>

## スクリーンショット / 証拠
<該当する場合、スクリーンショットやテスト出力>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**テンプレートの原則:**
- **専門用語を避ける** — 「キャッシュ」ではなく「一時的な保存場所」、「バリデーション」ではなく「入力チェック」
- **変更前/変更後で説明** — コードの変更ではなく、ユーザー体験の変化を書く
- **判断理由を必ず書く** — 「なぜこうしたか」と「なぜ他の方法を使わなかったか」をセットで

### 3. CI 確認

PR 作成後、CI の状況を確認:

```bash
gh pr checks --watch    # CI の完了を待つ（タイムアウト付き）
```

CI が失敗した場合:
1. 失敗内容を確認（`gh pr checks`）
2. 修正して追加コミット
3. 再度 CI 確認

### 4. AI コードレビュー

```
/pr-review    # PR にレビューコメントを投稿
```

`/pr-review` は公式 `code-review` プラグイン（`anthropics/claude-plugins-official`）が利用可能であればそれに委譲し、未インストールの場合は ccx-arsenal の `reviewer` エージェント（Anti-Bias Rules 搭載）でフォールバック実行する。

**公式プラグインを推奨**（より堅牢な4エージェント並列レビュー + 信頼度スコアリング）:
```shell
claude plugin install code-review@claude-plugins-official
```

レビュー指摘への対応:
1. Critical な指摘 → 修正して追加コミット
2. 軽微な指摘 → ユーザー判断に委ねる

## 原則

- **タイトルは 70 文字以内** — 詳細は body に
- **Review Guide を必ず含める** — レビュアーが何を見るべきか、Claude Code が答える
- **全コミットの内容を反映** — 最新コミットだけでなく、PR に含まれる全変更をカバー
- **push 前にユーザー確認** — PR 作成は外部に影響するため、必ず確認を取る

## Next

→ ユーザーレビュー（実装内容・設計判断）& マージ

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
