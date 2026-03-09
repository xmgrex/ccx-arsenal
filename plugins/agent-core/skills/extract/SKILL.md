---
name: extract
description: 大きなファイルを責務ごとに分割するリファクタリング。言語不問（Dart, Swift, TypeScript等）。参照の自動修正と検証を含む。Trigger - "ファイル分割", "大きすぎる", "責務分離", "extract", "split file", "ファイルが長い"
---

# Extract — 大ファイル分割

1ファイルに複数の責務が混在している場合に、責務単位で分割する。言語不問。

## Usage

```
/extract                        # 対話的に対象ファイルを指定
/extract src/app/dashboard.ts   # 指定ファイルを分割
```

`$ARGUMENTS` で対象ファイルを指定。省略時は AskUserQuestion で確認。

## Workflow

### 1. 対象ファイルを分析

ファイル全体を読み、以下を特定する:
- 責務の塊（クラス、関数グループ、Widget等）
- 各塊の行数
- 塊間の依存関係（どれがどれを参照しているか）

### 2. 分割計画を提示

ユーザーに承認を求める。実装前に必ずこの表を提示:

```markdown
## 分割計画: [元ファイル名] ([総行数]行)

| # | 新ファイル | 移動する要素 | 行数 | 依存 |
|---|----------|------------|------|------|
| 1 | [path]   | [class/func名] | ~N行 | なし |
| 2 | [path]   | [class/func名] | ~N行 | #1に依存 |
| 3 | [元ファイル（残留）] | [残る要素] | ~N行 | #1,#2をimport |

検証コマンド: [flutter analyze / swift build / tsc --noEmit 等]
```

**承認なしに分割を開始してはならない。**

判断に迷う場合（どこで切るか、命名、ディレクトリ構造等）は AskUserQuestion で確認する。

### 3. 言語別の抽出ルール

| 言語 | import修正 | アクセス修飾子 | 注意点 |
|------|----------|-------------|-------|
| **Dart** | `package:` importに統一 | private(`_`)→publicにする場合は確認 | `part/part of` は使わない |
| **Swift** | module内はimport不要 | `internal`→`public` が必要な場合あり | `@testable import` への影響確認 |
| **TypeScript** | 相対パス or エイリアス | `export` の追加 | barrel file (`index.ts`) の更新 |
| **その他** | 言語の慣習に従う | — | — |

### 4. 抽出を実行

依存関係の順序で抽出する（依存される側を先に）:

1. 新ファイルを作成し、要素を移動
2. 元ファイルから削除し、importを追加
3. **プロジェクト全体**で旧パスの参照を検索・修正（Grep で網羅的に）

ファイル数が多い場合は **complex-orchestrator** で並列実行。

### 5. 検証

```
検証結果?
    │
    ├─ ✅ ビルド成功 ──► 分割結果サマリーを報告。終了
    └─ ❌ エラー ─────► 参照漏れを修正（import/export/アクセス修飾子）
```

検証コマンド例:
- Dart: `flutter analyze` / `dart analyze`
- Swift: `swift build` / `xcodebuild`
- TypeScript: `tsc --noEmit` / `bun run build`

## 原則

- **計画を見せてから実行** — 分割は不可逆に近いため事前承認必須
- **1責務1ファイル** — 分割後のファイルも大きすぎないか確認
- **参照は網羅的に修正** — Grep で旧パスが残っていないことを確認
- **テストファイルも確認** — テストの import が壊れていないこと
- **迷ったらユーザーに聞く** — AskUserQuestion で命名や分割粒度を確認

## Integration

- **complex-orchestrator**: 10+ファイルへの参照修正を並列実行
- **investigate**: 分割後にビルドエラーが出た場合の調査に連携
- **local-code-review**: 分割後のレビューに使用
