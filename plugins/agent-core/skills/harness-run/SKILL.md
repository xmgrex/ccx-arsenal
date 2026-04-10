---
name: harness-run
description: TDD駆動の開発ワークフローオーケストレーター。独立スキルを組み合わせて、設計→実装→検証→PR→レビューの全工程を管理する。Trigger phrases: "アプリ作って", "harness run", "開発して", "アプリ開発", "full app", "作って"
disable-model-invocation: true
---

# Harness Run — TDD 駆動開発オーケストレーター

独立したスキルを組み合わせて、TDD 駆動の開発ワークフローを実行する。

**設計原則:**
- **オーケストレーターはコンテンツを生成しない** — 判断と委譲だけを行う（T-1）
- **各スキルは単独でも使える** — harness-run はそれらをフルワークフローで連結する
- **各ステップにゲート検証** — ゲートを通過しなければ次に進めない（T-2）
- **Your Human Partner** — 要所でユーザーに判断を仰ぐ。自律暴走しない

## Workflow Overview

```
Plan Mode ──→ /create-issue ──→ Branch
                                   │
              ┌────────────────────┘
              ▼
         /tdd-cycle ──→ /verify-local ──→ /smart-commit
              ▲               │                 │
              └── FAIL ───────┘                 │
                                                ▼
                                      機能が残っている？
                                       ├─ Yes → /tdd-cycle に戻る
                                       └─ No ↓
                                                ▼
                              /verify-local --full ──→ /pr-description
                                                           │
                                                           ▼
                                              /local-code-review
                                                           │
                                                           ▼
                                                  ユーザーレビュー
                                                           │
                                                           ▼
                                                    LGTM → マージ
```

---

## Step 1: 設計・タスク分解（Plan Mode）

**入力が曖昧な場合:**
1. コンテキスト探索 — 対象ユーザー、利用シーン、既存の代替手段を質問
2. コア価値の特定 — 「このアプリが無かったら何が困るか？」
3. アプローチ提案 — 2-3 の方向性を提示し、ユーザーに選ばせる

**入力が具体的な場合:**
Plan Mode で設計を行う（実行系ツール無効、調査のみ）:
- リポジトリ構造を把握
- 既存パターンを調査
- 技術選定と設計判断

**大規模な場合**: `harness-planner` を spawn して仕様と Implementation Checklist を作成。

**Gate**: ユーザー承認を得てから次へ。

---

## Step 2: Issue 作成 & ブランチ

`/create-issue` を実行:
- 設計を GitHub Issue に変換
- Acceptance Criteria と Implementation Checklist を含む
- Issue 番号からブランチを作成

**Gate**: Issue が作成され、ブランチが切られていること。

---

## Step 3: TDD 実装ループ

Implementation Checklist の各タスクについて:

```
/tdd-cycle <タスク内容>
    ↓
/verify-local          ← FAIL なら修正して再検証
    ↓
/smart-commit          ← feat: <タスク概要>
    ↓
次のタスクへ（or 全完了なら Step 4 へ）
```

### 大規模アプリの場合: Generator 分離

全タスクを1セッションで実装すると Context Degradation のリスクがある。以下の場合は `harness-generator` を spawn:

| 条件 | アクション |
|------|-----------|
| タスク数 10 以下 | 直接実装（スキルチェーン） |
| タスク数 11 以上 | `harness-generator` を spawn（worktree isolation） |
| コンテキスト劣化の兆候 | 新しい `harness-generator` を spawn + Handoff Document |

Generator の Context Degradation 兆候:
- 同じコードの再生成、同じ説明の繰り返し
- 仕様にある機能のスキップ
- エラーハンドリングの欠落、命名の不統一
- 「完了」宣言だが未実装機能が残っている

**Gate**: 全タスクのコミットが完了し、`/verify-local --full` が PASS。

---

## Step 4: PR 作成

`/pr-description` を実行:
- コミット履歴から PR を自動生成
- Summary, Changes, Test Plan, Review Guide を含む
- CI の完了を確認

**Gate**: PR が作成され、CI が PASS。

---

## Step 5: コードレビュー

### AI レビュー

`/local-code-review` を実行:
- 全差分をレビュー
- Critical issues は修正 → 追加コミット → CI 再確認

### QA（大規模アプリの場合）

`harness-evaluator` を spawn して Two-Stage QA:
- **Stage 1: Spec Compliance** — Acceptance Criteria を1つずつ検証
- **Stage 2: Code Quality** — Stage 1 全 PASS 後のみ実行

QA で ITERATE の場合:
1. QA Report の issues を分析
2. 独立した issues → 並列 spawn で修正
3. 相互依存 → 直列で修正
4. `/verify-local` → `/smart-commit` → 再 QA
5. **最大 3 ラウンド**。超過時はユーザーにエスカレーション

**Gate**: AI レビュー PASS（+ 大規模の場合 QA PASS）。

---

## Step 6: ユーザーレビュー & マージ

ユーザーに以下を提示:
1. **PR URL** — レビュー対象
2. **変更サマリー** — 何を実装したか
3. **レビュー観点** — 特に見てほしい箇所と設計判断の背景
4. **テスト結果** — 全テスト PASS の証拠
5. **質問への回答** — 「このPRについて質問があれば答えます」

ユーザーの LGTM を得てからマージ。**勝手にマージしない。**

---

## Stack Detection

開始前にマーカーファイルから検出:

| Marker | Stack | Build | Test | Lint |
|--------|-------|-------|------|------|
| package.json | Node.js | `npm run build` | `npm test` | `eslint` / `biome` |
| pubspec.yaml | Flutter | `flutter build` | `flutter test` | `flutter analyze` |
| Package.swift | Swift | `swift build` | `swift test` | `swiftlint` |
| Cargo.toml | Rust | `cargo build` | `cargo test` | `cargo clippy` |
| go.mod | Go | `go build` | `go test` | `golangci-lint` |
| pyproject.toml | Python | — | `pytest` | `ruff` |

---

## スキル一覧（このワークフローで使用）

| Skill | 役割 | 単独利用 |
|-------|------|---------|
| `/create-issue` | Issue 作成 + ブランチ | ✅ |
| `/tdd-cycle` | RED-GREEN-REFACTOR + 証拠 | ✅ |
| `/verify-local` | ビルド・テスト・lint 検証 | ✅ |
| `/smart-commit` | 検証済みコミット | ✅ |
| `/pr-description` | PR 自動生成 | ✅ |
| `/local-code-review` | AI コードレビュー | ✅ |

## エージェント（大規模開発で使用）

| Agent | 役割 | 使用条件 |
|-------|------|---------|
| `harness-planner` | 仕様 + Implementation Checklist 作成 | 大規模 or 複雑な設計 |
| `harness-generator` | worktree で TDD 実装 | タスク 11+ or Context Degradation |
| `harness-evaluator` | Two-Stage QA | 大規模アプリの品質検証 |
