# osu!mania ScoreV1 Scoring System

## Overview

This scoring system implements **osu!mania's ScoreV1** — the classic osu! scoring formula with base score + bonus score components, OD-based timing windows, playback rate modifiers, and sustain tail release judgements. ScoreV1 rewards consistency through a bonus multiplier that builds up with good hits and crashes on bad ones.

**Origin Game:** osu! (mania mode, ScoreV1)
**Script Prefix:** `osu_`
**Score Cap:** ~1,000,000 (modified by playback rate)
**Primary Metric:** Accuracy (weighted average of judgement values / 300)

---

## Differences from osu!mania (ScoreV1)

This implementation closely follows osu!mania's ScoreV1 as documented on the osu! wiki with these key differences:

| Aspect | osu!mania ScoreV1 (Original) | This Implementation |
|--------|------------------------------|---------------------|
| **Score Formula** | Base+Bonus system with hitValue/hitBonusValue/hitBonus/hitPunishment per judgement | Faithfully reproduced — same formula, same values, same bonus mechanics |
| **OD System** | OD 0–10 determines timing windows; maps have a fixed OD set by the mapper | OD configurable via settings (default OD 8) — not tied to chart metadata since FNF charts don't have OD |
| **LN (Long Notes)** | Press and release judged independently; body must be held continuously; shield/inverse mods available | Tail release judgement implemented with 1.5× lenient windows and broken-hold detection — functionally similar but uses Psych Engine's sustain system |
| **Mod Multiplier** | HalfTime (0.75x) gives 0.5× score; DoubleTime (1.5x) gives 1.0× score | Linear interpolation between 0.75x–1.0x for multiplier, matching osu! behavior; uses Psych Engine's playback rate |
| **Mod Divider** | DoubleTime reduces hitPunishment via ModDivider (1.0 at 1.0x, 1.1 at 1.5x) | Same interpolation formula implemented |
| **Accuracy Calculation** | MAX and 300 both count as 300 for accuracy; they are treated identically | Same behavior — MAX and 300 are treated identically for accuracy calculation |

---

## Timing Windows (OD-Based)

Hit windows in osu!mania are determined by **Overall Difficulty (OD)**, a value from 0 to 10:

| Judgement | Formula | OD 0 | OD 5 | OD 8 | OD 10 |
|-----------|---------|------|------|------|-------|
| MAX | ±16ms (fixed) | ±16ms | ±16ms | ±16ms | ±16ms |
| 300 | ±(64 - 3×OD) | ±64ms | ±49ms | ±40ms | ±34ms |
| 200 | ±(97 - 3×OD) | ±97ms | ±82ms | ±73ms | ±67ms |
| 100 | ±(127 - 3×OD) | ±127ms | ±112ms | ±103ms | ±97ms |
| 50 | ±(151 - 3×OD) | ±151ms | ±136ms | ±127ms | ±121ms |
| Miss | ±(188 - 3×OD) | ±188ms | ±173ms | ±164ms | ±158ms |

> MAX has a fixed 16ms window regardless of OD. All other windows shrink by 3ms per OD point.

### Tail Release Windows

Sustain tail releases use **1.5× lenient** versions of the regular windows:

$$\text{tailWindow} = \text{regularWindow} \times 1.5$$

| Judgement | Regular (OD 8) | Tail (OD 8) |
|-----------|---------------|-------------|
| MAX | ±16ms | ±24ms |
| 300 | ±40ms | ±60ms |
| 200 | ±73ms | ±109.5ms |
| 100 | ±103ms | ±154.5ms |
| 50 | ±127ms | ±190.5ms |

---

## ScoreV1 Formula

### Score Components

$$\text{Score} = \text{BaseScore} + \text{BonusScore}$$

$$\text{BaseScore} = \frac{\text{MaxScore} \times \text{ModMult} \times 0.5}{N_\text{total}} \times \frac{\text{hitValue}}{320}$$

$$\text{BonusScore} = \frac{\text{MaxScore} \times \text{ModMult} \times 0.5}{N_\text{total}} \times \frac{\text{hitBonusValue} \times \sqrt{\text{Bonus}}}{320}$$

