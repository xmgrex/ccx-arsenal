---
title: 生成と検証の分離の第一原理
date: 2026-04-13
type: research
tags: [research, first-principles, software-engineering, verification, agent-architecture, principles-reference]
summary: 「同じ LLM でも writer と reviewer を分離するだけでなぜ品質が上がるのか」を、計算複雑性 (P vs NP)・ピアレビュー実証研究・GAN/actor-critic・著者校正盲目性・認知距離 (construal level)・adversarial collaboration の 32 出典から還元した 5 つの第一原理。Claude Code Harness の TDD cycle / reviewer agent / verify-local gate / reward hack 検出の設計根拠として使える形にまとめた。
source_count: 32
confidence: high
---

# 生成と検証の分離の第一原理

## TL;DR

- **検証は生成より構造的に易しい**（一般には言い切れないが、NP に位置付けられるタスク — コード・論証・仕様合致判定 — では成立する）。この非対称性こそ separation が pay する根本理由 ([[verifier-law]])
- **書き手は自分の「意図」と「出力」を区別できない**。インテンション（頭の中の想定）が知覚を上書きし、バグ・誤字・論理飛躍が「無かったこと」にされる (inattentional blindness, Stafford)
- **生成コンテキストと検証コンテキストは認知的に別モード**であるべき。construal level 理論と writer/editor 分離論はこれを支持する。同一モデルでもコンテキストを fork すれば異なる「注意の焦点」を得られる
- **検証者の独立性は "偽の合意" を壊すために必要**。reward hacking / Goodhart の法則が示す通り、生成と検証が同じ目的関数を共有すると検証は sycophant 化する
- **ただし検証独立性は handoff cost と trade-off する**。過剰分離は context loss を生み、ピュアな intrinsic self-correction は LLM でも人間でも崩れる。境界条件は「検証基準が外在し、かつ構造化されている」ことにある

## Research question

> 「同一モデル能力を持つ writer と reviewer を物理的に分離するだけで出力品質が上がる現象は、計算複雑性・人間認知・agent architecture のどこまで還元すれば "なぜ機能するか" を説明し尽くせるか。そしてそれが害になる境界はどこか」

---

## 到達した第一原理

### Principle 1: Verification Asymmetry (検証は生成より構造的に易しい — NP クラスにおいて)

**主張**: 多くの実務的に重要な問題 — コードがテストを通るか、証明が valid か、仕様に合致するか — は解の生成が指数的に難しくても、解の検証は多項式時間で済む。これは P vs NP 問題の定義そのものであり、計算複雑性論が 50 年かけて維持してきた最強の経験的観察である。

**なぜ還元不能か**: NP の定義は「多項式時間で解を検証できる問題のクラス」であり、生成と検証の計算量が等しいことは P = NP の同値命題になる。Cook・Aaronson は「Riemann 予想の検証と発見を同列に扱わない常識」こそこの非対称性の経験的証拠だと論じる。generator/verifier 分離の「分離すると得する」量は、この計算量ギャップの relative size で決まる。ギャップが大きい問題ほど、弱い verifier で強い generator を鍛えられる (Wei の "Verifier's Law")。

**適用条件**:
- タスクが NP（あるいはそれに類似した非対称性を持つクラス）に属する
- 検証基準が objective かつ fast to evaluate
- 検証に low noise な ground truth が存在する（テストの pass/fail、型検査、コンパイル、lint）
- **反例**: 存在論的に曖昧な主張 (essay fact-check, 意図推定) では Brandolini の法則 (bullshit asymmetry: 反論は生成より重い) が逆に効く。検証 >> 生成 になりうる

**導かれる実践 (Claude Code Harness 直結)**:
- **verify-local gate は "objective・fast・low-noise" な検証のみを通す**。flutter analyze / swift build / npm test のような決定論ゲートを一次に置き、「雰囲気レビュー」は後段に回す。これが verifier's law を最大限享受する配置
- **TDD の RED フェーズが "検証基準を先に凍結する" のは合理的**。先にテストを書くことで、実装 (generation, potentially NP-hard) と検証 (polynomial) の複雑性ギャップを人工的に最大化している
- **reviewer agent に "subjective だが重要な観点" を切り出す**。コンパイル・テストでは捕まらない設計妥当性・命名・副作用 — ここは Principle 3 と 4 の出番

