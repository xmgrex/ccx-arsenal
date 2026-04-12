# agent-core

TDD 駆動開発ワークフローを fork ベースの独立エージェントで実現する、Claude Code プラグインです。

## 概要

`agent-core` は、AI エージェントに**役割ごとに独立したコンテキスト**で作業させることで、Self-Evaluation Bias（自己評価バイアス）を排除し、懐疑的な検証を強制するワークフローを提供します。

実装者・テスター・評価者を別々のエージェントとして fork することで、以下を実現します:

- **TDD 必須** — RED/GREEN の証拠を省略できない
- **評価者の独立性** — 実装したエージェントが自分で「動作確認」しない
- **報酬ハック検出** — テストが甘くないか別エージェントが監査する
- **懐疑的な受け入れテスト** — Anti-Bias Rules と Confidence レベルを持つ評価者

## インストール

```shell
# マーケットプレイスを登録
/plugin marketplace add xmgrex/ccx-arsenal

# プラグインをインストール
/plugin install agent-core@ccx-arsenal
```

## ワークフロー（二重ループ）

```
Phase 0: 設計（Planner）
  /planning → fork → planner
    → Product Spec + Acceptance Criteria + Implementation Checklist

内側ループ（Generator = TDD サイクル）:
  /create-issue → (/tdd-cycle → /verify-local → /smart-commit) × N

外側ループ（Evaluator = E2E/UI 検証）:
  全機能完了 → /e2e-evaluate
    ├─ PASS → /pr-description → ユーザーレビュー → マージ
    └─ ITERATE → 修正指示付きで /tdd-cycle に差し戻し（最大3ラウンド）
```

**アプリ開発の依頼を受けたら、原則 `/planning` から開始します。** `/planning` はユーザーの曖昧な要求を Product Spec に変換し、テスト可能な Acceptance Criteria と Implementation Checklist（1タスク=1アクション）を生成する fork skill です。以降の `/create-issue` / `/tdd-cycle` / `/e2e-evaluate` は、この Spec と AC を入力として使います。

Spec と AC が既にある場合のみ Phase 0 をスキップ可能。各スキルは独立しており、途中から開始することもできます。

### Phase 0: /planning（設計）

```shell
/planning "タスク管理アプリを作りたい"
```

内部で `planner` エージェントが独立 fork で起動し:

- 曖昧な場合は対象ユーザー・コア価値をヒアリング
- Feature リストを作成（User Story + Acceptance Criteria）
- Phase 分け（Phase 1 = MVP、Phase 2+ = 拡張）
- Implementation Checklist 生成（1タスク=1アクション、TDD サイクル明示）

planner の出力は以下の形式:

- **Product Vision / Target User** — 何を誰のために作るか
- **Features** — User Story + Testable Acceptance Criteria
- **Implementation Checklist** — `Write test → RED → Implement → GREEN → Commit` 形式のタスク分解

### Generator（内側ループ）

`/tdd-cycle` は内部で fork ベースのスキルを連鎖させます:

```
/tdd-cycle
  ├─ /red-test      → fork → tester        （テスト作成 & RED 確認）
  ├─ /audit-tests   → fork → test-auditor  （AC カバレッジ + 報酬ハック検出）
  ├─ /implement     → fork → implementer   （実装 & GREEN 確認）
  ├─ /verify-test   → fork → tester        （再度テスト実行）
  ├─ /simplify      → コード整理（リファクタ）
  └─ /verify-test   → fork → tester        （壊れていないか確認）
```

### Evaluator（外側ループ）

```
/e2e-evaluate → fork → acceptance-tester
  ├─ Phase 1: AC 検証（全機能を実動テスト）
  ├─ Phase 2: デザイン4軸評価（UI アプリの場合）
  │           Design Quality / Originality / Craft / Functionality
  └─ Phase 3: Negative & Adversarial Testing（機能を壊そうとする）
```

評価者は `acceptance-tester` として独立した fork で実行されるため、実装者のコンテキストに影響されません。

## Skills 一覧

### Core Workflow（通常のワークフロー）

