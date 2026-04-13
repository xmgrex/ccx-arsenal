---
name: tier-matrix-review
description: "3 ヶ月周期で .agent-core/sprints/ と post-mortem の Tier Matrix Suggestion を集計し、tier 判定ルール (classify-tier.sh と tier-matrix.md) の改定案を提示する。構造層 Gotcha 学習の HITL ゲート。Trigger: /tier-matrix-review, 四半期レビュー, tier 判定見直し"
disable-model-invocation: false
---

# Tier Matrix Review — 構造層 Gotcha の HITL 集約スキル

## Usage

```
/tier-matrix-review [--since=YYYY-MM-DD]
```

- `--since`: 集計開始日 (省略時は 3 ヶ月前)

---

## 設計原理

H-Consensus の Gotcha 2 層学習のうち、**Layer 2 (構造層)** を担当するスキル。

- **Layer 1 (prompt層)**: post-mortem agent が sprint 終了後に随時 agent/skill MD 末尾に append
- **Layer 2 (構造層)**: **このスキル**が 3 ヶ月周期で sprint ログと post-mortem の提案を集計 → tier 判定ルール改定案を HITL レビュー

構造層は agent の prompt 改善では直らない問題 (tier が誤判定された、fork 構成が適さなかった等) を扱う。頻繁に書き換えるべきではないため、3 ヶ月周期で HITL ゲートを必ず通す。

---

## 決定論ゲート (スキルローダー実行)

### ゲート 1: Sprint ログ集計

3 ヶ月以内の sprint 件数: !`find .agent-core/sprints -name 'S-*.json' -mtime -90 2>/dev/null | wc -l`

3 ヶ月前の日付: !`date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d`

### ゲート 2: Tier 別集計

T1 sprint 件数 (3ヶ月): !`find .agent-core/sprints -name 'S-*.json' -mtime -90 2>/dev/null | xargs -I{} grep -l '"tier": "T1"' {} 2>/dev/null | wc -l`

T2 sprint 件数 (3ヶ月): !`find .agent-core/sprints -name 'S-*.json' -mtime -90 2>/dev/null | xargs -I{} grep -l '"tier": "T2"' {} 2>/dev/null | wc -l`

T3 sprint 件数 (3ヶ月): !`find .agent-core/sprints -name 'S-*.json' -mtime -90 2>/dev/null | xargs -I{} grep -l '"tier": "T3"' {} 2>/dev/null | wc -l`

### ゲート 3: エスカレーション件数

3 ヶ月の ESCALATED sprint: !`find .agent-core/sprints -name 'S-*.json' -mtime -90 2>/dev/null | xargs -I{} grep -l '"verdict": "ESCALATED"' {} 2>/dev/null | wc -l`

### ゲート 4: 現行 tier-matrix.md

現行 tier-matrix 存在確認: !`test -f .agent-core/tier-matrix.md && echo "exists" || echo "missing"`

---

## 指示 (main Claude orchestrator 版)

あなたは `/tier-matrix-review` の orchestrator です。3 ヶ月間の sprint 運用実績から tier 判定ルールの改善点を抽出し、ユーザーに改定案を提示せよ。

### Step 1: データ収集

#### Step 1-A: sprint JSON の読み込み

ゲート 1-3 で得られた件数を確認。sprint が 10 件未満なら**早期終了**:

```
⚠️ 集計対象 sprint が {N} 件しかありません (10 件未満)。
tier matrix 改定には統計的サンプルが不足しています。
次回 /tier-matrix-review は sprint が 10 件以上蓄積された後に実行してください。
```

10 件以上ある場合、以下を Read で収集:

```bash
find .agent-core/sprints -name 'S-*.json' -mtime -90 -type f
```

各 sprint JSON から以下を抽出:
- `sprint_id`, `ticket_id`, `tier`, `cold_start_override`, `manual_force`, `iterations`, `verdict`
- `tier_metadata` (ticket JSON を join して参照)

#### Step 1-B: post-mortem の Tier Matrix Suggestion を収集

全 post-mortem レポートの `### Tier Matrix Suggestion` セクションを grep で抽出:

```bash
grep -rA 5 "### Tier Matrix Suggestion" .agent-core/sprints/ 2>/dev/null
```

各提案を `TIER_SUGGESTIONS` リストに集約。

### Step 2: パターン分析

以下の**定量的パターン**を機械的に検出する (LLM 的判断ではなく決定論集計):

#### Pattern A: Tier 判定の偏り
- T1 / T2 / T3 の実行比率
- 健全な分布: T1 15-30%, T2 50-70%, T3 10-25%
- 偏りが大きい場合、tier 判定ルールの閾値が不適切な可能性

#### Pattern B: Escalation 多発 tier
- tier 別の ESCALATED 件数を集計
- どの tier でエスカレーションが多発しているかを確認
- **T2 で escalation 多発** → fork 構成が不十分 (T3 化を検討)
- **T1 で escalation 多発** → 閾値が緩すぎて本来 T2 相当が T1 に落ちている

#### Pattern C: Iteration 過多
- 各 tier で iteration が 3 round 以上の sprint を抽出
- T2 で iteration 過多 → test-auditor 欠如が原因の可能性
- T1 で iteration 過多 → T1 判定ルールが甘い可能性

#### Pattern D: manual_force が発動した sprint
- ユーザーが `--force-tier` で判定を上書きしたケース
- 発動回数が多い tier → 自動判定の信頼性が低い

