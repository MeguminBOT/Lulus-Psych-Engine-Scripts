# ITG (In The Groove) Scoring System

## Overview

This scoring system implements **In The Groove / StepMania's** DDR MAX2-style scoring combined with ITG's dance point accuracy. It features a unique progressive-weight scoring formula where later notes are worth more than earlier ones, and integrates **hold note judgements** (OK/NG) as first-class scoring events.

**Origin Game:** In The Groove / StepMania (DDR MAX2 scoring formula)
**Script Prefix:** `itg_`
**Max Score:** 10,000,000 per song
**Primary Accuracy:** Dance Point Percentage (DP%)

---

## Differences from In The Groove / StepMania

This implementation faithfully reproduces the DDR MAX2 scoring formula and ITG dance point system with a few key differences:

| Aspect | ITG / StepMania (Original) | This Implementation |
|--------|---------------------------|---------------------|
| **DDR MAX2 Scoring** | Exact same progressive-weight formula (scoreWeight × stepCount) with triangular number max | Faithfully reproduced — same formula, same weights, same progressive behavior |
| **Dance Points** | Exact ITG theme DP weights: Fantastic=5, Excellent=4, Great=2, Decent=0, WayOff=-6, Miss=-12 | Same weights faithfully reproduced, including negative DP for Way Off and Miss |
| **Hold Scoring** | Hold OK/NG affect both score and DP as independent events, incrementing the step counter | Same behavior — holds count as additional scoring events and increment stepCount for progressive weighting |
| **Hold Notes** | Hold/Roll/Freeze arrows scored as OK/NG at release; rolls require continuous stepping | Only basic holds implemented (OK/NG) — no roll notes or freeze arrows |
| **Mine Notes** | Mines penalize if stepped on; avoiding them is part of scoring | Not implemented — FNF has no mine note type |
| **Timing Windows** | ITG2 base windows from metrics.ini (Fantastic ±21.5ms, Excellent ±43ms, Great ±102ms, Decent ±135ms, Way Off ±180ms) | Same base windows; window scale multiplier (0.1–4.0) added for difficulty customization |
| **Step Counter** | The step counter (used for progressive weighting) increments for ALL events including misses | Same behavior — stepCount always increments, even on miss, ensuring consistent progressive weighting |

---

## Timing Windows

ITG timing windows are wider than most systems, with optional scaling:

| Judgement | Base Window | Scaled (×0.5) | Scaled (×2.0) |
|-----------|------------|---------------|---------------|
| Fantastic | ±21.5ms | ±10.75ms | ±43ms |
| Excellent | ±43.0ms | ±21.5ms | ±86ms |
| Great | ±102.0ms | ±51ms | ±204ms |
| Decent | ±135.0ms | ±67.5ms | ±270ms |
| Way Off | ±180.0ms | ±90ms | ±360ms |

All windows are multiplied by `itg_windowScale` (default: 1.0, range: 0.1–4.0).

---

## DDR MAX2 Scoring

### The Step Counter

The DDR MAX2 formula uses a **step counter** that increments with every scoring event (tap hit, hold result, or miss). Crucially, later notes earn more points because the step counter multiplies the weight:

$$\text{earnedPoints} \mathrel{+}= \text{scoreWeight} \times \text{stepCount}$$

### Score Weights

| Event | Score Weight |
|-------|-------------|
| Fantastic | 10 |
| Excellent | 9 |
| Great | 5 |
| Decent | 0 |
| Way Off | 0 |
| Miss | 0 |
| Hold OK | 10 (same as Fantastic) |
| Hold NG | 0 |

### Maximum Possible Points

If $N$ = total scoring events (taps + holds):

$$\text{maxPossible} = 10 \times \frac{N \times (N + 1)}{2}$$

This is the triangular number formula — sum of $10 \times 1 + 10 \times 2 + \ldots + 10 \times N$.

### Displayed Score

$$\text{displayedScore} = \text{round}\!\left(\frac{\text{earnedPoints}}{\text{maxPossible}} \times 10{,}000{,}000\right)$$

