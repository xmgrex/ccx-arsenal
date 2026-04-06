---
name: harness-run
description: Application development using Planner→Generator→Evaluator multi-agent harness with QA-verified quality. Trigger phrases: "アプリ作って", "harness run", "開発して", "アプリ開発", "full app", "作って"
disable-model-invocation: true
---

# Harness Run — Multi-Agent Application Development

Generator-Evaluator 分離パターンでアプリ開発を行う。

**解決する問題:**
- **Self-Evaluation Bias** — Generator は自分の成果物を過大評価する → Evaluator を分離
- **Context Degradation** — 長時間タスクで品質が劣化する → Phase 間でコンテキストリセット

**設計原則:**
- **Your Human Partner** — ユーザーは協力者。自律暴走せず、要所で判断を仰ぐ
- **構造的にバグを不可能にする** — 症状を直すのではなく、発生しない設計にする
- **証拠なき完了宣言の禁止** — 動作を実証してから完了とする

## Prerequisites — Stack Detection

開始前に確定。既存プロジェクトならマーカーファイルから検出、新規なら質問:

| Marker | Stack | Build | Run | Test |
|--------|-------|-------|-----|------|
| package.json | Node.js | `npm run build` | `npm run dev` | `npm test` |
| pubspec.yaml | Flutter | `flutter build` | `flutter run` | `flutter test` |
| Package.swift | Swift | `swift build` | `swift run` | `swift test` |
| pyproject.toml | Python | `pip install -e .` | `python main.py` | `pytest` |
| Cargo.toml | Rust | `cargo build` | `cargo run` | `cargo test` |
| go.mod | Go | `go build` | `go run .` | `go test ./...` |

### QA Tool（Evaluator が使用）

| App Type | Tool |
|----------|------|
| Web app | **agent-browser CLI**（Bash 経由、200-400 tokens/page） |
| Mobile | mobile-mcp |
| CLI / API | Bash |

agent-browser 未インストール時: `npm install -g agent-browser && agent-browser install`

---

## Phase 0: Design Refinement

**曖昧な入力を構造化する。** ユーザーの説明が十分に具体的でない場合、Planning に進む前に設計を練る。

### Gate: Phase 0 が必要か判断

| 入力の状態 | 判定 | 例 |
|-----------|------|-----|
| 具体的な機能・画面が列挙されている | → Phase 1 へスキップ | 「Todoアプリ。追加・削除・完了・フィルター機能」 |
| 1文の概要のみ / 抽象的 | → Phase 0 実行 | 「なんかいい感じのダッシュボード作って」 |
| 「〜みたいなやつ」「〜的な」 | → Phase 0 実行 | 「Notion みたいなメモアプリ」 |

### Process（Socratic Design Refinement）

1. **コンテキスト探索** — 対象ユーザー、利用シーン、既存の代替手段を質問
2. **コア価値の特定** — 「このアプリが無かったら何が困るか？」で本質を絞る
3. **アプローチ提案** — 2-3 の方向性を提示し、ユーザーに選ばせる
4. **設計の構造化** — 選ばれた方向性を Feature リスト + UI スケッチ（テキスト）に変換
5. **ユーザー承認** — 「この方向で Plan に進めてよいか？」を確認

**Anti-pattern: 「これはシンプルだから設計不要」** — シンプルに見えるものほど暗黙の要件が多い。Phase 0 をスキップする判断は Gate の基準のみで行う。

---

## Phase 1: Plan

**spawn `harness-planner`** に以下を渡す:
- ユーザーの説明（`$ARGUMENTS`）または Phase 0 の設計出力
- 検出した Stack 情報

### Bite-Sized Task Breakdown

Planner は仕様に加えて **実装チェックリスト** を出力する:
- 各タスクは **1アクション**（テスト作成 / テスト実行 / 実装 / 実装検証 / コミット）
- 1タスク = 2-5分の作業量
- 依存順に並べる
- ゼロコンテキストのエンジニアが実行できる粒度

Planner が仕様を返したら**ユーザーに提示して承認を得る**。承認後のみ Phase 2 へ。

---

## Phase 2: Build

**spawn `harness-generator`** に以下を渡す:
- 承認済み仕様の全文（実装チェックリスト含む）
- Stack 情報（Build/Run/Test コマンド）

### TDD 強制（Test-Driven Development）

Generator は RED-GREEN-REFACTOR サイクルに従う:

1. **RED** — 失敗するテストを先に書く
2. **GREEN** — テストを通す最小限のコードを書く
3. **REFACTOR** — テストが通る状態を維持しながらリファクタ

**例外（TDD 緩和が許される Stack/場面）:**
- Flutter/Swift のビジュアルコンポーネント — スナップショットテストまたは手動確認で代替
- 初期スキャフォールド — プロジェクト構造の作成時はテスト不要
- 外部 API 統合 — integration test で代替可

### Systematic Debugging

ビルドエラーや想定外の挙動が発生した場合:

1. **根本原因の調査を先に行う** — 症状だけ見て直さない
2. コールチェーンを逆方向にトレースする
3. 仮説を立て、最も確度の高いものから検証する
4. 原因が判明してから修正に着手する

### Defense-in-Depth（4層バリデーション）

Generator はバグを「構造的に不可能にする」設計を心がける:

