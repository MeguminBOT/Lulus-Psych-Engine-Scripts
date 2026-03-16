# osu!mania ScoreV2 Scoring System

## Overview

This scoring system implements **osu!mania's ScoreV2** — the modern scoring formula used in osu! tournaments and multiplayer. Unlike ScoreV1's base+bonus system, ScoreV2 splits the 1,000,000 max score into two fixed components: **700,000 for combo** and **300,000 for accuracy**.

The key difference from V1: **all judgements continue combo** (even 50s). Only misses break combo. And accuracy's contribution uses a punishing 10th power exponent.

**Origin Game:** osu! (mania mode, ScoreV2)
**Script Prefix:** `osuv2_`
**Score Cap:** 1,000,000
**Primary Metric:** Accuracy + Combo Ratio

---

## Differences from osu!mania (ScoreV2)

ScoreV2 is osu!mania's modern scoring system used in tournament and multiplayer settings. This implementation reproduces its formula with a few key differences:

| Aspect | osu!mania ScoreV2 (Original) | This Implementation |
|--------|------------------------------|---------------------|
| **Score Formula** | 700K × ComboRatio + 300K × Accuracy^10 | Faithfully reproduced — same two-component formula with the same 10th power exponent |
| **Combo Ratio** | MaxComboAchieved / TotalObjects where total includes taps + LN heads + LN releases | Same formula — sustain heads and tails counted as separate objects |
| **Accuracy^10** | 10th power makes accuracy extremely sensitive at high values and negligible below 80% | Same behavior faithfully reproduced |
| **All Judgements Combo** | MAX, 300, 200, 100, and 50 all continue combo — only misses break | Same behavior — only misses break combo |
| **OD System** | Same OD-based windows as ScoreV1 | Same — shares OD setting with V1 implementation |
| **LN Scoring** | Each LN counts as 2 objects (press + release); both affect combo and accuracy independently | Same behavior — tail releases are judged independently with 1.5× lenient windows |
| **Playback Rate** | No score modifier from rate in ScoreV2 (unlike V1) | Same — no rate-based score adjustment |
| **MaxCombo Tracking** | Peak combo is tracked and permanently determines the combo component | Same behavior — once a combo peak is set, it can only increase, not decrease |
| **Accuracy Ceiling** | Accuracy can only reach 100% with all MAX/300 hits; any 200/100/50 permanently reduces it | Same behavior — accuracy formula is identical to osu!mania |
| **Score Normalization** | V2 was introduced to fix V1's problem where longer maps had inflated scores / unfair multiplayer comparison | Same benefit — all charts score out of exactly 1,000,000 regardless of length |

---

## Timing Windows

Identical to ScoreV1 — OD-based with the same formulas:

| Judgement | Formula | OD 0 | OD 5 | OD 8 | OD 10 |
|-----------|---------|------|------|------|-------|
| MAX | ±16ms (fixed) | ±16ms | ±16ms | ±16ms | ±16ms |
| 300 | ±(64 - 3×OD) | ±64ms | ±49ms | ±40ms | ±34ms |
| 200 | ±(97 - 3×OD) | ±97ms | ±82ms | ±73ms | ±67ms |
| 100 | ±(127 - 3×OD) | ±127ms | ±112ms | ±103ms | ±97ms |
| 50 | ±(151 - 3×OD) | ±151ms | ±136ms | ±127ms | ±121ms |
| Miss | ±(188 - 3×OD) | ±188ms | ±173ms | ±164ms | ±158ms |

### Tail Release Windows

Same 1.5× lenience as V1:

$$\text{tailWindow} = \text{regularWindow} \times 1.5$$

---

## ScoreV2 Formula

$$\text{Score} = 700{,}000 \times \text{ComboRatio} + 300{,}000 \times \text{Accuracy}^{10}$$

### Combo Ratio

$$\text{ComboRatio} = \frac{\text{MaxComboAchieved}}{\text{TotalObjects}}$$

Where:
- **MaxComboAchieved** = the highest combo the player reaches during the song (not current combo)
- **TotalObjects** = total judgeable objects (taps + LN starts + LN releases)
- ComboRatio is capped at 1.0

