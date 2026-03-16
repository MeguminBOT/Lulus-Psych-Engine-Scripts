# Beatmania IIDX EX Score System

## Overview

This scoring system replicates **beatmania IIDX**'s EX Score system. IIDX uses a deceptively simple scoring model — only two judgements (PGREAT and GREAT) earn EX Score points — combined with frame-based timing windows derived from the arcade hardware's 60fps refresh rate.

**Origin Game:** beatmania IIDX (PC normalized)
**Script Prefix:** `iidx_`
**Primary Metric:** EX Score (not a fixed max — depends on total notes × 2)

---

## Differences from Beatmania IIDX

This implementation captures IIDX's core EX Score system with a few key differences:

| Aspect | Beatmania IIDX (Original) | This Implementation |
|--------|--------------------------|---------------------|
| **Timing Windows** | Arcade uses frame-precise timing tied to 60fps refresh; varies slightly between AC/CS versions | PC-normalized millisecond values (16.67ms, 33.33ms, etc.) derived from frame timings — functionally identical but not frame-locked |
| **Weighted Accuracy** | IIDX only uses EX Rate (EX Score / Max EX) as its performance metric — no secondary accuracy | Adds a **weighted accuracy** display (PGREAT=1.0, GREAT=0.75, GOOD=0.5, BAD=0.25) alongside EX Rate for Psych Engine score text compatibility |
| **GOOD Combo Rule** | GOOD maintains combo but awards 0 EX — it's a "soft" hit | Same behavior faithfully reproduced — GOOD continues combo, 0 EX points |
| **POOR (Empty) vs POOR** | IIDX distinguishes "Empty POOR" (pressing with no note nearby) from "POOR" (missing a note) — Empty POOR has no EX penalty but still affects combo | No distinction — all misses treated as POOR with the same penalty |
| **Charge Notes (CN)** | Long notes scored on press and release independently; dropped CNs penalize EX Score | Sustain notes handled by Psych Engine's default system — no CN-specific EX scoring |
| **AWFUL Judgement** | In some IIDX versions, AWFUL is a distinct late/early judgement between BAD and POOR | Implemented as a distinct tier with its own window (±180ms) — behavior matches |

---

## Timing Windows

IIDX timing windows are derived from **arcade frame timings** converted to milliseconds at 60fps:

| Judgement | Window | Frame Origin | EX Points |
|-----------|--------|-------------|-----------|
| PGREAT | ±16.67ms | 1 frame @ 60fps | **+2** |
| GREAT | ±33.33ms | 2 frames @ 60fps | **+1** |
| GOOD | ±66.67ms | 4 frames @ 60fps | +0 |
| BAD | ±100ms | N/A | +0 |
| AWFUL | ±180ms | N/A | +0 |
| POOR | >180ms (miss) | N/A | +0 |

> Only PGREAT and GREAT contribute to EX Score. Everything else earns zero.

---

## EX Score

### Formula

$$\text{EX Score} = 2 \times N_\text{PGREAT} + 1 \times N_\text{GREAT}$$

### Maximum EX Score

$$\text{EX Score}_\text{max} = 2 \times N_\text{total}$$

Where $N_\text{total}$ is the total number of notes judged. A perfect play (all PGREATs) earns exactly $2 \times N_\text{total}$ EX.

### EX Rate

The EX Rate percentage is used for grade calculation:

$$\text{EX Rate} = \frac{\text{EX Score}}{2 \times N_\text{total}} \times 100\%$$

---

## Weighted Accuracy

In addition to the authentic EX Rate, this implementation provides a **weighted accuracy** for display purposes that produces values comparable to Psych Engine's built-in accuracy:

$$\text{Accuracy} = \frac{1.0 \times N_\text{PGREAT} + 0.75 \times N_\text{GREAT} + 0.5 \times N_\text{GOOD} + 0.25 \times N_\text{BAD} + 0 \times N_\text{AWFUL}}{N_\text{total}} \times 100\%$$

> The score text displays this weighted accuracy, while grades are determined by the authentic EX Rate.

