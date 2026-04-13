# agent-core

## 設計思想

**Autonomous development harness with H-Consensus (Tiered Static Fork).** チケットは `.agent-core/tickets/T-XXXX.json` に格納されるローカル JSON を Single Source of Truth とし、内側ループ (`/generate`) は **gh CLI を一切呼ばない** 完全オフライン動作です。GitHub Issue / PR への連携は `/ticket-publish` / `/pr-description` / `/pr-review` という **opt-in の publish レーン**でのみ行います。sandbox 環境でも開発フローが中断されません。

核心設計原理は 3 本柱:

1. **二重フィードバックループ**: harness blog の planner/generator/evaluator 3 役を **context:fork** で物理的に分離 (20x 品質ゲインの前提)
2. **Tiered Static Fork**: Sprint Contract metadata から **決定論 shell script** で tier (T1/T2/T3) を判定し、fork 構成を sprint 開始時に静的確定 (sprint 中は変更禁止)
3. **Gotcha 2 層学習**: prompt 層 (agent/skill MD) + 構造層 (tier-matrix) で複利学習。3 ヶ月周期の HITL で構造改定

---

## Workflow (H-Consensus)

```
Phase 0: 設計 (4 stage 収束ループ、fully offline)
  /planning → main が orchestrator
    │
    ├─ Stage 0: planner(KPI Mode) → .agent-core/specs/{slug}-kpi.md
    │            → spec-reviewer(KPI Mode) max 3R → HITL
    │
    ├─ Stage 1: planner(Spec Mode) → spec.md + flow.md
    │            → spec-reviewer + flow-reviewer 並列 max 3R → HITL
    │
    ├─ Stage 2: planner(Story Mode) → story.md
    │            → spec-reviewer(Story Mode) + flow-reviewer(Story Mode) 並列 max 3R → HITL
    │
    └─ Stage 3: ui-designer → screens/*.html (UI アプリのみ)
                → 決定論ゲート + ui-design-reviewer max 3R → HITL
      [注] create-ticket は呼ばない (lazy materialization)

内側ループ: /generate <story-id> (Tiered Static Fork、fully offline):
    Step 1: cold-start-check.sh (閾値判定)
    Step 2: Story pick (決定論選択 or 明示指定)
    Step 3: Sprint Contract 交渉
      ├─ Agent(planner, Contract Mode) fork → 提案
      └─ Agent(contract-reviewer) fork → 検証
      [合意] → .agent-core/tickets/T-XXXX.json を lazy 生成
    Step 4: classify-tier.sh (決定論 tier 判定)
      [cold start 中は強制 T2]
    Step 5: tier 別 fork 実行
      T1 (低): Agent(ticket-executor) fork + /verify-local
      T2 (中): /red-test → /implement → /verify-test → /e2e-evaluate
      T3 (高): /red-test → /audit-tests → /implement → /verify-test
               → /review-impl → /e2e-evaluate → Agent(post-mortem) fork
    Step 6: hard threshold 評価 (fail → ITERATE max 3R)
    Step 7: .agent-core/sprints/S-XXXX.json 記録 + /smart-commit
    Step 8: loop (同 Story 次 sprint or 次 Story)

外側ループ: /e2e-evaluate
  全機能完了 → acceptance-tester fork で E2E + デザイン評価
    ├─ PASS → Publish lane (optional)
    └─ ITERATE → 修正指示付きで /generate に差し戻し (最大3R)

Publish レーン (opt-in、team 共有時だけ、gh 依存はここのみ):
  /ticket-publish <T-ID>        ローカルチケットを GitHub Issue として push (一方向)
    ↓
  /pr-description               PR 作成 (publish 済みなら Fixes #N、未 publish なら Ticket: T-XXXX)
    ↓
  /pr-review                    PR コードレビュー投稿

構造層 Gotcha 学習 (3 ヶ月周期):
  /tier-matrix-review           → sprint 集計 → tier 判定ルール改定案 → HITL 承認
```

**アプリ開発の依頼を受けたら、原則 `/planning` から開始する。** KPI/Spec/Story/(Screens) が既にある場合のみ Phase 0 をスキップし、`/generate <story-id>` から開始可能。

---

## Generator 層 (`/generate`)

### Tiered Static Fork の決定論性

`/generate` Step 4 の tier 判定は **LLM 判断を挟まない**:

1. `classify-tier.sh --verifiability=X --risk=Y --surface=N` を `!` 構文で呼び出し
2. stdout の `TIER=` 行を context に注入
3. LLM は注入された tier を**改変禁止**
4. cold-start 中は `cold-start-check.sh` の `FORCED_TIER=T2` で強制上書き

この設計により、harness 自体のバイアスを排除し、再現性を保証します。

### fork 構成 (sprint 開始時に確定、中で変更禁止)

