/*
	>>> Ruthless Scoring System for Psych Engine
		HScript-based custom scoring system that uses a linear curve for
		accuracy calculation. Only perfectly timed hits earn full points

		Features:
			- Linear accuracy curve (no negative accuracy possible)
			- Max score of 1,000,000 per song (osu!mania-style base+bonus scoring)
			- Configurable perfect hit window (0-25ms, default 10ms)
			- Linear falloff with 0.5x penalty past 50ms
			- 7 judgement tiers: Flawless, Precise, Great, Good, Ok, Sloppy, Barely
			- *Optional* Kade Engine style score text formatting
			- Settings.json support (when using "Lulu's Feature Pack")

		Scoring Curve:
			- Hits within the perfect window (default <=10ms) = 100% points
			- Hits from perfect window to 50ms = linear falloff
			- Hits from 50ms to 100ms = linear falloff * 0.5 (halved for punishment)
			- Hits at 100ms+ = miss (0 points, no negative penalty)
			- Accuracy is always 0-100%, never negative
			- Score scales to 1,000,000 for a perfect run

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var ruthless_enabled = true;
var ruthless_debug = false;
var ruthless_replaceScoreText = true;
var ruthless_kadeEngineStyle = false; // Whether to use Kade Engine style scoreText or Psych Engine style.
// --- Scoring Parameters ---
var ruthless_perfectWindow = 10.0; // Maximum ms for a 100% scored hit (configurable 0-25ms)
var ruthless_missWindow = 100.0; // Miss boundary in ms
var ruthless_maxScore = 1000000; // Max total score for a perfect run
// --- Note Counting (Do Not Modify) ---
var ruthless_totalNotes = 0; // Total hittable notes in the song
var ruthless_notesCounted = false; // Whether notes have been counted yet
// --- Score State (Do Not Modify) ---
var ruthless_bonus = 100.0; // Bonus multiplier (0-100, rewards consistency like osu)
var ruthless_baseScoreAccum = 0.0; // Accumulated base score
var ruthless_bonusScoreAccum = 0.0; // Accumulated bonus score
var ruthless_songScore = 0; // Displayed song score (rounded)
// --- Accuracy Tracking (Do Not Modify) ---
var ruthless_curPoints = 0.0; // Accumulated points (0 to maxPoints per note)
var ruthless_maxPoints = 0.0; // Maximum possible points
// --- Judgement Tracking (Do Not Modify) ---
var ruthless_flawlessHits = 0; // Flawless (<=10ms, perfect window)
var ruthless_preciseHits = 0; // Precise (<=20ms)
var ruthless_greatHits = 0; // Great (<=30ms)
var ruthless_goodHits = 0; // Good (<=40ms)
var ruthless_okHits = 0; // Ok (<=50ms)
var ruthless_sloppyHits = 0; // Sloppy (<=75ms)
var ruthless_barelyHits = 0; // Barely (<=100ms)

// ========================================
// SETTINGS LOADER
// ========================================

/**
 * Loads settings from settings.json using getModSetting if available.
 * Settings from settings.json will override the default values above.
 */
function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath))) {
		trace('[Ruthless] settings.json not found, using default values from script');
		return;
	}
	trace('[Ruthless] settings.json found, loading settings...');

	var value:Dynamic;

	if ((value = getModSetting('scoring_system')) != null)
		ruthless_enabled = (value == 'Ruthless');

	if ((value = getModSetting('scoring_debug')) != null)
		ruthless_debug = value;

	if ((value = getModSetting('scoring_replaceScoreText')) != null)
		ruthless_replaceScoreText = value;

	if ((value = getModSetting('scoring_kadeEngineStyle')) != null)
		ruthless_kadeEngineStyle = value;

	if ((value = getModSetting('ruthless_perfectWindow')) != null) {
		var window:Float = value;
		if (window >= 0.0 && window <= 25.0) {
			ruthless_perfectWindow = window;
			debug('Loaded ruthless_perfectWindow from settings: ' + ruthless_perfectWindow + 'ms');
		} else {
			debug('Invalid perfect window: ' + window + ', must be between 0.0 and 25.0');
		}
	}
}

// ========================================
// DEBUG HELPER
// ========================================

