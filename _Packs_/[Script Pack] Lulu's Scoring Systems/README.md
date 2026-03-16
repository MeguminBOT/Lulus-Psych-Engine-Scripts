# Lulu's Scoring Systems — Psych Engine Script Pack

A collection of **10 rhythm game scoring/accuracy systems** for Friday Night Funkin' Psych Engine 1.0.4 as HScript. Each system attempts to faithfully recreate the timing windows, accuracy formulas, scoring algorithms, and grade thresholds from its respective game.

Switch between them at any time via the mod settings menu.

*Note that there are improvements that can be made and will be made in the future.*

---

## How It Works

### File Structure

```
mods/[Script Pack] Lulu's Scoring Systems/
├── pack.json                               Mod pack metadata
├── data/
│   └── settings.json                       Mod Settings definitions
├── scripts/
│   ├── Loader.hx                           Entry point — loads only what's needed
│   ├── scoring/                            One HScript per scoring system
│   │   ├── Wife3 Scoring System.hx
│   │   ├── OsuMania Scoring System.hx
│   │   ├── OsuManiaV2 Scoring System.hx
│   │   ├── ITG Scoring System.hx
│   │   ├── Ruthless Scoring System.hx
│   │   ├── O2Jam Scoring System.hx
│   │   ├── DJMAX Scoring System.hx
│   │   ├── IIDX Scoring System.hx
│   │   └── Quaver Scoring System.hx
│   └── extras/                             Optional feature scripts
│       ├── Timing Display.hx               Color-coded ms timing feedback
│       ├── Score Comparison.hx             All 10 systems side by side
│       ├── Rating Popups.hx                Custom judgement popup sprites
│       ├── Hit Error Bar.hx                Horizontal timing error bar
│       └── Judgement Counter.lua           Real-time judgement tally
├── images/
│   └── ratings/                            Optional custom rating popup images
└── docs/                                   Detailed per-system documentation
```

### The Loader

`Loader.hx` is the only script in the global `scripts/` folder — it's the entry point that runs every song. Instead of loading all 10 scoring systems at once, it reads your **Mod Settings** and initializes only:

- The **active scoring system** you've selected
- Any **extra features** you've enabled (timing display, rating popups, hit error bar, judgement counter)
- **Score Comparison** mode (loads all systems only when this is turned on)

This keeps overhead minimal — if you're using Wife3 with timing display, only those two scripts run.

### Documentation