Where MaxScore = 1,000,000 and the bonus is updated **before** calculating BonusScore:

$$\text{Bonus} = \text{clamp}\!\left(\text{Bonus} + \text{hitBonus} - \frac{\text{hitPunishment}}{\text{ModDivider}}, \; 0, \; 100\right)$$

### Hit Values

| Judgement | hitValue | hitBonusValue | hitBonus | hitPunishment |
|-----------|----------|---------------|----------|---------------|
| MAX | 320 | 32 | +2.0 | 0 |
| 300 | 300 | 32 | +1.0 | 0 |
| 200 | 200 | 16 | 0 | 8.0 |
| 100 | 100 | 8 | 0 | 24.0 |
| 50 | 50 | 4 | 0 | 44.0 |
| Miss | 0 | 0 | 0 | Bonus → 0 (reset) |

### How Bonus Works

The bonus starts at 100 and acts as a **consistency multiplier**:

- MAX/300 hits **increase** the bonus (+2/+1), rewarding streaks
- 200/100/50 hits **decrease** the bonus, with punishment reduced by ModDivider
- Misses **reset** the bonus to 0 instantly
- The bonus multiplies the BonusScore via $\sqrt{\text{Bonus}}$

At full bonus (100): $\sqrt{100} = 10$ → full bonus score
At zero bonus: $\sqrt{0} = 0$ → no bonus score at all

### Worked Example (100-note chart, OD 8, 1.0x speed)

All MAX hits:
$$\text{factor} = \frac{1{,}000{,}000 \times 1.0 \times 0.5}{100} = 5{,}000$$

Per MAX: BaseScore = $5000 \times 320/320 = 5000$, BonusScore = $5000 \times 32 \times \sqrt{100}/320 = 5000$

Total per note: 10,000. Over 100 notes: **1,000,000**

Now if note 50 is a 200:
- Bonus drops from 100 to 92 (100 + 0 - 8/1.0)
- BaseScore₅₀ = $5000 \times 200/320 = 3125$
- BonusScore₅₀ = $5000 \times 16 \times \sqrt{92}/320 = 2395$
- Remaining notes earn slightly less bonus score due to lower bonus value

---

## Playback Rate Modifiers

osu!mania adjusts scoring based on playback speed, mimicking the HalfTime/DoubleTime mod behavior:

### Mod Multiplier (slower speeds = score penalty)

| Rate | ModMultiplier |
|------|---------------|
| 0.75x (HT) | 0.50 |
| 0.85x | 0.70 |
| 1.0x | 1.00 |
| 1.5x+ (DT) | 1.00 |

For rates between 0.75x and 1.0x, linear interpolation:
$$\text{ModMult} = 0.5 + \frac{(\text{rate} - 0.75)}{0.25} \times 0.5$$

At 0.75x speed, the max achievable score is only **500,000** (half of 1M).

### Mod Divider (faster speeds = reduced punishment)

| Rate | ModDivider |
|------|------------|
| 1.0x | 1.00 |
| 1.25x | 1.05 |
| 1.5x+ (DT) | 1.10 |

For rates between 1.0x and 1.5x:
$$\text{ModDiv} = 1.0 + \frac{(\text{rate} - 1.0)}{0.5} \times 0.1$$

The divider reduces `hitPunishment` — at 1.5x speed, a 200 hit's punishment is $8/1.1 \approx 7.27$ instead of 8.

---

## Accuracy

osu!mania V1 accuracy treats MAX and 300 identically:

$$\text{Accuracy} = \frac{(N_\text{MAX} + N_{300}) \times 300 + N_{200} \times 200 + N_{100} \times 100 + N_{50} \times 50}{N_\text{total} \times 300} \times 100\%$$

> MAX doesn't give higher accuracy than 300 in V1 — it only contributes more to the bonus score.

---

## Sustain Tail Mechanics

osu!mania judges sustain (hold) note releases independently from the head hit:

### How Tails Are Tracked

