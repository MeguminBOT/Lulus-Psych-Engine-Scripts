# Lulu's Scoring Systems — Psych Engine Script Pack

A collection of **10 rhythm game scoring/accuracy systems** for Friday Night Funkin' Psych Engine 1.0.4 as HScript. Each system attempts to faithfully recreate the timing windows, accuracy formulas, scoring algorithms, and grade thresholds from its respective game.

Switch between them at any time via the mod settings menu. 

*Note that there are improvements that can be made and will be made in the future.*

This readme serves as an overview over the differences between the various systems.

Also includes:
- All math formulas are available so anyone can inspect or port to other engines if desired.
- API for the scoring systems to integrate with custom uis and such.




---

## Table of Contents

- [Quick Comparison](#quick-comparison)
- [Scoring Systems](#scoring-systems)
  - [Psych Engine (Default)](#1-psych-engine-default)
  - [Wife3 (Etterna)](#2-wife3-etterna)
  - [osu!mania ScoreV1](#3-osumania-scorev1)
  - [osu!mania ScoreV2](#4-osumania-scorev2)
  - [ITG (In The Groove)](#5-itg-in-the-groove)
  - [Ruthless](#6-ruthless)
  - [O2Jam](#7-o2jam)
  - [DJMAX RESPECT V](#8-djmax-respect-v)
  - [beatmania IIDX](#9-beatmania-iidx)
  - [Quaver](#10-quaver)
- [Timing Window Comparison](#timing-window-comparison)
- [Grade Threshold Comparison](#grade-threshold-comparison)
- [Supporting Features](#supporting-features)
- [Installation](#installation)
- [Configuration](#configuration)
- [For Developers](#for-developers)

---

## Quick Comparison

> **Authentic Score / Authentic Accuracy** — indicates whether the score or accuracy formula faithfully recreates the original game's algorithm. "Yes" means the formula is directly ported from the source game. "No" means the source game either does not have that formula at all (e.g. Etterna tracks accuracy only — it has no score formula, so one was custom-built for this pack) or the formula was otherwise replaced with a custom implementation. "—" means the system is entirely custom with no source game to compare against.
>
> **LNs Judged** — whether long note (hold note) releases are timed and scored independently. "Yes" = release is hit within a timing window and scored separately. "Pass/Fail" = release is tracked but only as binary (held to end or not, no timing window). "No" = releases are not judged at all.

| System | Origin Game | Max Score | Accuracy Type | Configurable Difficulty | Combo Matters for Score? | Authentic Score | Authentic Accuracy | LNs Judged |
|--------|-------------|-----------|---------------|------------------------|--------------------------|-----------------|---------------------|--------------------|
| **Psych** | FNF Psych Engine | Varies | Hit ratio | No | No | Yes | Yes | No |
| **Wife3** | Etterna | Varies | Error-function curve | Judge 1–9 (scale 0.009–4.0) | No | No | Yes | No |
| **osu!mania V1** | osu! | 1,000,000 | Weighted hit ratio | OD 0–10 | Yes (bonus multiplier) | Yes | Yes | Yes |
| **osu!mania V2** | osu! | 1,000,000 | Weighted hit ratio | OD 0–10 | Yes (70% of score) | Yes | Yes | Yes |
| **ITG** | In The Groove / StepMania | 10,000,000 | Dance Points | Window Scale 0.1–4.0 | No (step counter weighted) | Yes | Yes | Pass/Fail |
| **Ruthless** | Custom | 1,000,000 | Smoothstep curve | Perfect Window 0–25ms | No (bonus multiplier) | — | — | No |
| **O2Jam** | O2Jam | Unlimited | Weighted hit ratio | BPM scaling toggle | Yes (score = weight × combo) | Yes | Yes | No |
| **DJMAX** | DJMAX RESPECT V | 1,000,000 | Weighted average | No | No | Yes | Yes | No |
| **IIDX** | beatmania IIDX | EX Score | EX Rate | No | No | Yes | Yes | No |
| **Quaver** | Quaver | 1,000,000 | Weighted average | No | No | Yes | Yes | No |

---

## Scoring Systems

### 1. Psych Engine (Default)

The built-in scoring system. No custom script — uses the engine's native hit detection and rating system (Sick / Good / Bad / Shit).

---

### 2. Wife3 (Etterna)

The accuracy system used by **Etterna** (StepMania community fork), widely regarded as one of the most mathematically rigorous rhythm game accuracy systems.

#### Timing Windows

Windows scale with the **Judge preset** (J1–J9) or a custom **Judge Scale** value:

| Judgement | Base Window | Formula |
|-----------|-------------|---------|
| Marvelous | ±22ms | `22 × scale` |
| Perfect | ±45ms | `45 × scale` |
| Great | ±90ms | `90 × scale` |
| Good | ±135ms | `135 × scale` |
| Bad | ±180ms | `180 × scale` |

| Preset | Scale | Marvelous Window |
|--------|-------|------------------|
| J1 | 4.0 | ±88ms (easiest) |
| J4 | 1.0 | ±22ms (default) |
| J9 | 0.4 | ±8.8ms (hardest) |

#### Accuracy Formula

Wife3 uses an **error function (erf)** curve — accuracy points are continuous, not discrete tiers:

$$
\begin{aligned}
&s = \text{Judge Scale} \quad\quad \text{ridic} = 5s \quad\quad \text{max\_boo} = 180s \\
&\text{zero} = 65 \cdot s^{0.75} \quad\quad \text{dev} = 22.7 \cdot s^{0.75} \\
&\text{points}(t) = \begin{cases}
+2.0 & |t| \leq \text{ridic} \\
+2.0 \times \text{erf}\!\left(\dfrac{\text{zero} - |t|}{\text{dev}}\right) & |t| \leq \text{zero} \\
\dfrac{(|t| - \text{zero}) \times (-5.5)}{\text{max\_boo} - \text{zero}} & |t| \leq \text{max\_boo} \\
-5.5 & |t| > \text{max\_boo}
\end{cases} \\
&\text{Wife3 \%} = \frac{\displaystyle\sum_{i=1}^{N} \text{points}_i}{N \times 2.0} \times 100
\end{aligned}
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
Constants:
  ridic     = 5.0 × scale
  max_boo   = 180.0 × scale
  ts_pow    = 0.75
  zero      = 65.0 × scale^ts_pow
  dev       = 22.7 × scale^ts_pow
  max_points = 2.0
  miss_weight = -5.5

For a hit with |offset| ms:
  if offset ≤ ridic:      points = +2.0
  if offset ≤ zero:       points = +2.0 × erf((zero - offset) / dev)
  if offset ≤ max_boo:    points = (offset - zero) × miss_weight / (max_boo - zero)
  if offset > max_boo:    points = -5.5

Wife3 % = (Σ points / (total_notes × 2.0)) × 100
```

</details>

#### Score Formula

$$
\text{ratio} = \frac{\text{accuracy\_points}}{2.0}
$$

$$
\text{score} \mathrel{+}= \begin{cases}
\text{ratio} \times 350 & \text{if ratio} \geq 0 \\
\text{ratio} \times 200 & \text{if ratio} < 0
\end{cases}
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
wife3_ratio = accuracy_points / 2.0
if wife3_ratio ≥ 0:  score += wife3_ratio × 350
if wife3_ratio < 0:  score += wife3_ratio × 200
```

</details>

#### Grade Thresholds

| Grade | Threshold |
|-------|-----------|
| AAAAA | ≥ 99.70% |
| AAAA | ≥ 99.50% |
| AAA | ≥ 99.00% |
| AA | ≥ 98.00% |
| A | ≥ 96.50% |
| B | ≥ 93.00% |
| C | ≥ 90.00% |
| D | ≥ 80.00% |
| F | < 80.00% |

#### FC Tiers

| Tier | Criteria |
|------|----------|
| MFC | All Marvelous, no misses |
| PFC / SFC | Marvelous + Perfect only, no misses (name depends on Etterna FC Tier setting) |
| GFC | Up to Great, no misses |
| FC | No misses |
| SDCB | < 10 misses |
| Clear | ≥ 10 misses |

#### Combo Behavior

All judgements (Marvelous through Bad) **maintain combo**. Only misses break combo.

#### Settings

| Setting | Range | Default |
|---------|-------|---------|
| Judge Preset | 1–9 | 4 |
| Judge Scale | 0.009–4.0 | 1.0 |
| Use Etterna FC Tier Names | on/off | off |

---

### 3. osu!mania ScoreV1

The classic **osu!mania** scoring system with base + bonus score components and OD-based timing windows.

#### Timing Windows

Windows depend on **Overall Difficulty (OD)** (0–10):

| Judgement | Formula | OD 0 | OD 5 | OD 8 | OD 10 |
|-----------|---------|------|------|------|-------|
| MAX (Rainbow 300) | ±16ms (fixed) | ±16ms | ±16ms | ±16ms | ±16ms |
| 300 | ±(64 − 3 × OD) | ±64ms | ±49ms | ±40ms | ±34ms |
| 200 | ±(97 − 3 × OD) | ±97ms | ±82ms | ±73ms | ±67ms |
| 100 | ±(127 − 3 × OD) | ±127ms | ±112ms | ±103ms | ±97ms |
| 50 | ±(151 − 3 × OD) | ±151ms | ±136ms | ±127ms | ±121ms |

**Tail windows** (hold note releases): 1.5× the above values (more lenient).

#### Score Formula

$$
\text{Score} = \underbrace{\frac{500{,}000 \times M}{N} \times \frac{H_v}{320}}_{\text{BaseScore}} + \underbrace{\frac{500{,}000 \times M}{N} \times \frac{H_b \times \sqrt{B}}{320}}_{\text{BonusScore}} \quad (\max\ 1{,}000{,}000)
$$

$$
B_{\text{new}} = \text{clamp}\!\left(B + H_b - \frac{H_p}{M_d},\ 0,\ 100\right) \quad\quad B_{\text{miss}} = 0
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
Score = BaseScore + BonusScore    (max 1,000,000)

BaseScore  = (500,000 × ModMult / TotalNotes) × (HitValue / 320)
BonusScore = (500,000 × ModMult / TotalNotes) × (HitBonus × √Bonus / 320)

Bonus accumulator (0–100):
  On hit:  Bonus = clamp(Bonus + HitBonus − HitPunishment / ModDivider, 0, 100)
  On miss: Bonus = 0
```

</details>

| Judgement | HitValue | HitBonus | HitPunishment |
|-----------|----------|----------|---------------|
| MAX | 320 | 32 | 0 |
| 300 | 300 | 32 | 0 |
| 200 | 200 | 16 | 8 |
| 100 | 100 | 8 | 24 |
| 50 | 50 | 4 | 44 |
| Miss | 0 | 0 | ∞ (reset to 0) |

**Playback Rate Modifiers:**

| Rate | ModMultiplier | ModDivider |
|------|---------------|------------|
| ≤ 0.75× | 0.5 | 1.0 |
| 0.75–1.0× | 0.5–1.0 (lerp) | 1.0 |
| 1.0× | 1.0 | 1.0 |
| 1.0–1.5× | 1.0 | 1.0–1.1 (lerp) |
| ≥ 1.5× | 1.0 | 1.1 |

#### Accuracy Formula

$$
\text{Accuracy \%} = \frac{(N_{\text{MAX}} + N_{300}) \times 300 + N_{200} \times 200 + N_{100} \times 100 + N_{50} \times 50}{N_{\text{total}} \times 300} \times 100
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
                (CountMAX + Count300) × 300 + Count200 × 200 + Count100 × 100 + Count50 × 50
Accuracy % =  ──────────────────────────────────────────────────────────────────────────────── × 100
                                          TotalNotes × 300
```

</details>

#### Grade Thresholds

| Grade | Threshold |
|-------|-----------|
| SS | 100% |
| S | > 95% |
| A | > 90% |
| B | > 80% |
| C | > 70% |
| D | < 70% |

#### FC Tiers

| Tier | Criteria |
|------|----------|
| PFC | All MAX hits, no misses |
| FC | No misses |
| SDCB | < 10 misses |
| Clear | ≥ 10 misses |

#### Combo Behavior

All judgements (MAX through 50) **maintain combo**. Only misses break combo.

#### Special Mechanics

- **Tail judgements**: Hold note releases are scored separately with 1.5× lenient windows
- **Broken holds**: Early release caps the tail to a minimum of 50
- **Bonus accumulator**: √Bonus multiplier rewards consistency (resets on miss)
- **Playback rate**: Full ModMultiplier / ModDivider support

#### Settings

| Setting | Range | Default |
|---------|-------|---------|
| Overall Difficulty (OD) | 0.0–10.0 | 8.0 |

---

### 4. osu!mania ScoreV2

The **combo-weighted** osu!mania scoring variant used in tournaments. Shares timing windows with V1 but uses a fundamentally different score formula that heavily rewards combo.

#### Timing Windows

Same as [osu!mania ScoreV1](#3-osumania-scorev1) (shared OD setting).

#### Score Formula

$$
\text{Score} = 700{,}000 \times \frac{C_{\max}}{C_{\text{total}}} + 300{,}000 \times A^{10}
$$

Where $C_{\max}$ = highest combo achieved, $C_{\text{total}}$ = total objects (taps + LN starts + LN releases), $A$ = osu!mania accuracy as a decimal (0–1).

<details>
<summary>📋 Copy-pasteable formula</summary>

```
Score = 700,000 × ComboRatio + 300,000 × Accuracy¹⁰

ComboRatio = MaxComboAchieved / MaxCombo
Accuracy   = standard osu!mania accuracy (decimal 0–1)
MaxCombo   = total objects (taps + LN starts + LN releases)
```

</details>

> **Note:** The $A^{10}$ term means accuracy is raised to the 10th power. This creates an extreme exponential punishment — at 95% accuracy, the accuracy component is only ~0.5987 × 300,000 ≈ 179,600. At 90% accuracy, it drops to ~0.3487 × 300,000 ≈ 104,600.

#### Accuracy Formula

Same as [osu!mania ScoreV1](#3-osumania-scorev1).

#### Grades, FC Tiers, Combo Behavior

Same as [osu!mania ScoreV1](#3-osumania-scorev1).

#### Special Mechanics

- **Objects vs Notes**: Hold notes count as 2 objects (press + release), both judged separately
- **70/30 split**: 70% of score from max combo achieved, 30% from accuracy
- **Exponential accuracy**: Accuracy^10 creates massive punishment for anything below ~98%

#### Settings

Same as V1 (shared OD).

---

### 5. ITG (In The Groove)

The **DDR MAX2-style** scoring system used by StepMania and In The Groove, with dance point accuracy tracking.

#### Timing Windows

Windows scale with **Window Scale** multiplier:

| Judgement | Base Window | Formula |
|-----------|-------------|---------|
| Fantastic | ±21.5ms | `21.5 × scale` |
| Excellent | ±43ms | `43 × scale` |
| Great | ±102ms | `102 × scale` |
| Decent | ±135ms | `135 × scale` |
| Way Off | ±180ms | `180 × scale` |

#### Score Formula

DDR MAX2-style weighted accumulation:

$$
\text{Score} = \frac{\displaystyle\sum_{i=1}^{N} w_i \times i}{\dfrac{10 \times N \times (N+1)}{2}} \times 10{,}000{,}000
$$

Where $w_i$ = judgement weight for note $i$, and $i$ = step counter (increments on every note including misses).

<details>
<summary>📋 Copy-pasteable formula</summary>

```
Step Counter increments on every note (including misses)

On each note:
  EarnedPoints += judgement_weight × step_counter

MaxPossiblePoints = 10 × N × (N + 1) / 2    (where N = total scoring events)
Score = (EarnedPoints / MaxPossiblePoints) × 10,000,000
```

</details>

| Judgement | Weight | Dance Points |
|-----------|--------|-------------|
| Fantastic | 10 | +5 |
| Excellent | 9 | +4 |
| Great | 5 | +2 |
| Decent | 0 | 0 |
| Way Off | 0 | −6 |
| Miss | 0 | −12 |
| Hold OK | 10 | +5 |
| Hold NG | 0 | 0 |

#### Accuracy Formula (Dance Points)

$$
\text{DP Accuracy \%} = \frac{\text{EarnedDP}}{\text{MaxDP}} \times 100 \quad\quad \text{MaxDP} = 5 \times N
$$

Where $N$ = total scoring events (taps + holds).

<details>
<summary>📋 Copy-pasteable formula</summary>

```
                    EarnedDP
DP Accuracy % =  ────────── × 100
                    MaxDP

MaxDP = 5 × total scoring events (taps + holds)
```

</details>

#### Grade Thresholds

| Grade | DP % | | Grade | DP % |
|-------|------|-|-------|------|
| ★★★★ | 100% | | A− | ≥ 80% |
| ★★★ | ≥ 99% | | B+ | ≥ 76% |
| ★★ | ≥ 98% | | B | ≥ 72% |
| ★ | ≥ 96% | | B− | ≥ 68% |
| S+ | ≥ 94% | | C+ | ≥ 64% |
| S | ≥ 92% | | C | ≥ 60% |
| S− | ≥ 89% | | C− | ≥ 55% |
| A+ | ≥ 86% | | D | < 55% |
| A | ≥ 83% | | | |

#### FC Tiers

| Tier | Criteria |
|------|----------|
| FFC | All Fantastic, no misses |
| FEC | Fantastic + Excellent only, no misses |
| FGC | Up to Great, no misses |
| FC | No misses |
| SDCB | < 10 misses |
| Clear | ≥ 10 misses |

#### Combo Behavior

All non-miss judgements **maintain combo** (including Decent and Way Off). Only misses break combo.

#### Settings

| Setting | Range | Default |
|---------|-------|---------|
| Window Scale | 0.1–4.0 | 1.0 |

---

### 6. Lulu's Ruthless

A **custom scoring system**, using a linear curve. Accuracy is always 0–100% (never negative). Features 7 judgement tiers and a configurable perfect window.

#### Timing Windows

| Judgement | Window |
|-----------|--------|
| Flawless | ≤ perfect window (default 10ms) |
| Precise | ≤ 20ms |
| Great | ≤ 30ms |
| Good | ≤ 40ms |
| Ok | ≤ 50ms |
| Sloppy | ≤ 75ms |
| Barely | ≤ 100ms |
| Miss | > 100ms |

#### Score Formula

Same base + bonus structure as osu!mania V1:

$$
\text{Score} = \underbrace{\frac{500{,}000}{N} \times \frac{H_v}{320}}_{\text{BaseScore}} + \underbrace{\frac{500{,}000}{N} \times \frac{B_v \times \sqrt{B}}{320}}_{\text{BonusScore}} \quad (\max\ 1{,}000{,}000)
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
BaseScore  = (500,000 / TotalNotes) × (HitValue / 320)
BonusScore = (500,000 / TotalNotes) × (BonusValue × √Bonus / 320)

Score = BaseScore + BonusScore    (max 1,000,000)
```

</details>

| Judgement | HitValue | BonusValue | HitBonus | HitPunishment |
|-----------|----------|------------|----------|---------------|
| Flawless | 320 | 32 | +2.0 | 0 |
| Precise | 310 | 32 | +1.5 | 0 |
| Great | 300 | 32 | +1.0 | 0 |
| Good | 250 | 24 | 0 | −4 |
| Ok | 200 | 16 | 0 | −8 |
| Sloppy | 100 | 8 | 0 | −24 |
| Barely | 50 | 4 | 0 | −44 |
| Miss | 0 | 0 | 0 | reset to 0 |

#### Accuracy Formula

Linear smoothstep with halved punishment past 50ms:

$$
\text{points}(t) = \begin{cases}
1.0 & |t| \leq p \\
0.0 & |t| \geq 100 \\
\left(1 - \dfrac{|t| - p}{100 - p}\right) \times 0.5 & |t| > 50 \\
1 - \dfrac{|t| - p}{100 - p} & \text{otherwise}
\end{cases}
$$

$$
\text{Accuracy \%} = \frac{\displaystyle\sum_{i=1}^{N} \text{points}_i}{N} \times 100 \quad\quad (0\text{–}100\%,\ \text{never negative})
$$

Where $p$ = perfect window (default 10ms).

<details>
<summary>📋 Copy-pasteable formula</summary>

```
if |offset| ≤ perfect_window:  accuracy_points = 1.0 (100%)
if |offset| ≥ 100ms:           accuracy_points = 0.0 (0%)

Otherwise:
  linear = 1.0 − (|offset| − perfect_window) / (100 − perfect_window)
  if |offset| > 50ms:  linear = linear × 0.5

Accuracy % = (Σ accuracy_points / total_notes) × 100
Range: 0–100% (never negative)
```

</details>

#### Grade Thresholds

| Grade | % | | Grade | % |
|-------|---|-|-------|---|
| X+ | ≥ 99.00% | | B | ≥ 88.50% |
| X | ≥ 98.50% | | B− | ≥ 87.00% |
| X− | ≥ 98.00% | | C+ | ≥ 85.50% |
| SS+ | ≥ 97.50% | | C | ≥ 84.00% |
| SS | ≥ 97.00% | | C− | ≥ 82.50% |
| SS− | ≥ 96.50% | | D+ | ≥ 80.00% |
| S+ | ≥ 96.00% | | D | ≥ 77.50% |
| S | ≥ 95.00% | | D− | ≥ 75.00% |
| S− | ≥ 94.00% | | F | < 75.00% |
| A+ | ≥ 93.00% | | | |
| A | ≥ 92.00% | | | |
| A− | ≥ 91.00% | | | |
| B+ | ≥ 90.00% | | | |

#### FC Tiers

| Tier | Criteria |
|------|----------|
| MFC | All Flawless, no misses |
| SFC | Flawless + Precise only, no misses |
| GFC | Up to Great, no misses |
| FC | No misses |
| SDCB | < 10 misses |
| Clear | ≥ 10 misses |

#### Combo Behavior

All judgements (Flawless through Barely) **maintain combo**. Only misses break combo.

#### Settings

| Setting | Range | Default |
|---------|-------|---------|
| Perfect Window | 0.0–25.0ms | 10.0ms |

---

### 7. O2Jam

The scoring system from **O2Jam**, a Korean arcade/online rhythm game. Features combo-multiplied scoring where every point is scaled by your current combo count.

#### Timing Windows

**Fixed mode** (default):

| Judgement | Window |
|-----------|--------|
| COOL | ±33ms |
| GOOD | ±67ms |
| BAD | ±100ms |
| MISS | > 100ms |

**BPM mode** (optional, authentic O2Jam behavior):

| Judgement | Formula | @ 150 BPM | @ 200 BPM |
|-----------|---------|-----------|-----------|
| COOL | 7,500 / BPM ms | ±50ms | ±37.5ms |
| GOOD | 22,500 / BPM ms | ±150ms | ±112.5ms |
| BAD | 31,250 / BPM ms | ±208ms | ±156ms |

#### Score Formula

Score is **unlimited** — directly driven by combo:

$$
\text{score} \mathrel{+}= w_j \times \text{combo} \quad\quad w_{\text{COOL}} = 1.0,\quad w_{\text{GOOD}} = 0.7,\quad w_{\text{BAD}} = 0.4
$$

BAD and MISS reset combo to 0 before scoring (so BAD always adds 0).

<details>
<summary>📋 Copy-pasteable formula</summary>

```
On COOL hit:  score += 1.0 × current_combo
On GOOD hit:  score += 0.7 × current_combo
On BAD hit:   combo = 0, score += 0.4 × 0 = 0
On MISS:      combo = 0, score += 0
```

</details>

> Higher combo = exponentially more points. A COOL at combo 500 gives 500 points; at combo 1 it gives 1 point.

#### Accuracy Formula

$$
\text{Accuracy \%} = \frac{1.0 \times N_{\text{COOL}} + 0.7 \times N_{\text{GOOD}} + 0.4 \times N_{\text{BAD}}}{N_{\text{total}}} \times 100
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
                1.0 × CountCOOL + 0.7 × CountGOOD + 0.4 × CountBAD
Accuracy % =  ──────────────────────────────────────────────────────── × 100
                                   TotalNotes
```

</details>

#### Grade Thresholds

| Grade | Threshold |
|-------|-----------|
| SSS | 100% |
| SS | ≥ 99% |
| S | ≥ 95% |
| A | ≥ 90% |
| B | ≥ 80% |
| C | ≥ 70% |
| D | ≥ 60% |
| F | < 60% |

#### FC Tiers

| Tier | Criteria |
|------|----------|
| AFC | All COOL, no misses |
| FC | COOL + GOOD only, no BAD/MISS |
| SDCB | < 10 combo breaks |
| Clear | ≥ 10 combo breaks |

#### Combo Behavior

| Maintains Combo | Breaks Combo |
|----------------|--------------|
| COOL, GOOD | BAD, MISS |

#### Settings

| Setting | Options | Default |
|---------|---------|---------|
| BPM-Based Windows | on/off | off |

---

### 8. DJMAX RESPECT V

The scoring system from **DJMAX RESPECT V** (PC version), using fixed timing windows and accuracy-weighted scoring normalized to 1,000,000.

#### Timing Windows

| Judgement | Window |
|-----------|--------|
| MAX 100% | ±16ms |
| MAX 90% | ±33ms |
| GOOD | ±66ms |
| BAD | ±100ms |
| BREAK | > 100ms |

#### Score Formula

$$
\text{Score} = 1{,}000{,}000 \times \frac{\displaystyle\sum_{i=1}^{N} w_i}{N}
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
Score = 1,000,000 × (WeightedSum / TotalNotes)
```

</details>

| Judgement | Weight |
|-----------|--------|
| MAX 100% | 1.0 |
| MAX 90% | 0.9 |
| GOOD | 0.5 |
| BAD | 0.1 |
| BREAK | 0.0 |

#### Accuracy Formula

$$
\text{Accuracy \%} = \frac{\displaystyle\sum_{i=1}^{N} w_i}{N} \times 100
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
Accuracy % = (WeightedSum / TotalNotes) × 100
```

</details>

#### Grade Thresholds

| Grade | Threshold |
|-------|-----------|
| S | ≥ 97% |
| A | ≥ 90% |
| B | ≥ 80% |
| C | < 80% |

#### FC Tiers

| Tier | Criteria |
|------|----------|
| PP | All MAX 100%, no misses |
| FC | MAX 100% + MAX 90% only, no GOOD/BAD/BREAK |
| SDCB | < 10 combo breaks |
| Clear | ≥ 10 combo breaks |

#### Combo Behavior

| Maintains Combo | Breaks Combo |
|----------------|--------------|
| MAX 100%, MAX 90% | GOOD, BAD, BREAK |

> Unlike most systems, GOOD breaks combo in DJMAX.

---

### 9. beatmania IIDX

The **EX Score** system from **beatmania IIDX**, using frame-based timing windows normalized for PC (60fps). Grade boundaries are based on ninths (fractions of 9).

#### Timing Windows

| Judgement | Window | Frame Equivalent (60fps) |
|-----------|--------|-------------------------|
| PGREAT | ±16.67ms | 1 frame |
| GREAT | ±33.33ms | 2 frames |
| GOOD | ±100ms | — |
| BAD | ±180ms | — |
| POOR | > 180ms (miss) | — |

#### Score Formula

$$
\text{EX Score} = 2 \times N_{\text{PGREAT}} + 1 \times N_{\text{GREAT}} \quad\quad \text{Max EX} = 2N
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
EX Score = 2 × CountPGREAT + 1 × CountGREAT

Max EX = 2 × TotalNotes (all PGREATs)
```

</details>

| Judgement | EX Points |
|-----------|-----------|
| PGREAT | +2 |
| GREAT | +1 |
| GOOD | 0 |
| BAD | 0 |
| POOR | 0 |

#### Accuracy Formula (EX Rate)

$$
\text{EX Rate \%} = \frac{\text{EX Score}}{2 \times N} \times 100
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
                  EX Score
EX Rate % =  ──────────────── × 100
              2 × TotalNotes
```

</details>

#### Grade Thresholds

Grades are based on **ninths** of the maximum EX Score:

| Grade | Fraction | EX Rate |
|-------|----------|---------|
| AAA | ≥ 8/9 | ≥ 88.89% |
| AA | ≥ 7/9 | ≥ 77.78% |
| A | ≥ 6/9 | ≥ 66.67% |
| B | ≥ 5/9 | ≥ 55.56% |
| C | ≥ 4/9 | ≥ 44.44% |
| D | ≥ 3/9 | ≥ 33.33% |
| E | ≥ 2/9 | ≥ 22.22% |
| F | < 2/9 | < 22.22% |

#### FC Tiers

| Tier | Criteria |
|------|----------|
| PFC | All PGREAT, no misses |
| FC | No BAD or POOR |
| SDCB | < 10 combo breaks |
| Clear | ≥ 10 combo breaks |

#### Combo Behavior

| Maintains Combo | Breaks Combo |
|----------------|--------------|
| PGREAT, GREAT, GOOD | BAD, POOR |

---

### 10. Quaver

The scoring system from **Quaver**, an open-source vertical scrolling rhythm game. Uses weighted accuracy normalized to 1,000,000.

#### Timing Windows

| Judgement | Window |
|-----------|--------|
| Marvelous | ±18ms |
| Perfect | ±43ms |
| Great | ±76ms |
| Good | ±106ms |
| Miss | > 106ms |

#### Score Formula

$$
\text{Score} = 1{,}000{,}000 \times A
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
Score = 1,000,000 × Accuracy
```

</details>

#### Accuracy Formula

$$
\text{Accuracy \%} = \frac{\displaystyle\sum_{j} V_j \times N_j}{100 \times N} \times 100
$$

<details>
<summary>📋 Copy-pasteable formula</summary>

```
         Σ (V_j × N_j)
Acc =  ───────────────── × 100
          100 × N
```

</details>

| Judgement | Weight (V_j) |
|-----------|-------------|
| Marvelous | 100 |
| Perfect | 98 |
| Great | 65 |
| Good | 25 |
| Miss | 0 |

#### Grade Thresholds

| Grade | Threshold |
|-------|-----------|
| X | 100% |
| SS | ≥ 99% |
| S | ≥ 95% |
| A | ≥ 90% |
| B | ≥ 80% |
| C | ≥ 70% |
| D | < 70% |

#### FC Tiers

| Tier | Criteria |
|------|----------|
| PFC | All Marvelous, no misses |
| FC | No Good or Miss |
| SDCB | < 10 misses |
| Clear | ≥ 10 misses |

#### Combo Behavior

| Maintains Combo | Breaks Combo |
|----------------|--------------|
| Marvelous, Perfect, Great | Good, Miss |

---

## Timing Window Comparison

All values in milliseconds (±ms from perfect). Default settings for all systems.

| System | Tier 1 (Best) | Tier 2 | Tier 3 | Tier 4 | Tier 5 | Miss |
|--------|--------------|--------|--------|--------|--------|------|
| **Wife3** (J4) | ±22 (Marv) | ±45 (Perf) | ±90 (Great) | ±135 (Good) | ±180 (Bad) | — |
| **osu!mania** (OD8) | ±16 (MAX) | ±40 (300) | ±73 (200) | ±103 (100) | ±127 (50) | > 127 |
| **ITG** (1.0×) | ±21.5 (Fant) | ±43 (Exc) | ±102 (Great) | ±135 (Dec) | ±180 (WO) | — |
| **Ruthless** (10ms) | ±10 (Flaw) | ±20 (Prec) | ±30 (Great) | ±40 (Good) | ±50–100 | > 100 |
| **O2Jam** (fixed) | ±33 (COOL) | ±67 (GOOD) | ±100 (BAD) | — | — | > 100 |
| **DJMAX** | ±16 (MAX100) | ±33 (MAX90) | ±66 (GOOD) | ±100 (BAD) | — | > 100 |
| **IIDX** | ±16.67 (PGR) | ±33.33 (GR) | ±100 (GOOD) | ±180 (BAD) | — | > 180 |
| **Quaver** | ±18 (Marv) | ±43 (Perf) | ±76 (Great) | ±106 (Good) | — | > 106 |

### Strictest → Most Lenient (Best Judgement Window)

1. **Ruthless** — 10ms (configurable down to 0ms)
2. **osu!mania** — 16ms (fixed MAX window)
3. **DJMAX** — 16ms
4. **IIDX** — 16.67ms
5. **Quaver** — 18ms
6. **Wife3** — 22ms (J4 default, configurable down to 8.8ms at J9)
7. **ITG** — 21.5ms (configurable)
8. **O2Jam** — 33ms (fixed) / BPM-dependent

---

## Grade Threshold Comparison

What accuracy do you need for the "best" achievable grade (below perfect)?

| System | Top Grade | Requires | Second Grade | Requires |
|--------|-----------|----------|-------------|----------|
| Wife3 | AAAAA | 99.70% | AAAA | 99.50% |
| osu!mania | SS | 100% | S | > 95% |
| ITG | ★★★★ | 100% | ★★★ | ≥ 99% |
| Ruthless | X+ | 99.00% | X | 98.50% |
| O2Jam | SSS | 100% | SS | ≥ 99% |
| DJMAX | S | 97.00% | A | ≥ 90% |
| IIDX | AAA | 88.89% | AA | 77.78% |
| Quaver | X | 100% | SS | ≥ 99% |

---

## Supporting Features

These scripts work alongside all scoring systems:

### Timing Display
Color-coded timing feedback (e.g. "+12.5ms") that appears on-screen after each note hit. Colors match the active scoring system's judgement tiers.

### Score Comparison
Shows **all 10 scoring systems side by side** during gameplay — score, accuracy, grade, and FC tier for each. Useful for comparing how different systems evaluate the same performance.

### Rating Popups
Optionally replaces Psych Engine's default rating images (sick/good/bad/shit) with custom sprites matching the active scoring system's judgement names. Place images in `images/ratings/[system]/[judgement].png`.

### Judgement Counter
Displays a breakdown of judgement counts during gameplay.

---

## Installation

1. Download the script pack folder
2. Place it in your `mods/` directory:
   ```
   mods/[Script Pack] Lulu's Scoring Systems/
   ├── pack.json
   ├── data/
   │   └── settings.json
   ├── scripts/
   │   ├── Wife3 Scoring System.hx
   │   ├── OsuMania Scoring System.hx
   │   ├── OsuManiaV2 Scoring System.hx
   │   ├── ITG Scoring System.hx
   │   ├── Ruthless Scoring System.hx
   │   ├── O2Jam Scoring System.hx
   │   ├── DJMAX Scoring System.hx
   │   ├── IIDX Scoring System.hx
   │   ├── Quaver Scoring System.hx
   │   ├── Timing Display.hx
   │   ├── Score Comparison.hx
   │   ├── Rating Popups.hx
   │   └── Judgement Counter.hx
   └── images/
       └── ratings/          (optional custom rating popup images)
   ```
3. Enable the script pack in the Psych Engine mod menu
4. Configure your preferred scoring system in **Mod Settings**

---

## Configuration

All settings are configurable through Psych Engine's **Mod Settings** menu. No code editing required.

### General Settings (All Systems)

| Setting | Description | Default |
|---------|-------------|---------|
| Scoring System | Select active system | Psych |
| Replace Score Text | Override default HUD text | On |
| Custom Rating Popups | Use system-specific rating images | Off |
| Show Timing Display | Show ms timing feedback | On |
| Use Kade Engine Style | Alternative score text format | Off |
| Show Score Comparison | Show all systems side by side | Off |
| Enable Scoring Debug Output | Print debug info | Off |

### Per-System Settings

| System | Setting | Description |
|--------|---------|-------------|
| Wife3 | Judge Preset (1–9) | Timing strictness preset |
| Wife3 | Judge Scale (0.009–4.0) | Custom timing scale (overrides preset) |
| Wife3 | Use Etterna FC Tier Names | PFC vs SFC naming |
| osu!mania V1/V2 | Overall Difficulty (0–10) | Timing window strictness |
| ITG | Window Scale (0.1–4.0) | Timing window multiplier |
| Ruthless | Perfect Window (0–25ms) | Flawless timing threshold |
| O2Jam | BPM-Based Windows | Authentic BPM-scaling toggle |

---

## For Developers

All scoring systems register their functions as global callbacks, accessible from any other script via `getVar()`:

```haxe
// Example: Reading Wife3 accuracy from another script
var getAcc = getVar('wife3_getAccuracy');
if (getAcc != null) {
    var accuracy = getAcc();
    trace('Wife3 accuracy: ' + accuracy + '%');
}
```

### Callback Prefixes

| System | Prefix | Example |
|--------|--------|---------|
| Wife3 | `wife3_` | `wife3_getAccuracy`, `wife3_getScore`, `wife3_getGrade` |
| osu!mania V1 | `osu_` | `osu_getAccuracy`, `osu_getScore`, `osu_getGrade` |
| osu!mania V2 | `osuv2_` | `osuv2_getAccuracy`, `osuv2_getScore`, `osuv2_getGrade` |
| ITG | `itg_` | `itg_getAccuracy`, `itg_getScore`, `itg_getGrade` |
| Ruthless | `ruthless_` | `ruthless_getAccuracy`, `ruthless_getScore`, `ruthless_getGrade` |
| O2Jam | `o2jam_` | `o2jam_getAccuracy`, `o2jam_getScore`, `o2jam_getGrade` |
| DJMAX | `djmax_` | `djmax_getAccuracy`, `djmax_getScore`, `djmax_getGrade` |
| IIDX | `iidx_` | `iidx_getAccuracy`, `iidx_getScore`, `iidx_getGrade` |
| Quaver | `quaver_` | `quaver_getAccuracy`, `quaver_getScore`, `quaver_getGrade` |

### Common Callbacks (All Systems)

Every system exposes:

| Callback | Returns | Description |
|----------|---------|-------------|
| `{prefix}_getAccuracy()` | Float | Current accuracy percentage (0–100) |
| `{prefix}_getScore()` | Int | Current score |
| `{prefix}_getGrade(percent)` | String | Letter grade for given accuracy |
| `{prefix}_getRatingFC()` | String | FC tier string |
| `{prefix}_formatPercent(value)` | String | Formatted percentage string |
| `{prefix}_getJudgement(offsetMs)` | String | Judgement name for timing offset |
| `{prefix}_getHitWindow(judgement)` | Float | Window size for judgement name |
| `{prefix}_setEnabled(bool)` | Void | Enable/disable system |
| `{prefix}_resetScoring()` | Void | Reset all state |

---

*Script pack by AutisticLulu.*