| Skill | 役割 | Next |
|-------|------|------|
| `/planning` | **起点** — Spec + AC + Checklist 生成（fork） | → `/create-issue` |
| `/create-issue` | タスクを GitHub Issue として構造化 | → `/tdd-cycle` |
| `/tdd-cycle` | RED-GREEN-REFACTOR（fork ベース） | → `/verify-local` |
| `/verify-local` | ビルド・テスト・lint 検証ゲート | → `/smart-commit` |
| `/smart-commit` | 検証済みコミット作成 | → `/tdd-cycle` or `/e2e-evaluate` |
| `/e2e-evaluate` | E2E + デザイン評価（fork） | → `/pr-description` or ITERATE |
| `/pr-description` | PR 自動生成 | → `/pr-review` |
| `/pr-review` | PR コードレビュー（公式優先 + フォールバック） | → ユーザーレビュー |

### Fork Skills（サブエージェント起動）

| Skill | fork 先エージェント | 用途 |
|-------|-----------------|------|
| `/planning` | planner | Product Spec + AC + Implementation Checklist 生成 |
| `/red-test` | tester | テスト作成 & RED 確認 |
| `/audit-tests` | test-auditor | テスト品質監査（AC カバレッジ + 報酬ハック検出） |
| `/implement` | implementer | テストを通す実装 |
| `/verify-test` | tester | テスト実行 & GREEN/FAIL 判定 |
| `/e2e-evaluate` | acceptance-tester | E2E + デザイン評価 |
| `/review-impl` | reviewer | コードレビュー（任意） |

### 補助 Skills

| Skill | 用途 |
|-------|------|
| `/investigate` | 構造化されたバグ調査・デバッグワークフロー |

## Agents 一覧

| Agent | Model | 役割 |
|-------|-------|------|
| `planner` | opus | **起点** — Product Spec + AC + Implementation Checklist を生成（`/planning` で起動） |
| `tester` | sonnet | テストファイルの作成・修正・実行のみ |
| `implementer` | sonnet | テストを通すソースコード実装（テストは変更不可） |
| `test-auditor` | opus | テスト品質監査（読み取り専用、Anti-Bias Rules 搭載） |
| `acceptance-tester` | opus | E2E + デザイン評価（Anti-Bias Rules 搭載） |
| `reviewer` | opus | コードレビュー（読み取り専用、Anti-Bias Rules 搭載） |

## 典型的な使用例

### パターン1: ゼロからアプリを作る（フルワークフロー）

```shell
# 0. 設計 — Product Spec + AC + Implementation Checklist を生成
/planning "タスク管理アプリを作りたい"

# 1. Issue 作成 + ブランチ作成（Checklist の Feature ごと）
/create-issue "Feature 1: ユーザー登録"

# 2. TDD サイクル（内部で red-test → audit-tests → implement → verify-test）
/tdd-cycle "Feature 1 の AC"

# 3. ローカル検証
/verify-local

# 4. コミット
/smart-commit

# 5. 2〜4 を全 Feature について繰り返す

# 6. 全機能完了後、E2E 評価
/e2e-evaluate "アプリ起動方法 + 全 AC リスト"

# 7. PASS なら PR 作成
/pr-description

# 8. PR コードレビュー（公式 code-review プラグインを優先、未インストール時はフォールバック）
/pr-review
```

### 推奨: 公式 code-review プラグインの併用

`/pr-review` は公式 `code-review` プラグインを優先利用します（4エージェント並列レビュー + 信頼度スコアリング）。未インストールでも ccx-arsenal 独自の reviewer エージェントでフォールバック動作しますが、より堅牢なレビューのため公式プラグインの併用を推奨します:

```shell
claude plugin install code-review@claude-plugins-official
```

### パターン2: 既に仕様がある場合（途中から開始）

```shell
# Spec と AC が既にある場合、/planning をスキップして /create-issue から開始
/create-issue "既存仕様から切り出した Feature"
/tdd-cycle "AC"
# ... 以降同じ
```

### パターン3: 既存テストの監査

