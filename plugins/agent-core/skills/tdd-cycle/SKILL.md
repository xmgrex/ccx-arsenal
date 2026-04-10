---
name: tdd-cycle
description: RED-GREEN-REFACTOR サイクルを証拠付きで実行する。テスト作成→失敗確認→実装→成功確認→リファクタ。単独でも harness-run からも使える。
---

# TDD Cycle — 証拠付き RED-GREEN-REFACTOR

## Usage

```
/tdd-cycle ユーザー認証のログイン機能
/tdd-cycle $ARGUMENTS
```

## Cycle

各機能について以下を**厳密に順序通り**実行する:

### 1. RED — 失敗するテストを書く

- 機能の振る舞いを検証するテストを書く（実装より先）
- テストを実行し、**失敗出力を表示する**（RED 証拠）
- 失敗メッセージが「未実装だから失敗している」ことを確認する（typo や import エラーではない）

### 2. GREEN — 最小限の実装

- テストを通す**最小限**のコードを書く
- テストを実行し、**成功出力を表示する**（GREEN 証拠）
- 他のテストが壊れていないことも確認する

### 3. REFACTOR — 整理

- テストが通る状態を維持しながらコードを整理
- リファクタ後もテスト実行して PASS を確認

## Evidence Protocol（証拠必須）

RED と GREEN の両方で、テストランナーの stdout を**必ず表示する**。

```
# RED 証拠の例
$ npm test -- auth.test.ts
FAIL src/auth/auth.test.ts
  ✕ should authenticate valid credentials (2ms)
    Expected: { token: expect.any(String) }
    Received: undefined

# GREEN 証拠の例
$ npm test -- auth.test.ts
PASS src/auth/auth.test.ts
  ✓ should authenticate valid credentials (3ms)
  ✓ should reject invalid password (1ms)

Tests: 2 passed, 2 total
```

**証拠を省略した場合、コードレビューで TDD 未実施と判定される。**

### Verification-Before-Completion（重要ロジックのみ）

ビジネスルール・状態遷移・データバリデーションでは:

1. GREEN 確認後、実装を一時的に revert
2. テスト実行 → 失敗を確認（テストが本当に実装を検証している証拠）
3. 実装を restore → テスト実行 → 再び PASS

## 絶対ルール

- **テストより先に本番コードを書いた場合、削除してテストからやり直す**
- テストを書いたが実行せずに先に進むこと → 禁止
- テストを通すために本番コードにテスト専用メソッドを追加 → 禁止
- Mock の振る舞いをテストすること → 禁止（実際の振る舞いをテストする）

## TDD 緩和が許される場面

| 場面 | 代替手段 |
|------|---------|
| Flutter/Swift のビジュアルコンポーネント | スナップショットテスト or 目視確認 |
| 初期スキャフォールド（プロジェクト構造作成） | テスト不要 |
| 外部 API 統合 | Integration test で代替 |
| CSS/スタイリングのみの変更 | 目視確認で代替 |

## Testing Anti-Patterns

| Anti-Pattern | 問題 | 正しいアプローチ |
|-------------|------|----------------|
| Mock の動作をテスト | 本物の挙動を検証していない | 実際の依存を使うか、振る舞いベースでテスト |
| テスト専用メソッドを本番に追加 | テストのためだけに本番を汚す | Public API のみでテスト |
| 過剰な Mock | テストが実装詳細に密結合 | 外部境界のみ Mock |
| テスト間の状態汚染 | テスト順序で結果が変わる | 各テストで状態をリセット |
| ブリトルテスト | リファクタのたびに壊れる | 振る舞いをテスト、実装をテストしない |
