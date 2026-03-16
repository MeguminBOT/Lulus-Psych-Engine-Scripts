# Wife3 (Etterna) Scoring System

## Overview

This scoring system implements **Etterna's Wife3** accuracy algorithm — a continuous accuracy curve that uses the mathematical error function (erf) to calculate precision points. Unlike discrete judgement-based systems, Wife3 produces a smooth, granular accuracy value that responds to even sub-millisecond timing differences.

**Origin Game:** Etterna (StepMania fork)
**Script Prefix:** `wife3_`
**Primary Metric:** Wife3 Accuracy Percentage (continuous, 0–100%)
**Secondary Metric:** Song Score (Wife3 accuracy mapped to points)

---

## Differences from Etterna

This implementation closely follows Etterna's Wife3 algorithm (ported from the C++ source) but differs in several key scoring areas:

| Aspect | Etterna (Original) | This Implementation |
|--------|-------------------|---------------------|
| **Wife3 Algorithm** | Exact C++ implementation with `double` precision floating-point math | Faithful port — erf() approximation and all four regions are identical, but minor floating-point differences may occur due to Haxe/HScript runtime |
| **Negative Accuracy** | Wife3 accuracy can go deeply negative (e.g., -30% on a bad play) and is displayed as-is | Clamped to **0% minimum** for display — Psych Engine's score text doesn't handle negative percentages |
| **Song Score** | Etterna uses Wife3 percentage directly as the score metric; no separate "points" system | Custom song score conversion: positive Wife3 points → up to 350pts, negative → min -200pts per note — **this is NOT from Etterna** |
| **MaxWife Tracking** | Etterna has a Wife% ceiling where MaxWife tracks theoretical best remaining accuracy | Not implemented — no max-possible tracking or "best remaining" display |
| **Mine Notes** | Mines (anti-notes) penalize Wife3 accuracy if hit | Not implemented — FNF has no mine note type |
| **Hold Notes** | Dropped holds penalize Wife3 accuracy directly | Sustain notes handled by Psych Engine's default system — **no Wife3 penalty for dropped holds** |
| **Combo System** | Combo tracked but has no effect on Wife3 accuracy or scoring | Same behavior — combo has no effect on Wife3 calculations |

---

## Judge System

Wife3's core innovation is the **judge scale** — a single floating-point value that controls all timing windows. The scale is exposed as both preset integers (J1–J9) and a raw decimal for fine-tuning.

### Judge Presets

| Preset | Scale | Marvelous Window | Bad Window |
|--------|-------|-----------------|------------|
| J1 | 4.0 | ±88.0ms | ±720ms |
| J2 | 3.0 | ±66.0ms | ±540ms |
| J3 | 2.0 | ±44.0ms | ±360ms |
| **J4** | **1.0** | **±22.0ms** | **±180ms** |
| J5 | 0.9 | ±19.8ms | ±162ms |
| J6 | 0.75 | ±16.5ms | ±135ms |
| J7 | 0.6 | ±13.2ms | ±108ms |
| J8 | 0.5 | ±11.0ms | ±90ms |
| J9 (JUSTICE) | 0.4 | ±8.8ms | ±72ms |

> J4 (scale = 1.0) is the standard difficulty. Lower scale = harder. Custom scales from 0.009 to 4.0 are supported.

### Timing Windows

All windows are calculated from the judge scale:

| Judgement | Formula | J4 (1.0) | J9 (0.4) |
|-----------|---------|----------|----------|
| Marvelous | 22 × scale | ±22ms | ±8.8ms |
| Perfect | 45 × scale | ±45ms | ±18ms |
| Great | 90 × scale | ±90ms | ±36ms |
| Good | 135 × scale | ±135ms | ±54ms |
| Bad | 180 × scale | ±180ms | ±72ms |
| Miss | >180 × scale | >180ms | >72ms |

---

## Wife3 Algorithm

The wife3 function maps a timing offset (in seconds) to accuracy points in the range **-5.5 to +2.0**. It uses four regions with different curves:

### Threshold Calculations

Given judge scale $s$:

$$\text{ridic} = 5 \times s$$
$$\text{zero} = 65 \times s^{0.75}$$
$$\text{dev} = 22.7 \times s^{0.75}$$
$$\text{maxBoo} = 180 \times s$$

### Region 1: Perfect Zone ($|\text{offset}| \leq \text{ridic}$)

$$\text{points} = 2.0$$

Hits within 5ms × scale earn maximum points. At J4, this is ±5ms.

### Region 2: Error Function Curve ($|\text{offset}| \leq \text{zero}$)

$$\text{points} = 2.0 \times \text{erf}\!\left(\frac{\text{zero} - |\text{offset}|}{\text{dev}}\right)$$

The error function creates a smooth S-shaped curve that gradually decreases from 2.0 toward 0.0. The `zero` threshold is where the erf output crosses zero — hits at exactly this offset earn 0 points.

### Region 3: Linear Penalty ($|\text{offset}| \leq \text{maxBoo}$)

$$\text{points} = \frac{(|\text{offset}| - \text{zero}) \times (-5.5)}{\text{maxBoo} - \text{zero}}$$

Linear interpolation from 0 to -5.5. This punishes late/bad hits with increasing negative accuracy.

### Region 4: Miss ($|\text{offset}| > \text{maxBoo}$)

$$\text{points} = -5.5$$

Maximum penalty. Same as a miss.

### Error Function Approximation

The erf() implementation uses **Abramowitz & Stegun formula 7.1.26**:

$$\text{erf}(x) = 1 - (a_1t + a_2t^2 + a_3t^3 + a_4t^4 + a_5t^5)e^{-x^2}$$

Where $t = \frac{1}{1 + 0.3275911 \cdot |x|}$ and the coefficients are:
- $a_1 = 0.254829592$
- $a_2 = -0.284496736$
- $a_3 = 1.421413741$
- $a_4 = -1.453152027$
- $a_5 = 1.061405429$

---

## Accuracy Calculation

Wife3 accuracy is a running weighted average:

$$\text{Accuracy} = \frac{\sum \text{wife3}(\text{offset}_i)}{N \times 2.0} \times 100\%$$

Where:
- Each hit adds its wife3 points (can be negative) to the numerator
- Each hit (or miss) adds 2.0 (the maximum possible) to the denominator
- Misses add -5.5 to the numerator and 2.0 to the denominator

### Worked Example

5 notes hit at J4:

| Note | Offset | Wife3 Points | Running Total | Running Max |
|------|--------|-------------|---------------|-------------|
| 1 | 3ms | +2.000 (Region 1) | 2.000 | 2.0 |
| 2 | 15ms | +1.847 (Region 2, erf) | 3.847 | 4.0 |
| 3 | 40ms | +0.892 (Region 2, erf) | 4.739 | 6.0 |
| 4 | 100ms | -1.661 (Region 3, linear) | 3.078 | 8.0 |
| 5 | Miss | -5.500 (Region 4) | -2.422 | 10.0 |

$$\text{Accuracy} = \frac{-2.422}{10.0} \times 100\% = -24.22\% \to 0\%$$

(Clamped to 0% minimum)

> One miss at J4 is devastating — it takes roughly 2.75 perfect hits just to recover from the -5.5 penalty.

---

## Song Score

Song score converts Wife3 points to an integer point value:

$$\text{scorePoints} = \begin{cases} \text{round}\!\left(\frac{\text{wife3Points}}{2.0} \times 350\right) & \text{if wife3Points} \geq 0 \\ \text{round}\!\left(\frac{\text{wife3Points}}{2.0} \times 200\right) & \text{if wife3Points} < 0 \end{cases}$$

| Wife3 Points | Song Score Points |
|-------------|------------------|
| +2.0 (perfect) | +350 |
| +1.0 | +175 |
| 0.0 | 0 |
| -2.75 | -275 |
| -5.5 (miss) | -550 |