### Why Later Notes Matter More

Consider a 4-note chart where you get Fantastic on all notes:

| Step | Score Weight | Step Count | Points Added | Cumulative |
|------|-------------|------------|-------------|------------|
| 1 | 10 | 1 | 10 | 10 |
| 2 | 10 | 2 | 20 | 30 |
| 3 | 10 | 3 | 30 | 60 |
| 4 | 10 | 4 | 40 | 100 |

Max possible = $10 \times 4 \times 5 / 2 = 100$. Score = $100/100 \times 10M = 10{,}000{,}000$.

Now if step 4 was a Way Off instead:

| Step | Score Weight | Step Count | Points Added | Cumulative |
|------|-------------|------------|-------------|------------|
| 1 | 10 | 1 | 10 | 10 |
| 2 | 10 | 2 | 20 | 30 |
| 3 | 10 | 3 | 30 | 60 |
| 4 | **0** | 4 | **0** | **60** |

Score = $60/100 \times 10M = 6{,}000{,}000$. Missing the last note cost 40% of the score!

If step 1 was Way Off instead:
| Step | Score Weight | Step Count | Points Added | Cumulative |
|------|-------------|------------|-------------|------------|
| 1 | **0** | 1 | **0** | **0** |
| 2 | 10 | 2 | 20 | 20 |
| 3 | 10 | 3 | 30 | 50 |
| 4 | 10 | 4 | 40 | 90 |

Score = $90/100 \times 10M = 9{,}000{,}000$. Missing the first note only cost 10%.

> This progressive weighting means recovery is possible — doing well at the end of a song recovers more points than doing well at the start.

---

## Dance Point Accuracy

Dance Points provide a separate accuracy metric independent of note ordering:

### Dance Point Weights

| Event | DP Weight | Max Per Event |
|-------|-----------|---------------|
| Fantastic | +5 | 5 |
| Excellent | +4 | 5 |
| Great | +2 | 5 |
| Decent | 0 | 5 |
| Way Off | **-6** | 5 |
| Miss | **-12** | 5 |
| Hold OK | +5 | 5 |
| Hold NG | 0 | 5 |

### DP Accuracy Formula

$$\text{DP\%} = \frac{\text{earnedDP}}{\text{maxDP}} \times 100\%$$

Where maxDP increments by 5 for every scoring event (the max possible per event).

### Worked Example

200-note chart (150 taps + 50 holds), player gets:
- 120 Fantastic, 20 Excellent, 8 Great, 2 Decent, 0 Way Off, 0 Miss
- 45 Hold OK, 5 Hold NG

$$\text{earnedDP} = (120 \times 5) + (20 \times 4) + (8 \times 2) + (2 \times 0) + (45 \times 5) + (5 \times 0)$$
$$= 600 + 80 + 16 + 0 + 225 + 0 = 921$$
$$\text{maxDP} = 200 \times 5 = 1000$$
$$\text{DP\%} = \frac{921}{1000} \times 100\% = 92.1\%$$

Grade: **S** (92.1% ≥ 92%)

> Note: Way Off (-6 DP) and Miss (-12 DP) are severely punishing — a single miss costs the equivalent of 2.4 Fantastic hits in DP.

---

## Hold Note Scoring

ITG tracks hold notes as additional scoring events:

### Total Notes Calculation

$$\text{totalScoringEvents} = \text{tapNotes} + \text{holdNotes}$$

Each hold note adds one extra scoring event for the tail (OK or NG), in addition to the head tap.

### How Hold Results Work

- **Hold OK:** Player held the note to the end → treated as Fantastic (scoreWeight=10, DP=+5)
- **Hold NG:** Player released early / missed the tail → treated as Decent (scoreWeight=0, DP=0, maxDP still increments)

Only the **last tail piece** of a sustain is scored. Intermediate sustain pieces are ignored.

---

## Combo System

