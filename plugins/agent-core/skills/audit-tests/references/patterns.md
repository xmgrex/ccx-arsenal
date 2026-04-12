# Test Reward-Hack Pattern Catalog（Stack-Agnostic）

テストコードにおける「報酬ハック」パターンの完全カタログ。
各パターンはテストが「パスする（=報酬）」を最大化しつつ、本来の検証目的を達成していない状態を示す。

## Stack 別の検出キーワード

| パターン | Dart | JS/TS (Jest) | Python | Go | Swift | Rust |
|---------|------|-------------|--------|-----|-------|------|
| Assertion | `expect()` | `expect()` | `assert*` | `t.Error/Fatal` | `XCTAssert*` | `assert*!` |
| Test block | `test()` | `test()/it()` | `def test_` | `func Test` | `func test` | `#[test]` |
| Loop | `for (x in list)` | `for (x of list)` | `for x in list` | `for _, x := range` | `for x in list` | `for x in list` |

---

## CRITICAL（即修正）

### 1. EMPTY_LOOP — 空ループアサーション

ループ対象コレクションが空の場合、ループ本体は実行されず、全アサーションが「通ったことになる」。

**検出**: ループ内にアサーションがあるが、ループ対象の非空チェックがない

**悪い例** (JS):
```js
test('all items have valid dates', () => {
  const items = getItems();
  for (const item of items) {
    expect(item.date).toBeDefined(); // items が空なら実行されない
  }
});
```

**修正**: ループ前に `expect(items.length).toBeGreaterThan(0)` を追加

**例外**: setUp でデータ投入済み、または空を含む全ケースをカバー

---

### 2. NO_ASSERTIONS — アサーションなし

テストブロック内にアサーションが存在しない。テストカウントを水増しするだけ。

**検出**: テストブロック内に assertion 関数がない

**悪い例** (Python):
```python
def test_process_data():
    processor.process(data)  # 例外が出なければパス
```

**修正**: 戻り値や状態変化を明示的にアサート

**例外**: 「例外が出ないこと」の確認が目的（ただし明示的に書くべき）

---

### 3. TAUTOLOGICAL — 恒真アサーション

リテラル値のアサーションは常にパスする。システムの振る舞いを検証していない。

**検出**: `expect(true).toBe(true)`, `assert True`, `XCTAssertTrue(true)` 等

---

### 4. EXCEPTION_SWALLOW — 例外握りつぶし

catch ブロックで例外を無視してテストを通す。実際のバグを隠蔽する。

**検出**: catch ブロック内に rethrow/throw/fail/assert がない

---

## WARNING（改善推奨）

### 5. ZERO_TOLERANT — 曖昧な数量チェック

「1つ以上」で正確な数を検証しない。数量の回帰を検出できない。

**検出**: `toBeGreaterThan(0)` のみで具体的な数値チェックがない（UI 要素数の検証等）

---

### 6. DIRECTION_ONLY — 方向のみ検証

「増えた/減った」の方向は正しくても、具体的な量を検証しない。

**検出**: `greaterThan(before)` / `lessThan(before)` のみで差分の値チェックがない

**例外**: プロパティベーステスト、ソート結果の比較

---

### 7. COMMENTED_ASSERTION — コメントアウトされたアサーション

以前存在したアサーションがコメントアウトされている。検証範囲が縮小。

**検出**: `// expect(`, `# assert`, `// XCTAssert` 等

**例外**: `TODO(#issue)` 付き → INFO に降格

---

### 8. TYPE_ONLY — 型のみチェック

型チェックだけで値の内容を検証しない。

**検出**: `instanceof` / `isA<T>()` のみで `.having()` / プロパティチェックがない

---

### 9. NON_DETERMINISTIC — 非決定論的依存

テスト内で現在時刻等を使用。実行タイミングで結果が変わる。

**検出**: テスト本体内の `Date.now()`, `DateTime.now()`, `time.Now()` 等

---

## INFO（確認推奨）

### 10. EXISTENCE_ONLY — 存在のみチェック

`isNotNull` / `toBeDefined()` だけで中身を検証しない。

**例外**: UUID やタイムスタンプ等、値の存在確認が妥当な場合

---

### 11. OVER_MOCKING — 過剰モック

テスト対象自体がモック化されている。モックの設定を検証しているだけ。

---

### 12. STATE_LEAKAGE — 状態リーク

テスト間で mutable state を共有。テスト順序依存。

---

### 13. IGNORED_RETURN — 戻り値無視

メソッド呼出しの戻り値を未検証。副作用のないメソッドでは何もテストしていない。

---

### 14. HARDCODED_EXPECTED — ハードコード期待値

マジックナンバーで計算式との対応不明。仕様変更時のメンテナンスが困難。

**修正**: 計算式をテスト内にコメントまたは変数で明記

---

## コンテキスト例外（偽陽性として除外）

1. プロパティベーステスト内の方向チェック
2. 例外テストパターン内の catch
3. setUp でデータ投入済みのコレクションに対するループ
4. `TODO(#issue)` 付きのコメントアウト → WARNING → INFO に降格
5. Stream/Observable テストの非同期 assertion
6. 「例外が出ないこと」を明示的に検証するパターン