/**
 * Helper function to print debug messages only when ruthless_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!ruthless_debug || !ruthless_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[Ruthless] ' + message, color);
}

// ========================================
// RUTHLESS ALGORITHM
// ========================================

/**
 * Ruthless scoring algorithm - calculates accuracy points based on timing offset.
 * Uses a linear falloff with a 0.5x penalty past 45ms for extra punishment.
 *
 * - Within perfect window: 1.0 (100%)
 * - From perfect window to 50ms: linear falloff
 * - From 50ms to miss window: linear falloff * 0.5 (halved)
 * - Beyond miss window (100ms): 0.0
 *
 * @param offsetMs Absolute timing offset in milliseconds
 * @return Accuracy points (0.0 to 1.0, never negative)
 */
function ruthless(offsetMs:Float):Float {
	if (offsetMs < 0.0)
		offsetMs = -offsetMs;

	// Perfect zone: full points
	if (offsetMs <= ruthless_perfectWindow)
		return 1.0;

	// Beyond miss window: zero points
	if (offsetMs >= ruthless_missWindow)
		return 0.0;

	// Linear falloff from perfect window to miss window
	var linear = 1.0 - (offsetMs - ruthless_perfectWindow) / (ruthless_missWindow - ruthless_perfectWindow);

	// Past 50ms: halve the value for extra punishment
	if (offsetMs > 50.0)
		linear = linear * 0.5;

	return linear;
}

/**
 * Processes a note hit using osu!mania-style base+bonus scoring with Ruthless judgements.
 *
 * Score = BaseScore + BonusScore
 * BaseScore  = (MaxScore * 0.5 / TotalNotes) * (HitValue / 320)
 * BonusScore = (MaxScore * 0.5 / TotalNotes) * (HitBonusValue * sqrt(Bonus) / 320)
 *
 * Bonus is updated BEFORE calculating BonusScore:
 * Bonus = clamp(Bonus + HitBonus - HitPunishment, 0, 100)
 *
 * @param judgement The judgement tier string
 */
function processHit(judgement:String) {
	var hitValue = 0;
	var hitBonusValue = 0;
	var hitBonus = 0.0;
	var hitPunishment = 0.0;

	if (judgement == 'flawless') {
		hitValue = 320;
		hitBonusValue = 32;
		hitBonus = 2.0;
	} else if (judgement == 'precise') {
		hitValue = 310;
		hitBonusValue = 32;
		hitBonus = 1.5;
	} else if (judgement == 'great') {
		hitValue = 300;
		hitBonusValue = 32;
		hitBonus = 1.0;
	} else if (judgement == 'good') {
		hitValue = 250;
		hitBonusValue = 24;
		hitPunishment = 4.0;
	} else if (judgement == 'ok') {
		hitValue = 200;
		hitBonusValue = 16;
		hitPunishment = 8.0;
	} else if (judgement == 'sloppy') {
		hitValue = 100;
		hitBonusValue = 8;
		hitPunishment = 24.0;
	} else {
		// barely
		hitValue = 50;
		hitBonusValue = 4;
		hitPunishment = 44.0;
	}

	// Update bonus BEFORE calculating bonus score
	ruthless_bonus = ruthless_bonus + hitBonus - hitPunishment;
	if (ruthless_bonus < 0)
		ruthless_bonus = 0;
	if (ruthless_bonus > 100)
		ruthless_bonus = 100;

	// Calculate score components
	var factor = (ruthless_maxScore * 0.5) / ruthless_totalNotes;
	var baseScore = factor * (hitValue / 320.0);
	var bonusScore = factor * (hitBonusValue * Math.sqrt(ruthless_bonus) / 320.0);

	ruthless_baseScoreAccum = ruthless_baseScoreAccum + baseScore;
	ruthless_bonusScoreAccum = ruthless_bonusScoreAccum + bonusScore;
	ruthless_songScore = Math.round(ruthless_baseScoreAccum + ruthless_bonusScoreAccum);
}

/**
 * Processes a miss using osu!mania-style bonus penalty.
 */
