---
name: ticket-publish
description: "ローカル JSON チケット（.agent-core/tickets/T-XXXX.json）を GitHub Issue として push する opt-in スキル。完了後、JSON の github_issue_number フィールドを更新する。agent-core のうち gh CLI に依存する唯一のチケット関連スキル。チームに共有する時だけ明示的に実行する。Trigger: /ticket-publish <T-XXXX>, ticket 公開, GitHub に共有, チケットを issue 化"
---

# Ticket Publish — ローカルチケットを GitHub Issue に push（opt-in）

## Usage

```
/ticket-publish <T-XXXX>
```

例: `/ticket-publish T-0003`

---

## このスキルの位置付け

`/ticket-publish` は **agent-core における GitHub 連携の境界線**でございます。内側ループ（`/create-ticket` / `/tdd-cycle` / `/ticket-cycle`）はすべて完全オフラインで動き、`gh` を一切呼びません。GitHub にチケットを共有したい時**だけ**、ユーザーがこのスキルを明示的に実行します。

```
内側ループ（fully offline）:
  /create-ticket → /tdd-cycle or /ticket-cycle → /verify-local → /smart-commit
       ↓
  ← gh 依存の境界線 ─────────────────────────────────────────
       ↓
  /ticket-publish   ← このスキル（唯一の gh 依存ポイント、opt-in）
       ↓
  /pr-description / /pr-review
```

**使うタイミングの例**:
- 個人開発中はずっと使わなくてよい（ローカル完結）
- チームレビューに出したい → publish してから PR 作成
- 外部の協力者に issue を見せたい → publish

**使わない場合**: チケットはローカル JSON のまま一生を終えてもよい。`status: done` になればそれで完結。

---

## Prerequisites

このスキルは gh CLI に依存いたします。以下が揃っていない場合は失敗いたします:

- `gh` CLI がインストール済み
- `gh auth login` 済み（または `GH_TOKEN` 環境変数が set 済み）
- 対象リポジトリへの issue 作成権限
- sandbox が厳格（`~/.config/gh` 読み取り deny）な場合は、旦那様個人の `~/.zshrc` 等で以下を設定済みのこと:
  ```bash
  export GH_CONFIG_DIR="$HOME/.gh-sandbox"
  # 任意: Keychain 経由で GH_TOKEN を事前に set
  export GH_TOKEN=$(security find-generic-password -a "$USER" -s "claude-gh-token" -w 2>/dev/null)
  ```
  詳細は `plugins/agent-core/README.md` の「sandbox hardening」節を参照。

---

## 決定論ゲート（スキルローダーが実行）

チケット ID の正規化（`T-0003`, `3`, `#3` 等を受理）:

!`echo "$ARGUMENTS" | grep -oE '[0-9]+' | head -1 | awk '{printf "T-%04d\n", $1}'`

チケット JSON の読み込み:

!`TID=$(echo "$ARGUMENTS" | grep -oE '[0-9]+' | head -1 | awk '{printf "T-%04d\n", $1}'); if [ -z "$TID" ]; then echo "TICKET_ID_PARSE_FAILED: '$ARGUMENTS' から数値を抽出できません"; elif [ ! -f ".agent-core/tickets/${TID}.json" ]; then echo "TICKET_NOT_FOUND: .agent-core/tickets/${TID}.json が存在しません"; else echo "=== TICKET FILE ==="; cat ".agent-core/tickets/${TID}.json"; fi`

gh の認証状態を確認（失敗した場合は remediation 案内を表示するため事前に検知）:

!`gh auth status 2>&1 | head -20 || echo "GH_AUTH_FAILED"`

現在時刻（`updated_at` 用）:

!`date -u +"%Y-%m-%dT%H:%M:%SZ"`

---

## Task

あなた（メイン Claude）は ticket-publish orchestrator です。

### Step 1: 前提条件チェック

上記の決定論ゲート出力から以下を判定:

#### 1-A. チケット読み込みチェック
- `TICKET_ID_PARSE_FAILED` → 停止、正しい ID を促す
- `TICKET_NOT_FOUND` → 停止、`/create-ticket` を先に実行するよう促す

#### 1-B. gh 認証チェック
- `GH_AUTH_FAILED` または `gh auth status` の出力に `not logged into` / `failed to read configuration` 等のエラー → **停止**して以下の remediation を提示:

```
⚠️ gh CLI の認証が失敗しました

エラー内容: <gh の stderr>

対処案:
1. `gh auth login` で認証
2. または GH_TOKEN 環境変数を export
3. sandbox が厳格で ~/.config/gh を deny している場合:
   - ~/.zshrc で GH_CONFIG_DIR と GH_TOKEN を設定
   - 詳細は plugins/agent-core/README.md の sandbox hardening 節を参照
4. Claude Code を再起動して環境変数を反映

publish はチーム共有時の opt-in ですので、今すぐ解決しない場合は
ローカルで作業を続行できます。
```

#### 1-C. idempotent チェック（既に publish 済みか）

チケット JSON の `github_issue_number` フィールドを確認:
- **既に set されている**（非 null）→ **停止**。以下を表示:

```
ℹ️ このチケットは既に publish 済みです

Ticket: <T-ID> <title>
GitHub Issue: #<number>（既に作成済み）
URL: https://github.com/<owner>/<repo>/issues/<number>

再 publish は禁止されています（重複 issue 防止）。
既存 issue を編集したい場合は gh issue edit を手動でご使用ください。
```

- **null** → Step 2 へ進む

---

### Step 2: Issue 作成の計画提示（ユーザー承認ゲート）

チケット JSON から以下を抽出:
- `title`
- `body`（Markdown）
- `labels`

以下を**ユーザーに提示**し、明示承認を待つ:

```
📤 Ticket Publish Plan

Ticket: <T-ID> <title>
Labels: <labels>

Preview (gh issue create --title ...):
  Title: <title>
  Body:
    <body の先頭 20 行>
    ...

この内容で GitHub Issue を作成してよろしいですか？ (yes / no / 修正指示)
```

**重要**: ユーザーの明示 `yes` なしに Step 3 以降に進まない。publish は外部に影響を与える不可逆操作のため、必ず確認を取る。

---

### Step 3: Issue 作成

Bash ツールで以下を実行:

```bash
gh issue create \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body の全文>

---
_This issue was created by `/ticket-publish` from local ticket <T-ID>._
_See `.agent-core/tickets/<T-ID>.json` for the source of truth._
EOF
)"
```

`labels` が非空の場合は `--label <l1>,<l2>,...` を追加する。

実行結果から issue 番号と URL を capture する（gh は標準出力に issue URL を出す）。

#### 3-A. 失敗の場合

- network 不達 → 停止、後日再試行を促す
- permission denied / forbidden → 停止、token スコープを確認するよう促す
- 他のエラー → 停止、エラー内容を表示

**失敗時はチケット JSON を変更しない**（publish 未完了の状態を維持）。

---

### Step 4: チケット JSON の更新

publish 成功後、`.agent-core/tickets/<T-ID>.json` を Edit で更新:

- `github_issue_number`: 作成された issue 番号（integer）
- `updated_at`: 現在の ISO 8601 UTC 時刻（決定論ゲートで取得した値）

**変更しないフィールド**: `status`, `branch`, `title`, `body`, その他

---

### Step 5: サマリー出力

```markdown
✅ Ticket Published

Ticket: <T-ID> <title>
GitHub Issue: #<number>
URL: <issue URL>

### 変更
- .agent-core/tickets/<T-ID>.json:
  - github_issue_number: null → <number>
  - updated_at: <new timestamp>

### Next（optional）
- PR 作成: /pr-description
- レビュー投稿: /pr-review
```

---

## エラー処理のまとめ

| 状況 | 対処 |
|------|-----|
| チケット ID 不正 / 存在しない | 即停止、正しい ID を促す |
| チケット既に publish 済み | 即停止、idempotent 扱い |
| gh 未認証 / sandbox EPERM | 即停止、remediation 案内 |
| network 不達 | 即停止、後日再試行を促す |
| permission denied | 即停止、token スコープを確認 |
| 成功後の JSON 更新失敗 | 警告表示、手動での JSON 更新を促す（issue は既に作成済みなので、JSON だけが古い状態になる） |

---

## 原則

- **opt-in** — ユーザーが明示的に実行しない限り、チケットはローカルのまま
- **one-way sync** — local → GitHub の一方向のみ。GitHub 側の編集は local に反映しない
- **idempotent** — 同じチケットを 2 回 publish することは禁止（重複 issue 防止）
- **gh 依存はここだけ** — agent-core のチケット系スキル（create/cycle/publish）のうち、publish のみが gh に依存する
- **承認ゲート必須** — publish は外部に影響するため、必ずユーザー承認を取る
- **失敗時は JSON を変更しない** — publish が中途半端な状態で JSON が古くなるのを避ける

---

## Next

→ `/pr-description` で PR 作成 → `/pr-review` でレビュー → ユーザー承認 → マージ

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