| Layer | Purpose | Example |
|-------|---------|---------|
| 1. Entry Point | API 境界でのバリデーション | 入力値チェック、型検証 |
| 2. Business Logic | ドメインルールの強制 | 不正な状態遷移の防止 |
| 3. Environment | コンテキスト固有の安全装置 | 環境変数の検証 |
| 4. Debug Logging | 障害診断の最終手段 | 構造化ログ |

### Git Worktree Isolation

Generator は `isolation: "worktree"` で spawn する。失敗しても main を汚さない。

### Context Reset

Generator がコンテキスト劣化の兆候を報告した場合:
1. Handoff Document を受け取る
2. **新しい** `harness-generator` を spawn し、Handoff + 残タスクを渡す

---

## Phase 3: QA（Two-Stage Review）

**spawn `harness-evaluator`** に以下を渡す:
- 承認済み仕様（Acceptance Criteria が評価基準）
- Run instructions（Phase 2 の出力）
- プロジェクトパス

**Generator とは別のエージェント**であること。同一エージェントに評価させない。

### Stage 1: Spec Compliance（仕様準拠）

全 Acceptance Criteria を1つずつ検証: PASS / FAIL / PARTIAL

- **仕様に書かれていることが実装されているか？** が唯一の判定基準
- コード品質・スタイルはこのステージでは評価しない
- 1つでも FAIL → 即 ITERATE（Stage 2 に進まない）

### Stage 2: Code Quality（コード品質）

Stage 1 を全 PASS した場合のみ実行:

| Criterion | Weight |
|-----------|--------|
| Product Depth | 30% |
| Functionality | 30% |
| Visual/UX | 20% |
| Code Quality | 20% |

- **PASS**: Weighted total >= 7.0 AND Critical issues = 0
- **ITERATE**: それ以外

**なぜ 2 段階か:** 仕様未達のまま品質を磨く無駄を防ぐ。

---

## Phase 4: Iterate

ITERATE の場合:

### Parallel Agent Dispatch

QA Report の issues が**独立している場合**、複数の Generator を並列 spawn する:

| 判定 | アクション |
|------|-----------|
| Issues が異なるファイル/機能に属する | → 並列 Generator spawn |
| Issues が同一機能内で相互依存 | → 直列 Generator（従来通り） |
| 1件のみ | → 単一 Generator |

### Systematic Fix Flow

各 Generator は以下の手順で修正:

1. **根本原因調査** — QA Report の issue を読み、まず原因を特定する
2. **修正計画** — 場当たり修正ではなく、根本的な修正を設計する
3. **TDD で修正** — 再発防止テストを先に書いてから修正
4. **回帰チェック** — 既存テストが全て通ることを確認

### 渡すもの

1. QA Report を**無編集で**渡す（フィルタリング禁止）
2. 併せて渡す: 承認済み仕様（原本）、全 QA Report、git log
3. Generator が修正完了 → **新しい** `harness-evaluator` で再 QA
4. **最大 3 ラウンド**。超過時はユーザーにエスカレーション

---

## Phase 5: Simplify

PASS 後、`/simplify` を実行してコードを整理する。

機能は Evaluator が保証済みなので、安全にリファクタリングできる。

---

## Phase 6: Final Verification

Simplify 後、**リファクタで壊れていないことを証明する**。

1. **全テスト実行** — テストスイートが全 PASS であること
2. **Smoke Test** — アプリを起動し、主要機能が動作することを確認
3. **差分レビュー** — Simplify の差分が機能変更を含んでいないことを確認

**証拠なき完了宣言の禁止**: テスト結果・起動確認のログを提示してから Delivery に進む。

---

## Final Delivery

Final Verification 完了後にユーザーへ報告:

1. 実装 Feature 一覧（仕様との対応）
2. 起動方法
3. 最終 QA スコア
4. テスト結果サマリー
5. 既知の制限事項
6. 次のステップ提案

---

## Testing Anti-Patterns（Generator/Evaluator 共通参照）

Generator・Evaluator が避けるべきテストパターン:

| Anti-Pattern | 問題 | 正しいアプローチ |
|-------------|------|----------------|
| Mock の動作をテスト | 本物の挙動を検証していない | 実際の依存を使うか、振る舞いベースでテスト |
| テスト専用メソッドを本番コードに追加 | テストのためだけに本番を汚す | Public API のみでテスト |
| 過剰な Mock | テストが実装詳細に密結合 | 外部境界のみ Mock |
| テスト間の状態汚染 | テスト順序で結果が変わる | 各テストで状態をリセット |
| ブリトルテスト | リファクタのたびにテストが壊れる | 振る舞いをテスト、実装をテストしない |

---

## Skill Pressure Testing（harness-run 自体の品質保証）

このスキルの改善を行う際は、敵対的テストで効果を実証する:

1. **ベースライン計測** — スキルなしで Agent にアプリ開発させ、問題パターンを記録
2. **スキル適用** — 変更後のスキルで同じタスクを実行
3. **Before/After 比較** — ベースラインで発生した問題が解消されたか確認
4. **副作用チェック** — 新たな問題が発生していないか確認

---

## Integration

| Situation | Route to |
|-----------|----------|
| 説明が曖昧 | Phase 0 Design Refinement |
| Build 中にエラー | Systematic Debugging → 根本原因調査 |
| Build 3-strike | delegation-triggers → GPT escalation |
| QA issues が独立 | Phase 4 Parallel Agent Dispatch |
| QA issues 多数・相互依存 | `complex-orchestrator` で並列修正 |
| 完了後レビュー | `local-code-review` |