| Tier | Fork 構成 (順序) | ラウンド上限 |
|------|----------------|------------|
| T1 | ticket-executor → verify-local | impl 3R |
| T2 | red-test → implement → verify-test → e2e-evaluate | impl 3R, e2e 3R |
| T3 | red-test → audit-tests → implement → verify-test → review-impl → e2e-evaluate → post-mortem | audit 3R, impl 3R, review 2R, e2e 3R |

**全 tier 共通の不可侵**:
- test-writer (tester fork via red-test) ≠ implementer (fork via implement) — TDD の物理的分離
- evaluator (acceptance-tester fork) ≠ generator — skeptical 評価の前提

### Lazy Ticket Materialization

Ticket は **Sprint Contract 交渉合意時に 1 つずつ lazy 生成**する。Phase 0 では Ticket を作らない。

- `/planning` は KPI/Spec/Story/(Screens) のみ生成
- `/generate` が Story から 1 sprint 分ずつ Ticket を negotiate → 合意 → `.agent-core/tickets/T-XXXX.json` に Write
- Ticket JSON には `tier_metadata` (verifiability / risk_layer / surface) と `story_id` を含む

---

## Gotcha 2 層学習

### Layer 1 (prompt 層)

全 agent/skill MD 末尾の `## Gotchas` セクション。**post-mortem agent** が sprint PASS 直後に sha1 8 桁 hash 完全一致で dedup し append。

Entry format:
```
- [HASH8] [YYYY-MM-DD] <事象>: <対処> (hits: N, source: T-XXXX)
```

De-dup:
- 正規化: 小文字化 + 空白圧縮
- hash: `sha1(normalize(event+action))[:8]`
- 既存 hit 時は該当 entry の `hits: N` を N+1 に increment、新規 append はしない
- 3 ヶ月 hit=0 の entry は `.agent-core/gotchas/archive/YYYY-QN.md` に自動退避

### Layer 2 (構造層)

`.agent-core/tier-matrix.md` + `scripts/classify-tier.sh`。post-mortem が提案する tier matrix 改定案を 3 ヶ月周期で `/tier-matrix-review` が HITL 承認で適用。

**post-mortem の書き込み権限**: frontmatter `## Allowed Write Paths` で制約 + orchestrator 側の `git diff --stat` 境界チェック (二段防御)。

---

## Skills

### Core Workflow