> Positive hits can earn up to 350 points, but negative hits are capped at -200× the ratio, reducing the harshness slightly for score.

---

## Combo System

Wife3 itself does **not** track combo — Psych Engine's built-in combo system handles this. The script only processes accuracy; combo is managed by the engine's default `goodNoteHit` and `noteMiss` behavior.

---

## Grade Thresholds

Grades are based on Wife3 accuracy percentage:

| Grade | Accuracy Required |
|-------|------------------|
| AAAAA | ≥ 99.70% |
| AAAA | ≥ 99.50% |
| AAA | ≥ 99.00% |
| AA | ≥ 98.00% |
| A | ≥ 96.50% |
| B | ≥ 93.00% |
| C | ≥ 90.00% |
| D | ≥ 80.00% |
| F | < 80.00% |

> The gap between AAAA (99.50%) and AAAAA (99.70%) is tiny — only 0.2% — reflecting Etterna's emphasis on near-perfect play at the top tier.

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| MFC | All Marvelous — no Perfects, Greats, Goods, or Bads |
| PFC | No Greats, Goods, or Bads — Marvelous + Perfect only |
| GFC | No Goods or Bads — Marvelous + Perfect + Great only |
| FC | No misses at all |
| SDCB | < 10 misses (Single Digit Combo Break) |
| Clear | 10+ misses |

---

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `wife3_enabled` | `true` | Enable/disable the scoring system |
| `wife3_debug` | `false` | Show debug messages |
| `wife3_replaceScoreText` | `true` | Replace Psych Engine's default score text |
| `wife3_kadeEngineStyle` | `false` | Use Kade Engine style formatting |
| `wife3_judge_scale` | `1.0` | Judge scale (1.0 = J4) |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"Wife3"` to activate |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |
| `wife3_judgePreset` | Int (1-9) | Set judge preset (J1–J9) |
| `wife3_judgeScale` | Float (0.009-4.0) | Custom judge scale (overrides preset) |

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `wife3_getAccuracy()` | Float (0-100) | Current Wife3 accuracy percentage |
| `wife3_getScore()` | Int | Current song score |
| `wife3_getGrade(percent)` | String | Grade for given accuracy |
| `wife3_getJudgeScale()` | Float | Current judge scale |
| `wife3_getJudgePreset()` | Float | Current judge preset (with interpolation) |
| `wife3_getTimingWindow(type)` | Float | Window in ms for given type |
| `wife3_getMarvelousHits()` | Int | Count of Marvelous hits |
| `wife3_getPerfectHits()` | Int | Count of Perfect hits |
| `wife3_getGreatHits()` | Int | Count of Great hits |
| `wife3_getGoodHits()` | Int | Count of Good hits |
| `wife3_getBadHits()` | Int | Count of Bad hits |
| `wife3_getRatingFC()` | String | Current FC tier |
| `wife3_formatPercent(value)` | String | Format to 2 decimal places |
| `wife3_getReplaceScoreText()` | Bool | Whether score text replacement is on |
| `wife3_getKadeEngineStyle()` | Bool | Whether Kade Engine style is on |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `wife3_setEnabled(bool)` | Enable/disable scoring |
| `wife3_setJudgeScale(scale)` | Set custom judge scale (0.009–0.090) |
| `wife3_setJudgePreset(1-9)` | Set judge preset |
| `wife3_resetAccuracy()` | Reset all state to initial values |
| `wife3_setReplaceScoreText(bool)` | Toggle score text replacement |
| `wife3_setKadeEngineStyle(bool)` | Toggle Kade Engine style |
| `wife3_updateScoreText()` | Force score text update |

---

## Score Text Format

**Psych Engine style:**
```
Score: 12500 | Misses: 2 | Rating: AAA (99.12%) - PFC
```

**Kade Engine style:**
```
Score: 12500 | Combo Breaks: 2 | Accuracy: 99.12 % | (PFC) AAA
```
