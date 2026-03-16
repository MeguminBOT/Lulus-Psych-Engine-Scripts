# Ruthless Scoring System

## Overview

Ruthless is a **custom-designed scoring system** that emphasizes precise timing through a linear accuracy curve with a configurable "perfect zone." Only hits within a tiny window (default 10ms) earn full points, and accuracy is always non-negative (0–100%) — there are no negative penalties like Wife3.

The score uses **osu!mania-style base+bonus scoring** capped at 1,000,000, rewarding consistency through a bonus multiplier that builds with accurate hits and drops sharply on poor ones.

**Origin:** Custom (inspired by osu!mania scoring with stricter accuracy)
**Script Prefix:** `ruthless_`
**Primary Metric:** Accuracy (0–100%, never negative)
**Score Cap:** 1,000,000

---

## Differences from osu!mania (Inspiration Source)

Ruthless is a **custom-designed system**, not a direct replica of any game. Its scoring formula borrows from osu!mania's ScoreV1 base+bonus system while introducing entirely custom accuracy and judgement mechanics:

| Aspect | osu!mania ScoreV1 (Inspiration) | Ruthless |
|--------|--------------------------------|----------|
| **Accuracy Curve** | Discrete judgement tiers (MAX/300/200/100/50) with fixed accuracy weights per tier | Continuous **linear curve** based on raw ms offset — accuracy smoothly drops from 100% to 0% |
| **Perfect Zone** | MAX (≤16ms, fixed) gives highest score tier | Configurable perfect window (0–25ms, default 10ms) gives 100% accuracy |
| **Score Formula** | Base+Bonus with hitValue/hitBonus/hitPunishment tables per judgement | Same base+bonus formula structure, but mapped to **7 custom judgement tiers** with custom hitValues |
| **Judgement Tiers** | 6 tiers: MAX, 300, 200, 100, 50, Miss | 7 tiers: Flawless, Precise, Great, Good, Ok, Sloppy, Barely + Miss |
| **Combo Break Threshold** | Only misses break combo; all hits (including 50) continue combo | Hits **>50ms break combo** (Sloppy, Barely) even though they still earn accuracy — stricter than osu!mania |
| **2× Penalty Zone** | No doubled falloff — judgement boundaries are hard cutoffs | Linear falloff **doubles past 50ms** — a 75ms hit is scored as if it were 100ms |
| **OD System** | Hit windows scale with Overall Difficulty (OD 0–10) | No OD — windows are fixed with only the perfect zone configurable |
| **Playback Rate Mods** | ModMultiplier reduces max score at slow speeds; ModDivider reduces punishment at fast speeds | Not implemented — no rate-based score adjustments |
| **Sustain Tails** | Tail releases judged independently with 1.5× lenient windows | Not implemented — uses Psych Engine's default sustain handling |
| **Grade Tiers** | 6 grades: SS, S, A, B, C, D | **23 grades**: XX through F — extremely granular ranking |
| **FC Tiers** | PFC (all MAX), FC (no misses) | FFC, PFC, GFC, FC (no >50ms hits), SDCB, Clear — more tiers reflecting the stricter combo rules |

---

## Timing Windows

Ruthless uses 7 judgement tiers with fixed boundaries (except Flawless, which uses the configurable perfect window):

| Judgement | Window | Score Role |
|-----------|--------|-----------|
| Flawless | ≤ perfectWindow (default 10ms) | Full accuracy + highest score |
| Precise | ≤ 20ms | High accuracy |
| Great | ≤ 30ms | Good accuracy |
| Good | ≤ 40ms | Moderate accuracy |
| Ok | ≤ 50ms | Low accuracy (last combo-safe tier) |
| Sloppy | ≤ 75ms | Very low accuracy + **combo break** |
| Barely | ≤ 100ms | Minimal accuracy + **combo break** |
| Miss | > 100ms | Zero accuracy + **combo break** |

> Hits later than 50ms break combo, even though they still earn some accuracy points.

---

## Ruthless Algorithm

The accuracy curve is **linear** with a doubled penalty past 50ms:

### Perfect Zone ($|\text{offset}| \leq \text{perfectWindow}$)

$$\text{accuracy} = 1.0$$

### Normal Falloff ($\text{perfectWindow} < |\text{offset}| \leq 50\text{ms}$)

$$\text{accuracy} = 1.0 - \frac{|\text{offset}| - \text{perfectWindow}}{100 - \text{perfectWindow}}$$

