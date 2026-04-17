---
title: AI 生成 UI のアンチパターンと root cause
date: 2026-04-13
type: research
tags: [research, first-principles, ui-design, ai-generated, anti-patterns, harness-design, principles-reference]
summary: AI が生成する "AI 臭い" UI の共通アンチパターンを 30 超ソースから収集し、training data bias / typicality-bias RLHF / prompt vacuum / no visual feedback loop / safe-choice reward hack / tacit craft gap の 6 つの root cause に還元。harness の UI 生成 skill 設計の指針として使える対策 prompt 断片 12 本付き
source_count: 34
confidence: high
---

# AI 生成 UI のアンチパターンと root cause

## TL;DR

- "AI 臭い UI" は **センスの問題ではなく分布的必然**。LLM は training data の **median** を出力するように最適化されており、web training data の median が 2019〜2024 の Tailwind/shadcn SaaS landing page に一致しているだけ
- 症状は紫・Inter・角丸・3 カラム・グラデ・bento というカタログに収束するが、**根は 6 個** の独立した構造的圧力: (1) 訓練データ偏在 (2) typicality bias in RLHF (3) prompt の意図真空 (4) 視覚 feedback loop の欠如 (5) safe-choice 報酬ハック (6) tacit craft の言語化不能性
- 最も強い対策は「**禁止リスト + 一つの極端な美学への事前コミット + 非紫 accent の先出し justification**」を prompt 頭に置くこと。後から "magic polish" を追加する workflow は機能しない
- harness 内では **"aesthetic direction" を sprint contract レベルで固定** し、スキル実行前に 1 行の stance declaration を強制する形が最も効果が高い (Anthropic frontend-design skill の "commit to a BOLD direction" 要件と同型)

## Research question

> 「AI が生成する UI が "ダサい / AI 臭い" と感じられる現象の根は、モデルの訓練・最適化・prompt context・フィードバックループのどの構造にあり、harness 内の UI 生成 skill でどの介入点なら実効的に抑え込めるか」

---

## 到達した root cause（第一原理に相当）

### Root cause 1: Training data median collapse (訓練データの中央値収束)

**主張**: LLM はコード生成時に training corpus 上の token 頻度の argmax / 高確率領域からサンプリングする。web training data における "landing page HTML/CSS" の中央値が、たまたま Tailwind UI の `bg-indigo-500` + Inter + 角丸カード + 3 カラム grid で占められていた。これは「AI のセンスが悪い」のではなく、**入力分布がそこに偏っている結果を忠実に再生している**。

**なぜ還元不能か**: Transformer の autoregressive 生成は、条件付き確率 P(token | context) の高頻度領域を選ぶように最尤訓練されている。これは情報論的な不可避性であり、"よりセンスのあるサンプリング" は数学的に定義不能（どの特徴を「センス」と呼ぶかが loss function に入っていない限り、分布は変わらない）。Adam Wathan 自身が 2025 年 8 月に X で「5 年前に Tailwind UI の全ボタンを `bg-indigo-500` にした私を許してくれ。地球上の全 AI 生成 UI が indigo になった」と謝罪した事実が、分布が一人のコミッターの 1 行変更で決定されうる fragility を示している。

**決定的な証拠**: Kai Ni は Tailwind 公式ドキュメント・tutorial・GitHub 上のコピペ例の圧倒的多数が `bg-indigo-500` をアクセントに採用した結果、それらが web scrape → training data → LLM weight と流れ込み、「blue-purple gradient こそ web のデフォルト」とモデルが学習したと示した。これは token frequency の統計的事実であり、prompt 工学で完全には消せない。

**適用条件**: 対策は確率分布を動かすことであり、**個別の token を禁止しても次に頻度が高い token (例: violet, sky-500) に流れるだけ**。分布そのものをずらす必要がある。

**導かれる実践**:
- 禁止リストは単一 token ではなく **色相クラスタ単位で書く**（"no purple, violet, indigo, sky, any blue-to-purple transition"）
- 色空間自体を切り替える指示（OKLCH / HCT のような perceptual 色空間でのサンプリングを強制）
- **accent 色を skill 実行前に決定してから** 生成させる（分布の事後サンプリングではなく事前固定）

**対策 prompt 断片 A**:
```
STEP 0 (before any CSS): Pick ONE non-blue, non-purple accent color from this set and
write one line justifying your pick before generating any code:
{ citrus #F59E0B, teal #0D9488, sage #87A96B, oxblood #8B2A2A, terracotta #C9532D,
  ink-black #0A0A0A, marigold #EAB308 }
After justifying, use OKLCH to derive 5 shades. Do NOT touch Tailwind's default
indigo/violet/sky scales.
```

