---
name: e2e-evaluate
description: "E2E + UI/デザイン評価。アプリを実動テストし、AC 検証 + デザイン4軸評価を行う。Trigger: E2Eテスト, 受け入れテスト, UIチェック, デザイン評価"
context: fork
agent: acceptance-tester
disable-model-invocation: true
---

## E2E + Design Evaluation

### Stack 情報

!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

### Acceptance Criteria & 起動方法

$ARGUMENTS

### 指示

1. **アプリを起動**する（$ARGUMENTS の起動方法に従う）
2. **全画面を操作**して AC を1つずつ検証する（PASS/FAIL/PARTIAL）
3. **UI を持つアプリの場合**、デザイン4軸（Design Quality / Originality / Craft / Functionality）を採点プロセスに従って評価する
4. **Negative & Adversarial Testing** — 機能を壊そうとする（権限違反、二重実行、入力攻撃、境界違反）
5. 以下の形式でレポートする

### 出力形式

```markdown
## E2E + Design Evaluation Report

### AC Results
| Feature | Criterion | Status | Evidence |
|---------|-----------|--------|----------|
| [Name] | [Text] | PASS/FAIL/PARTIAL | [操作内容と結果] |
| [Negative] [Name] | [テスト内容] | PASS/FAIL | [Phase 3 の結果] |

### Design Scores（UI アプリの場合）
| Axis | Score | Adjustments | Evidence |
|------|-------|-------------|----------|
| Design Quality | X/10 | 5 → +N(理由) -N(理由) | [具体的な根拠] |
| Originality | X/10 | 5 → +N(理由) -N(理由) | [具体的な根拠] |
| Craft | X/10 | 5 → +N(理由) -N(理由) | [具体的な根拠] |
| Functionality | X/10 | 5 → +N(理由) -N(理由) | [具体的な根拠] |

### Negative Testing Results
| Category | Test | Result | Detail |
|----------|------|--------|--------|
| [カテゴリ] | [テスト内容] | PASS/FAIL | [観察結果] |

### Verdict: PASS / ITERATE (Confidence: HIGH/MEDIUM/LOW)
PASS: 全 AC PASS AND デザイン全軸 5/10 以上 AND Negative Testing で重大な問題なし
ITERATE: AC FAIL あり OR デザインしきい値未達 OR 重大な防御欠陥

### Issues（ITERATE の場合）
1. **[AC/Design/Negative]** [問題] → 修正指示: [具体的に何をどう直すか]
```

## Verdict 受理条件（オーケストレーターが検証）

acceptance-tester が PASS を返しても、以下を満たさなければ **PASS を受理しない**:

1. **Evidence 完全性**: AC Results の Evidence 列が空の AC が1つでもあれば拒否
2. **デザインスコア根拠**: Design Scores の Evidence 列が空の軸があれば拒否
3. **Negative Testing 実施**: Negative Testing Results セクションが含まれていなければ拒否
4. **Confidence 確認**: `Confidence: LOW` の場合、追加検証を検討

受理拒否時: acceptance-tester に「Evidence が不足。[具体的に何が足りないか] を補完せよ」と再実行指示。

## Regression Baseline（ITERATE 2ラウンド目以降）

ITERATE で再評価する場合、前回レポートの PASS 項目リストを $ARGUMENTS に含める:

```
### 前回 PASS 済み AC（回帰チェック対象）
- [Feature]: [Criterion] — PASS @ Round N
```

acceptance-tester への指示:
「以下の項目は前回 PASS だった。**最初にこれらの回帰テストを実施**し、回帰があれば即 ITERATE とする。回帰がなければ、今回の修正対象 AC の検証に進む。」

## Next

→ PASS: `/pr-description` で PR 作成
→ ITERATE: 修正指示に基づいて `/tdd-cycle` で修正 → 再度 `/e2e-evaluate`（最大3ラウンド）

---

## Gotchas

<\!-- post-mortem agent appends entries here -->
<\!-- Format: - [HASH8] [YYYY-MM-DD] <event>: <action> (hits: N, source: T-XXXX) -->
