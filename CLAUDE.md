# ccx-arsenal Development Guide

このファイルはClaude Codeへの指示書です。マーケットプレイスの構築・メンテナンス時に参照してください。

## プラグイン追加手順

### 1. メンバーディレクトリの作成

```bash
mkdir -p plugins/{member_name}/.claude-plugin
mkdir -p plugins/{member_name}/skills
```

### 2. plugin.json の作成

`plugins/{member_name}/.claude-plugin/plugin.json`:

```json
{
  "name": "{member_name}",
  "description": "Plugins by {member_name}",
  "version": "1.0.0",
  "author": {
    "name": "{member_name}"
  }
}
```

### 3. marketplace.json への登録

`.claude-plugin/marketplace.json` の `plugins` 配列に追加:

```json
{
  "name": "{member_name}",
  "source": "{member_name}",
  "description": "Plugins by {member_name}"
}
```

## スキル作成規則

### ファイル配置

```
plugins/{member_name}/skills/{skill-name}/SKILL.md
```

### SKILL.md テンプレート

```markdown
---
name: {skill-name}
description: Brief description for Claude to understand when to use
disable-model-invocation: true  # true = ユーザー手動実行のみ
---

Skill instructions here.
Use $ARGUMENTS for user input.
```

## バリデーション

プラグイン追加後は必ず検証:

```shell
/plugin validate ./plugins/{member_name}
```

## 命名規則

| 項目 | 規則 | 例 |
|------|------|-----|
| メンバー名 | kebab-case | `taro-yamada` |
| スキル名 | kebab-case | `code-review` |
| プラグインバージョン | semver | `1.0.0` |

## 環境変数

プラグイン内でパスを参照する際は `${CLAUDE_PLUGIN_ROOT}` を使用:

```json
{
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"
}
```