1. **Head hit:** When the player hits a sustain note's head, the system starts tracking the sustain on that column
2. **Holding:** While held, intermediate sustain pieces are consumed normally
3. **Release:** When the player releases the key, the release timing is compared to the tail's strumTime
4. **Judgement:** The tail receives its own judgement using 1.5× lenient windows

### Broken Holds

If a hold is broken (player releases early or misses intermediate pieces), the tail judgement is **capped to 50** regardless of release timing.

### Tail Miss

If a sustain tail is missed entirely:
- Bonus resets to 0
- No accuracy earned (only denominator increases)
- Counts as a combo break (tracked separately from engine misses)

### Key Release Processing

The `processKeyRelease(key)` function handles release timing:
1. Check if there's an active sustain on the released column
2. Calculate offset: `tailStrumTime - songPosition` (adjusted for playback rate)
3. If offset > tail miss window → mark hold as broken (early release)
4. If within miss window → score the tail release using lenient windows
5. Mark remaining tail pieces as consumed to prevent double-processing

---

## Combo System

osu!mania's combo is managed by the engine. The script tracks `comboBreaks` separately for tail misses.

---

## Grade Thresholds

| Grade | Accuracy Required |
|-------|------------------|
| SS | 100% |
| S | > 95% |
| A | > 90% |
| B | > 80% |
| C | > 70% |
| D | ≤ 70% |

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| PFC | All MAX — no 300s, 200s, 100s, or 50s |
| FC | No misses or tail misses |
| SDCB | < 10 total breaks (misses + combo breaks from tails) |
| Clear | 10+ breaks |

---

## Configuration

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `osu_enabled` | `true` | — | Enable/disable scoring |
| `osu_debug` | `false` | — | Show debug messages |
| `osu_replaceScoreText` | `true` | — | Replace Psych Engine's score text |
| `osu_kadeEngineStyle` | `false` | — | Use Kade Engine style formatting |
| `osu_od` | `8.0` | 0–10 | Overall Difficulty |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"OsuMania"` to activate |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |
| `osu_od` | Float (0-10) | Override OD |

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `osu_getAccuracy()` | Float (0-100) | Current accuracy percentage |
| `osu_getScore()` | Int | Current score |
| `osu_getMaxPossibleScore()` | Int | Max score (1M × modifier) |
| `osu_getGrade(percent)` | String | Grade for given accuracy |
| `osu_getOD()` | Float | Current OD value |
| `osu_getHitWindow(judgement)` | Float | Hit window in ms |
| `osu_getTailHitWindow(judgement)` | Float | Tail window in ms (1.5×) |
| `osu_getJudgement(offsetMs)` | String | Judgement for offset |
| `osu_getTailJudgement(offsetMs)` | String | Tail judgement for offset |
| `osu_getMaxHits()` | Int | MAX count |
| `osu_get300Hits()` | Int | 300 count |
| `osu_get200Hits()` | Int | 200 count |
| `osu_get100Hits()` | Int | 100 count |
| `osu_get50Hits()` | Int | 50 count |
| `osu_getBonus()` | Float | Current bonus (0–100) |
| `osu_getModMultiplier()` | Float | Current mod multiplier |
| `osu_getModDivider()` | Float | Current mod divider |
| `osu_getTotalNotes()` | Int | Total notes (incl. tails) |
| `osu_getRatingFC()` | String | Current FC tier |
| `osu_formatPercent(value)` | String | Format to 2 decimal places |
| `osu_getReplaceScoreText()` | Bool | Score text replacement state |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `osu_setEnabled(bool)` | Enable/disable scoring |
| `osu_setOD(od)` | Set OD (clamped 0–10) |
| `osu_resetScoring()` | Reset all state |
| `osu_recountNotes()` | Recount total notes |
| `osu_setReplaceScoreText(bool)` | Toggle score text replacement |
| `osu_updateScoreText()` | Force score text update |

---

## Score Text Format

**Psych Engine style:**
```
Score: 987654 | Combo Breaks: 2 | Misses: 1 | Rating: S (96.50%) - FC
```

**Kade Engine style:**
```
Score: 987654 | Combo Breaks: 2 | Misses: 1 | Accuracy: 96.50 % | (FC) S
```