| Skill | Role | Next |
|-------|------|------|
| `/planning` | **起点** — KPI/Spec/Story/(UI) の 4 stage 収束ループ | → `/generate` |
| `/plan-review` | スタンドアロン版レビュー (収束ループなし) | → 手動判断 |
| `/generate <story-id>` | **内側ループ orchestrator** — lazy ticket + tier 判定 + fork 実行 | → `/e2e-evaluate` or 次 sprint |
| `/verify-local` | ビルド・テスト・lint 検証 (stack auto-detect) | → `/smart-commit` |
| `/smart-commit` | 検証済みコミット (Ticket/Sprint trailer) | → 次 sprint or `/e2e-evaluate` |
| `/e2e-evaluate` | E2E + デザイン評価 (acceptance-tester fork) | → `/pr-description` or ITERATE |
| `/ticket-publish` | opt-in GitHub Issue push | → `/pr-description` |
| `/pr-description` | PR 作成 (Fixes #N or Ticket trailer) | → `/pr-review` |
| `/pr-review` | 公式 code-review 優先 + フォールバック | → ユーザーレビュー |
| `/tier-matrix-review` | 3 ヶ月周期構造層 Gotcha 学習 HITL レビュー | → tier 判定ルール改定 |

### Deprecated (1.3.0+、後方互換存置)

| Skill | 代替 |
|-------|------|
| `/create-ticket` | `/generate` (lazy materialization) |
| `/tdd-cycle` | `/generate` の T2 分岐 |
| `/ticket-cycle` | `/generate` の T1 分岐 |

### Fork Skills (`/generate` から内部的に呼ばれる)

| Skill | fork 先 | 用途 |
|-------|---------|------|
| `/red-test` | tester | テスト作成 & RED 確認 |
| `/audit-tests` | test-auditor | AC カバレッジ + 報酬ハック検出 (T3 のみ) |
| `/implement` | implementer | テストを通す最小実装 |
| `/verify-test` | tester | テスト実行 & GREEN 確認 |
| `/review-impl` | reviewer | コードレビュー (T3 のみ) |
| `/e2e-evaluate` | acceptance-tester | E2E + デザイン評価 |

---

## Agents

| Agent | Role |
|-------|------|
| `planner` | KPI / Spec / Story 生成 (Mode 分岐、Revise Mode 対応) |
| `spec-reviewer` | KPI/Spec/Story を Mode 分岐でレビュー (read-only、Anti-Bias Rules 搭載) |
| `flow-reviewer` | Spec Mode: 画面 DAG / Story Mode: Story 依存 DAG (read-only) |
| `ui-designer` | HTML screens 生成 (Tailwind layout-only、装飾禁止) |
| `ui-design-reviewer` | HTML 評価 + 決定論ゲート (read-only) |
| **`contract-reviewer`** | **(新)** Sprint Contract 検証 (atomicity / AC testability / Story 前進性 / tier metadata / KPI alignment) |
| `tester` | テスト作成・実行専門 (red-test と verify-test で別 fork) |
| `test-auditor` | テスト品質監査 (報酬ハック検出、read-only) |
| `implementer` | テストを通す最小実装 (テスト変更禁止) |
| `ticket-executor` | T1 用 AC 駆動 executor (削除・リファクタ・config) |
| `reviewer` | コードレビュー (T3 のみ、read-only) |
| `acceptance-tester` | E2E + デザイン 4 軸評価 + Negative Testing |
| **`post-mortem`** | **(新)** sprint PASS 後に Gotcha 抽出 (sha1 hash dedup、Allowed Write Paths 制約) |

---

## Rules

- **アプリ開発依頼時は原則 `/planning` から開始** (KPI/Spec/Story が既にある場合のみスキップ可)
- **Phase 0 は `/planning` の 4 stage 収束ループで完結** → 最終承認 → `/generate` の順
- 各 Stage は最大 3 ラウンド。収束しなければ全ラウンド履歴付きでユーザーエスカレーション
- **Stage 3 (UI) は UI アプリのみ実行**。CLI/API/ライブラリは Stage 3 全体をスキップ
- 各ラウンドの agent は必ず **fresh spawn** (kill-and-spawn)
- spec-reviewer と flow-reviewer は **同一メッセージ内で並列 spawn**
- **`/generate` Step 4 の tier は LLM 改変禁止** (`classify-tier.sh` の出力を厳守)
- **cold-start 保護**: post-mortem 10 件 or sprint 20 件の閾値前は強制 T2
- **Sprint Contract は lazy**: Phase 0 では Ticket を作らない、`/generate` が 1 sprint ずつ作る
- **全 tier で test-writer ≠ implementer**: TDD の物理的分離は sprint 中変更禁止
- **evaluator ≠ generator**: skeptical 評価の前提、fork 境界で分離
- **内側ループは fully offline**: `/generate` は gh を一切呼ばない
- **gh 依存は publish レーンに局所化**: `/ticket-publish` / `/pr-description` / `/pr-review` の 3 skill のみ
- **ローカル JSON が SSoT**: `.agent-core/tickets/` と `.agent-core/sprints/` が権威。GitHub は one-way sync 下流ミラー
- **post-mortem の書き込みは Allowed Write Paths 内のみ**: agent/skill MD の `## Gotchas` セクションと `.agent-core/gotchas/` に限定
- **Gotcha de-dup は sha1 8 桁完全一致**: LLM 類似判定は使わない (非決定論)
- **`/tier-matrix-review` は 3 ヶ月周期、HITL 必須**: 自動適用禁止、10 sprint 未満では改定しない
- AIコードレビューは `/pr-review` で PR 上に投稿 (公式 code-review プラグイン優先、未インストール時はフォールバック)
- **決定論ゲートを優先**: 重要な連鎖は `!command` 構文で SKILL.md に埋め込み、Claude の判断スキップを防ぐ
- 設計・チケット化はユーザー承認を挟む
- 勝手にマージ・push しない
- **バイアスなき品質検証**: 常にレビューは kill して spawn しながら進める
- **spec-reviewer.md / flow-reviewer.md の Anti-Bias Rules は共通仕様**: 特に「Sprint セマンティクス防衛」3 ルール (sprint 時間換算禁止 / 明記なき数値閾値禁止 / 数値判定のルール ID 引用義務) は両ファイルで完全同一である必要がある。片方だけ変更せず、常に両方同期する。同期マーカー `ANTI-BIAS-SYNC: vN` を両ファイル末尾のコメントで管理し、変更時はマーカーを bump する
- **Sprint 用語の SSoT は `planner.md` の「Sprint 用語の定義」セクション**: agent-core における「1 sprint = 1 atomic PR 相当の作業単位」という定義は planner.md が権威ソース。他の agent/skill MD は必要なら参照のみ行い、独自定義を書かない

## 旧ワークフローとの互換性

既存の `.agent-core/tickets/T-XXXX.json` (旧 `/create-ticket` で生成) は `/tdd-cycle` / `/ticket-cycle` deprecated alias でそのまま動作します。新規プロジェクトは `/planning` → `/generate` に切り替えを推奨。

1.3.0+ では deprecated skill の skill 本体は残存しており、冒頭に ⚠️ 注記のみ追加されています。
