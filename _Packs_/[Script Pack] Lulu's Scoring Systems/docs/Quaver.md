# Quaver Scoring System

## Overview

This scoring system replicates **Quaver**'s judgement and scoring mechanics. Quaver features **8 difficulty presets** with increasingly strict timing windows, an accuracy system using signed judgement weights (where some judgements penalize you), and a 1,000,000 max score directly tied to accuracy.

**Origin Game:** Quaver
**Script Prefix:** `quaver_`
**Max Score:** 1,000,000

---

## Differences from Quaver

This implementation faithfully reproduces Quaver's scoring math but differs in a few key areas:

| Aspect | Quaver (Original) | This Implementation |
|--------|-------------------|---------------------|
| **Long Notes (LN)** | LN releases are judged independently with their own timing window; LN bodies contribute to combo | Sustain notes handled by Psych Engine's default system — no custom release judgement affecting accuracy |
| **Scoring Formula** | Score = 1,000,000 × Accuracy — identical formula | Faithfully reproduced — same weights, same accuracy calculation, same score mapping |
| **Judgement Weights** | Marvelous=100, Perfect=98.25, Great=65, Good=25, Okay=-100, Miss=-50 | Same weights — including the punishing negative values for Okay and Miss |
| **Difficulty Presets** | 8 presets (Peaceful → Impossible) controlling all 6 timing windows | Same 8 presets with identical window values |
| **Fail Condition** | No health bar — songs always complete regardless of performance | FNF/Psych Engine has a health bar; players can die — fundamentally different fail behavior |
| **Grade Calculation** | Grade calculated from accuracy only; combo has no effect | Same behavior — grades are accuracy-based, matching the original |

---

## Timing Windows

### Difficulty Presets

Quaver supports 8 difficulty presets. Each preset defines 6 timing windows (in milliseconds):

| Preset | Marvelous | Perfect | Great | Good | Okay | Miss |
|--------|-----------|---------|-------|------|------|------|
| Peaceful | ±23 | ±57 | ±101 | ±141 | ±169 | ±218 |
| Lenient | ±21 | ±52 | ±91 | ±128 | ±153 | ±198 |
| Chill | ±19 | ±47 | ±83 | ±116 | ±139 | ±180 |
| **Standard** | **±18** | **±43** | **±76** | **±106** | **±127** | **±164** |
| Strict | ±16 | ±39 | ±69 | ±96 | ±127 | ±164 |
| Tough | ±14 | ±35 | ±62 | ±87 | ±127 | ±164 |
| Extreme | ±13 | ±32 | ±57 | ±79 | ±127 | ±164 |
| Impossible | ±8 | ±20 | ±35 | ±49 | ±127 | ±164 |

> **Note:** From Strict onwards, Okay and Miss windows are locked at ±127ms and ±164ms respectively. Only the positive judgement windows (Marvelous through Good) get tighter.

### Default Preset: Standard

| Judgement | Window |
|-----------|--------|
| Marvelous | ±18ms |
| Perfect | ±43ms |
| Great | ±76ms |
| Good | ±106ms |
| Okay | ±127ms |
| Miss | ±164ms |

---

## Scoring Formula

### Judgement Weights

Quaver uses **signed weights** — Okay and Miss have **negative** weights that actively reduce your accuracy.

| Judgement | Weight | Combo Effect |
|-----------|--------|-------------|
| Marvelous | +100.0 | Continues |
| Perfect | +98.25 | Continues |
| Great | +65.0 | Continues |
| Good | +25.0 | Continues |
| Okay | **-100.0** | **Breaks** |
| Miss | **-50.0** | **Breaks** |

> **Key Insight:** An Okay hit (-100) is more damaging to accuracy than a Miss (-50). This punishes players who ghost-tap or hit notes extremely late rather than missing them entirely.

### Accuracy Formula

$$\text{Accuracy} = \frac{\sum V_j \times N_j}{100 \times N_\text{total}} \times 100\%$$

Where:
- $V_j$ = weight for judgement $j$
- $N_j$ = number of notes receiving judgement $j$
- $N_\text{total}$ = total notes judged (hits + misses)

The denominator uses 100 (the Marvelous weight) as the normalization factor. A perfect play (all Marvelous) gives exactly 100% accuracy.

### Score Formula

