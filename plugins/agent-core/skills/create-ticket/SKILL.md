---
name: create-ticket
description: "Spec ファイル（.agent-core/specs/*-spec.md）から Phase 1 の Feature を読み取り、ローカル JSON チケット（.agent-core/tickets/T-XXXX.json）を一括作成する。gh 依存なし、完全オフライン動作。GitHub Issue 化したい時は別途 /ticket-publish を opt-in で実行。Trigger: /create-ticket, ticket 作成, spec からチケット化, チケット一括生成"
---

# Create Ticket — Spec から Feature 単位でローカル JSON チケット一括生成

> ⚠️ **DEPRECATED (1.3.0+)** — 新規プロジェクトでは `/generate <story-id>` を推奨します。
>
> H-Consensus (Tiered Static Fork) モデルでは、チケットは **Sprint Contract 交渉時に lazy 生成**する設計です。`/planning` で KPI → Spec → Story を固めた後、`/generate` が 1 sprint ずつ Ticket を動的に作ります。
>
> このスキル (Spec → Phase 1 全 Feature を eager に一括生成) は、**既存プロジェクトの後方互換のためのみ**に残存しています。旧 `/tdd-cycle` や `/ticket-cycle` と組み合わせた従来フローはそのまま動作します。
>
> 新規プロジェクトでは `/planning` → `/generate <story-id>` のフローに切り替えてください。

## Usage

```
/create-ticket                                      # .agent-core/specs/ の最新 Spec を自動検出
/create-ticket .agent-core/specs/counter-app-spec.md  # 明示指定
```

## Workflow Awareness

あなたは agent-core の TDD 駆動パイプラインで Phase 0 と Phase 1 をつなぐ「チケット化」ステップを担当する。全体構造:

```
Phase 0: /planning → spec.md + flow.md + screens/*.html
  ↓（ユーザー承認）
Phase チケット化: /create-ticket  ← あなたはここ
  → .agent-core/tickets/T-XXXX.json を spec から一括生成
  ↓
Phase 1-N: 内側ループ（2 レーン、ユーザーが明示使い分け）
  ├─ /tdd-cycle <T-ID>     — テスト先行が自然なタスク
  └─ /ticket-cycle <T-ID>  — テスト先行が不自然なタスク（削除・リファクタ・インフラ）
  ↓
Phase Publish（opt-in）: /ticket-publish → GitHub に push
  /pr-description → PR 作成 → /pr-review
```

**重要**: このスキルは **gh を一切呼ばない**。GitHub Issue に push したい場合は別途 `/ticket-publish <T-ID>` を明示的に実行する。ローカル JSON が Single Source of Truth である。

---

## 決定論ゲート（スキルローダーが実行）

specs / tickets ディレクトリ確保 + Spec ファイル解決:

!`mkdir -p .agent-core/tickets && if [ -n "$ARGUMENTS" ] && [ -f "$ARGUMENTS" ]; then echo "SPEC_FILE: $ARGUMENTS"; else LATEST=$(ls -t .agent-core/specs/*-spec.md 2>/dev/null | head -1); if [ -z "$LATEST" ]; then echo "SPEC_RESOLVE_RESULT: NOT_FOUND"; echo "ERROR: No spec file found. Run /planning first or pass an explicit path."; else echo "SPEC_RESOLVE_RESULT: OK"; echo "SPEC_FILE: $LATEST"; fi; fi`

既存チケットの最大 ID を取得（次の ID 計算用）:

!`if ls .agent-core/tickets/T-*.json >/dev/null 2>&1; then ls .agent-core/tickets/T-*.json | sed -E 's/.*T-([0-9]+)\.json/\1/' | sort -n | tail -1; else echo "0"; fi`

現在時刻を取得（`created_at` / `updated_at` 用、ISO 8601 UTC）:

!`date -u +"%Y-%m-%dT%H:%M:%SZ"`

---

## Task

あなたは create-ticket orchestrator です。上記の決定論ゲート出力から以下を抽出して作業してください:

- `SPEC_FILE`: 対象 spec ファイルのパス（`SPEC_RESOLVE_RESULT: NOT_FOUND` なら即停止）
- `MAX_ID`: 既存チケットの最大 ID 数値部分（初回なら `0`）
- `NOW`: ISO 8601 UTC 時刻

### Step 1: Spec 読み込み & Feature 抽出

Read ツールで `SPEC_FILE` の内容を読み、以下を行う:

1. `## Features` セクション配下の `### Feature N: <Name>` ブロックを全て抽出
2. 各 Feature から以下を取得:
   - **Title**: `### Feature N: <Name>` の `<Name>` 部分（チケットタイトルは `feat: <Name>` 形式でよい）
   - **User Story**: `- **User Story**: ...` 行
   - **Acceptance Criteria**: `- **Acceptance Criteria**:` 配下のチェックボックス行
   - **Phase**: `- **Phase**: N` の値
3. **`Phase == 1` の Feature のみ**をチケット化対象とする
4. 対応する `## Implementation Checklist` 内の `#### Feature N: <Name>` ブロックも取得（body に含める）

Phase 1 の Feature が 0 個だった場合は「Phase 1 Feature が見つかりませんでした」と報告して停止。

### Step 2: チケット ID 採番

`MAX_ID` の次の番号から連番で採番する:

```
次のチケット ID = T-{printf "%04d" $(($MAX_ID + 1))}
```

例: `MAX_ID=0` なら `T-0001` から、`MAX_ID=12` なら `T-0013` から。

### Step 3: チケット JSON 作成ループ

抽出した各 Feature について、Write ツールで `.agent-core/tickets/T-XXXX.json` を生成する。JSON スキーマ:

```json
{
  "ticket_id": "T-0001",
  "title": "feat: <Feature Name>",
  "body": "## 概要\n<User Story>\n\n## Acceptance Criteria\n<AC をチェックボックスで列挙>\n\n## Implementation Checklist\n<Implementation Checklist の該当 Feature ブロックを転記>\n\n## Spec Reference\n`<SPEC_FILE>` — Feature <N>: <Feature Name>",
  "status": "open",
  "phase": 1,
  "labels": [],
  "branch": null,
  "github_issue_number": null,
  "github_pr_number": null,
  "created_at": "<NOW>",
  "updated_at": "<NOW>",
  "spec_reference": "<SPEC_FILE>#feature-<N>"
}
```

- `ticket_id` とファイル名を必ず一致させる（例: `T-0001` なら `T-0001.json`）
- `body` は Markdown 文字列として生成し、改行は `\n` で JSON エスケープする
- `labels` は今回は空配列で OK（spec に明示的なラベル指定があれば拾う）
- `status` は常に `"open"` で初期化
- `phase` は `1`（Phase 1 Feature のみ対象のため）
- `branch` / `github_issue_number` / `github_pr_number` は全て `null`（後段のスキルが set する）
- `spec_reference` は spec ファイルの該当 Feature へのアンカー風参照

### Step 4: 結果サマリー

全チケット作成後、以下を会話に出力:

```
Created N tickets from <SPEC_FILE>:
  - T-0001 feat: <Feature 1 Name>
  - T-0002 feat: <Feature 2 Name>
  - ...

Skipped: <Phase 2+ の Feature 数> (Phase 2 以降)

Next steps:
  - TDD 向き Feature: /tdd-cycle T-XXXX
  - 非 TDD 向き Feature（削除・リファクタ・インフラ）: /ticket-cycle T-XXXX
  - GitHub に共有（optional）: /ticket-publish T-XXXX
```

---

## 原則

- **Spec ファイルが Single Source of Truth の上流** — create-ticket は Spec の忠実なチケット化のみ担い、内容の再解釈や追加判断はしない
- **Phase 1 のみ対象** — Phase 2 以降は将来の拡張 or 手動対応
- **gh 依存なし** — このスキルは完全にローカルで動く。GitHub への push は `/ticket-publish` の opt-in 責務
- **ブランチは作成しない** — ブランチ作成は `/tdd-cycle` / `/ticket-cycle` 側の責務
- **Acceptance Criteria は Spec の記述をそのまま転記** — 「入力・操作・期待値」への変換は planner 側で完了している前提
- **1 Feature = 1 チケット** — Feature の粒度が大きすぎる場合は planner に戻って Spec を分割する
- **ticket_id は連番** — 既存の最大 ID の次から採番。欠番は埋めない（削除されたチケットがあっても飛ばす）

---

## エラー処理

| 状況 | 対処 |
|------|-----|
| Spec ファイル未検出 | 「Spec が見つかりません。/planning を先に実行してください」と停止 |
| Phase 1 Feature ゼロ | 「Phase 1 Feature が見つかりませんでした」と停止 |
| JSON 書き込み失敗 | 途中までのチケットを残したまま停止し、成功/失敗を報告 |
| 既存 T-XXXX.json との衝突 | 理論上発生しない（MAX_ID+1 採番のため）が、万一ファイルが存在したら警告して停止 |

---

## Next

→ 各チケットを `/tdd-cycle <T-ID>` または `/ticket-cycle <T-ID>` で実装
→ Team に共有したければ `/ticket-publish <T-ID>` で GitHub Issue 化（opt-in、gh 依存）

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