ITG uses Psych Engine's built-in combo system — the script doesn't manually manage combo. The engine handles combo maintenance and breaking.

---

## Grade Thresholds

Grades are based on **Dance Point percentage**:

| Grade | DP% Required | Grade | DP% Required |
|-------|-------------|-------|-------------|
| **** | 100% | A+ | ≥ 86% |
| *** | ≥ 99% | A | ≥ 83% |
| ** | ≥ 98% | A- | ≥ 80% |
| * | ≥ 96% | B+ | ≥ 76% |
| S+ | ≥ 94% | B | ≥ 72% |
| S | ≥ 92% | B- | ≥ 68% |
| S- | ≥ 89% | C+ | ≥ 64% |
| | | C | ≥ 60% |
| | | C- | ≥ 55% |
| | | D | < 55% |

> The quad-star (****) requires a perfect 100% DP — every note Fantastic and every hold OK.

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| FFC | All Fantastic — no Excellents, Greats, Decents, or Way Offs |
| FEC | Fantastic + Excellent only |
| FGC | All Great or better — no Decents or Way Offs |
| FC | No misses at all |
| SDCB | < 10 misses (Single Digit Combo Break) |
| Clear | 10+ misses |

---

## Configuration

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `itg_enabled` | `true` | — | Enable/disable scoring |
| `itg_debug` | `false` | — | Show debug messages |
| `itg_replaceScoreText` | `true` | — | Replace Psych Engine's score text |
| `itg_kadeEngineStyle` | `false` | — | Use Kade Engine style formatting |
| `itg_windowScale` | `1.0` | 0.1–4.0 | Timing window scale factor |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"ITG"` to activate |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |
| `itg_windowScale` | Float (0.1-4.0) | Override timing window scale |

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `itg_getAccuracy()` | Float (0-100) | Dance point percentage |
| `itg_getScore()` | Int | Current DDR MAX2 score (0 to 10M) |
| `itg_getMaxPossibleScore()` | Int | Maximum score (10,000,000) |
| `itg_getGrade(percent)` | String | Grade for given DP% |
| `itg_getWindowScale()` | Float | Current window scale |
| `itg_getHitWindow(judgement)` | Float | Hit window in ms (scaled) |
| `itg_getJudgement(offsetMs)` | String | Judgement for given offset |
| `itg_getFantasticHits()` | Int | Fantastic count |
| `itg_getExcellentHits()` | Int | Excellent count |
| `itg_getGreatHits()` | Int | Great count |
| `itg_getDecentHits()` | Int | Decent count |
| `itg_getWayOffHits()` | Int | Way Off count |
| `itg_getHoldOKs()` | Int | Hold OK count |
| `itg_getHoldNGs()` | Int | Hold NG count |
| `itg_getTotalNotes()` | Int | Total scoring events |
| `itg_getEarnedDP()` | Float | Earned dance points |
| `itg_getMaxDP()` | Float | Maximum dance points so far |
| `itg_getRatingFC()` | String | Current FC tier |
| `itg_formatPercent(value)` | String | Format to 2 decimal places |
| `itg_getReplaceScoreText()` | Bool | Score text replacement state |
| `itg_getKadeEngineStyle()` | Bool | Kade Engine style state |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `itg_setEnabled(bool)` | Enable/disable scoring |
| `itg_setWindowScale(scale)` | Set window scale (0.1–4.0) |
| `itg_resetScoring()` | Reset all state to initial values |
| `itg_recountNotes()` | Recount total scoring events |
| `itg_setReplaceScoreText(bool)` | Toggle score text replacement |
| `itg_setKadeEngineStyle(bool)` | Toggle Kade Engine style |
| `itg_updateScoreText()` | Force score text update |

---

## Score Text Format

**Psych Engine style:**
```
Score: 9876543 | Misses: 2 | Rating: *** (99.12%) - FEC
```

**Kade Engine style:**
```
Score: 9876543 | Combo Breaks: 2 | Accuracy: 99.12 % | (FEC) ***
```