Standard linear decrease from 1.0 toward 0.0.

### Doubled Falloff ($50\text{ms} < |\text{offset}| \leq 100\text{ms}$)

$$\text{adjustedOffset} = 50 + (|\text{offset}| - 50) \times 2$$

$$\text{accuracy} = \max\!\left(0, \quad 1.0 - \frac{\text{adjustedOffset} - \text{perfectWindow}}{100 - \text{perfectWindow}}\right)$$

Past 50ms, the offset is effectively doubled — a 75ms hit is treated like a 100ms hit in the falloff calculation. This makes the curve twice as steep in the second half.

### Beyond Miss Window ($|\text{offset}| > 100\text{ms}$)

$$\text{accuracy} = 0.0$$

### Curve Visualization (default 10ms perfect window)

```
Accuracy
1.0 |████████████
    |            ████
    |                ████
    |                    ████
    |                        ██  ← 2x steeper after 50ms
    |                          █
    |                           █
0.0 |____________________________█___
    0    10   20   30   40   50  75  100ms
         ↑                   ↑       ↑
    perfectWindow        2x penalty  miss
```

### Worked Example (perfectWindow = 10ms)

| Offset | Calculation | Accuracy |
|--------|-------------|----------|
| 5ms | Within perfect zone | 100.0% |
| 10ms | Within perfect zone | 100.0% |
| 30ms | 1.0 - (30-10)/(100-10) = 1.0 - 20/90 | 77.8% |
| 50ms | 1.0 - (50-10)/(100-10) = 1.0 - 40/90 | 55.6% |
| 60ms | adjusted = 50 + (60-50)×2 = 70, 1.0 - (70-10)/90 | 33.3% |
| 75ms | adjusted = 50 + (75-50)×2 = 100, 1.0 - (100-10)/90 = 0.0 | 0.0% |
| 100ms | Beyond miss window | 0.0% |

> With the default 10ms perfect window and 2x penalty, accuracy already reaches 0% at 75ms — true 100ms hits are rare since the curve bottoms out earlier.

---

## Score System (osu!mania-style Base + Bonus)

The scoring formula is identical to osu!mania ScoreV1's base+bonus system, mapped to Ruthless's 7 judgement tiers:

### Hit Values

| Judgement | hitValue | hitBonusValue | hitBonus | hitPunishment |
|-----------|----------|---------------|----------|---------------|
| Flawless | 320 | 32 | +2.0 | 0 |
| Precise | 310 | 24 | +1.0 | 0 |
| Great | 300 | 16 | 0 | 0 |
| Good | 250 | 12 | 0 | -4.0 |
| Ok | 200 | 8 | 0 | -8.0 |
| Sloppy | 100 | 4 | 0 | -24.0 |
| Barely | 50 | 2 | 0 | -44.0 |

### Score Formula

$$\text{factor} = \frac{1{,}000{,}000 \times 0.5}{N_\text{total}}$$

Bonus is updated **before** calculating the bonus score:

$$\text{Bonus} = \text{clamp}(\text{Bonus} + \text{hitBonus} - \text{hitPunishment}, \; 0, \; 100)$$

$$\text{BaseScore} = \text{factor} \times \frac{\text{hitValue}}{320}$$

$$\text{BonusScore} = \text{factor} \times \frac{\text{hitBonusValue} \times \sqrt{\text{Bonus}}}{320}$$

$$\text{Score} = \text{round}(\sum \text{BaseScore} + \sum \text{BonusScore})$$

### Score Breakdown Example (100-note chart, all Flawless)

$$\text{factor} = \frac{1{,}000{,}000 \times 0.5}{100} = 5{,}000$$

Per note:
- BaseScore = 5000 × (320/320) = 5000
- Bonus stays at 100 (max)
- BonusScore = 5000 × (32 × √100 / 320) = 5000 × (32 × 10 / 320) = 5000

Total: 100 × (5000 + 5000) = **1,000,000**

---

## Combo System

| Judgement | Combo Effect |
|-----------|-------------|
| Flawless | Combo continues (+1) |
| Precise | Combo continues (+1) |
| Great | Combo continues (+1) |
| Good | Combo continues (+1) |
| Ok | Combo continues (+1) |
| Sloppy | **Combo breaks** (>50ms) |
| Barely | **Combo breaks** (>50ms) |
| Miss | **Combo breaks** |

