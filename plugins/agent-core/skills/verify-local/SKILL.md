---
name: verify-local
description: ローカルでビルド・テスト・lint を実行し、変更が壊れていないことを証明する。コミット前やPR前の検証ゲートとして使う。
---

# Verify Local — ローカル検証ゲート

## Usage

```
/verify-local
/verify-local --full    # 全検証（ビルド + テスト + lint + セキュリティ）
```

## Stack Detection

プロジェクトルートのマーカーファイルから自動検出:

| Marker | Stack | Build | Test | Lint |
|--------|-------|-------|------|------|
| package.json | Node.js | `npm run build` | `npm test` | `npx eslint . \|\| npx biome check .` |
| pubspec.yaml | Flutter | `flutter build` | `flutter test` | `flutter analyze` |
| Package.swift | Swift | `swift build` | `swift test` | `swiftlint` |
| Cargo.toml | Rust | `cargo build` | `cargo test` | `cargo clippy` |
| go.mod | Go | `go build ./...` | `go test ./...` | `golangci-lint run` |
| pyproject.toml | Python | `pip install -e .` | `pytest` | `ruff check .` |

## Verification Steps

### 1. Build

```bash
# Stack に応じたビルドコマンドを実行
# exit 0 でなければ FAIL
```

### 2. Test

```bash
# テストスイート全実行
# 結果サマリーを表示（テスト数・成功数・失敗数）
# 1つでも FAIL → 全体 FAIL
```

### 3. Lint / Static Analysis

```bash
# lint ツールを実行
# warning は報告、error は FAIL
```

### 4. Security Audit（--full 時のみ）

```bash
# npm audit / cargo audit / pip-audit 等
# Critical/High の脆弱性があれば報告
```

## Output

```markdown
## Local Verification Result

| Check | Status | Detail |
|-------|--------|--------|
| Build | ✅ PASS | clean build, 0 warnings |
| Test  | ✅ PASS | 42 passed, 0 failed |
| Lint  | ⚠️ WARN | 2 warnings (non-blocking) |

**Verdict: PASS** — コミット/PR 可能
```

Verdict が FAIL の場合、問題の詳細と修正の方向性を提示する。

## 原則

- **証拠なき「動いてます」は PASS ではない** — コマンド出力を必ず表示
- **テスト数の減少を検出** — 前回より減っている場合は警告
- **全検証を通してから次のステップへ** — ゲートとして機能する

## Next

→ `/smart-commit` で検証済みコミット

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
