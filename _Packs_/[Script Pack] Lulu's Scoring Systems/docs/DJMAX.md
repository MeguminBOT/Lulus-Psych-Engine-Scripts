# DJMAX RESPECT V Scoring System

## Overview

This scoring system replicates **DJMAX RESPECT V**'s judgement and scoring system (PC version). DJMAX uses fixed timing windows (BPM-independent), weighted accuracy scoring, and a simple combo system where only the two best judgements maintain combo.

**Origin Game:** DJMAX RESPECT V (PC)
**Script Prefix:** `djmax_`
**Max Score:** 1,000,000

---

## Differences from DJMAX RESPECT V

This implementation closely replicates DJMAX RESPECT V (PC) but has several notable differences in scoring mechanics:

| Aspect | DJMAX RESPECT V (Original) | This Implementation |
|--------|---------------------------|---------------------|
| **MAX Percentage** | Continuous scale from MAX 100% down to MAX 1% based on precise timing within the MAX window | Simplified to two discrete tiers: MAX 100% (≤16ms) and MAX 90% (≤33ms) — no intermediate values |
| **Fever System** | Fever gauge fills on MAX hits, activates a **score multiplier** that boosts points during Fever mode | Not implemented — no Fever gauge or score multiplier; score is purely accuracy-weighted |
| **Combo Effect on Score** | Higher combo contributes to Fever gauge fill rate, indirectly boosting score | Combo is tracked but has **no effect on score** — purely cosmetic |
| **Hold Note Judgement** | Long notes have their own unique judgement at release (continuous percentage applied to accuracy) | Sustain notes handled by Psych Engine's default system — no custom release judgement affecting accuracy |
| **GOOD/BAD Combo** | GOOD and BAD both break combo in the original | Same behavior — GOOD and BAD break combo |
| **Score Display** | Score shown as a raw value; percentage shown only on results screen | Score = 1,000,000 × accuracy shown live during gameplay |

---

## Timing Windows

DJMAX RESPECT V (PC version) uses **unified, fixed timing windows** regardless of BPM. The PC version uses approximately 2.5 frames of tolerance at 60fps.

| Judgement | Window | Description |
|-----------|--------|-------------|
| MAX 100% | ±16ms | Perfect timing |
| MAX 90% | ±33ms | Slightly off |
| GOOD | ±66ms | Noticeably off |
| BAD | ±100ms | Greatly off |
| BREAK | >100ms | Complete miss |

> **Note:** In the actual game, the MAX percentage is continuous (100% down to 1%), but this implementation uses simplified discrete tiers for gameplay purposes.

---

## Scoring Formula

DJMAX uses a **weighted accuracy** system. Each hit is assigned a weight based on its judgement tier, and the final score is a direct function of your overall accuracy.

### Judgement Weights

| Judgement | Weight |
|-----------|--------|
| MAX 100% | 1.0 |
| MAX 90% | 0.9 |
| GOOD | 0.5 |
| BAD | 0.1 |
| BREAK | 0.0 |

### Score Calculation

$$\text{Score} = 1{,}000{,}000 \times \frac{\text{WeightedSum}}{\text{TotalNotes}}$$

Where:
- **WeightedSum** = sum of all judgement weights earned
- **TotalNotes** = total number of notes judged (hits + misses)

### Accuracy

$$\text{Accuracy} = \frac{\text{WeightedSum}}{\text{TotalNotes}} \times 100\%$$

Since Score = 1,000,000 × Accuracy(decimal), the score and accuracy are directly proportional. A 95% accuracy always yields a score of 950,000.

### Worked Example

Given a 100-note chart where the player hits:
- 70 MAX 100% hits
- 20 MAX 90% hits
- 5 GOOD hits
- 3 BAD hits
- 2 BREAKs (misses)