This readme is a quick reference. Each scoring system has its own detailed doc file in [`docs/`](docs/) with full math formulas, worked examples, and comparisons with the original games. The API for integrating scoring systems with custom UIs is in the [For Developers](#for-developers) section.

---

## Table of Contents
- [How It Works](#how-it-works)
- [Supporting Features](#supporting-features)
  - [Rating Popups](#rating-popups)
  - [Hit Error Bar](#hit-error-bar)
- [Installation](#installation)
- [Configuration](#configuration)
- [Systems Quick Comparison](#systems-quick-comparison)
- [Timing Window Comparison](#timing-window-comparison)
- [Grade Threshold Comparison](#grade-threshold-comparison)
- [For Developers](#for-developers)

---

## Supporting Features

These scripts work alongside all scoring systems:

### Timing Display
Color-coded timing feedback (e.g. "+12.5ms") that appears on-screen after each note hit. Colors match the active scoring system's judgement tiers.

### Score Comparison
Shows **all 10 scoring systems side by side** during gameplay — score, accuracy, grade, and FC tier for each. Useful for comparing how different systems evaluate the same performance.

### Rating Popups

Replaces Psych Engine's default rating images (sick/good/bad/shit) with custom sprites matching the active scoring system's judgement names. When enabled, the engine's built-in rating sprite is hidden and custom popups are spawned instead.

#### How It Works

Each time a note is hit, the script determines the judgement from the active scoring system and looks for a matching image. The lookup priority is:

1. **Individual image** — `images/ratings/[system]/[judgement].png`
2. **Spritesheet animation** — `images/ratings/[system]/spritesheet.png` + `.xml`, matching the animation prefix to the judgement name
3. **Skip** — if neither exists for that judgement, no popup appears (the default Psych popup is already hidden)

Individual images always override spritesheet entries for the same judgement. For example, if both `flawless.png` and a `flawless` animation exist in the spritesheet, the individual image is used.

#### System Folder Names & Judgement Names

Each system's images go in a folder matching its internal name (case-sensitive as listed):

| System | Folder | Judgement image/prefix names |
|--------|--------|------------------------------|
| Wife3 | `Wife3/` | marvelous, perfect, great, good, bad, miss |
| osu!mania V1 | `OsuMania/` | max, threehundred, twohundred, hundred, fifty, miss |
| osu!mania V2 | `osumaniav2/` | max, threehundred, twohundred, hundred, fifty, miss |
| ITG | `ITG/` | fantastic, excellent, great, decent, wayoff, miss |
| Ruthless | `ruthless/` | flawless, precise, great, good, ok, sloppy, barely, miss |
| O2Jam | `O2Jam/` | cool, good, bad, miss |
| DJMAX | `djmax/` | maxhundred, maxninety, good, bad, miss |
| IIDX | `IIDX/` | pgreat, great, good, bad, miss |
| Quaver | `quaver/` | marvelous, perfect, great, good, okay, miss |

> **Numeric name mapping:** osu!mania's numeric judgements and DJMAX's `max100`/`max90` are automatically mapped to spelled-out asset names to avoid conflicts with Sparrow XML's frame-numbering convention. Use `threehundred` not `300`, `maxhundred` not `max100`, etc.

#### Individual Images

Place PNG files directly in the system's ratings folder:

```
images/ratings/ruthless/
├── flawless.png
├── precise.png
├── great.png
├── good.png
├── ok.png
├── sloppy.png
├── barely.png
└── miss.png
```

You don't need to provide every judgement — missing ones are simply skipped.

#### Spritesheets (Animated Popups)

Place a Sparrow atlas (`spritesheet.png` + `spritesheet.xml`) in the system's ratings folder. Animation prefixes in the XML must match the judgement names listed above.

```
images/ratings/ruthless/
├── spritesheet.png
├── spritesheet.xml
└── theme.json          (optional)
```

Spritesheet popups are auto-centered using `centerOffsets()` so frames with different dimensions stay aligned. The animation framerate defaults to 60fps but is configurable via `theme.json` or Mod Settings.

#### theme.json

An optional `theme.json` in the system's ratings folder lets you configure popup behavior per system. These values are used when **Use Theme Defaults** is enabled in Mod Settings:

```json
{
    "antialiasing": true,
    "scale": 0.75,
    "framerate": 60,
    "tweenDuration": 0.1,
    "velocityX": 0,
    "velocityY": -75,
    "accelerationX": 0,
    "accelerationY": 550,
    "offsets": {
        "max": [50, 0],
        "threehundred": [50, 0],
        "twohundred": [50, 0],
        "hundred": [50, 0],
        "fifty": [50, 0],
        "miss": [50, 0]
    }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `antialiasing` | bool | true | Sprite antialiasing for this system's popups |
| `scale` | float | 1.0 | Scale multiplier for popup sprites |
| `framerate` | int | 60 | Animation framerate for spritesheet popups |
| `tweenDuration` | float | 0.1 | Fade-out tween duration in seconds |
| `velocityX` | float | 0 | Horizontal velocity (pixels/sec) |
| `velocityY` | float | −75 | Vertical velocity (negative = upward) |
| `accelerationX` | float | 0 | Horizontal acceleration |
| `accelerationY` | float | 550 | Vertical acceleration (positive = downward gravity) |
| `offsets` | object | — | Per-judgement `[x, y]` position adjustments. Keys use asset names (e.g. `threehundred`, not `300`) |

All of these (except `offsets`) can also be overridden globally via Mod Settings, which take effect when **Use Theme Defaults** is off.

#### osu!mania Hold Note Behavior

For osu!mania and OsuManiaV2, hold note **heads** do not show rating popups — only the last **tail** release shows a popup. This matches the official osu!mania behavior where the hold result is displayed at the end of the sustain.

### Hit Error Bar

A horizontal bar at the bottom of the screen that visualizes your timing accuracy in real time, similar to osu!'s hit error meter. Each note hit places a colored marker on the bar — left of center for early hits, right of center for late hits.

The bar is built from the active scoring system's timing windows. Each window tier is drawn as a color-coded segment mirrored on both sides of the center line, so you can see at a glance which judgement tier your hits are landing in. Window boundary labels (showing the ms value at each tier edge) appear briefly at the start of the song, then fade out.

#### Visual Layout

```
  Early                              Late
   ◄──────────────┼──────────────►
   ║  bad  │ good │ great │ good │  bad  ║
                  ▲
            center (0ms)
```

- **Center line** — a white marker at 0ms (perfect timing)
- **Color segments** — each judgement tier is a colored band, mirrored on both sides
- **Hit markers** — vertical lines placed at the corresponding offset, colored by judgement tier
- **"Early" / "Late" labels** — shown at the edges, fade out after 1 second
- **Window labels** — ms values at each tier boundary, staggered vertically to avoid overlap, fade out after 1 second

The bar replaces Psych Engine's time bar when enabled. The song time text is moved to the bottom-left corner of the screen.

#### Hit Markers

Each note hit spawns a marker from a pre-allocated pool of 100. Markers fade in quickly (0.1s) then slowly fade out (3s). When old markers are recycled, their tweens are cancelled and they're repositioned for the new hit. Sustain notes (hold tails) are excluded — only regular note heads produce markers.

#### Positioning

The bar automatically centers itself horizontally across the player's 4 strum columns. It sits at the bottom of the screen (`FlxG.height - 30`). This works correctly with both normal and middlescroll.

#### Simple Colors Mode

When **Simple Colors** is enabled in Mod Settings, the bar collapses all judgement tiers down to 3 colors regardless of the scoring system:
- **Cyan** — tightest window (best judgement)
- **Lime** — middle window
- **Orange** — widest window

This gives a consistent osu!-style 3-color look across all systems.

#### Mod Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Show Hit Error Bar | Enable/disable the bar | Off |
| Hit Error Bar Width | Bar width in pixels (100–800) | 400 |
| Hit Error Bar BG Opacity | Background opacity (0%–100%, 5% steps) | 25% |
| Hit Error Bar Simple Colors | Collapse to 3-color mode | Off |

#### Developer API

The script exposes two functions via `setVar()` for use by other scripts:

| Function | Description |
|----------|-------------|
| `heb_addHit(offsetMs)` | Manually add a hit marker at the given timing offset |
| `heb_clearHitData()` | Clear all markers and reset the timing average |

### Judgement Counter
Displays a real-time breakdown of judgement counts during gameplay. Automatically uses labels and colors from the active scoring system. For osu!mania and OsuManiaV2, the counter reads tallies directly from the scoring system (including tail judgements) rather than classifying hits independently.

---

## Installation

1. Download the script pack from the releases page:
2. Place it in your `mods/` directory:
   ```
   mods/[Script Pack] Lulu's Scoring Systems/
   ├── pack.json
   ├── data/
   │   └── settings.json
   ├── scripts/
   │   ├── Loader.hx                    (auto-loads only needed scripts)
   │   ├── scoring/
   │   │   ├── Wife3 Scoring System.hx
   │   │   ├── OsuMania Scoring System.hx
   │   │   ├── OsuManiaV2 Scoring System.hx
   │   │   ├── ITG Scoring System.hx
   │   │   ├── Ruthless Scoring System.hx
   │   │   ├── O2Jam Scoring System.hx
   │   │   ├── DJMAX Scoring System.hx
   │   │   ├── IIDX Scoring System.hx
   │   │   └── Quaver Scoring System.hx
   │   └── extras/
   │       ├── Timing Display.hx
   │       ├── Score Comparison.hx
   │       ├── Rating Popups.hx
   │       ├── Hit Error Bar.hx
   │       └── Judgement Counter.lua
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
| Enable Scoring Debug Output | Print debug info | Off |
| Replace Score Text | Override default HUD text | On |
| Show Timing Display | Show ms timing feedback | On |
| Show Judgement Counter | Show real-time judgement tally | On |
| Show Score Comparison | Show all systems side by side | Off |
| Use Kade Engine Style | Alternative score text format | Off |
| Show Hit Error Bar | Show horizontal timing error bar | Off |
| Hit Error Bar Width | Bar width in pixels (100–800) | 400 |
| Hit Error Bar BG Opacity | Background opacity (0%–100%) | 25% |
| Hit Error Bar Simple Colors | Collapse to 3-color mode | Off |
| Custom Rating Popups | Use system-specific rating images | Off |
| Use Theme Defaults | Read scale/antialiasing from theme.json | Off |
| Rating Popup Scale | Scale multiplier for popup sprites | 1.0 |
| Rating Popup Antialiasing | Antialiasing mode (ClientPrefs / On / Off) | ClientPrefs |
| Rating Popup Framerate | Animation framerate for spritesheets | 60 |
| Rating Popup Fade Duration | Fade-out tween duration (seconds) | 0.1 |
| Rating Popup Velocity X | Horizontal velocity of popup sprites | 0.0 |
| Rating Popup Velocity Y | Vertical velocity of popup sprites | −70.0 |

### Per-System Settings

| System | Setting | Description |
|--------|---------|-------------|
| Wife3 | Judge Preset (1–9) | Timing strictness preset |
| Wife3 | Judge Scale (0.009–4.0) | Custom timing scale (overrides preset) |
| osu!mania V1/V2 | Overall Difficulty (0–10) | Timing window strictness |
| ITG | Window Scale (0.1–4.0) | Timing window multiplier |
| Ruthless | Perfect Window (0–15ms) | Flawless timing threshold |
| O2Jam | BPM-Based Windows | Authentic BPM-scaling toggle |
| Quaver | Judgement Difficulty | Preset: Peaceful → Impossible |

---

## Systems Quick Comparison

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
| **Ruthless** | Custom | 1,000,000 | Linear curve | Perfect Window 0–15ms | No (bonus multiplier) | — | — | No |
| **O2Jam** | O2Jam | Unlimited | Weighted hit ratio | BPM scaling toggle | Yes (score = weight × combo) | Yes | Yes | No |
| **DJMAX** | DJMAX RESPECT V | 1,000,000 | Weighted average | No | No | Yes | Yes | No |
| **IIDX** | beatmania IIDX | EX Score | EX Rate | No | No | Yes | No | No |
| **Quaver** | Quaver | 1,000,000 | Weighted average | 8 Difficulty Presets | No | Yes | Yes | No |

Detailed documentation for each scoring system is available in the [`docs/`](docs/) folder:
[Wife3](docs/Wife3.md) · [osu!mania V1](docs/OsuMania.md) · [osu!mania V2](docs/OsuManiaV2.md) · [ITG](docs/ITG.md) · [Ruthless](docs/Ruthless.md) · [O2Jam](docs/O2Jam.md) · [DJMAX](docs/DJMAX.md) · [IIDX](docs/IIDX.md) · [Quaver](docs/Quaver.md)

---

## Timing Window Comparison

All values in milliseconds (±ms from perfect). Default settings for all systems.

| System | Tier 1 (Best) | Tier 2 | Tier 3 | Tier 4 | Tier 5 | Tier 6 | Miss |
|--------|--------------|--------|--------|--------|--------|--------|------|
| **Wife3** (J4) | ±22 (Marv) | ±45 (Perf) | ±90 (Great) | ±135 (Good) | ±180 (Bad) | — | — |
| **osu!mania** (OD8) | ±16 (MAX) | ±40 (300) | ±73 (200) | ±103 (100) | ±127 (50) | — | > 127 |
| **ITG** (1.0×) | ±21.5 (Fant) | ±43 (Exc) | ±102 (Great) | ±135 (Dec) | ±180 (WO) | — | — |
| **Ruthless** (10ms) | ±10 (Flaw) | ±20 (Prec) | ±30 (Great) | ±40 (Good) | ±50 (Ok) | ±50–100 | > 100 |
| **O2Jam** (fixed) | ±33 (COOL) | ±67 (GOOD) | ±100 (BAD) | — | — | — | > 100 |
| **DJMAX** | ±16 (MAX100) | ±33 (MAX90) | ±66 (GOOD) | ±100 (BAD) | — | — | > 100 |
| **IIDX** | ±16.67 (PGR) | ±33.33 (GR) | ±66.67 (GOOD) | ±100 (BAD) | ±180 (AWFUL) | — | > 180 |
| **Quaver** (Std) | ±18 (Marv) | ±43 (Perf) | ±76 (Great) | ±106 (Good) | ±127 (Okay) | — | > 164 |

### Strictest → Most Lenient (Best Judgement Window)

1. **Ruthless** — 10ms (configurable down to 0ms)
2. **osu!mania** — 16ms (fixed MAX window)
3. **DJMAX** — 16ms
4. **IIDX** — 16.67ms
5. **Quaver** — 18ms (Standard default, configurable down to 8ms at Impossible)
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
| Ruthless | XX | 99.50% | X+ | 99.00% |
| O2Jam | SSS | 100% | SS | ≥ 99% |
| DJMAX | S | 97.00% | A | ≥ 90% |
| IIDX | AAA | 88.89% | AA | 77.78% |
| Quaver | X | 100% | SS | ≥ 99% |

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
| `{prefix}_setEnabled(bool)` | Void | Enable/disable system |
| `{prefix}_resetScoring()` | Void | Reset all state |

Most systems also expose:

| Callback | Returns | Description |
|----------|---------|-------------|
| `{prefix}_getJudgement(offsetMs)` | String | Judgement name for timing offset |
| `{prefix}_getHitWindow(judgement)` | Float | Window size for judgement name |

> **Note:** Wife3 uses `wife3_getTimingWindow(windowType)` instead of `getHitWindow`, and does not expose `getJudgement`. Ruthless uses `ruthless_getTimingWindow(windowType)` instead of `getHitWindow`.

### System-Specific Callbacks

| System | Callback | Description |
|--------|----------|-------------|
| Wife3 | `wife3_setJudgeScale(scale)` | Set custom timing scale |
| Wife3 | `wife3_setJudgePreset(preset)` | Set judge preset (1–9) |
| Wife3 | `wife3_getJudgeScale()` | Get current timing scale |
| Wife3 | `wife3_getJudgePreset()` | Get nearest preset for current scale |
| Wife3 | `wife3_getTimingWindow(windowType)` | Get ms window for judgement type |
| osu!mania V1 | `osu_getTailJudgement(offsetMs)` | Judgement with 1.5× lenient tail windows |
| Ruthless | `ruthless_getTimingWindow(windowType)` | Get ms window for judgement type |
| Ruthless | `ruthless_setPerfectWindow(ms)` | Set perfect window (0–15ms) |
| Ruthless | `ruthless_getPerfectWindow()` | Get current perfect window |
| ITG | `itg_setWindowScale(scale)` | Set timing window scale |
| ITG | `itg_getWindowScale()` | Get current window scale |
| O2Jam | `o2jam_getCombo()` | Get current combo |
| O2Jam | `o2jam_setUseBPMWindows(bool)` | Enable/disable BPM mode |
| O2Jam | `o2jam_getUseBPMWindows()` | Check BPM mode status |
| O2Jam | `o2jam_updateBPMWindows()` | Recalculate windows from BPM |
| DJMAX | `djmax_getCombo()` | Get current combo |
| IIDX | `iidx_getExRate()` | Get EX Rate % (used for grading) |
| IIDX | `iidx_getCombo()` | Get current combo |
| Quaver | `quaver_getCombo()` | Get current combo |

### Judgement Counter Variables

Scoring systems expose their judgement counts via `setVar()` for use by the Judgement Counter and other scripts:

| System | Variables |
|--------|-----------|
| Wife3 | `wife3_marvelousHits`, `wife3_perfectHits`, `wife3_greatHits`, `wife3_goodHits`, `wife3_badHits` |
| osu!mania V1 | `osu_maxHits`, `osu_300Hits`, `osu_200Hits`, `osu_100Hits`, `osu_50Hits` |
| osu!mania V2 | `osuv2_maxHits`, `osuv2_300Hits`, `osuv2_200Hits`, `osuv2_100Hits`, `osuv2_50Hits` |

### Script Loader

The pack includes a `Loader.hx` script that dynamically loads only the scoring systems and extras needed based on the current Mod Settings. Scoring system scripts are **not** placed in the global `scripts/` directory — the Loader reads `data/settings.json` and initializes only the active system (and comparison systems if enabled). This prevents unnecessary script overhead.

---

*Script pack by AutisticLulu.*