---

## Combo System

| Judgement | Combo Effect |
|-----------|-------------|
| PGREAT | Combo continues (+1) |
| GREAT | Combo continues (+1) |
| GOOD | Combo continues (+1) |
| BAD | **Combo breaks** (resets to 0) |
| AWFUL | **Combo breaks** (resets to 0) |
| POOR | **Combo breaks** (resets to 0) |

Three judgement tiers maintain combo. BAD and below break combo despite GOOD giving 0 EX.

---

## Grade Thresholds

Grades are based on **EX Rate** (not weighted accuracy) and use **ninths** of the maximum:

| Grade | EX Rate Required | Fraction |
|-------|-----------------|----------|
| AAA | ≥ 88.89% | 8/9 |
| AA | ≥ 77.78% | 7/9 |
| A | ≥ 66.67% | 6/9 |
| B | ≥ 55.56% | 5/9 |
| C | ≥ 44.44% | 4/9 |
| D | ≥ 33.33% | 3/9 |
| E | ≥ 22.22% | 2/9 |
| F | < 22.22% | <2/9 |

### Worked Example

200-note chart, player hits:
- 150 PGREATs, 30 GREATs, 10 GOODs, 5 BADs, 3 AWFULs, 2 POORs

$$\text{EX Score} = (150 \times 2) + (30 \times 1) = 300 + 30 = 330$$
$$\text{EX Rate} = \frac{330}{200 \times 2} \times 100\% = \frac{330}{400} \times 100\% = 82.5\%$$

Grade: **AA** (82.5% ≥ 77.78%)

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| PFC | All PGREATs — no GREATs, GOODs, BADs, AWFULs, or POORs |
| FC | No BADs, AWFULs, or POORs — PGREATs + GREATs + GOODs only |
| SDCB | < 10 combo breaks (BADs + AWFULs + POORs) |
| Clear | 10+ combo breaks |

---

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `iidx_enabled` | `true` | Enable/disable the scoring system |
| `iidx_debug` | `false` | Show debug messages |
| `iidx_replaceScoreText` | `true` | Replace Psych Engine's default score text |
| `iidx_kadeEngineStyle` | `false` | Use Kade Engine style formatting |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"IIDX"` to activate |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `iidx_getExRate()` | Float (0-100) | Authentic EX Rate percentage (used for grades) |
| `iidx_getAccuracy()` | Float (0-100) | Weighted accuracy percentage (for display) |
| `iidx_getScore()` | Int | Current EX Score |
| `iidx_getGrade(percent)` | String | Grade for given EX Rate percentage |
| `iidx_getCombo()` | Int | Current combo |
| `iidx_getHitWindow(judgement)` | Float | Hit window in ms |
| `iidx_getJudgement(offsetMs)` | String | Judgement for given offset |
| `iidx_getPgreatHits()` | Int | Count of PGREATs |
| `iidx_getGreatHits()` | Int | Count of GREATs |
| `iidx_getGoodHits()` | Int | Count of GOODs |
| `iidx_getBadHits()` | Int | Count of BADs |
| `iidx_getAwfulHits()` | Int | Count of AWFULs |
| `iidx_getTotalNotes()` | Int | Total notes judged |
| `iidx_getRatingFC()` | String | Current FC tier |
| `iidx_formatPercent(value)` | String | Format to 2 decimal places |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `iidx_setEnabled(bool)` | Enable/disable scoring |
| `iidx_resetScoring()` | Reset all state to initial values |
| `iidx_setReplaceScoreText(bool)` | Toggle score text replacement |
| `iidx_setKadeEngineStyle(bool)` | Toggle Kade Engine style |
| `iidx_updateScoreText()` | Force score text update |

---

## Score Text Format

The score text shows **EX Score** as the primary metric with a fraction display:

**Psych Engine style:**
```
EX: 330/400 | Misses: 2 | Rating: AA (82.50%) - FC
```

**Kade Engine style:**
```
EX: 330/400 | Combo Breaks: 2 | EX Rate: 82.50 % | (FC) AA
```