> This means a single combo break mid-song can permanently cap your ComboRatio at below 1.0, losing a significant portion of the 700K component.

### Accuracy Component

$$\text{Accuracy} = \frac{(N_\text{MAX} + N_{300}) \times 300 + N_{200} \times 200 + N_{100} \times 100 + N_{50} \times 50}{N_\text{total} \times 300}$$

This is the same 0–1 accuracy as V1, but raised to the **10th power** before multiplying by 300,000:

| Accuracy | Accuracy^10 | Accuracy Points |
|----------|-------------|-----------------|
| 100% (1.0) | 1.0 | 300,000 |
| 99% (0.99) | 0.904 | 271,200 |
| 98% (0.98) | 0.817 | 245,100 |
| 95% (0.95) | 0.599 | 179,700 |
| 90% (0.90) | 0.349 | 104,700 |
| 80% (0.80) | 0.107 | 32,100 |
| 70% (0.70) | 0.028 | 8,400 |
| 50% (0.50) | 0.001 | 300 |

> The 10th power is extremely punishing — dropping from 100% to 95% accuracy loses over 120,000 points from the accuracy component alone. Below 90%, the accuracy contribution is nearly negligible.

---

## Key Difference from ScoreV1: Combo Rules

### ScoreV1 Combo Behavior
- Misses break combo
- Tail misses cause combo breaks
- Bonus system rewards consecutive good hits

### ScoreV2 Combo Behavior
- **ALL judgements continue combo** — MAX, 300, 200, 100, AND 50 all increment combo
- **Only misses break combo** (resets to 0)
- MaxComboAchieved tracks the peak, not the current combo

This makes ScoreV2 more forgiving for combo than V1: a 50 judgement in V1 devastates the bonus multiplier, but in V2 it just increases combo while barely affecting accuracy.

---

## Worked Example

200 total objects, player achieves:
- Max combo of 180 (one combo break at note 120, then 80 more without breaking)
- 150 MAX, 30 300s, 10 200s, 5 100s, 3 50s, 2 misses

**Combo Component:**
$$\text{ComboRatio} = \frac{180}{200} = 0.9$$
$$\text{ComboScore} = 700{,}000 \times 0.9 = 630{,}000$$

**Accuracy Component:**
$$\text{Accuracy} = \frac{(150 + 30) \times 300 + 10 \times 200 + 5 \times 100 + 3 \times 50}{200 \times 300}$$
$$= \frac{54{,}000 + 2{,}000 + 500 + 150}{60{,}000} = \frac{56{,}650}{60{,}000} = 0.9442$$

$$\text{Accuracy}^{10} = 0.9442^{10} = 0.5625$$
$$\text{AccuracyScore} = 300{,}000 \times 0.5625 = 168{,}750$$

**Total Score:**
$$\text{Score} = 630{,}000 + 168{,}750 = \textbf{798,750}$$

> Compare: a perfect play would be $700{,}000 + 300{,}000 = 1{,}000{,}000$. The combo break cost 70,000 from combo and inaccurate hits cost 131,250 from accuracy.

---

## Sustain Tail Mechanics

Identical to ScoreV1:

1. **Head hit** starts tracking the sustain on that column
2. **Key release** timing is compared to the tail's end with 1.5× lenient windows
3. **Broken holds** (early release + missed intermediate pieces) cap the tail to 50
4. **Tail misses** break combo and add to accuracy denominator

Each sustain note counts as **2 objects**: the head (tap judgement) and the tail (release judgement). Both contribute to combo and accuracy independently.

### processJudgement (shared function)

V2 uses a shared `processJudgement()` function for all hit types — tap hits, tail hits, and tail releases all flow through the same combo and accuracy tracking. This ensures consistent behavior regardless of how the judgement was triggered.

---

## Grade Thresholds

Same as ScoreV1:

| Grade | Accuracy Required |
|-------|------------------|
| SS | 100% |
| S | > 95% |
| A | > 90% |
| B | > 80% |
| C | > 70% |
| D | ≤ 70% |

