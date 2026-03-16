# O2Jam Scoring System

## Overview

This scoring system replicates **O2Jam**'s judgement and scoring mechanics. O2Jam uses a combo-multiplied scoring model where score earned per hit scales with your current combo, along with weighted accuracy tracking. It uniquely supports both **fixed timing windows** and **BPM-based timing windows** (authentic O2Jam behavior).

**Origin Game:** O2Jam
**Script Prefix:** `o2jam_`
**Max Score:** Theoretically unbounded (combo-dependent)

---

## Differences from O2Jam

This implementation replicates O2Jam's core scoring mechanics but differs in several areas:

| Aspect | O2Jam (Original) | This Implementation |
|--------|-----------------|---------------------|
| **BPM-Based Windows** | O2Jam dynamically adjusts timing windows based on BPM using an internal tick system (this is the default behavior) | Supported as an **optional** mode (`o2jam_useBPMWindows`), but defaults to fixed windows (33/67/100ms) for consistency |
| **Long Note Scoring** | Long notes are scored at press and release independently; missed releases lose the tail bonus and affect accuracy | Sustain notes handled by Psych Engine — no custom tail release judgement or accuracy impact |
| **Score Scale** | Scores can reach extremely high values (millions+) depending on combo length and note count | Same unbounded combo-multiplied formula, but values will differ since FNF charts typically have fewer notes than O2Jam 7-key charts |
| **Golden Notes** | Special golden notes give bonus score multipliers on hit | Not implemented — all notes scored identically |
| **Pill Items** | Pill items drop from notes and can boost score or combo | Not implemented — no score-boosting items |
| **BAD Score** | BAD earns 0 score because combo resets to 0 before the score calculation (weight × 0 = 0), but BAD's weight (0.4) still counts toward accuracy | Same behavior faithfully reproduced — BAD contributes to accuracy but not score |

---

## Timing Windows

### Fixed Windows (Default)

These are used when `o2jam_useBPMWindows` is `false`:

| Judgement | Window | Description |
|-----------|--------|-------------|
| COOL | ±33ms | At least 80% of the note hit the target bar |
| GOOD | ±67ms | 50-80% of the note hit the target bar |
| BAD | ±100ms | ~20-50% of the note hit the target bar |
| MISS | >100ms | Note missed the target bar entirely |

### BPM-Based Windows (Authentic Mode)

When `o2jam_useBPMWindows` is `true`, timing windows scale dynamically with BPM using the **tick-based formula**:

$$\text{Tick} = \frac{60000}{\text{BPM} \times 48}$$

Where 48 is the minimum note placement interval (ticks per beat).

| Judgement | Ticks | Formula | Example (120 BPM) | Example (200 BPM) |
|-----------|-------|---------|-------------------|-------------------|
| COOL | 6 | $\frac{7500}{\text{BPM}}$ ms | 62.5ms | 37.5ms |
| GOOD | 18 | $\frac{22500}{\text{BPM}}$ ms | 187.5ms | 112.5ms |
| BAD | 25 | $\frac{31250}{\text{BPM}}$ ms | 260.4ms | 156.25ms |

> BPM-based windows update automatically when BPM changes mid-song (checked on every beat hit).

---

## Scoring Formula

O2Jam uses a **combo-multiplied scoring** system. Unlike most rhythm games where score is normalized to a fixed max, O2Jam's score scales with combo length.

### Per-Hit Score

$$\text{Score}_\text{hit} = \text{JudgementWeight} \times \text{Combo}$$

| Judgement | Weight | Combo Effect | Score Added |
|-----------|--------|-------------|-------------|
| COOL | 1.0 | +1 (continues) | 1.0 × new combo |
| GOOD | 0.7 | +1 (continues) | 0.7 × new combo |
| BAD | 0.4 | Reset to 0 | 0.4 × 0 = **0** |
| MISS | 0.0 | Reset to 0 | 0 |

> **Key insight:** BAD hits earn 0 actual score despite having a weight of 0.4, because combo is reset to 0 *before* the score calculation. BAD's weight only affects accuracy, not score.

### Total Score

$$\text{TotalScore} = \sum_{i=1}^{N} \text{Round}(\text{Weight}_i \times \text{Combo}_i)$$

