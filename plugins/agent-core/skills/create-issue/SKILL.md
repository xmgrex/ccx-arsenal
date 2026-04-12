---
name: create-issue
description: タスクを GitHub Issue として構造化して作成する。設計・タスク分解の成果物を Issue に変換する。
---

# Create Issue — 構造化 Issue 作成

## Usage

```
/create-issue ユーザー認証機能の実装
/create-issue $ARGUMENTS
```

## Workflow

### 1. タスク分解

`$ARGUMENTS` の内容を分析し、実装可能な粒度に分解する:

- 各タスクは **1アクション**（2-5分の作業量）
- 依存順に並べる
- TDD サイクル（テスト作成→実装→検証）を各タスクに組み込む

### 2. Issue 作成

```bash
gh issue create \
  --title "<type>: <summary>" \
  --body "$(cat <<'EOF'
## 概要
<何を、なぜ実装するか>

## Acceptance Criteria

### AC-1: <名前>
- **入力**: <具体的な入力データ>
- **操作**: <何をするか>
- **期待値**: <何が起こるべきか>

### AC-2: <名前>
- **入力**: <具体的な入力データ>
- **操作**: <何をするか>
- **期待値**: <何が起こるべきか>

## Implementation Checklist
- [ ] Write test: <テスト内容>
- [ ] Run test → verify RED
- [ ] Implement: <実装内容>
- [ ] Run test → verify GREEN
- [ ] Commit: `feat: <summary>`

## Technical Notes
<アーキテクチャ判断、既存コードとの関連、注意点>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 3. ブランチ作成

Issue 番号からブランチを作成:

```bash
git switch -c <type>/issue-<number>-<short-description>
```

ブランチ名の例:
- `feat/issue-42-user-auth`
- `fix/issue-57-login-redirect`

## 原則

- **Acceptance Criteria は「入力・操作・期待値」の3点セットで書く** — 「〜できること」ではなく具体的に
- **1 Issue = 1つの論理的な変更単位** — 大きすぎる場合は分割
- **Implementation Checklist に TDD を埋め込む** — テスト→実装の順序を構造的に強制

## Next

→ `/tdd-cycle` で Implementation Checklist の各タスクを実装開始