$$\text{WeightedSum} = (70 \times 1.0) + (20 \times 0.9) + (5 \times 0.5) + (3 \times 0.1) + (2 \times 0.0)$$
$$= 70 + 18 + 2.5 + 0.3 + 0 = 90.8$$

$$\text{Accuracy} = \frac{90.8}{100} \times 100\% = 90.8\%$$

$$\text{Score} = 1{,}000{,}000 \times 0.908 = 908{,}000$$

---

## Combo System

DJMAX has a strict combo system:

| Judgement | Combo Effect |
|-----------|-------------|
| MAX 100% | Combo continues (+1) |
| MAX 90% | Combo continues (+1) |
| GOOD | **Combo breaks** (resets to 0) |
| BAD | **Combo breaks** (resets to 0) |
| BREAK | **Combo breaks** (resets to 0) |

This means only the two best judgements maintain combo. Even a GOOD hit (which still gives 50% accuracy weight) will break your combo.

---

## Grade Thresholds

| Grade | Accuracy Required |
|-------|------------------|
| S | ≥ 97% |
| A | ≥ 90% |
| B | ≥ 80% |
| C | < 80% |

---

## FC (Full Combo) Tiers

| Tier | Condition |
|------|-----------|
| PP | All MAX 100% — no other judgements, no misses |
| FC | No GOOD, BAD, or BREAK — only MAX 100% and MAX 90% |
| SDCB | < 10 combo breaks (GOODs + BADs + BREAKs) |
| Clear | 10+ combo breaks |

> **Combo breaks** in DJMAX include GOOD hits, BAD hits, and BREAKs (misses) — since all three reset combo.

---

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `djmax_enabled` | `true` | Enable/disable the scoring system |
| `djmax_debug` | `false` | Show debug messages on screen |
| `djmax_replaceScoreText` | `true` | Replace Psych Engine's default score text |
| `djmax_kadeEngineStyle` | `false` | Use Kade Engine style formatting |

### Settings.json Keys

| Key | Type | Effect |
|-----|------|--------|
| `scoring_system` | String | Set to `"DJMAX"` to activate as primary system |
| `scoring_debug` | Bool | Override debug setting |
| `scoring_replaceScoreText` | Bool | Override score text replacement |
| `scoring_kadeEngineStyle` | Bool | Override score text style |

---

## API Reference

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `djmax_getAccuracy()` | Float (0-100) | Current accuracy percentage |
| `djmax_getScore()` | Int (0-1,000,000) | Current score |
| `djmax_getGrade(percent)` | String | Letter grade for given percentage |
| `djmax_getCombo()` | Int | Current combo |
| `djmax_getHitWindow(judgement)` | Float | Hit window in ms for judgement name |
| `djmax_getJudgement(offsetMs)` | String | Judgement name for given offset |
| `djmax_getMax100Hits()` | Int | Count of MAX 100% judgements |
| `djmax_getMax90Hits()` | Int | Count of MAX 90% judgements |
| `djmax_getGoodHits()` | Int | Count of GOOD judgements |
| `djmax_getBadHits()` | Int | Count of BAD judgements |
| `djmax_getTotalNotes()` | Int | Total notes judged |
| `djmax_getRatingFC()` | String | Current FC tier |
| `djmax_formatPercent(value)` | String | Format to 2 decimal places |

### Setters / Actions

| Function | Description |
|----------|-------------|
| `djmax_setEnabled(bool)` | Enable/disable scoring |
| `djmax_resetScoring()` | Reset all state to initial values |
| `djmax_setReplaceScoreText(bool)` | Toggle score text replacement |
| `djmax_setKadeEngineStyle(bool)` | Toggle Kade Engine style |
| `djmax_updateScoreText()` | Force score text update |

---

## Score Text Format

**Psych Engine style:**
```
Score: 950000 | Misses: 2 | Rating: S (95.00%) - FC
```

**Kade Engine style:**
```
Score: 950000 | Combo Breaks: 2 | Accuracy: 95.00 % | (FC) S
```