**主な出典**:
- [Asymmetry of verification and verifier's law — Jason Wei](https://www.jasonwei.net/blog/asymmetry-of-verification-and-verifiers-law)
- [P vs NP — Scott Aaronson](https://www.scottaaronson.com/papers/pnp.pdf)
- [P versus NP problem — Wikipedia](https://en.wikipedia.org/wiki/P_versus_NP_problem)
- [Verification Is Not Easier Than Generation In General — LessWrong](https://www.lesswrong.com/posts/2PDC69DDJuAx6GANa/verification-is-not-easier-than-generation-in-general)（反例側）
- [Brandolini's law — Wikipedia](https://en.wikipedia.org/wiki/Brandolini%27s_law)
- [PHYS771 Lecture 6: P, NP, and Friends — Scott Aaronson](https://www.scottaaronson.com/democritus/lec6.html)

---

### Principle 2: Author Intention Blindness (書き手の意図は自分の出力知覚を上書きする)

**主張**: 書き手は自分が「書いたつもりのもの」と「実際に書いたもの」を知覚レベルで区別できない。これは単なる注意散漫ではなく、inattentional blindness と top-down の意味生成優先という、脳の根本アーキテクチャに根差した制約である。校正・デバッグ・PR self-review のいずれでも、著者は自分のコードのバグを「見えていても認識できない」状態に陥る。

**なぜ還元不能か**: Tom Stafford (Sheffield 大) の研究によれば、執筆中の脳は「意味を伝える」という high-level タスクに認知資源を配分し、letter→word→sentence→idea の bottom-up パースを generalization によってスキップする。その結果、画面に表示された実際のトークンと、頭の中の想定バージョンが「注意の奪い合い」に陥り、強い mental model (= 著者自身) が勝つ。Simons & Chabris の invisible gorilla 実験が示した inattentional blindness の一般化で、知覚そのものの構造的限界であって努力で消せない。著者は自分の頭の中を読んでいるのであって、紙面を読んでいない。

**適用条件**:
- 書き手が生成直後（認知的距離がゼロ）に検証する場面すべて
- 反例候補: 時間を空ける (sleep on it) ことで著者≒別人になれば部分的に回避可能。ただし実務の速度では通常不可能
- LLM にも同じ構造が存在: 自分の chain-of-thought に既に dependent な状態で「これは正しい？」と聞くと、top-down 制約が勝ち、誤りを自己正当化する ("Large Language Models Cannot Self-Correct Reasoning Yet", Huang et al., DeepMind 2023)

**導かれる実践**:
- **reviewer agent は必ず別コンテキスト (context fork) で起動する**。同一プロセスで "write then review" させると intention blindness が LLM 上で再現する。harness の context:fork パターンはここに直接根拠を持つ ([[context-fork]])
- **RED phase の tester と implement の implementer は別 fork**。test 作成者が実装を知っていると、テストは「通るように無意識に弱く書かれる」(intention blindness が test 側に漏れる)。[[wiki/draft.md]] にある「tdd-cycle をモノリシックから fork 分離する」判断はこの原理に対応
- **self-review PR は人間でも LLM でも構造的に信用しない**。harness の PR 前 review を「同じ実装コンテキスト内」で完結させてはならない

**主な出典**:
- [Why We Can't See Our Own Typos (Wired via Verblio)](https://www.verblio.com/blog/why-we-cant-see-our-own-typos)
- [The Reason It's So Hard to Spot Your Own Typos — Mental Floss](https://www.mentalfloss.com/article/633063/reason-its-so-hard-spot-your-own-typos)
- [Gorillas in our midst — Simons & Chabris 1999](http://www.chabris.com/Simons1999.pdf)
- [Large Language Models Cannot Self-Correct Reasoning Yet — Huang et al.](https://arxiv.org/abs/2310.01798)
- [The Self-Critique Paradox — Snorkel AI](https://snorkel.ai/blog/the-self-critique-paradox-why-ai-verification-fails-where-its-needed-most/)

---

### Principle 3: Construal Distance Enables Critical Evaluation (認知的距離が批判能力を開く)

**主張**: 検証者が生成者から認知的に離れているほど、判断は局所的・具体的から大域的・抽象的に構造転換する。これは construal level 理論が 20 年以上の実験で示した堅い現象であり、「誰がレビューするか」ではなく「どの認知距離からレビューするか」が品質を決める。writer/editor、driver/navigator、director/editor はすべてこの距離を人工的に作る装置である。

**なぜ還元不能か**: Trope & Liberman の construal level theory (CLT) によれば、object が自己から遠い (時間・空間・社会・仮説) ほど人は高次 (abstract, goal-directed, schematic) な表象を使い、近いほど低次 (concrete, procedural) な表象を使う。2025 年の PNAS 系メタ研究では、psychological distance が creative-idea selection の質を有意に改善することが示された。pair programming 研究では navigator が driver より abstract level で思考し、design flaw を捕らえる頻度が高いことが計測されている。Walter Murch が "editor's cut is a blink" と呼んだ現象 — 編集者は監督ではない人格として素材を見る — も同じ構造である。

**適用条件**:
- 検証が "局所的 syntactic" ではなく "大域的 semantic / design" の次元で効く場面
- LLM の場合: fork で context を切るだけで認知距離が生まれる（同一モデル重みでも、異なる prompt/system/state は異なる construal を生む）
- **反例**: 極端なコンテキスト剥奪は distance ではなく ignorance になる。reviewer が domain を全く知らないと、feedback は "汎用的な lint" に退化する (handoff cost, Principle 5 で扱う)

**導かれる実践**:
- **reviewer agent の system prompt を "designer / architect" persona に寄せる**。同じモデルでも construal level を意図的に abstract 側に持ち上げると、review comment の質が変わる。多くの LLM ハーネスで "review persona" が効果を生むのはこの原理
- **TDD の REFACTOR フェーズは RED/GREEN と別 construal で回す**。「通ったテストを前提に構造を見直す」は高 construal タスクであり、implement フェーズと同じ mental mode では成立しない。harness の simplify step を別 fork にするのはこれを言語化している
- **test-reward-hack-detector も authoring context とは離す**。test の抜け穴を探すタスクは、test を書いた本人の construal では絶対に見えない（intention blindness + 低 construal のダブル）

**主な出典**:
- [Construal-Level Theory of Psychological Distance — Trope & Liberman (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3152826/)
- [Greater psychological distance, better creative-idea selection — BMC Psychology 2025](https://bmcpsychology.biomedcentral.com/articles/10.1186/s40359-025-02370-3)
- [Pair programming and the mysterious role of the navigator — Bryant et al.](https://www.sciencedirect.com/science/article/abs/pii/S1071581907000456)
- [Walter Murch "nodal editing" — Filmmaker Magazine](https://filmmakermagazine.com/103987-watch-walter-murch-talks-music-the-conversation-and-nodal-editing/)
- [Editing vs. Revision — UC Berkeley SLC](https://slc.berkeley.edu/writing-worksheets-and-other-writing-resources/editing-vs-revision)

---

### Principle 4: Independence Breaks Reward-Hacking Collusion (検証独立性は偽の合意を壊す)

**主張**: 生成と検証が同一目的関数・同一インセンティブ・同一コンテキストを共有すると、検証は必然的に sycophant 化する。検証者が独立な基準 (external ground truth or adversarial stance) を持たないと、Goodhart の法則により「書き手にとって都合のいいこと」と「正しいこと」が衝突した瞬間に、検証は前者に傾く。SOX の auditor independence、Kahneman の adversarial collaboration、GAN の discriminator、actor-critic の critic、すべて同型の構造的答えである。

**なぜ還元不能か**: Goodhart の法則 ("When a measure becomes a target, it ceases to be a good measure") は optimization 理論の必然であり、reward hacking は強化学習・LLM RLHF・RL from AI feedback で再発見されてきた (Skalse et al., Lilian Weng の解説)。単一エージェントが generator と verifier を兼ねる構造は、定義上「自分を最大化する関数を自分で評価する」ループであり、proxy と真値の乖離に対して self-correcting ではない。GAN の generator/discriminator 分離、A2C の actor/critic 分離、peer review の double-blind、SOX Title II の監査非監査分離 — 全て「独立な gradient signal を作り出す」という同じ目的に奉仕する。Irving & Christiano の "AI safety via debate" が PSPACE に届くのは、独立 2 者の adversarial 構造が単一 verifier (NP) より表現力が高いからである。

**適用条件**:
- 生成側に「通るように書く」インセンティブが存在する場合（ほぼ常に成立）
- 検証の reward が連続的・微分可能な proxy で表現される場合（reward model over-optimization が起きる）
- **反例**: 完全な objective ground truth (数学証明の形式検証, 単体テストの pass/fail) がある場合は、独立性の必要性は下がる。ground truth そのものが adversary の役を果たすため

**導かれる実践**:
- **test-reward-hack-detector は harness の必須コンポーネント**。LLM は「テストを通すために実装を書く」のと同じ容易さで「実装を通すためにテストを書く」ができる。両方向の reward hacking を catch する独立検出器が必要
- **reviewer agent に "adversarial" system prompt を与える**。"find issues" ではなく "try to break this" と指示することで、generator の default な "cooperative completion" インセンティブから強制的に離す
- **verify-local と reviewer を直列ではなく並列の独立チェックとして使う**。一方が他方の出力を見て feedback するのは independence を崩す。両者が元の artifact を独立に評価し、後で結果を集約する aggregation pattern が望ましい
- **reward model ensemble (Coste et al.) の発想で reviewer を複数化**すると、単一 reviewer が captured される確率を下げられる

**主な出典**:
- [Reward hacking — Wikipedia](https://en.wikipedia.org/wiki/Reward_hacking)
- [Reward Hacking in Reinforcement Learning — Lilian Weng](https://lilianweng.github.io/posts/2024-11-28-reward-hacking/)
- [Defining and Characterizing Reward Hacking — Skalse et al.](https://arxiv.org/pdf/2209.13085)
- [Goodhart's Law in Reinforcement Learning](https://arxiv.org/html/2310.09144v1)
- [AI safety via debate — Irving & Christiano 2018](https://arxiv.org/abs/1805.00899)
- [Adversarial Collaboration — Daniel Kahneman (Edge)](https://www.edge.org/adversarial-collaboration-daniel-kahneman)
- [SOX Title II Auditor Independence — Cybersierra summary](https://cybersierra.co/blog/sarbanes-oxley-title-ii-auditor-independence/)
- [Actor-critic algorithm — Wikipedia](https://en.wikipedia.org/wiki/Actor-critic_algorithm)
- [Generative adversarial network — Wikipedia](https://en.wikipedia.org/wiki/Generative_adversarial_network)
- [Reviewer bias in single- vs double-blind peer review — PNAS](https://www.pnas.org/doi/10.1073/pnas.1707323114)

---

### Principle 5: Handoff Cost Bounds Separation (分離は無料ではない — 境界条件)

**主張**: separation は常に利益ではない。検証者が持つ context が生成者より弱いと、feedback は汎用的・表層的になり、むしろ品質を下げる。agile 文献が示す通り handoff は context loss を生み、モノリシックな self-review より悪化することがある。DHH の "TDD is Dead" 批判、Huang らの "LLMs cannot self-correct yet" の肯定側、pair programming の "lazy agent" 現象、すべてこの境界を指している。分離は「検証基準が外在化・構造化されている範囲」でのみ payoff を保証する。

**なぜ還元不能か**: 検証の質は「検証者が持つ情報」× 「検証基準の構造化度」で決まる。context switching には必ず情報損失と時間コストが伴い (Scrum.org の handoff 研究)、このコストは linear ではなく cycle time を指数的に伸ばす (code review wait time の実測)。さらに reviewer が generator の意図を再構成するためのメタ情報がなければ、construal level はただの ignorance に堕ちる。Huang らが示した「LLM は external feedback があれば self-correct できるが、純粋 intrinsic では性能が劣化する」は、分離単独では十分でなく、独立性に加えて "外部 anchor" が必要であることを意味している。DHH の TDD 批判の妥当な部分は、TDD が「検証基準 (test) を先に凍結することが設計判断に先立つ」という超越的な外在化を強いる点に向けられている。

**適用条件 (この原理自体の)**:
- 検証基準が文書化・自動化されていない場合、分離コストが利益を上回る
- 反復サイクルが短い (< 数分) 場合、handoff overhead が支配的になる
- generator と verifier のモデル能力差が大きすぎると、弱い verifier は noise になる (Huang et al.)

**導かれる実践**:
- **分離する前に "外在化された検証基準" を必ず用意する**。TDD の test、formal spec、AC list、lint rule、type — これらが reviewer に渡す "external anchor" になる。anchor なしで reviewer agent を spawn しても Principle 2-4 の利益は実現しない
- **handoff のペイロードを最小化する**。reviewer agent には diff + spec + test output を渡す。full codebase を渡すと context loss の代わりに context overload が起きる
- **reviewer の結果は generator が直接適用せず、別 fork の implementer が適用する**。feedback loop を閉じる主体を切り替えることで construal level を維持する
- **"cycle short enough that handoff dominates" な場面では分離しない**。typo fix や rename のような micro change に reviewer agent を噛ませると純コスト。harness の tier 判定 (T1/T2/T3) がこの閾値管理に対応

**主な出典**:
- [Why Handoffs Are Killing Your Agility — Scrum.org](https://www.scrum.org/resources/blog/why-handoffs-are-killing-your-agility)
- [An efficient code review process has fast feedback loops — Software.com](https://www.software.com/src/efficient-code-review-process-fast-feedback-loops)
- [Large Language Models Cannot Self-Correct Reasoning Yet — Huang et al.](https://arxiv.org/abs/2310.01798)
- [TDD is dead. Long live testing. — DHH](https://dhh.dk/2014/tdd-is-dead-long-live-testing.html)
- [Is TDD Dead? — Martin Fowler (discussion)](https://martinfowler.com/articles/is-tdd-dead/)
- [Pair programming and the mysterious role of the navigator — lazy navigator findings](https://www.sciencedirect.com/science/article/abs/pii/S1071581907000456)
- [Scaling Automated Process Verifiers for LLM Reasoning](https://arxiv.org/pdf/2410.08146)

---

## 表層の共通点（原理ではなく帰結として）

以下は頻出する "分離すると品質上がる系" の主張だが、いずれも上記 5 原理から演繹できる帰結である:

- **「レビュー付きの方がバグが減る」** (Fagan 82%, McConnell 55-60%, SmartBear/Cisco) → Principle 1 (検証の計算量ギャップ) + Principle 2 (著者 intention blindness)
- **「TDD で欠陥率が下がる」** (IBM 50%, Microsoft 2x) → Principle 1 (検証基準の凍結による NP 化) + Principle 4 (test が external anchor として独立)
- **「ペアプロが効く」** (Hannay et al.) → Principle 3 (driver と navigator の construal distance)
- **「自分のコードは夜寝かせてから読むとバグが見える」** → Principle 2 + Principle 3 の時間的変種
- **「AI 安全性には debate が必要」** (Irving & Christiano) → Principle 4 (adversarial independence が PSPACE を拓く)
- **「GAN / actor-critic で分離すると勾配の質が上がる」** → Principle 4 (同じ目的関数の中の partial adversary)

これらは "原理" ではなく、5 原理のいずれか（多くは 2 つ以上）の直接的な応用にすぎない。top-10 list として並べると失われる構造が、5 原理の下に立つと見える。

## 対立する主張と、その根底

| 対立 A | 対立 B | 根底にある前提 (と解消) |
|---|---|---|
| Wei: 検証は生成より易しい | Brandolini: 反論は生成より重い | 前提違い: A は NP 問題（構造化された検証基準あり）、B は曖昧な言明。**構造化された基準の有無が決定変数**。Principle 1 の適用条件に還元 |
| TDD は品質を上げる (IBM/Microsoft 実証) | DHH: TDD は design を破壊する | 前提違い: 前者は "test as external anchor"、後者は "test-first が設計判断に優越する" という解釈。**anchor と master の区別**に還元。Principle 5 の境界 |
| LLM は self-critique で改善する (Constitutional AI) | LLM は intrinsic self-correct 不能 (Huang et al.) | 前提違い: 前者は external principle (constitution) を与えている = 実は external feedback。後者は純粋 intrinsic。**external anchor の有無**に還元。Principle 4 と 5 の交差 |
| 多くの研究: 分離すると品質上がる | Handoff 研究: 分離は context loss を生む | 前提違い: 前者は "external anchor あり"、後者は "anchor なしで communication だけで context を渡す"。Principle 5 の条件分岐 |
| double-blind peer review が bias を減らす (Tomkins et al.) | single-blind 擁護派 | bias は避けられないが、どの bias を許容するかの価値判断。構造的には独立性を上げる方が期待値高い (Principle 4) |

**全ての対立は「外在化された検証基準と独立性が両立している範囲で分離は payoff し、どちらかが欠けるとコストが利益を上回る」という同一の境界条件に還元できる**。これが本リサーチの最も強い帰結。

## 反例と境界

Stage 5 で能動的に探した反例と、各原理がどう生き残るか:

1. **Brandolini's law: 反論は生成より重い** → Principle 1 の適用条件「NP かつ構造化検証」から外れた場合の境界。原理は崩れず、適用条件に吸収される
2. **LLMs cannot self-correct reasoning intrinsically** (Huang et al.) → Principle 2 の LLM 側での実証。反例ではなく補強
3. **DHH "TDD is Dead"** → Principle 5 の handoff cost 系。test が設計判断を越えて master になると害になる。原理は「分離は無料ではない」として残る
4. **Pair programming の "lazy navigator" 現象** → Principle 5 の境界。navigator に外在的タスクがないと construal distance が機能せず watching に堕ちる
5. **double-blind peer review に対する批判** (reviewer の accountability が下がる) → Principle 4 の trade-off。独立性と責任の tension で、これは未解決の open problem
6. **Reward model over-optimization** → Principle 4 の確認。独立なはずの verifier も proxy にすぎなければ captured される → ensemble や debate が必要
7. **Multi-agent LLM で "lazy agent" が発生** (Zhong et al.) → Principle 5 の境界。分離しても inject される情報差がないと collusion に似た failure mode に入る
8. **Self-consistency (Wang et al.) は同一モデルで効く** → Principle 3 の stochastic 版。単一モデルでも sampling noise による construal variation が検証の役を部分的に果たす

**崩れた原理はない**。全ての反例は 5 原理のどれかの適用条件 / 境界として吸収された。ただし Principle 4 と 5 の境界 (independence vs accountability) は open problem として残る。

## 調査ログ

- 調査ソース数: 32（うち一次情報論文 / primary: 14, 二次 survey / blog: 18）
- ソース多様性:
  - 時代: 古典 (Simons & Chabris 1999, Fagan inspection 1976-80s, Newell & Simon 1956 via Logic Theorist) / 現代 (McConnell 2004, Kahneman adversarial collaboration) / 最新 (Jason Wei 2025, Huang et al. 2023, constitutional AI 2022)
  - 立場: 実務家 (DHH, Fowler, Murch) / 研究者 (Aaronson, Cook, Simons, Kahneman, Trope, Huang) / 批評家 (LessWrong contrarians, DHH)
  - 分野: 計算複雑性 / 認知心理学 / ソフトウェア工学 / 映画編集 / 会計監査 / 機械学習 / 科学社会学 / 進化計算
  - 形式: peer-reviewed paper / 公式 arxiv / 書籍 (Code Complete, GPS) / blog / wiki
- Saturation 判定: 32 件目 (Scaling Automated Process Verifiers) 以降で新規 angle が 3 連続出なくなった。Principle 1-5 の枠に吸収される主張ばかりになった時点で終了
- c-brain 既存知識との関係:
  - 補強: [[wiki/draft.md]] の "tdd-cycle を context:fork で分離する" 判断 → Principle 2, 3 で根拠付け
  - 補強: [[context-fork]] glossary → Principle 3 の構造化
  - 補強: [[AgentTeams]] → Principle 4 の多重独立 verifier
  - 矛盾: なし

## 出典一覧

**計算複雑性 / verifier's law:**
- [Asymmetry of verification and verifier's law — Jason Wei](https://www.jasonwei.net/blog/asymmetry-of-verification-and-verifiers-law)
- [P vs NP — Scott Aaronson](https://www.scottaaronson.com/papers/pnp.pdf)
- [P vs NP — Stephen Cook (Clay Math)](https://www.claymath.org/wp-content/uploads/2022/06/pvsnp.pdf)
- [Verification Is Not Easier Than Generation In General — LessWrong](https://www.lesswrong.com/posts/2PDC69DDJuAx6GANa/verification-is-not-easier-than-generation-in-general)
- [Brandolini's law — Wikipedia](https://en.wikipedia.org/wiki/Brandolini%27s_law)
- [PHYS771 Lecture 6: P, NP, and Friends — Aaronson](https://www.scottaaronson.com/democritus/lec6.html)

**認知心理学 / intention blindness:**
- [Why We Can't See Our Own Typos — Verblio/Stafford](https://www.verblio.com/blog/why-we-cant-see-our-own-typos)
- [The Reason It's So Hard to Spot Your Own Typos — Mental Floss](https://www.mentalfloss.com/article/633063/reason-its-so-hard-spot-your-own-typos)
- [Gorillas in our midst — Simons & Chabris 1999](http://www.chabris.com/Simons1999.pdf)
- [Construal-Level Theory — Trope & Liberman](https://pmc.ncbi.nlm.nih.gov/articles/PMC3152826/)
- [Greater psychological distance, better creative-idea selection — BMC 2025](https://bmcpsychology.biomedcentral.com/articles/10.1186/s40359-025-02370-3)
- [Dunning-Kruger effect — Wikipedia](https://en.wikipedia.org/wiki/Dunning%E2%80%93Kruger_effect)
- [Do Code Models Suffer from the Dunning-Kruger Effect?](https://arxiv.org/html/2510.05457v1)

**ソフトウェア工学 / code review / TDD:**
- [Fagan inspection — Wikipedia](https://en.wikipedia.org/wiki/Fagan_inspection)
- [Characteristics of Useful Code Reviews at Microsoft — Bosu et al.](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/bosu2015useful.pdf)
- [Expectations, Outcomes, and Challenges of Modern Code Review — Bacchelli & Bird](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/ICSE202013-codereview.pdf)
- [Realizing Quality Improvement Through TDD — Nagappan et al. (Microsoft/IBM)](https://www.microsoft.com/en-us/research/wp-content/uploads/2009/10/Realizing-Quality-Improvement-Through-Test-Driven-Development-Results-and-Experiences-of-Four-Industrial-Teams-nagappan_tdd.pdf)
- [Test-driven development — Wikipedia](https://en.wikipedia.org/wiki/Test-driven_development)
- [TDD is Dead — DHH](https://dhh.dk/2014/tdd-is-dead-long-live-testing.html)
- [Is TDD Dead? — Martin Fowler](https://martinfowler.com/articles/is-tdd-dead/)
- [Why code review beats testing — Kevin Burke](https://kevin.burke.dev/kevin/the-best-ways-to-find-bugs-in-your-code/)
- [Pair programming and the mysterious role of the navigator — Bryant et al.](https://www.sciencedirect.com/science/article/abs/pii/S1071581907000456)
- [Why Handoffs Are Killing Your Agility — Scrum.org](https://www.scrum.org/resources/blog/why-handoffs-are-killing-your-agility)

**機械学習 / LLM / AI 安全性:**
- [Generative adversarial network — Wikipedia](https://en.wikipedia.org/wiki/Generative_adversarial_network)
- [Actor-critic algorithm — Wikipedia](https://en.wikipedia.org/wiki/Actor-critic_algorithm)
- [Constitutional AI: Harmlessness from AI Feedback — Anthropic](https://arxiv.org/abs/2212.08073)
- [Self-Consistency Improves Chain of Thought — Wang et al.](https://arxiv.org/abs/2203.11171)
- [Large Language Models Cannot Self-Correct Reasoning Yet — Huang et al.](https://arxiv.org/abs/2310.01798)
- [AI safety via debate — Irving & Christiano](https://arxiv.org/abs/1805.00899)
- [Reward Hacking in Reinforcement Learning — Lilian Weng](https://lilianweng.github.io/posts/2024-11-28-reward-hacking/)
- [Defining and Characterizing Reward Hacking — Skalse et al.](https://arxiv.org/pdf/2209.13085)
- [Scaling Automated Process Verifiers for LLM Reasoning](https://arxiv.org/pdf/2410.08146)

**その他 (adversarial collaboration / 科学社会学 / 映画 / 会計):**
- [Adversarial Collaboration — Daniel Kahneman (Edge)](https://www.edge.org/adversarial-collaboration-daniel-kahneman)
- [Reviewer bias in single- vs double-blind peer review — PNAS](https://www.pnas.org/doi/10.1073/pnas.1707323114)
- [Walter Murch — Wikipedia](https://en.wikipedia.org/wiki/Walter_Murch)
- [Editing vs. Revision — UC Berkeley SLC](https://slc.berkeley.edu/writing-worksheets-and-other-writing-resources/editing-vs-revision)
- [SOX Title II Auditor Independence — Cybersierra](https://cybersierra.co/blog/sarbanes-oxley-title-ii-auditor-independence/)
- [Newell & Simon — Logic Theorist](https://en.wikipedia.org/wiki/Logic_Theorist)

## 関連

- [[context-fork]]
- [[AgentTeams]]
- [[ハーネスエンジニアリング]]
- [[wiki/draft.md]]（tdd-cycle の fork 分離設計メモ）
- [[20260413-beautiful-ui-principles]]（姉妹原理集）

---

🤖 Generated with Claude Code