function processMiss() {
	// Miss resets bonus to 0 (harsh punishment for consistency tracker)
	ruthless_bonus = 0;
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Enables or disables the Ruthless scoring system
 * @param enabled Whether to enable Ruthless scoring
 */
function ruthless_setEnabled(enabled:Bool) {
	ruthless_enabled = enabled;
	setVar('ruthless_enabled', ruthless_enabled);
	debug('Ruthless scoring ' + (enabled ? 'enabled' : 'disabled'));
}

/**
 * Sets the perfect hit window
 * @param window Perfect window in ms (clamped 0-25)
 */
function ruthless_setPerfectWindow(window:Float) {
	ruthless_perfectWindow = Math.max(0.0, Math.min(25.0, window));
	debug('Perfect window set to: ' + ruthless_perfectWindow + 'ms');
}

/**
 * Returns the current perfect window in ms
 * @return Perfect window in milliseconds
 */
function ruthless_getPerfectWindow():Float {
	return ruthless_perfectWindow;
}

/**
 * Returns the current Ruthless accuracy as a percentage
 * @return Accuracy percentage (0-100, never negative)
 */
function ruthless_getAccuracy():Float {
	if (ruthless_maxPoints <= 0)
		return 0.0;
	var percent = (ruthless_curPoints / ruthless_maxPoints) * 100.0;
	if (percent < 0.0)
		percent = 0.0;
	if (percent > 100.0)
		percent = 100.0;
	return percent;
}

/**
 * Returns the current song score
 * @return Total song score
 */
function ruthless_getScore():Int {
	return ruthless_songScore;
}

/**
 * Gets letter grade for a given percentage.
 * Ruthless uses the same grade thresholds as Wife3 for consistency.
 * @param percent Ruthless percentage (0-100)
 * @return Letter grade string
 */
function ruthless_getGrade(percent:Float):String {
	if (percent >= 99.50)
		return 'XX';
	if (percent >= 99.00)
		return 'X+';
	if (percent >= 98.50)
		return 'X';
	if (percent >= 98.00)
		return 'X-';
	if (percent >= 97.50)
		return 'SS+';
	if (percent >= 97.00)
		return 'SS';
	if (percent >= 96.50)
		return 'SS-';
	if (percent >= 96.00)
		return 'S+';
	if (percent >= 95.00)
		return 'S';
	if (percent >= 94.00)
		return 'S-';
	if (percent >= 93.00)
		return 'A+';
	if (percent >= 92.00)
		return 'A';
	if (percent >= 91.00)
		return 'A-';
	if (percent >= 90.00)
		return 'B+';
	if (percent >= 88.50)
		return 'B';
	if (percent >= 87.00)
		return 'B-';
	if (percent >= 85.50)
		return 'C+';
	if (percent >= 84.00)
		return 'C';
	if (percent >= 82.50)
		return 'C-';
	if (percent >= 80.00)
		return 'D+';
	if (percent >= 77.50)
		return 'D';
	if (percent >= 75.00)
		return 'D-';
	return 'F';
}

/**
 * Gets a timing window (in ms) for a given judgement tier.
 * @param windowType Window type: 'flawless', 'precise', 'decent', 'sloppy', 'barely'
 * @return Timing window in milliseconds
 */
function ruthless_getTimingWindow(windowType:String):Float {
	switch (windowType.toLowerCase()) {
		case 'flawless':
			return ruthless_perfectWindow;
		case 'precise':
			return 20.0;
		case 'great':
			return 30.0;
		case 'good':
			return 40.0;
		case 'ok':
			return 50.0;
		case 'sloppy':
			return 75.0;
		case 'barely':
			return 100.0;
		default:
			return 0.0;
	}
}

/**
 * Gets the judgement name for a given timing offset.
 * @param offsetMs Absolute timing offset in milliseconds
 * @return Judgement name string
 */
function ruthless_getJudgement(offsetMs:Float):String {
	if (offsetMs < 0.0)
		offsetMs = -offsetMs;

	if (offsetMs <= ruthless_perfectWindow)
		return 'flawless';
	if (offsetMs <= 20.0)
		return 'precise';
	if (offsetMs <= 30.0)
		return 'great';
	if (offsetMs <= 40.0)
		return 'good';
	if (offsetMs <= 50.0)
		return 'ok';
	if (offsetMs <= 75.0)
		return 'sloppy';
	if (offsetMs <= 100.0)
		return 'barely';
	return 'miss';
}

/**
 * Resets all accuracy tracking variables to zero.
 */
function ruthless_resetScoring() {
	ruthless_curPoints = 0.0;
	ruthless_maxPoints = 0.0;
	ruthless_bonus = 100.0;
	ruthless_baseScoreAccum = 0.0;
	ruthless_bonusScoreAccum = 0.0;
	ruthless_songScore = 0;
	ruthless_flawlessHits = 0;
	ruthless_preciseHits = 0;
	ruthless_greatHits = 0;
	ruthless_goodHits = 0;
	ruthless_okHits = 0;
	ruthless_sloppyHits = 0;
	ruthless_barelyHits = 0;
	debug('Ruthless scoring reset');

	if (ruthless_replaceScoreText) {
		ruthless_updateScoreText();
	}
}

/**
 * Returns the total number of Flawless hits
 * @return Count of Flawless judgements (within perfect window)
 */
function ruthless_getFlawlessHits():Int {
	return ruthless_flawlessHits;
}

/**
 * Returns the total number of Precise hits
 * @return Count of Precise judgements (<=20ms)
 */
function ruthless_getPreciseHits():Int {
	return ruthless_preciseHits;
}

/**
 * Returns the total number of Great hits
 * @return Count of Great judgements (<=30ms)
 */
function ruthless_getGreatHits():Int {
	return ruthless_greatHits;
}

/**
 * Returns the total number of Good hits
 * @return Count of Good judgements (<=40ms)
 */
function ruthless_getGoodHits():Int {
	return ruthless_goodHits;
}

/**
 * Returns the total number of Ok hits
 * @return Count of Ok judgements (<=50ms)
 */
function ruthless_getOkHits():Int {
	return ruthless_okHits;
}

/**
 * Returns the total number of Sloppy hits
 * @return Count of Sloppy judgements (<=75ms)
 */
function ruthless_getSloppyHits():Int {
	return ruthless_sloppyHits;
}

/**
 * Returns the total number of Barely hits
 * @return Count of Barely judgements (<=100ms)
 */
function ruthless_getBarelyHits():Int {
	return ruthless_barelyHits;
}

/**
 * Formats percentage to 2 decimal places
 * @param value Percentage value
 * @return Formatted string
 */
function ruthless_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

/**
 * Gets the rating FC (Full Combo) tier based on judgement counts.
 * @return Rating FC string (MFC, PFC, GFC, FC, SDCB, Clear)
 */
function ruthless_getRatingFC():String {
	var misses = game.songMisses;

	if (misses > 0) {
		if (misses < 10) {
			return 'SDCB'; // Single Digit Combo Break
		}
		return 'Clear';
	}

	if (ruthless_preciseHits == 0 && ruthless_greatHits == 0 && ruthless_goodHits == 0 && ruthless_okHits == 0 && ruthless_sloppyHits == 0
		&& ruthless_barelyHits == 0) {
		return 'MFC'; // Marvelous Full Combo (all Flawless)
	}

	if (ruthless_greatHits == 0 && ruthless_goodHits == 0 && ruthless_okHits == 0 && ruthless_sloppyHits == 0 && ruthless_barelyHits == 0) {
		return 'SFC'; // Sick Full Combo (Flawless + Precise only)
	}

	if (ruthless_goodHits == 0 && ruthless_okHits == 0 && ruthless_sloppyHits == 0 && ruthless_barelyHits == 0) {
		return 'GFC'; // Good Full Combo
	}

	return 'FC'; // Full Combo
}

/**
 * Enables or disables Ruthless score text replacement
 * @param replace Whether to replace Psych Engine's default score text
 */
function ruthless_setReplaceScoreText(replace:Bool) {
	ruthless_replaceScoreText = replace;
	setVar('ruthless_replaceScoreText', ruthless_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

/**
 * Returns whether Ruthless score text replacement is enabled
 * @return Current state of score text replacement
 */
function ruthless_getReplaceScoreText():Bool {
	return ruthless_replaceScoreText;
}

/**
 * Sets the score text format style
 * @param kadeStyle If true, uses Kade Engine format; if false, uses Psych Engine format
 */
function ruthless_setKadeEngineStyle(kadeStyle:Bool) {
	ruthless_kadeEngineStyle = kadeStyle;
	setVar('ruthless_kadeEngineStyle', ruthless_kadeEngineStyle);
	debug('Kade Engine style score text ' + (kadeStyle ? 'enabled' : 'disabled'));
}

/**
 * Returns the current score text format style
 * @return True if using Kade Engine style, false if using Psych Engine style
 */
function ruthless_getKadeEngineStyle():Bool {
	return ruthless_kadeEngineStyle;
}

// ========================================
// SCORE TEXT
// ========================================

/**
 * Updates the score text with Ruthless information.
 * This function replaces the default scoreText content.
 */
function ruthless_updateScoreText() {
	if (!ruthless_enabled || !ruthless_replaceScoreText)
		return;

	var score = ruthless_getScore();
	var misses = game.songMisses;
	var hasHitNotes = (ruthless_maxPoints > 0);

	var scoreText = '';

	if (hasHitNotes) {
		var accuracy = ruthless_getAccuracy();
		var formattedPercent = ruthless_formatPercent(accuracy);
		var grade = ruthless_getGrade(accuracy);
		var ratingFC = ruthless_getRatingFC();

		scoreText = ruthless_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ' + formattedPercent + ' % | (' + ratingFC
			+ ') ' + grade : 'Score: '
			+ score
			+ ' | Misses: '
			+ misses
			+ ' | Rating: '
			+ grade
			+ ' ('
			+ formattedPercent
			+ '%) - '
			+ ratingFC;
	} else {
		scoreText = ruthless_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ?' : 'Score: '
			+ score
			+ ' | Misses: '
			+ misses
			+ ' | Rating: ?';
	}

	game.scoreTxt.text = scoreText;
}

// ========================================
// CALLBACK REGISTRATION
// ========================================

/**
 * Registers all functions as global callbacks.
 * Makes these functions accessible from other scripts via setVar() and createGlobalCallback().
 */
function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['ruthless_getAccuracy', ruthless_getAccuracy],
		['ruthless_getScore', ruthless_getScore],
		['ruthless_getGrade', ruthless_getGrade],
		['ruthless_getPerfectWindow', ruthless_getPerfectWindow],
		['ruthless_getFlawlessHits', ruthless_getFlawlessHits],
		['ruthless_getPreciseHits', ruthless_getPreciseHits],
		['ruthless_getGreatHits', ruthless_getGreatHits],
		['ruthless_getGoodHits', ruthless_getGoodHits],
		['ruthless_getOkHits', ruthless_getOkHits],
		['ruthless_getSloppyHits', ruthless_getSloppyHits],
		['ruthless_getBarelyHits', ruthless_getBarelyHits],
		['ruthless_formatPercent', ruthless_formatPercent],
		['ruthless_getRatingFC', ruthless_getRatingFC],
		['ruthless_getTimingWindow', ruthless_getTimingWindow],
		['ruthless_getJudgement', ruthless_getJudgement],
		['ruthless_setEnabled', ruthless_setEnabled],
		['ruthless_setPerfectWindow', ruthless_setPerfectWindow],
		['ruthless_resetScoring', ruthless_resetScoring],
		['ruthless_setReplaceScoreText', ruthless_setReplaceScoreText],
		['ruthless_getReplaceScoreText', ruthless_getReplaceScoreText],
		['ruthless_updateScoreText', ruthless_updateScoreText],
		['ruthless_setKadeEngineStyle', ruthless_setKadeEngineStyle],
		['ruthless_getKadeEngineStyle', ruthless_getKadeEngineStyle]
	];

	for (callback in callbacks) {
		createGlobalCallback(callback[0], callback[1]);
		setVar(callback[0], callback[1]);
	}
}

// ========================================
// NOTE COUNTING
// ========================================

/**
 * Counts total non-sustain player notes from the game's note arrays.
 * Called after chart is loaded so score can be properly scaled to 1,000,000.
 */
function countTotalNotes() {
	ruthless_totalNotes = 0;

	if (game.unspawnNotes != null) {
		for (note in game.unspawnNotes) {
			if (note != null && note.mustPress && !note.isSustainNote) {
				ruthless_totalNotes = ruthless_totalNotes + 1;
			}
		}
	}

	if (game.notes != null && game.notes.members != null) {
		for (note in game.notes.members) {
			if (note != null && note.mustPress && note.alive && !note.isSustainNote) {
				ruthless_totalNotes = ruthless_totalNotes + 1;
			}
		}
	}

	if (ruthless_totalNotes <= 0)
		ruthless_totalNotes = 1;

	ruthless_notesCounted = true;
	debug('Total notes counted: '
		+ ruthless_totalNotes
		+ ' (score per perfect note: '
		+ Math.round(ruthless_maxScore / ruthless_totalNotes)
		+ ')');
}

/**
 * Ensures note count is accurate by recounting on first note interaction.
 * Catches chart modifications made by other scripts (e.g., Play Both Charts).
 */
function ensureNotesCounted() {
	if (!ruthless_notesCounted) {
		countTotalNotes();
	}
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	loadSettings();
	registerCallbacks();

	debug('Ruthless functions registered - accessible from other scripts');
	debug('Ruthless Scoring System Initialized (perfect window: ' + ruthless_perfectWindow + 'ms)');
}

function onCreatePost() {
	ruthless_resetScoring();
	countTotalNotes();
}

function preUpdateScore(miss:Bool) {
	if (ruthless_enabled && ruthless_replaceScoreText) {
		if (!miss) {
			game.doScoreBop();
		}
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (ruthless_enabled && ruthless_replaceScoreText) {
		ruthless_updateScoreText();
	}
}

function goodNoteHit(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;

	// Calculate timing offset
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;
	var offsetMs = Math.abs(noteDiff);

	// Calculate accuracy via linear curve
	var accuracy = ruthless(offsetMs);

	// Ensure notes are counted (catches chart modifications by other scripts)
	ensureNotesCounted();

	// Track judgements based on timing windows
	if (offsetMs <= ruthless_perfectWindow) {
		ruthless_flawlessHits = ruthless_flawlessHits + 1;
		setVar('ruthless_flawlessHits', ruthless_flawlessHits);
	} else if (offsetMs <= 20.0) {
		ruthless_preciseHits = ruthless_preciseHits + 1;
		setVar('ruthless_preciseHits', ruthless_preciseHits);
	} else if (offsetMs <= 30.0) {
		ruthless_greatHits = ruthless_greatHits + 1;
		setVar('ruthless_greatHits', ruthless_greatHits);
	} else if (offsetMs <= 40.0) {
		ruthless_goodHits = ruthless_goodHits + 1;
		setVar('ruthless_goodHits', ruthless_goodHits);
	} else if (offsetMs <= 50.0) {
		ruthless_okHits = ruthless_okHits + 1;
		setVar('ruthless_okHits', ruthless_okHits);
	} else if (offsetMs <= 75.0) {
		ruthless_sloppyHits = ruthless_sloppyHits + 1;
		setVar('ruthless_sloppyHits', ruthless_sloppyHits);
	} else {
		ruthless_barelyHits = ruthless_barelyHits + 1;
		setVar('ruthless_barelyHits', ruthless_barelyHits);
	}

	// Update accuracy tracking (accuracy is 0-1, never negative)
	ruthless_curPoints = ruthless_curPoints + accuracy;
	ruthless_maxPoints = ruthless_maxPoints + 1.0;

	// Update score via osu-style base+bonus system
	var judgement = ruthless_getJudgement(offsetMs);
	processHit(judgement);

	debug('Hit at ' + ruthless_formatPercent(offsetMs) + 'ms -> ' + judgement + ' (' + ruthless_formatPercent(accuracy * 100) + '%) | Score: '
		+ ruthless_songScore + ' | Bonus: ' + Math.round(ruthless_bonus));

	if (ruthless_replaceScoreText) {
		ruthless_updateScoreText();
	}
}

function noteMiss(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;

	// Miss adds 0 points but still increases max possible (no negative penalty)
	ruthless_maxPoints = ruthless_maxPoints + 1.0;
	processMiss();

	debug('Note missed - bonus reset | Score: ' + ruthless_songScore);

	if (ruthless_replaceScoreText) {
		ruthless_updateScoreText();
	}
}

function onDestroy() {
	// Cleanup handled by other scripts
}
