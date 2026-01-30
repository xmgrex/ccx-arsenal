# ccx-arsenal

Claude Code プラグインの個人用マーケットプレイスです。

## 概要

このリポジトリは、Claude Code で使用するプラグイン、スキル、MCPサーバー設定などを一元管理するための個人用マーケットプレイスとして機能します。チームメンバーごとにディレクトリを分けてプラグインを管理できます。

## ディレクトリ構造

```
ccx-arsenal/
├── .claude-plugin/
│   └── marketplace.json      # マーケットプレイス定義
├── plugins/
│   └── {member_name}/        # メンバーごとのプラグインディレクトリ
│       ├── .claude-plugin/
│       │   └── plugin.json   # プラグインマニフェスト
│       ├── skills/           # スキル定義
│       │   └── {skill-name}/
│       │       └── SKILL.md
│       ├── commands/         # コマンド定義
│       ├── agents/           # サブエージェント定義
│       ├── hooks/            # フック設定
│       │   └── hooks.json
│       └── .mcp.json         # MCPサーバー設定
├── CLAUDE.md                 # Claude Code 用指示書
└── README.md
```

## 使用方法

### マーケットプレイスの登録

```shell
/plugin marketplace add xmgrex/ccx-arsenal
```

ローカル開発時:
```shell
/plugin marketplace add /path/to/ccx-arsenal
```

### プラグインのインストール

```shell
# 利用可能なプラグインを確認
/plugin search @ccx-arsenal

# プラグインをインストール
/plugin install {plugin_name}@ccx-arsenal
```

### メンバーとしてプラグインを追加する

1. `plugins/{your_name}/` ディレクトリを作成
2. `.claude-plugin/plugin.json` を配置
3. 必要に応じて skills/, commands/, agents/, hooks/ を追加
4. `.claude-plugin/marketplace.json` にプラグインエントリを追加

詳細は [CLAUDE.md](./CLAUDE.md) を参照してください。

## 参考資料

### 公式ドキュメント（英語）

- [Best Practices](https://code.claude.com/docs/en/best-practices) - Claude Code ベストプラクティス
- [Plugins](https://code.claude.com/docs/en/plugins) - プラグインの作成方法
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference) - プラグインリファレンス
- [Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) - マーケットプレイスの作成・配布

### 公式ドキュメント（日本語）

- [スラッシュコマンド](https://docs.claude.com/ja/docs/claude-code/slash-commands) - カスタムスラッシュコマンドの作成方法
- [サブエージェント](https://docs.claude.com/ja/docs/claude-code/sub-agents) - サブエージェントの活用方法
- [MCP](https://docs.claude.com/ja/docs/claude-code/mcp) - Model Context Protocol の設定
- [フックガイド](https://docs.claude.com/ja/docs/claude-code/hooks-guide) - フックの設定・活用方法

## ライセンス

Private - 個人使用のみ