#### Pattern E: post-mortem からの集約提案
- `TIER_SUGGESTIONS` 内の重複提案を頻度順にソート
- 3 件以上の独立 sprint から同じ提案が出ていれば採用候補

### Step 3: 改定案の生成

Pattern A-E の結果を元に、以下の候補を生成する:

#### 3-A: classify-tier.sh の閾値変更案
- 現行 surface threshold (10) を変更すべきか
- 現行 risk_layer のカテゴリ分けを変更すべきか (新規 layer を追加 or 既存を統合)

#### 3-B: tier-matrix.md の記述更新案
- 各 tier の典型例を実データで更新
- post-mortem 提案を反映した判定ルール追記

#### 3-C: cold-start-check.sh の閾値変更案
- 現行の sprint 20 / gotcha 10 の閾値が適切だったか
- 実績から最適値を逆算

### Step 4: 改定案の HITL 提示

以下の Handoff Document でユーザーに提示:

```markdown
## Tier Matrix Review Report (since {SINCE_DATE})

### Sprint Statistics
- Total: {N} sprints
- T1: {N1} ({P1}%)
- T2: {N2} ({P2}%)
- T3: {N3} ({P3}%)
- Escalated: {NE} ({PE}%)
- Cold-start override: {NC}
- Manual force: {NM}

### Pattern Findings

#### Pattern A (Distribution Balance)
- 実測分布: T1 {P1}%, T2 {P2}%, T3 {P3}%
- 健全範囲: T1 15-30%, T2 50-70%, T3 10-25%
- 判定: {within_range / too_low_T1 / too_high_T3 / etc.}

#### Pattern B (Escalation by Tier)
- T1 escalation: {n} / {total}
- T2 escalation: {n} / {total}
- T3 escalation: {n} / {total}
- 顕著な偏り: {yes/no, 詳細}

#### Pattern C (Iteration Excess)
- iteration >= 3 round が発生した sprint: {count}
- 最も iteration 過多だった tier: {tier}

#### Pattern D (Manual Force Frequency)
- --force-tier 発動: {count} 回
- 最多上書き先: {tier}

#### Pattern E (Post-Mortem Proposals)
- 収集した提案数: {count}
- 頻度 3 以上の共通提案 (採用候補):
  1. {proposal 1} (頻度 {N1})
  2. {proposal 2} (頻度 {N2})
  3. {proposal 3} (頻度 {N3})

---

### 改定案

#### Proposal 1: classify-tier.sh の閾値変更
- 対象: [surface threshold / risk_layer mapping / etc.]
- 現行: [現在の値]
- 推奨: [新値]
- 理由: [Pattern A/B/C のどれに基づくか]
- 適用影響: 過去 3 ヶ月 {N} sprint のうち {M} sprint が再分類される見込み

#### Proposal 2: tier-matrix.md 記述更新
- 追記内容: [具体的な文言]
- 理由: [Pattern E の post-mortem 提案を反映]

#### Proposal 3: cold-start-check.sh 閾値調整
- 対象: [sprint / gotcha 閾値]
- 現行: 20 / 10
- 推奨: [新値]
- 理由: [実績データに基づく逆算]

---

### 選択肢

1. Proposal 1/2/3 を全て承認 → 自動適用 → git diff で確認
2. 一部のみ承認 → 個別選択
3. 全て却下 → 現状維持
4. 分析結果だけ見て、修正は後回し
5. 次回レビュー日を再設定 (早める / 遅らせる)

どれにしますか？
```

### Step 5: 承認後の適用 (HITL 承認時のみ)

ユーザーが承認した Proposal のみ適用する。

#### 5-A: classify-tier.sh の変更
- `plugins/agent-core/scripts/classify-tier.sh` を Edit で変更
- 変更後、テストケースで動作確認 (4 パターン smoke test)

#### 5-B: tier-matrix.md の変更
- `.agent-core/tier-matrix.md` が存在しなければ `plugins/agent-core/scripts/tier-matrix-initial.md` をコピーしてから Edit
- 追記内容を Edit で反映

#### 5-C: cold-start-check.sh の変更
- `plugins/agent-core/scripts/cold-start-check.sh` を Edit で変更

#### 5-D: Review 実施記録

`.agent-core/tier-matrix-reviews/YYYY-QN.md` に実施記録を残す:

```markdown
# Tier Matrix Review YYYY-QN ({実施日})

## Sprints Analyzed
{集計結果}

## Proposals Applied
- Proposal 1: {採用 / 却下}
- Proposal 2: {採用 / 却下}
- Proposal 3: {採用 / 却下}

## Applied Diff
{git diff --stat}

## Next Review Due
{3ヶ月後の日付}
```

---

## Rules

- このスキルは **HITL 必須** (自動適用は禁止)
- 3 ヶ月周期の運用を推奨 (頻繁な変更は tier 判定の一貫性を損なう)
- 10 sprint 未満の集計では改定しない (統計的有意性不足)
- 改定後は必ず classify-tier.sh の smoke test を実行
- 却下された Proposal も記録に残す (将来の再検討のため)

## Next

→ ユーザー承認後: 自動適用 → smoke test → 次回レビュー日予約
→ 却下時: 現状維持、記録だけ残す
→ 3 ヶ月後: 再度 `/tier-matrix-review` を実行

---

## Gotchas

<!-- post-mortem agent appends entries here -->
<!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