### Worked Example

A sequence of 5 notes: COOL, COOL, GOOD, BAD, COOL

| Note # | Judgement | Combo After | Score Added | Running Total |
|--------|-----------|-------------|-------------|---------------|
| 1 | COOL | 1 | 1.0 × 1 = 1 | 1 |
| 2 | COOL | 2 | 1.0 × 2 = 2 | 3 |
| 3 | GOOD | 3 | 0.7 × 3 = 2 | 5 |
| 4 | BAD | 0 | 0.4 × 0 = 0 | 5 |
| 5 | COOL | 1 | 1.0 × 1 = 1 | 6 |

---

## Accuracy

Accuracy uses a **weighted average** independent of combo:

$$\text{Accuracy} = \frac{1.0 \times N_\text{COOL} + 0.7 \times N_\text{GOOD} + 0.4 \times N_\text{BAD} + 0.0 \times N_\text{MISS}}{N_\text{total}} \times 100\%$$

---

## Combo System

| Judgement | Combo Effect |
|-----------|-------------|
| COOL | Combo continues (+1) |
| GOOD | Combo continues (+1) |
| BAD | **Combo breaks** (resets to 0) |
| MISS | **Combo breaks** (resets to 0) |

---

## Grade Thresholds

| Grade | Accuracy Required |
|-------|------------------|
| SSS | 100% |
| SS | ≥ 99% |
| S | ≥ 95% |
| A | ≥ 90% |
| B | ≥ 80% |
| C | ≥ 70% |
| D | ≥ 60% |
| F | < 60% |

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| AFC | All COOLs — no GOODs, BADs, or MISSes |
| FC | No BADs or MISSes — only COOLs and GOODs |
| SDCB | < 10 combo breaks (BADs + MISSes) |
| Clear | 10+ combo breaks |

---

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `o2jam_enabled` | `true` | Enable/disable the scoring system |
| `o2jam_debug` | `false` | Show debug messages on screen |
| `o2jam_replaceScoreText` | `true` | Replace Psych Engine's default score text |
| `o2jam_kadeEngineStyle` | `false` | Use Kade Engine style formatting |
| `o2jam_useBPMWindows` | `false` | Use BPM-based timing windows |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"O2Jam"` to activate |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |
| `o2jam_useBPMWindows` | Bool | Enable BPM-based windows |

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `o2jam_getAccuracy()` | Float (0-100) | Current accuracy percentage |
| `o2jam_getScore()` | Int | Current score (combo-dependent) |
| `o2jam_getGrade(percent)` | String | Letter grade for given percentage |
| `o2jam_getCombo()` | Int | Current combo |
| `o2jam_getHitWindow(judgement)` | Float | Hit window in ms |
| `o2jam_getJudgement(offsetMs)` | String | Judgement for given offset |
| `o2jam_getCoolHits()` | Int | Count of COOL judgements |
| `o2jam_getGoodHits()` | Int | Count of GOOD judgements |
| `o2jam_getBadHits()` | Int | Count of BAD judgements |
| `o2jam_getTotalNotes()` | Int | Total notes judged |
| `o2jam_getRatingFC()` | String | Current FC tier |
| `o2jam_getUseBPMWindows()` | Bool | Whether BPM windows are active |
| `o2jam_formatPercent(value)` | String | Format to 2 decimal places |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `o2jam_setEnabled(bool)` | Enable/disable scoring |
| `o2jam_resetScoring()` | Reset all state to initial values |
| `o2jam_setReplaceScoreText(bool)` | Toggle score text replacement |
| `o2jam_setKadeEngineStyle(bool)` | Toggle Kade Engine style |
| `o2jam_setUseBPMWindows(bool)` | Toggle BPM-based windows |
| `o2jam_updateBPMWindows(bpm)` | Manually recalculate BPM windows |
| `o2jam_updateScoreText()` | Force score text update |

---

## Score Text Format

**Psych Engine style:**
```
Score: 1250 | Misses: 3 | Rating: A (92.50%) - FC
```

**Kade Engine style:**
```
Score: 1250 | Combo Breaks: 3 | Accuracy: 92.50 % | (FC) A
```
