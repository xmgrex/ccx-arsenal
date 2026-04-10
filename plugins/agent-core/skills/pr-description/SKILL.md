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

### 2. PR 作成

```bash
gh pr create --title "<summary>" --body "$(cat <<'EOF'
## Summary
<変更の目的と概要を 1-3 bullet points>

## Changes
<変更内容をファイル/機能単位で説明>

## Test Plan
- [ ] <テスト手順 1>
- [ ] <テスト手順 2>

## Review Guide
<レビュアーが確認すべきポイント>
- **特に見てほしい箇所**: <ファイル:行番号>
- **設計判断の背景**: <なぜこのアプローチを選んだか>

## Screenshots / Evidence
<該当する場合、スクリーンショットやテスト出力>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 3. CI 確認

PR 作成後、CI の状況を確認:

```bash
gh pr checks --watch    # CI の完了を待つ（タイムアウト付き）
```

CI が失敗した場合:
1. 失敗内容を確認（`gh pr checks`）
2. 修正して追加コミット
3. 再度 CI 確認

## 原則

- **タイトルは 70 文字以内** — 詳細は body に
- **Review Guide を必ず含める** — レビュアーが何を見るべきか、Claude Code が答える
- **全コミットの内容を反映** — 最新コミットだけでなく、PR に含まれる全変更をカバー
- **push 前にユーザー確認** — PR 作成は外部に影響するため、必ず確認を取る