The threshold for combo breaks is 50ms — the boundary between Ok and Sloppy. This is tracked separately from engine misses as `comboBreaks`.

---

## Grade Thresholds

Ruthless uses **23 grade tiers** for extremely granular performance ranking:

| Grade | Accuracy | Grade | Accuracy | Grade | Accuracy |
|-------|----------|-------|----------|-------|----------|
| XX | ≥ 99.50% | SS+ | ≥ 97.50% | A+ | ≥ 93.00% |
| X+ | ≥ 99.00% | SS | ≥ 97.00% | A | ≥ 92.00% |
| X | ≥ 98.50% | SS- | ≥ 96.50% | A- | ≥ 91.00% |
| X- | ≥ 98.00% | S+ | ≥ 96.00% | B+ | ≥ 90.00% |
| | | S | ≥ 95.00% | B | ≥ 88.50% |
| | | S- | ≥ 94.00% | B- | ≥ 87.00% |
| | | | | C+ | ≥ 85.50% |
| | | | | C | ≥ 84.00% |
| | | | | C- | ≥ 82.50% |
| | | | | D+ | ≥ 80.00% |
| | | | | D | ≥ 77.50% |
| | | | | D- | ≥ 75.00% |
| | | | | F | < 75.00% |

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| FFC | All Flawless — no other judgements |
| PFC | Flawless + Precise only |
| GFC | Flawless + Precise + Great only |
| FC | No Sloppy, Barely, or Misses (all hits ≤ 50ms) |
| SDCB | < 10 total combo breaks (misses + breaks from >50ms hits) |
| Clear | 10+ combo breaks |

> FC in Ruthless means no hits later than 50ms — stricter than most systems.

---

## Configuration

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `ruthless_enabled` | `true` | — | Enable/disable scoring |
| `ruthless_debug` | `false` | — | Show debug messages |
| `ruthless_replaceScoreText` | `true` | — | Replace Psych Engine's default score text |
| `ruthless_kadeEngineStyle` | `false` | — | Use Kade Engine style formatting |
| `ruthless_perfectWindow` | `10.0` | 0–25ms | Width of the 100% accuracy zone |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"Ruthless"` to activate |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |
| `ruthless_perfectWindow` | Float (0-25) | Configure perfect window |

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `ruthless_getAccuracy()` | Float (0-100) | Current accuracy percentage |
| `ruthless_getScore()` | Int | Current song score (0 to 1,000,000) |
| `ruthless_getGrade(percent)` | String | Grade for given accuracy |
| `ruthless_getPerfectWindow()` | Float | Current perfect window in ms |
| `ruthless_getTimingWindow(type)` | Float | Window in ms for given tier |
| `ruthless_getJudgement(offsetMs)` | String | Judgement name for offset |
| `ruthless_getFlawlessHits()` | Int | Flawless count |
| `ruthless_getPreciseHits()` | Int | Precise count |
| `ruthless_getGreatHits()` | Int | Great count |
| `ruthless_getGoodHits()` | Int | Good count |
| `ruthless_getOkHits()` | Int | Ok count |
| `ruthless_getSloppyHits()` | Int | Sloppy count |
| `ruthless_getBarelyHits()` | Int | Barely count |
| `ruthless_getRatingFC()` | String | Current FC tier |
| `ruthless_formatPercent(value)` | String | Format to 2 decimal places |
| `ruthless_getReplaceScoreText()` | Bool | Score text replacement state |
| `ruthless_getKadeEngineStyle()` | Bool | Kade Engine style state |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `ruthless_setEnabled(bool)` | Enable/disable scoring |
| `ruthless_setPerfectWindow(ms)` | Set perfect window (clamped 0–25) |
| `ruthless_resetScoring()` | Reset all state to initial values |
| `ruthless_setReplaceScoreText(bool)` | Toggle score text replacement |
| `ruthless_setKadeEngineStyle(bool)` | Toggle Kade Engine style |
| `ruthless_updateScoreText()` | Force score text update |

---

## Score Text Format

**Psych Engine style:**
```
Score: 987654 | Combo Breaks: 3 | Misses: 1 | Rating: S+ (96.32%) - FC
```

**Kade Engine style:**
```
Score: 987654 | Combo Breaks: 3 | Misses: 1 | Accuracy: 96.32 % | (FC) S+
```

> Score text always shows both combo breaks (from >50ms hits) and misses separately.