```shell
# AC カバレッジと報酬ハックのみチェック
/audit-tests "Acceptance Criteria..."
```

### パターン4: E2E 評価の ITERATE ループ

```
/e2e-evaluate → ITERATE（Round 1）
  ↓ 修正指示
/tdd-cycle [Iteration Mode で再発防止テスト付き修正]
  ↓
/e2e-evaluate → PASS / ITERATE（Round 2、最大3ラウンド）
```

## 設計思想

### Self-Evaluation Bias の排除

実装者が自分で「動作確認」すると、無意識のうちに甘い判定になります。`agent-core` では:

- **implementer はテストを変更できない**（テストファイル編集を禁止）
- **tester はソースコードを変更できない**（テストを通すために実装を弄れない）
- **acceptance-tester / reviewer / test-auditor は読み取り専用**（問題を指摘するだけ）

### Anti-Bias Rules

全評価者は冒頭に「懐疑性を強制するルール」を持ちます:

- 「動いているから OK」と判断しない
- 疑わしきは FAIL / NEEDS_FIX
- 問題を見つけることが仕事（褒めるモードに入らない）
- エビデンスなき判定は許さない

### Confidence レベル

全評価者の判定に `Confidence: HIGH / MEDIUM / LOW` を付与。LOW の場合は追加検証を推奨します。

### メタ評価（エビデンス検証）

オーケストレーター（`/tdd-cycle` / `/e2e-evaluate`）は評価者が PASS を返しても:

- Evidence 列が空の項目があれば受理しない
- Negative Testing や Semantic Analysis が欠けていれば受理しない
- Confidence: LOW なら追加検証を検討

評価者が手を抜いても検出できる二段構えになっています。

### 決定論ゲート（!構文）

重要な連鎖ステップには `!command` 構文を使い、スキルローダーレベルで機械的に実行することで、Claude の判断スキップを防いでいます。「Claude の気分でスキップされる」事故を構造的に防ぐ設計です。

#### `/pr-review` の決定論化

PR レビューの「PR diff 取得 → 公式プラグイン試行 → フォールバック起動」を `!` 構文で固定:

1. **PR 情報取得**: `` !`gh pr view` `` で PR 番号・タイトル・URL を必ず取得（決定論）
2. **diff 取得**: `` !`gh pr diff` `` で diff を必ず取得（決定論）
3. **公式プラグイン試行**: `` !`claude -p "/code-review"` `` でサブプロセスとして公式プラグインを呼出（決定論）
4. **フォールバック起動**: シェル `||` で失敗時に `FALLBACK_TRIGGERED` を注入し、reviewer エージェントが即座に独自レビューに切り替え（決定論、1段）

最終的なコメント投稿のみ reviewer エージェントの判断に依存しますが、必要なデータ（diff・PR 情報・公式試行結果）が全て事前注入されているため、データ欠落による失敗確率はゼロに近くなります。

#### `/tdd-cycle` の決定論化

TDD サイクルの最も重要な「テストファースト + 報酬ハック検出」を確実に実行するため、Phase 1 (RED) と Phase 1.5 (AUDIT) を `!` 構文で必ず実行します:

1. **Phase 1 (RED)**: `` !`claude -p "/red-test ..."` `` でテスト作成を必ず実行（決定論）
2. **Phase 1.5 (AUDIT 1回目)**: `` !`claude -p "/audit-tests ..."` `` で報酬ハック検出を必ず実行（決定論）
3. **Phase 2 以降**: orchestrator が判定ロジックで進行（条件分岐とループ上限あり）

これにより「Claude が AUDIT をスキップして弱いテストで実装を進める」事故が構造的に防げます。さらに全ループに明示的な上限（AUDIT NEEDS_IMPROVEMENT 最大3回、VERIFY FAIL 最大3回、SIMPLIFY 失敗 最大2回）が設定されており、暗黙の無限ループは存在しません。

## 詳細ドキュメント

より詳しい開発ガイドラインは [CLAUDE.md](./CLAUDE.md) を参照してください。