$$\text{Score} = 1{,}000{,}000 \times \frac{\text{Accuracy}}{100}$$

Score is a direct function of accuracy. 95% accuracy = 950,000 score.

### Worked Example

Given a 200-note chart:
- 150 Marvelous
- 30 Perfect
- 10 Great
- 5 Good
- 3 Okay
- 2 Miss

$$\text{WeightedSum} = (150 \times 100) + (30 \times 98.25) + (10 \times 65) + (5 \times 25) + (3 \times -100) + (2 \times -50)$$
$$= 15000 + 2947.5 + 650 + 125 - 300 - 100 = 18322.5$$

$$\text{Accuracy} = \frac{18322.5}{100 \times 200} \times 100\% = 91.61\%$$

$$\text{Score} = 1{,}000{,}000 \times 0.9161 = 916{,}125$$

---

## Combo System

| Judgement | Combo Effect |
|-----------|-------------|
| Marvelous | Combo continues (+1) |
| Perfect | Combo continues (+1) |
| Great | Combo continues (+1) |
| Good | Combo continues (+1) |
| Okay | **Combo breaks** (resets to 0) |
| Miss | **Combo breaks** (resets to 0) |

Max combo is tracked separately from current combo.

---

## Grade Thresholds

| Grade | Accuracy Required |
|-------|------------------|
| X | 100% (perfect play) |
| SS | ≥ 99% |
| S | ≥ 95% |
| A | ≥ 90% |
| B | ≥ 80% |
| C | ≥ 70% |
| D | < 70% |

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| PFC | All Marvelous — no other judgements |
| FC | No Okay or Miss — Marvelous/Perfect/Great/Good only |
| SDCB | < 10 combo breaks (Okay + Miss count) |
| Clear | 10+ combo breaks |

---

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `quaver_enabled` | `true` | Enable/disable the scoring system |
| `quaver_debug` | `false` | Show debug messages |
| `quaver_replaceScoreText` | `true` | Replace Psych Engine's default score text |
| `quaver_kadeEngineStyle` | `false` | Use Kade Engine style formatting |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"Quaver"` to activate |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |
| `quaver_difficulty` | String | Difficulty preset name (e.g. `"Standard"`, `"Strict"`) |

---

## SafeZone Override

Quaver's miss window varies by preset. Some presets (Peaceful=218ms, Lenient=198ms) have windows *wider* than Psych Engine's default safeZoneOffset (~166.67ms). Without the override, Psych Engine would auto-miss notes before Quaver could judge them. The script sets:

$$\text{safeZoneOffset} = \text{missWindow} \times \text{playbackRate}$$

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `quaver_getAccuracy()` | Float (0-100) | Current accuracy percentage |
| `quaver_getScore()` | Int (0-1,000,000) | Current score |
| `quaver_getGrade(percent)` | String | Letter grade for given percentage |
| `quaver_getCombo()` | Int | Current combo |
| `quaver_getHitWindow(judgement)` | Float | Hit window in ms |
| `quaver_getJudgement(offsetMs)` | String | Judgement for given offset |
| `quaver_getMarvelousHits()` | Int | Count of Marvelous judgements |
| `quaver_getPerfectHits()` | Int | Count of Perfect judgements |
| `quaver_getGreatHits()` | Int | Count of Great judgements |
| `quaver_getGoodHits()` | Int | Count of Good judgements |
| `quaver_getOkayHits()` | Int | Count of Okay judgements |
| `quaver_getMissHits()` | Int | Count of misses (from `game.songMisses`) |
| `quaver_getTotalNotes()` | Int | Total notes judged |
| `quaver_getRatingFC()` | String | Current FC tier |
| `quaver_formatPercent(value)` | String | Format to 2 decimal places |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `quaver_setEnabled(bool)` | Enable/disable scoring |
| `quaver_resetScoring()` | Reset all state to initial values |
| `quaver_setReplaceScoreText(bool)` | Toggle score text replacement |
| `quaver_setKadeEngineStyle(bool)` | Toggle Kade Engine style |
| `quaver_updateScoreText()` | Force score text update |

---

## Score Text Format

**Psych Engine style:**
```
Score: 916125 | Misses: 2 | Rating: A (91.61%) - FC
```

**Kade Engine style:**
```
Score: 916125 | Combo Breaks: 2 | Accuracy: 91.61 % | (FC) A
```