> Grades are based on accuracy, not total score. A player can have a low score due to broken combo but still get an S grade if accuracy is high.

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| PFC | All MAX — no 300s, 200s, 100s, or 50s |
| FC | No misses or tail misses |
| SDCB | < 10 total breaks (misses + tail combo breaks) |
| Clear | 10+ breaks |

---

## Configuration

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `osuv2_enabled` | `true` | — | Enable/disable scoring |
| `osuv2_debug` | `false` | — | Show debug messages |
| `osuv2_replaceScoreText` | `true` | — | Replace Psych Engine's score text |
| `osuv2_kadeEngineStyle` | `false` | — | Use Kade Engine style formatting |
| `osuv2_od` | `8.0` | 0–10 | Overall Difficulty (shared with V1) |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"OsuManiaV2"` to activate |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |
| `osu_od` | Float (0-10) | Override OD (same key as V1) |

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `osuv2_getAccuracy()` | Float (0-100) | Current accuracy percentage |
| `osuv2_getScore()` | Int | Current ScoreV2 score |
| `osuv2_getGrade(percent)` | String | Grade for given accuracy |
| `osuv2_getOD()` | Float | Current OD value |
| `osuv2_getHitWindow(judgement)` | Float | Hit window in ms |
| `osuv2_getTailHitWindow(judgement)` | Float | Tail window in ms (1.5×) |
| `osuv2_getJudgement(offsetMs)` | String | Judgement for offset |
| `osuv2_getTailJudgement(offsetMs)` | String | Tail judgement for offset |
| `osuv2_getMaxHits()` | Int | MAX count |
| `osuv2_get300Hits()` | Int | 300 count |
| `osuv2_get200Hits()` | Int | 200 count |
| `osuv2_get100Hits()` | Int | 100 count |
| `osuv2_get50Hits()` | Int | 50 count |
| `osuv2_getCombo()` | Int | Current combo |
| `osuv2_getMaxComboAchieved()` | Int | Peak combo reached |
| `osuv2_getTotalObjects()` | Int | Total objects |
| `osuv2_getRatingFC()` | String | Current FC tier |
| `osuv2_formatPercent(value)` | String | Format to 2 decimal places |
| `osuv2_getReplaceScoreText()` | Bool | Score text replacement state |
| `osuv2_getKadeEngineStyle()` | Bool | Kade Engine style state |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `osuv2_setEnabled(bool)` | Enable/disable scoring |
| `osuv2_setOD(od)` | Set OD (clamped 0–10) |
| `osuv2_resetScoring()` | Reset all state |
| `osuv2_recountObjects()` | Recount total objects |
| `osuv2_setReplaceScoreText(bool)` | Toggle score text replacement |
| `osuv2_setKadeEngineStyle(bool)` | Toggle Kade Engine style |
| `osuv2_updateScoreText()` | Force score text update |

---

## Score Text Format

**Psych Engine style:**
```
Score: 876543 | Combo Breaks: 2 | Misses: 1 | Rating: S (96.50%) - FC
```

**Kade Engine style:**
```
Score: 876543 | Combo Breaks: 2 | Misses: 1 | Accuracy: 96.50 % | (FC) S
```

---

## ScoreV1 vs ScoreV2 Comparison

| Aspect | ScoreV1 | ScoreV2 |
|--------|---------|---------|
| **Score Formula** | BaseScore + BonusScore | 700K × ComboRatio + 300K × Acc^10 |
| **Max Score** | 1,000,000 × ModMult | 1,000,000 (fixed) |
| **Combo Breaks** | Bonus → 0, indirect score loss | Direct 700K component loss |
| **50 Judgement** | Destroys bonus (-44 punishment) | Continues combo, minimal loss |
| **Consistency Reward** | Bonus multiplier (gradual) | All-or-nothing combo ratio |
| **Accuracy Sensitivity** | Linear contribution | 10th power (extreme at top) |
| **Playback Rate** | Modifier + Divider | No rate adjustment |
| **Recovery Potential** | Bonus rebuilds gradually | MaxCombo is permanent peak |
