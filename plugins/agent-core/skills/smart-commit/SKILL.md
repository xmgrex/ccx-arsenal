---
name: smart-commit
description: コミット前にビルド・テスト・lintを検証し、構造化されたコミットメッセージで安全にコミットする。
---

# Smart Commit — 検証済みコミット

## Usage

```
/smart-commit
/smart-commit feat: ユーザー認証機能
```

## Workflow

### 1. Pre-commit Verification

コミット前に以下を**全て実行し、出力を確認**する:

```
検出した Stack に応じて実行:
├─ package.json  → npm test && npx tsc --noEmit (TSの場合)
├─ pubspec.yaml  → flutter analyze && flutter test
├─ Package.swift → swift build && swift test
├─ Cargo.toml   → cargo test
├─ go.mod       → go test ./...
└─ pyproject.toml → pytest
```

**1つでも失敗 → コミットしない。** 問題を修正してから再実行。

### 2. Diff Review

```bash
git diff --staged --stat    # 変更ファイル一覧
git diff --staged           # 変更内容の確認
```

確認項目:
- 意図しないファイルが含まれていないか
- デバッグコード（console.log, print, debugger）が残っていないか
- 機密情報（.env, credentials, API keys）が含まれていないか

### 3. Structured Commit

Conventional Commits 形式:

```
<type>: <summary>

<body（任意）>

Co-Authored-By: Claude Code <noreply@anthropic.com>
```

| Type | 用途 |
|------|------|
| feat | 新機能 |
| fix | バグ修正 |
| refactor | リファクタリング |
| test | テスト追加・修正 |
| docs | ドキュメント |
| chore | ビルド・設定変更 |

### 4. Post-commit Verification

```bash
git log --oneline -1    # コミットが正しく作成されたか確認
git status              # ワーキングツリーがクリーンか確認
```

## 原則

- **テストが通らないコードをコミットしない**
- **1コミット = 1つの論理的変更**（複数機能を1コミットに混ぜない）
- **コミットメッセージは "why" を書く**（"what" は diff でわかる）
- 機密ファイルは `git add` しない（.env, credentials 等）

## Next

→ 次の機能があれば `/tdd-cycle`、全機能完了なら `/e2e-evaluate` で E2E + デザイン評価