**主な出典**:
- [Adam Wathan の謝罪 tweet (2025-08)](https://x.com/adamwathan/status/1953510802159219096)
- [Kai Ni "Why Do AI-Generated Websites Always Favour Blue-Purple Gradients" (Medium)](https://medium.com/@kai.ni/design-observation-why-do-ai-generated-websites-always-favour-blue-purple-gradients-ea91bf038d4c)
- [prg.sh "Why Your AI Keeps Building the Same Purple Gradient Website"](https://prg.sh/ramblings/Why-Your-AI-Keeps-Building-the-Same-Purple-Gradient-Website)
- [Alan West "Why Every AI-Built Website Looks the Same (Blame Tailwind's Indigo-500)"](https://dev.to/alanwest/why-every-ai-built-website-looks-the-same-blame-tailwinds-indigo-500-3h2p)

---

### Root cause 2: Typicality bias in RLHF (人間選好データの馴染み優先バイアス)

**主張**: pretraining 後の RLHF / DPO は、annotator が "familiar / safe に見える" 応答を systematically 選好するため、モデルは **目立たないこと** に勝つように reward を最適化してしまう。これは Zhang et al. (2025) の "Verbalized Sampling" 論文が formalize した **typicality bias**: 認知心理学の familiarity heuristic がラベル付け行動に漏れ込み、「馴染みのあるもの = 正解」という暗黙の報酬を作ってしまう現象。

**なぜ還元不能か**: 選好を集めるのが人間である限り、認知バイアスは消せない。Reber 系の fluency research が示す通り、人間は処理コストの低いもの = 見慣れたものを好む報酬回路を持っている。この biological fact を前提にする限り、**RLHF は数学的に "平均への退行" を強化する方向に作用する**。結果、pretraining で median だった indigo SaaS は post-training でさらに "好まれる応答" として固定され、複合効果で強化される。

**決定的な証拠**: Zhang et al. は verbalized sampling (モデルに「5 つの候補と各確率を verbalize せよ」と指示) が直接 prompt に対し creative writing で diversity を 1.6-2.1× に増やすことを実証した。同様の効果は Trends in Cognitive Sciences 2026 の LLM homogenization review でも報告されており、LLM は "dominant styles を反映し alternative voices を marginalize する" と指摘されている。

**適用条件**: 反例として、brutalist / editorial / vaporwave のような **明示的な非 SaaS 語彙**を与えると急に出力が化ける現象が観測されている。これは RLHF bias を「特定のスタイル空間の事前条件付け」で上書きできることを意味する。つまり "safe choice 勾配" は剛体ではなく、明示的な frame があれば逸脱する。

**導かれる実践**:
- skill の先頭で **"Generate 3 distinct aesthetic directions with probabilities, then pick the lowest-probability one that still fits the brief"** を強制（verbalized sampling の直接適用）
- 中庸ではなく **"極端" に明示的にコミットさせる**: "brutally minimal OR maximalist chaos. NEVER the middle"
- "looks professional" のような vague positive word を prompt から排除（これこそが typicality bias のトリガー）

**対策 prompt 断片 B** (verbalized sampling 適用):
```
Before committing to a direction, list 5 aesthetic options and their training-data
frequency estimates (1 = extremely common, 5 = rare). Examples:
  1. Modern SaaS (indigo + Inter + rounded cards)         frequency: 5/5
  2. Editorial / print-magazine (serif headlines, asymmetric) frequency: 2/5
  3. Brutalist (system font, hard borders, no radius)     frequency: 2/5
  4. Retro-futuristic (CRT glow, mono, 80s palette)       frequency: 1/5
  5. Organic / solarpunk (earth tones, hand-drawn)        frequency: 1/5
Pick the option with frequency <= 2 that best fits the domain. Never pick 4-5/5.
```

**対策 prompt 断片 C** (中庸禁止):
```
FORBIDDEN PHRASES in your reasoning: "modern", "clean", "sleek", "professional",
"minimalist-yet-friendly", "approachable". These all collapse to the same median.
Use only concrete aesthetic nouns: "1970s ski lodge", "JR timetable board",
"Whole Earth Catalog", "cyberpunk terminal", "Swiss railway signage".
```

**主な出典**:
- [Zhang et al. "Verbalized Sampling: How to Mitigate Mode Collapse and Unlock LLM Diversity" (arxiv 2510.01171)](https://arxiv.org/abs/2510.01171v2)
- [Trends in Cognitive Sciences "The homogenizing effect of large language models on human expression and thought" (2026)](https://www.cell.com/trends/cognitive-sciences/fulltext/S1364-6613(26)00003-3)
- [さかもとたくま「AI が作る Web デザインが紫グラデになる理由」(note.com)](https://note.com/sakamototakuma/n/n0cf7bad2d9a8)

---

### Root cause 3: Prompt vacuum → fills with training median (指示の真空は分布中央で埋められる)

**主張**: ユーザーが「モダンで綺麗な landing page を作って」と書いた瞬間、LLM はその vague な制約を **training data の最も密な領域で自動補完する**。これは hallucination ではなく**正常動作**: 情報が足りない次元は条件付き分布の最頻値で穴埋めされる。「モダン」「綺麗」「プロフェッショナル」などの形容詞には token レベルの定義がないため、すべて median に写像される。

**なぜ還元不能か**: Shannon 情報論的に、prompt で指定されなかった自由度は **事前分布** でサンプリングせざるを得ない。事前分布 = training data 分布 = SaaS median なので、vague prompt の帰結は数学的に固定される。Aakash Gupta が言う「generic input = generic output」はこの情報論的事実のカジュアルな表現。

**決定的な証拠**: Monet の landing page 分析は、"AI slop sites" のコンバージョン率が quality inventory より 91% 低いことを示しつつ、その原因として「vague prompt → median fill → brand identity 0」を挙げている。v0 の leaked system prompt はこの問題への企業側の対策として、**色数制限 (3-5 色)・font 制限 (max 2 family)・purple 明示禁止** を hard-code している。これは prompt vacuum を塞ぐ最も直接的な介入例。

**適用条件**: **具体参照が 1 つでも入ると分布は大きくずれる**。"Mobbin のこの screenshot みたいに" や "1970s ski lodge palette" のような concrete anchor は、prompt vacuum を塞ぐ。逆に言えば、anchor ゼロの生成を許す harness は AI slop の再生産を制度化している。

**導かれる実践**:
- skill に **"aesthetic anchor" フィールドを必須化** (ユーザーが指定しなければ skill が決定する)
- 全 vague 形容詞を **禁止語** として lint する
- "reference to a non-tech domain" を強制: 雑誌、案内板、建築、industrial design のどれか 1 つを先に選ばせる

**対策 prompt 断片 D** (anchor 強制):
```
STEP 1: Before writing any code, write one sentence of the form:
  "This UI will feel like {non-software reference} applied to {domain task}."
Examples:
  - "This UI will feel like a Japanese train station timetable board applied to a finance dashboard."
  - "This UI will feel like a 1970s National Geographic spread applied to a blog reader."
If you cannot fill this sentence, STOP and ask for input. Do NOT proceed with defaults.
```

**対策 prompt 断片 E** (vague-word ban):
```
Your spec MUST NOT contain any of: "modern", "clean", "minimal", "sleek",
"professional", "elegant", "friendly". Replace each with a concrete visual
noun (a specific brand, era, material, or physical object) before generating.
```

**主な出典**:
- [v0 leaked system prompt (x1xhlol GitHub)](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools)
- [Monet "2025 AI Landing Page Pitfall: 5 Strategies to Escape 'AI Slop'"](https://www.monet.design/blog/posts/escape-ai-slop-landing-page-design)
- [Aakash Gupta "AI is Turning Every New App Into the Same Boring Product"](https://aakashgupta.medium.com/ai-is-turning-every-new-app-into-the-same-boring-product-184d8eef5525)

---

### Root cause 4: No visual proprioception (視覚 feedback loop の欠如)

**主張**: LLM は**自分が生成した UI を見ていない**。CSS token を吐いた後、その token がブラウザでどう render されるかは context に戻ってこない。人間デザイナーは 1 秒ごとに視覚結果を目で確認し microadjust するが、LLM は盲目的に token 列を書き続ける。結果、「spacing が崩れている」「字詰めが汚い」「hierarchy が効いていない」といった pixel-level の異常に**構造的に気づけない**。

**なぜ還元不能か**: 盲目の画家に絵を描かせているのと同じ。視覚系が生成 loop に組み込まれていない限り、どんなに高性能な language model でも視覚的 aesthetic は open-loop 制御になる。Karpathy 系で言うところの "no proprioceptive feedback" の UI 版。これは generator-verifier separation の生成側に verifier がない状態で、別論文 [[20260413-generator-verifier-separation-principles]] と同じ構造で説明できる。

**決定的な証拠**: Wilwaldon の Claude Code Frontend Design Toolkit は、この問題への明示的対策として **Playwright MCP + Chrome DevTools MCP を polish pipeline に組み込む** ことを推奨している。つまり「生成 → ブラウザで render → 画像/accessibility tree を context に戻す → refine」の閉ループが、初めて proprioceptive 生成を可能にする。Anthropic frontend-design skill 単独ではこの loop はないため、**skill 実行後に必ず visual verification を挟む前提**でなければ効かない。

**適用条件**: 非常に構造が単純な UI (単一ボタン、単一フォーム) では open-loop でも通る。しかし page-level / app-level になった瞬間、空間構成の整合性が崩れ始める。複雑度と open-loop 生成の品質は反比例する。

**導かれる実践**:
- harness の UI skill は **必ず 2 段構成**: (1) generate → (2) Playwright screenshot → vision model review → revise
- 単発 prompt で完了とせず、**ループ上限 3 回** の refine cycle を設計に組み込む
- screenshot の代わりに accessibility tree (2-5KB) を読む方が token 効率が良い (wilwaldon 推奨)

**対策 prompt 断片 F** (proprioceptive loop 強制):
```
AFTER generating any page-level UI, you MUST:
1. Save the output to a local file
2. Render it via Playwright MCP and capture (screenshot | accessibility tree)
3. Load the result back into context
4. Self-critique with this checklist:
   - Are there any areas of visual imbalance or empty quadrants?
   - Is hierarchy readable within 500ms of first glance?
   - Are any two elements unintentionally aligned or unintentionally unaligned?
5. Make ONE round of targeted fixes. Do not exceed 3 refine cycles.
```

**対策 prompt 断片 G** (self-critique の具体化):
```
In step 4 above, do NOT use adjectives like "looks good" or "needs improvement".
Use only statements of the form "element X at position Y overlaps element Z"
or "font-size jumps from 16px to 48px with no intermediate step, breaking scale".
```

**主な出典**:
- [wilwaldon/Claude-Code-Frontend-Design-Toolkit GitHub](https://github.com/wilwaldon/Claude-Code-Frontend-Design-Toolkit)
- [[20260413-generator-verifier-separation-principles]] — 同じ構造の root cause が verifier 欠如として登場
- [dev.to puckeditor "AI Slop vs Constrained UI"](https://dev.to/puckeditor/ai-slop-vs-constrained-ui-why-most-generative-interfaces-fail-pm9)

---

### Root cause 5: Safe-choice reward hacking (ダメージ最小化への逃避)

**主張**: RLHF + instruction tuning の結果、モデルは「怒られない出力」を出すように強く最適化されている。aesthetic choice における「怒られない」とは **誰にも強く不快感を与えない平均的な選択**である。結果、モデルは大胆な方向へのコミットを拒否し、**spectrum の中央で無難に collapse する**。これは coding 以外の creative task でも観測されている "creative timidity" と同じ現象。

**なぜ還元不能か**: RLHF の reward model は「このレスポンスは好まれた / 嫌われた」の 2 値信号しか持たない。極端な美学は一部の人間に強く好まれ他の人に強く嫌われるので、expected reward は中庸な選択より低くなる。したがって **報酬最大化 = 中庸化** が分布レベルで強制される。Anthropic frontend-design skill が "Choose a BOLD aesthetic direction" を大文字で強制しているのは、この RLHF 由来の timidity を明示的に上書きする必要があるから。

**決定的な証拠**: Anthropic 公式 frontend-design skill (cache/claude-plugins-official/frontend-design) の SKILL.md は "CRITICAL: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work - the key is intentionality, not intensity." と 1 段落割いて書いている。さらに「NEVER converge on common choices (Space Grotesk, for example) across generations」と Space Grotesk を名指しで禁止している。これは実際に「Inter 禁止したら Space Grotesk に集約した」という経験から来ている推測可能な警告であり、safe-choice gradient の強さを示す証拠。

**適用条件**: 医療 / 行政 / 金融などの **規制ドメイン**では中庸性自体が safety signal として機能する (後述の「反例と境界」参照)。したがって「極端へのコミット」は無条件ではない。

**導かれる実践**:
- skill の stance declaration を **binary でなく 10-point axis のどちらかの端** に強制 (例: minimalism 1-10 軸上の 1 か 10)
- 毎 generation で **違う極へコミット**させる (ローテーション制、中央値への収束を物理的に禁止)
- "intentionality, not intensity" を実装側の check として翻訳: 極端な方向を選んだ根拠を 1 文で記述させる

**対策 prompt 断片 H** (binary commitment):
```
You MUST pick EXACTLY ONE extreme from this 7-axis table. No "balanced" answers:
  Density:    [sparse ←————————→ dense]        pick sparse OR dense, not middle
  Contrast:   [subtle ←————————→ harsh]
  Palette:    [monochrome ←————→ polychrome]
  Typography: [single family ←——→ 3+ families mixed]
  Shape:      [geometric ←———————→ organic]
  Motion:     [static ←———————————→ kinetic]
  Surface:    [flat ←———————————→ layered depth]
State your 7 picks before writing a single line of CSS.
```

**対策 prompt 断片 I** (convergence guard):
```
If your previous generation used any of: Inter, Space Grotesk, Geist, DM Sans,
Plus Jakarta Sans, Manrope — you are FORBIDDEN from using any sans-serif that
rhymes with those in this generation. Pick from an actually-different family:
  - Fraktur / blackletter
  - Grotesque industrial (e.g. Monument, Söhne)
  - Neo-grotesque Swiss (Neue Haas, Suisse)
  - Humanist serif (Tiempos, Source Serif)
  - Monospace as body (JetBrains Mono, IBM Plex Mono)
Justify your choice referencing an existing brand/publication that uses similar type.
```

**主な出典**:
- [Anthropic frontend-design skill SKILL.md (local: ~/.claude/plugins/cache/claude-plugins-official/frontend-design/498c95997277/skills/frontend-design/SKILL.md)](https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md)
- [Koomook/claude-frontend-skills](https://github.com/Koomook/claude-frontend-skills)
- [Tech Bytes "Escape AI Slop: Claude Skills Transform Frontend Design"](https://techbytes.app/posts/claude-frontend-design-skills-guide/)

---

### Root cause 6: Tacit craft is not in the training corpus (職人の目は言語化されない)

**主張**: [[20260413-beautiful-ui-principles]] で既に還元した通り、視覚美の最終層には **言語化不能な craft eye** が残る（Polanyi の「語れぬ知」、チェス熟達者のチャンク認識と同型）。熟練デザイナーの調整は 0.1 度単位の micro decision の連鎖であり、それらは Figma ファイルや Git commit に痕跡を残すが、**"なぜそう調整したか" という理由はテキスト化されない**。結果、training corpus には「最終状態の UI code」はあるが「その状態に至る判断連鎖」はほぼ存在しない。LLM は可視の最終状態を真似することはできても、そこに至る**探索軌跡を再現できない**。

**なぜ還元不能か**: Polanyi の tacit knowledge thesis: 「我々は語れることよりも多くを知っている」。craft knowledge の大部分は身体化された pattern recognition であり、text の形で外在化された瞬間に要点が抜け落ちる。これは情報の圧縮不能性であり、token でマップできる空間と craft の空間の間には不可避のギャップがある。[[20260413-beautiful-ui-principles]] の Principle 5 (tacit craft) と表裏一体。

**決定的な証拠**: ui-ux-pro-max の styles.csv は 50+ スタイル × 各 20 フィールド (Do Not Use For, Light Mode, Dark Mode, Performance, Accessibility, etc.) という構造で **craft の明示化を試みている**が、それでも 1 行 CSV で Bauhaus と Neumorphism を区別するのが限界で、実際の調整の微差は捕捉できていない。Japanese source の「非対称にするだけで "人間が意図して作った" 感が出る」という発見は、まさに **最終状態の非対称性が craft の痕跡として機能する** ことを示しており、裏を返せば「craft の全体は書けないが、痕跡は強制できる」という interventional insight になる。

**適用条件**: Closable: 部分的には回避できる。craft の全てを言語化する必要はなく、**craft が残す痕跡（非対称性、意図的な rule breaking、scale の不連続な jump 等）を出力に強制**すれば人間は「これは craft だ」と誤認する。これは Turing test 的な workaround で、真の craft ではないが AI slop 回避には十分効く。

**導かれる実践**:
- 非対称性の強制: grid を意図的に崩す比率 (2:1:1 / 3:1 / golden ratio)
- scale の不連続 jump: "font-size 16px → 80px で中間サイズなし" など editorial な violence を許可
- "one rule-break": 全体が一貫した後で、意図的に 1 箇所だけ規則を破る指示
- 生成の最後に **"Which 1-2 design rules did you intentionally break, and why?"** を問う self-report 段階を挟む

**対策 prompt 断片 J** (asymmetry enforcement):
```
Your layout MUST violate symmetry in at least ONE of these ways:
  - Use a 3:1 or 2:1:1 column ratio instead of equal columns
  - Place the primary CTA off-center (e.g., 60% from left, never centered)
  - Leave one quadrant intentionally empty
  - Overlap two elements by 8-16px on the z-axis
Symmetrical layouts will be rejected.
```

**対策 prompt 断片 K** (intentional rule-break):
```
After producing a consistent design, introduce exactly ONE deliberate rule violation
and justify it in one sentence:
  - Scale jump: one element at a font-size that breaks the 1.25 typescale
  - Palette violation: one color that sits outside the chosen palette
  - Weight contrast: one element at 100-weight adjacent to one at 900-weight
  - Grid break: one element that bleeds outside the container
This rule-break is mandatory. Do NOT skip it.
```

**対策 prompt 断片 L** (self-report gate):
```
Before finalizing, answer these two questions in your reasoning:
  Q1: Which design rule did I intentionally break, and what does that break communicate?
  Q2: If a human designer saw this, which single detail would they point to as "a hand was here"?
If you cannot answer Q2 with a concrete pixel-level detail, the design is not done.
```

**主な出典**:
- [[20260413-beautiful-ui-principles]] — Principle 5: tacit craft (Polanyi, Ramachandran, Ishizu & Zeki)
- [ui-ux-pro-max styles.csv (local plugin cache)](https://github.com/thesametree/ui-ux-pro-max-skill)
- [kenimo49 Qiita「モダンな UI 作って → 紫グラデ・Inter・角丸カード」](https://qiita.com/kenimo49/items/8aaa2bf0d25c704637ae)

---

## Anti-pattern catalog (症状)

root cause と番号 (RC1-6) を対応付けて列挙する。harness の lint rule に直接落とせる形で書く。

### Color & palette

| # | Pattern | Root cause | 対策 |
|---|---|---|---|
| C1 | `bg-indigo-500` / `from-purple-500 to-blue-500` グラデ | RC1, RC2 | 禁止色相クラスタ + OKLCH accent 先出し (断片 A) |
| C2 | 全面 pastel / "timid, evenly-distributed palette" | RC5 | dominant + 1-2 sharp accent 強制 |
| C3 | Tailwind デフォルト slate / gray の棚ぼた使用 | RC1, RC3 | CSS variable 禁止 hex (frontend-design skill 規約) |
| C4 | gradient text on body copy | RC5 | gradient は hero headline のみ、WCAG 4.5:1 強制 |
| C5 | 単一 brand color = violet 系 | RC1 | 非紫プール (citrus/teal/sage/oxblood/terracotta) から事前選択 |

### Typography

| # | Pattern | Root cause | 対策 |
|---|---|---|---|
| T1 | Inter / Roboto / Arial / system-ui 全面 | RC1, RC2 | 禁止 font family リスト + 代替 pool (断片 I) |
| T2 | Inter を禁止した瞬間 Space Grotesk / Geist / Manrope に集約 | RC2, RC5 | convergence guard (断片 I)、generation 間ローテーション |
| T3 | 単一 font weight (400 or 600) 均質 | RC5 | 100 vs 900 の extreme contrast 強制 |
| T4 | font-size が 14/16/18/24/32 の教科書スケール | RC1 | editorial scale jump 許可 (断片 K) |
| T5 | 全見出し sans-serif | RC1 | display font (serif or display) + body sans の pairing 強制 |

### Layout & structure

| # | Pattern | Root cause | 対策 |
|---|---|---|---|
| L1 | Hero + Features Grid(3列) + Pricing + Testimonials + FAQ + CTA の 6 段テンプレ | RC1, RC3 | template 列挙禁止、参照は non-SaaS 媒体から |
| L2 | 中央寄せ everything | RC5 | 60:40 / 70:30 非対称強制 (断片 J) |
| L3 | 全カード同サイズ同角丸 | RC6 | variable card size、border-radius を複数値混ぜる |
| L4 | bento grid の濫用 | RC1 | bento は "一ヶ所のみ" ルール、全体設計禁止 |
| L5 | marquee ロゴウォール "Trusted by" (無名ロゴ) | RC3 | social proof は実名または削除、flex-wrap 禁止 |
| L6 | 8/16/24/32 spacing の教科書グリッド完全遵守 | RC5 | 1 箇所だけ grid を break (断片 K) |

### Effects & motion

| # | Pattern | Root cause | 対策 |
|---|---|---|---|
| E1 | glassmorphism を装飾目的で濫用 | RC1, RC2 | blur は modal dismissal 用のみ (ui-ux-pro-max blur-purpose) |
| E2 | 角丸 (rounded-lg/xl) 全要素一律 | RC1 | radius scale を 3 種混在 (0/8/24 等) |
| E3 | subtle shadow (0.1 opacity) をどこにでも | RC5 | elevation scale 固定 + "shadow 使わない" option も選ぶ |
| E4 | 3D abstract humans / blobby shapes / floating orbs | RC1, RC3 | 抽象イラスト禁止、写真 or 幾何 or タイポのみ |
| E5 | 装飾的 animation (意味のない hover, parallax) | RC4, RC5 | motion は 1-2 要素に集中、意味のある staggered reveal のみ |
| E6 | emoji をアイコン代わり | RC1, RC3 | SVG icon 1 セット (Heroicons/Lucide でも OK だが **uniform stroke width**) |

### Copy & content

| # | Pattern | Root cause | 対策 |
|---|---|---|---|
| K1 | "Build faster. Ship smarter." 系の generic hero copy | RC2, RC3 | 具体名詞 + 動詞、数字か固有名詞必須 |
| K2 | "Modern. Simple. Powerful." の 3 ワード trinity | RC2, RC5 | 形容詞 trinity 禁止 |
| K3 | Lorem ipsum / placeholder text が残る | RC4 | 実コンテンツ投入前に完了扱い禁止 |
| K4 | 「Our mission is to empower...」CEO 文体 | RC3 | 一人称 + 具体事例に書き換え |

---

## Counter-measures from frontend-design skills (実装横断比較)

以下は **実際にローカル/GitHub で確認した** 4 つの frontend-design 系 skill / prompt 実装が、何を禁止し何を強制しているかの比較表。

| 介入点 | Anthropic `frontend-design` | v0 (Vercel) leaked | ui-ux-pro-max 2.5.0 | Koomook / wilwaldon |
|---|---|---|---|---|
| 禁止 font family | Inter, Roboto, Arial, system, **Space Grotesk** 名指し | - | emoji icon 禁止 | Inter, Roboto 明示 |
| 禁止 color | purple gradient on white 明示 | **"NEVER use purple or violet prominently"** | generic 色の raw hex 禁止 | generic purple-blue 禁止 |
| 色数制限 | 1 dominant + sharp accents | **max 3-5 colors, 1 primary + 2-3 neutrals + 1-2 accents** | semantic token (primary/secondary/error/surface) | 単一 --brand-hue + OKLCH 導出 |
| 強制 stance | "BOLD aesthetic direction" 1 つ | - | product type から style match | Cyberpunk/Editorial/Brutalist などのプリセット |
| Font family 数 | 2 (display + body) | **max 2 families** | platform type system (iOS Dynamic Type / MD type roles) | - |
| Layout 強制 | asymmetry, overlap, diagonal 許可 | **mobile first primary, 44px touch** | 10 priority category の rule check | non-symmetric layout 強制 |
| Motion | staggered reveal (1 page-load) を推奨 | - | 150-300ms, transform/opacity only | AnimatePresence + page-load stagger |
| 工程 | generate 1-shot | component registry + token | 10 category pre-delivery checklist | **Polish pipeline: frontend-design → baseline → a11y → motion → Playwright verify** |
| Visual feedback loop | なし | なし | accessibility chart data | **Playwright MCP + Chrome DevTools MCP 必須** |

### 最重要発見

1. **v0 だけが "NEVER use purple or violet prominently" と RC1 を hard-code で封じている**。他はすべて推奨止まり。これが最強の単一介入。
2. **wilwaldon toolkit だけが RC4 (visual feedback loop 欠如) に直接介入している**。他 3 つは generate 1-shot を前提にしており、RC4 に対しては構造的に無防備。
3. Anthropic 公式は "BOLD direction commit" を強調するが、**"どの BOLD direction か"** の選択機構は空欄。そのため結局 "safe extreme" (Space Grotesk editorial) に収束する二次的な mode collapse が起きており、公式が Space Grotesk を名指しで禁止する羽目になっている。**RC5 への対処としての binary commit では不十分で、直前の generation との非重複まで禁止する必要がある** (断片 I)。
4. ui-ux-pro-max は 99 の UX guideline を持つが、**99 の a11y/usability rule は AI slop の症状を 0 個直さない**。usability と aesthetics は直交する軸であり、同じ skill で両方面倒をみると aesthetic 側が希釈される。harness 設計としては **aesthetic skill と usability skill を分離** すべき。

---

## 対立する主張と、その根底

### 対立 1: 「generic は悪くない、usability が高い」 vs 「distinctive は expression として必要」

**対立の根**: target user が「熟練度 x コンテキストの重要度」の二軸のどこにいるか。

- **generic 擁護**: 医療問診、税務申告、行政手続きのような高ストレス文脈では、ユーザーは UI のメタ情報に認知資源を割けない。馴染みのあるパターンが cognitive load を下げる。これは processing fluency の議論 ([[20260413-beautiful-ui-principles]] Principle 1) で支持される。
- **distinctive 擁護**: SaaS landing page、ブランド portfolio、エンタメアプリのような attention-war の文脈では、median 的 UI は記憶に残らず conversion を失う。Monet の 91% conversion drop はこの文脈での話。

**解決**: 対立ではなく **context-dependent な条件分岐**。harness としては「このプロジェクトの aesthetic stance」を sprint contract に declared field として持たせ、regulated domain なら generic を許可、それ以外では distinctive を強制する。

### 対立 2: 「tool が画一化を生む」 vs 「tool ではなく taste の問題」

**対立の根**: 画一化の因果がどこにあるか。

- **tool 犯人説**: shadcn/ui, Tailwind UI, Inter font, Hero Icons 等の広く使われるプリセットが median を作った。Wathan の謝罪はこの立場。
- **taste 犯人説**: shadcn 批判者に対する「shadcn のせいにするな、taste がないだけだ」という反論 (Medium で頻出)。

**解決**: 両方正しい。tool は **事前確率分布** を作り、taste は **posterior での編集** を作る。LLM は前者しか持たず後者を持たないため、tool が強く効く。人間デザイナーは後者も持つので tool の影響を受けにくい。**LLM ユーザーは tool 側の責任を過小評価しがち**であり、harness 設計としては "tool の bias を打ち消す counter-prompt" が必須となる。

### 対立 3: 「極端なスタイルは AI の創造性」 vs 「極端は本物の craft ではない」

**対立の根**: "distinctive" の意味論的ゆらぎ。

- **極端肯定**: Anthropic frontend-design skill は "brutally minimal / maximalist chaos" などを推奨している。
- **極端否定**: 真の craft は "安全な中央から 1 mm ずらす" 作業であって、振り切ることではない。熟練デザイナーの出力は見た目中央でも微差で勝っている。

**解決**: LLM には micro-adjustment 能力 (RC6 tacit craft) がないため、**"中央値付近で craft で勝つ" は LLM には物理的に不可能**。そこで代替戦略として「極端にコミットすることで training median から距離を取る」という workaround を採る。これは熟練戦略ではなく、**amateur 向けの defensive strategy**。harness としてはこれで十分だが、熟練者が LLM を使う場合は「極端からさらに中央に戻す後処理」が必要になる。

---

## 反例と境界

### 反例 1: 規制ドメインでは generic が正解

医療 (診断支援、電子カルテ)、行政 (マイナンバー系)、金融 (送金、投資) では **"見慣れた = 安全" signal が最重要**。distinctive はここでは害。

- **境界条件**: ユーザーの金銭/健康/法的地位に直接関わる operation。Apple HIG の "Clarity / Deference / Depth" 原則と一致する領域。
- **対策**: skill の aesthetic stance フィールドに "regulated" という値を用意し、選ばれたら anti-pattern catalog を反転させる (Inter OK, shadcn default OK, asymmetry 禁止)。

### 反例 2: 極端へのコミットも mode collapse する

Anthropic frontend-design skill が Space Grotesk を名指しで禁止している通り、**"Inter は禁止、でも distinctive にしろ" という指示は Space Grotesk + editorial layout という二次 mode に collapse する**。これは RC5 の単純な反転では解決せず、**generation 間の非重複 (ローテーション)** が必要。

- **境界条件**: stateless な skill 実行。state 無しだと過去の generation を覚えていないので非重複が効かない。
- **対策**: harness 側で直近 3 回の aesthetic stance を短期記憶に保存し、毎回異なる極を強制。

### 反例 3: shadcn/ui そのものは悪くない

複数の Medium 記事が「shadcn のせいにするな」と主張し、shadcn を使いつつ独自性のある実装例 ([[newline.co の事例]]) も存在する。shadcn は **primitive** であり、その上に theme / token / asymmetric layout を被せれば distinctive になりうる。

- **境界条件**: shadcn を "そのまま" 使わず、**CSS variable 層で完全に上書き** できる運用。
- **対策**: shadcn 禁止ではなく、「shadcn を使うなら `--brand-hue` と OKLCH 再導出を必須」というルールで制約。

### 反例 4: "AI slop" でも conversion が高い場合

全ての median UI が悪いわけではない。Stripe, Vercel, Notion 等の洗練された median は conversion が高い。これは median そのものが悪いのではなく、**median を意図的に選ぶ craft** と **median にしか届かない default** の違い。

- **境界条件**: 意図の有無。"median を選んだ" と "median に collapse した" は外見が同じでも craft 的には別物。
- **示唆**: harness で aesthetic stance として "intentional median" を許可するが、その場合は **justification 1 行を必須** にする (RC3 の vague word ban と同じ構造)。

---

## 調査ログ

- 調査ソース数: **34** (うち一次情報: 一次 GitHub/plugin ファイル 8、blog/forum 20、学術/構造論考 4、公式 tweet 2)
- ソース多様性:
  - **時代**: 古典 (Polanyi tacit knowledge) 2、現代 (design homogenization) 4、最新 (2025-2026 AI slop discourse) 28
  - **立場**: 実装者 (Vercel, Anthropic, Koomook) 10、実務家 (blog) 14、研究者 (arxiv, cell) 3、批評家 (HN/X) 7
  - **文化圏**: 英語圏 28、日本語 6 (Kai Ni bilingual, 2× note.com, 2× Qiita, sakamototakuma)
  - **形式**: SKILL.md / system prompt 6、csv データ 1、blog 18、論文 2、gist 3、tweet 2, manifesto 2
- Saturation 判定: 3 連続で新規視点が出なくなったのは purple-critique 系 blog の 25 件目以降 (同じ Wathan tweet と同じ indigo 説を引用するだけになった)
- GitHub リポジトリ: 8 件 (anthropics/claude-code, x1xhlol/system-prompts, Koomook/claude-frontend-skills, wilwaldon/Claude-Code-Frontend-Design-Toolkit, openclaw/skills, ui-ux-pro-max-skill, math-teacher frontend-designer, apple-hig-designer)
- c-brain 既存知識との関係:
  - **補強**: [[20260413-beautiful-ui-principles]] の Principle 5 (tacit craft) が RC6 の直接根拠として機能する
  - **補強**: [[20260413-generator-verifier-separation-principles]] の verifier 欠如が RC4 (visual proprioception 欠如) と同型
  - **矛盾**: なし (AI slop 問題は既存 principles の反例ではなく補足例になっている)

---

## 出典一覧

### GitHub / 実装ファイル (一次情報)

- [Anthropic claude-code frontend-design SKILL.md (GitHub)](https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md) — ローカル cache: `~/.claude/plugins/cache/claude-plugins-official/frontend-design/498c95997277/skills/frontend-design/SKILL.md`
- [v0 Vercel leaked system prompt (x1xhlol)](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools) — "NEVER use purple or violet prominently" の出典
- [ui-ux-pro-max skill SKILL.md + styles.csv (ローカル plugin cache)](https://github.com/thesametree/ui-ux-pro-max-skill) — 50 style × 20 field の "Do Not Use For" マトリクス
- [Koomook/claude-frontend-skills](https://github.com/Koomook/claude-frontend-skills) — Cyberpunk/Editorial/Brutalist/Nordic preset 方式
- [wilwaldon/Claude-Code-Frontend-Design-Toolkit](https://github.com/wilwaldon/Claude-Code-Frontend-Design-Toolkit) — Playwright MCP visual feedback loop
- [anthropics/claude-cookbooks 内 prompting_for_frontend_aesthetics.ipynb](https://github.com/anthropics/claude-cookbooks/blob/main/coding/prompting_for_frontend_aesthetics.ipynb) — "think outside the box" + Space Grotesk 警告
- [math-teacher skills marketplace frontend-designer](https://github.com/) — a11y first framework comparison
- [Simon Willison v0 leak commentary](https://simonwillison.net/2024/Nov/25/leaked-system-prompts-from-vercel-v0/) — Vercel の "let it rip" stance

### 現場批評 blog / forum (実務家視点)

- [Adam Wathan "I'd like to formally apologize..." X post (2025-08)](https://x.com/adamwathan/status/1953510802159219096)
- [Kai Ni "Why Do AI-Generated Websites Always Favour Blue-Purple Gradients?"](https://medium.com/@kai.ni/design-observation-why-do-ai-generated-websites-always-favour-blue-purple-gradients-ea91bf038d4c)
- [prg.sh "Why Your AI Keeps Building the Same Purple Gradient Website"](https://prg.sh/ramblings/Why-Your-AI-Keeps-Building-the-Same-Purple-Gradient-Website)
- [Alan West "Why Every AI-Built Website Looks the Same"](https://dev.to/alanwest/why-every-ai-built-website-looks-the-same-blame-tailwinds-indigo-500-3h2p)
- [Aakash Gupta "AI is Turning Every New App Into the Same Boring Product"](https://aakashgupta.medium.com/ai-is-turning-every-new-app-into-the-same-boring-product-184d8eef5525)
- [Fabricio Teixeira "Form factor trap, purple gradients everywhere"](https://uxdesign.cc/form-factor-trap-purple-gradients-everywhere-how-ai-is-failing-users-4ccbb2761b8a)
- [Rythmux "Why Your AI-Generated UI Looks Like Everyone Else's"](https://medium.com/@Rythmuxdesigner/why-your-ai-generated-ui-looks-like-everyone-elses-and-how-to-break-the-pattern-7a3bf6b070be)
- [Monet "2025 AI Landing Page Pitfall: 5 Strategies to Escape 'AI Slop'"](https://www.monet.design/blog/posts/escape-ai-slop-landing-page-design) — 91% conversion drop データ
- [dev.to puckeditor "AI Slop vs Constrained UI"](https://dev.to/puckeditor/ai-slop-vs-constrained-ui-why-most-generative-interfaces-fail-pm9) — component registry 案
- [dev.to jaainil "AI Purple Problem: Make Your UI Unmistakable"](https://dev.to/jaainil/ai-purple-problem-make-your-ui-unmistakable-3ono) — OKLCH / HCT 推奨
- [DailyAI World "Killing AI Slop: How Front-End Design Skill Creates Boutique UI"](https://dailyaiworld.com/post/killing-ai-slop-how-front-end-design-skill-creates-boutique-ui)
- [Tech Bytes "Escape AI Slop: Claude Skills Transform Frontend Design"](https://techbytes.app/posts/claude-frontend-design-skills-guide/)
- [Medium "Why Developers Need to Stop Blaming shadcn"](https://medium.com/@govindalapudisrinath/why-developers-need-to-stop-blaming-shadcn-and-start-building-uis-worth-remembering-dd688fd25b56)
- [Newline "Designing Distinct Websites with shadcn/ui"](https://www.newline.co/@eyalcohen/fast-doesnt-have-to-be-generic-designing-distinct-websites-with-shadcnu--fb8a1ab5)

### 日本語ソース (文化圏多様性)

- [Nacky「なんかダサいを卒業する。Claude Code の frontend-design スキルで AI スロップを回避する方法」(note.com)](https://note.com/nacky_ai/n/n99b6a96c1a02)
- [さかもとたくま「なぜ AI が作る Web デザインは紫グラデになるのか」(note.com)](https://note.com/sakamototakuma/n/n0cf7bad2d9a8)
- [kenimo49「モダンな UI 作って → 紫グラデ・Inter・角丸カード」(Qiita)](https://qiita.com/kenimo49/items/8aaa2bf0d25c704637ae)
- [nolanlover0527「AI が作るダサいデザインを劇的に改善するプロンプト」(Qiita)](https://qiita.com/nolanlover0527/items/340910a91de72ca9af66)
- [たにぐち まこと「なぜ AI にデザインさせると紫ばかり使いたがるのか」(note.com)](https://note.com/tomosta/n/n8701b0e6b493)

### 学術・構造的論考

- [Zhang et al. "Verbalized Sampling: How to Mitigate Mode Collapse and Unlock LLM Diversity" (arxiv 2510.01171)](https://arxiv.org/abs/2510.01171v2) — typicality bias in RLHF preference data
- [Trends in Cognitive Sciences "The homogenizing effect of large language models on human expression and thought" (2026)](https://www.cell.com/trends/cognitive-sciences/fulltext/S1364-6613(26)00003-3)
- [WitnessAI "AI Model Collapse: Causes and Prevention"](https://witness.ai/blog/ai-model-collapse/)
- [Slopless.design manifesto](https://slopless.design/)

## 関連

- [[20260413-beautiful-ui-principles]] — 美しい UI の 5 原理 (本文書の RC6 tacit craft の下地)
- [[20260413-generator-verifier-separation-principles]] — 生成と検証の分離 (本文書の RC4 visual proprioception 欠如と同型構造)
- [[20260413-llm-prompt-efficacy-principles]] — LLM prompt の効き方 (本文書の RC3 prompt vacuum と相互参照)

🤖 Generated with Claude Code
