/*
	>>> Quaver Scoring System for Psych Engine
		HScript-based scoring system that implements Quaver's judgement and scoring system.
		This replaces Psych Engine's default scoring system.
		Can be used with Custom HUDs in Lua/HScript by using the provided global callbacks.

		Features:
			- Quaver judgement windows with 8 difficulty presets (Peaceful → Impossible)
			- Standard difficulty: Marvelous (±18ms), Perfect (±43ms), Great (±76ms), Good (±106ms), Okay (±127ms), Miss (±164ms)
			- Accuracy = sum(Vj * Nj) / (100 * N) where Vj = judgement weight, Nj = count, N = total notes
			- Score = 1,000,000 × Accuracy (normalized)
			- Judgement weights: Marvelous=100, Perfect=98.25, Great=65, Good=25, Okay=-100, Miss=-50
			- Quaver-style grade thresholds: X (100%), SS (99%+), S (95%+), A (90%+), B (80%+), C (70%+), D (<70%)
			- Okay and Miss break combo; Marvelous/Perfect/Great/Good maintain combo
			- *Optional* Kade Engine style score text formatting
			- Settings.json support (when using "Lulu's Scoring Systems" pack)
				- Configure settings through the mod settings menu
				- Settings from settings.json will override the default values in the script

		Quaver Judgement System (Standard difficulty):
			- Marvelous: ±18ms  — Weight 100.    Combo continues.
			- Perfect:   ±43ms  — Weight 98.25.  Combo continues.
			- Great:     ±76ms  — Weight 65.     Combo continues.
			- Good:      ±106ms — Weight 25.     Combo continues.
			- Okay:      ±127ms — Weight -100.   Combo breaks.
			- Miss:      ±164ms — Weight -50.    Combo breaks.

		Difficulty Presets:
			- Peaceful:   ±23 / ±57 / ±101 / ±141 / ±169 / ±218 ms
			- Lenient:    ±21 / ±52 / ±91  / ±128 / ±153 / ±198 ms
			- Chill:      ±19 / ±47 / ±83  / ±116 / ±139 / ±180 ms
			- Standard:   ±18 / ±43 / ±76  / ±106 / ±127 / ±164 ms (default)
			- Strict:     ±16 / ±39 / ±69  / ±96  / ±127 / ±164 ms
			- Tough:      ±14 / ±35 / ±62  / ±87  / ±127 / ±164 ms
			- Extreme:    ±13 / ±32 / ±57  / ±79  / ±127 / ±164 ms
			- Impossible: ±8  / ±20 / ±35  / ±49  / ±127 / ±164 ms

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var quaver_enabled = true;
var quaver_isActiveSystem = false;
var quaver_debug = false;
var quaver_replaceScoreText = true;
var quaver_kadeEngineStyle = false;

// --- Timing Windows (Standard difficulty) ---
var quaver_marvelousWindow = 18.0; // Marvelous: ±18ms
var quaver_perfectWindow = 43.0; // Perfect:   ±43ms
var quaver_greatWindow = 76.0; // Great:     ±76ms
var quaver_goodWindow = 106.0; // Good:      ±106ms
var quaver_okayWindow = 127.0; // Okay:      ±127ms
var quaver_missWindow = 164.0; // Miss:      ±164ms (beyond = ghost)
// --- Judgement Weights (Do Not Modify) ---
var quaver_marvelousWeight = 100.0;
var quaver_perfectWeight = 98.25;
var quaver_greatWeight = 65.0;
var quaver_goodWeight = 25.0;
var quaver_okayWeight = -100.0;
var quaver_missWeight = -50.0;

// --- Difficulty Presets ---
// Each preset is [marvelous, perfect, great, good, okay, miss]
var QUAVER_DIFFICULTIES:Array<Dynamic> = [
	[23.0, 57.0, 101.0, 141.0, 169.0, 218.0], // Peaceful
	[21.0, 52.0, 91.0, 128.0, 153.0, 198.0], // Lenient
	[19.0, 47.0, 83.0, 116.0, 139.0, 180.0], // Chill
	[18.0, 43.0, 76.0, 106.0, 127.0, 164.0], // Standard (default)
	[16.0, 39.0, 69.0, 96.0, 127.0, 164.0], // Strict
	[14.0, 35.0, 62.0, 87.0, 127.0, 164.0], // Tough
	[13.0, 32.0, 57.0, 79.0, 127.0, 164.0], // Extreme
	[8.0, 20.0, 35.0, 49.0, 127.0, 164.0] // Impossible
];

var QUAVER_DIFFICULTY_NAMES:Array<String> = [
	'Peaceful',
	'Lenient',
	'Chill',
	'Standard',
	'Strict',
	'Tough',
	'Extreme',
	'Impossible'
];

// --- Score State (Do Not Modify) ---
var quaver_combo = 0;
var quaver_maxCombo = 0;

// --- Accuracy Tracking (Do Not Modify) ---
var quaver_weightedSum = 0.0;
var quaver_totalNotes = 0;

// --- Judgement Tracking (Do Not Modify) ---
var quaver_marvelousHits = 0;
var quaver_perfectHits = 0;
var quaver_greatHits = 0;
var quaver_goodHits = 0;
var quaver_okayHits = 0;

// ========================================
// SETTINGS LOADER
// ========================================

/**
 * Loads settings from settings.json using getModSetting if available.
 * Settings from settings.json will override the default values above.
 */
function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath)))
		return;

	var value:Dynamic;

	if ((value = getModSetting('scoring_system')) != null) {
		quaver_isActiveSystem = (value == 'Quaver');
		quaver_enabled = quaver_isActiveSystem;
	}

	if (!quaver_enabled) {
		var cmpEnabled:Dynamic = getModSetting('scoring_showComparison');
		var cmpShow:Dynamic = getModSetting('cmp_showQuaver');
		if (cmpEnabled == true && cmpShow == true)
			quaver_enabled = true;
	}

	if (!quaver_enabled)
		return;

	trace('[Quaver] settings.json found, loading settings...');

	if ((value = getModSetting('scoring_debug')) != null)
		quaver_debug = value;

	if ((value = getModSetting('scoring_replaceScoreText')) != null)
		quaver_replaceScoreText = value;

	if ((value = getModSetting('scoring_kadeEngineStyle')) != null)
		quaver_kadeEngineStyle = value;

	if ((value = getModSetting('quaver_difficulty')) != null) {
		var idx:Int = 0;
		for (i in 0...QUAVER_DIFFICULTY_NAMES.length) {
			if (QUAVER_DIFFICULTY_NAMES[i] == value) {
				idx = i;
				break;
			}
		}
		var windows = QUAVER_DIFFICULTIES[idx];
		quaver_marvelousWindow = windows[0];
		quaver_perfectWindow = windows[1];
		quaver_greatWindow = windows[2];
		quaver_goodWindow = windows[3];
		quaver_okayWindow = windows[4];
		quaver_missWindow = windows[5];
		debug('Loaded difficulty: ' + value + ' (Marvelous: ±' + windows[0] + 'ms)');
	}
}

// ========================================
// DEBUG HELPER
// ========================================

/**
 * Helper function to print debug messages only when quaver_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!quaver_debug || !quaver_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[Quaver] ' + message, color);
}

// ========================================
// HIT WINDOW FUNCTIONS
// ========================================

/**
 * Gets the hit window (in ms) for a judgement.
 *
 * Quaver timing windows (Standard difficulty):
 *   Marvelous: ±18ms
 *   Perfect:   ±43ms
 *   Great:     ±76ms
 *   Good:      ±106ms
 *   Okay:      ±127ms
 *   Miss:      ±164ms
 *
 * @param judgement Judgement name: 'marvelous', 'perfect', 'great', 'good', 'okay', 'miss'
 * @return Hit window in milliseconds
 */
function quaver_getHitWindow(judgement:String):Float {
	switch (judgement.toLowerCase()) {
		case 'marvelous':
			return quaver_marvelousWindow;
		case 'perfect':
			return quaver_perfectWindow;
		case 'great':
			return quaver_greatWindow;
		case 'good':
			return quaver_goodWindow;
		case 'okay':
			return quaver_okayWindow;
		case 'miss':
			return quaver_missWindow;
		default:
			return quaver_missWindow;
	}
}

/**
 * Determines the Quaver judgement for a given timing offset.
 * @param offsetMs Timing offset in milliseconds (absolute value used for judgement)
 * @return Judgement string: 'marvelous', 'perfect', 'great', 'good', 'okay', 'miss'
 */
function quaver_getJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= quaver_marvelousWindow)
		return 'marvelous';
	if (absMs <= quaver_perfectWindow)
		return 'perfect';
	if (absMs <= quaver_greatWindow)
		return 'great';
	if (absMs <= quaver_goodWindow)
		return 'good';
	return 'okay';
}

// ========================================
// SCORING ALGORITHM
// ========================================

/**
 * Processes a note hit and updates Quaver score and accuracy.
 *
 * Quaver scoring:
 *   Accuracy = sum(Vj * Nj) / (100 * N)
 *   Score = 1,000,000 × Accuracy
 *
 *   Marvelous, Perfect, Great, Good maintain combo.
 *   Okay breaks combo.
 *
 * Judgement weights:
 *   Marvelous = 100
 *   Perfect   = 98.25
 *   Great     = 65
 *   Good      = 25
 *   Okay      = -100
 *   Miss      = -50
 *
 * @param offsetMs Timing offset in milliseconds
 */
function processHit(offsetMs:Float) {
	var judgement = quaver_getJudgement(offsetMs);

	var weight = 0.0;

	if (judgement == 'marvelous') {
		weight = quaver_marvelousWeight;
		quaver_combo = quaver_combo + 1;
		quaver_marvelousHits = quaver_marvelousHits + 1;
		setVar('quaver_marvelousHits', quaver_marvelousHits);
	} else if (judgement == 'perfect') {
		weight = quaver_perfectWeight;
		quaver_combo = quaver_combo + 1;
		quaver_perfectHits = quaver_perfectHits + 1;
		setVar('quaver_perfectHits', quaver_perfectHits);
	} else if (judgement == 'great') {
		weight = quaver_greatWeight;
		quaver_combo = quaver_combo + 1;
		quaver_greatHits = quaver_greatHits + 1;
		setVar('quaver_greatHits', quaver_greatHits);
	} else if (judgement == 'good') {
		weight = quaver_goodWeight;
		quaver_combo = quaver_combo + 1;
		quaver_goodHits = quaver_goodHits + 1;
		setVar('quaver_goodHits', quaver_goodHits);
	} else {
		// Okay - combo breaks
		weight = quaver_okayWeight;
		quaver_combo = 0;
		quaver_okayHits = quaver_okayHits + 1;
		setVar('quaver_okayHits', quaver_okayHits);
	}

	// Track max combo
	if (quaver_combo > quaver_maxCombo)
		quaver_maxCombo = quaver_combo;

	// Update accuracy tracking
	quaver_weightedSum = quaver_weightedSum + weight;
	quaver_totalNotes = quaver_totalNotes + 1;

	debug('Hit: '
		+ judgement
		+ ' ('
		+ Math.round(offsetMs * 100) / 100
		+ 'ms) | Combo: '
		+ quaver_combo
		+ ' | Score: '
		+ quaver_getScore());
}

/**
 * Processes a miss. Resets combo and adds miss weight to accuracy.
 */
function processMiss() {
	quaver_combo = 0;
	quaver_totalNotes = quaver_totalNotes + 1;
	quaver_weightedSum = quaver_weightedSum + quaver_missWeight;

	debug('MISS! | Combo: 0 | Score: ' + quaver_getScore());
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Enables or disables the Quaver scoring system
 * @param enabled Whether to enable Quaver scoring
 */
function quaver_setEnabled(enabled:Bool) {
	quaver_enabled = enabled;
	setVar('quaver_enabled', quaver_enabled);
	debug('Quaver scoring ' + (enabled ? 'enabled' : 'disabled'));
}

/**
 * Returns the current Quaver accuracy as a percentage.
 * Accuracy = sum(Vj * Nj) / (100 * N) × 100
 * @return Accuracy percentage (0-100)
 */
function quaver_getAccuracy():Float {
	if (quaver_totalNotes <= 0)
		return 0.0;
	var percent = (quaver_weightedSum / (100.0 * quaver_totalNotes)) * 100.0;
	if (percent < 0.0)
		percent = 0.0;
	if (percent > 100.0)
		percent = 100.0;
	return percent;
}

/**
 * Returns the current Quaver score.
 * Score = 1,000,000 × Accuracy (as decimal 0-1)
 * @return Total song score (0 - 1,000,000)
 */
function quaver_getScore():Int {
	if (quaver_totalNotes <= 0)
		return 0;
	var accuracy = quaver_weightedSum / (100.0 * quaver_totalNotes);
	return Math.round(accuracy * 1000000);
}

/**
 * Returns the current Quaver combo.
 * @return Current combo count
 */
function quaver_getCombo():Int {
	return quaver_combo;
}

/**
 * Gets letter grade for a given percentage.
 * Uses Quaver grade thresholds.
 * @param percent Quaver percentage (0-100)
 * @return Letter grade string
 */
function quaver_getGrade(percent:Float):String {
	if (percent >= 100.0)
		return 'X';
	if (percent >= 99.0)
		return 'SS';
	if (percent >= 95.0)
		return 'S';
	if (percent >= 90.0)
		return 'A';
	if (percent >= 80.0)
		return 'B';
	if (percent >= 70.0)
		return 'C';
	return 'D';
}

/**
 * Gets the FC (Full Combo) tier based on judgement counts and misses.
 *   PFC  = Perfect Full Combo (all Marvelous, no misses)
 *   FC   = Full Combo (no Good/Miss)
 *   SDCB = <10 combo breaks (Single Digit Combo Break)
 *   Clear = 10+ combo breaks
 *
 * @return FC tier string
 */
function quaver_getRatingFC():String {
	var misses = game.songMisses;
	var comboBreaks = misses + quaver_okayHits; // Okay and Miss both break combo

	if (comboBreaks > 0) {
		if (comboBreaks < 10)
			return 'SDCB';
		return 'Clear';
	}

	if (quaver_perfectHits == 0 && quaver_greatHits == 0 && quaver_goodHits == 0 && quaver_okayHits == 0)
		return 'PFC'; // All Marvelous

	return 'FC'; // No Okay or Miss
}

/**
 * Returns the total number of Marvelous hits.
 * @return Count of Marvelous judgements (<=18ms)
 */
function quaver_getMarvelousHits():Int {
	return quaver_marvelousHits;
}

/**
 * Returns the total number of Perfect hits.
 * @return Count of Perfect judgements (<=43ms)
 */
function quaver_getPerfectHits():Int {
	return quaver_perfectHits;
}

/**
 * Returns the total number of Great hits.
 * @return Count of Great judgements (<=76ms)
 */
function quaver_getGreatHits():Int {
	return quaver_greatHits;
}

/**
 * Returns the total number of Good hits.
 * @return Count of Good judgements (<=106ms)
 */
function quaver_getGoodHits():Int {
	return quaver_goodHits;
}

/**
 * Returns the total number of Okay hits.
 * @return Count of Okay judgements (<=127ms)
 */
function quaver_getOkayHits():Int {
	return quaver_okayHits;
}

/**
 * Returns the total number of misses.
 * @return Count of missed notes
 */
function quaver_getMissHits():Int {
	return game.songMisses;
}

/**
 * Returns the total number of notes judged so far.
 * @return Total note count (hits + misses)
 */
function quaver_getTotalNotes():Int {
	return quaver_totalNotes;
}

/**
 * Formats percentage to 2 decimal places.
 * @param value Percentage value
 * @return Formatted string
 */
function quaver_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

/**
 * Resets all scoring state to initial values.
 */
function quaver_resetScoring() {
	quaver_combo = 0;
	quaver_maxCombo = 0;
	quaver_weightedSum = 0.0;
	quaver_totalNotes = 0;
	quaver_marvelousHits = 0;
	quaver_perfectHits = 0;
	quaver_greatHits = 0;
	quaver_goodHits = 0;
	quaver_okayHits = 0;
	debug('Quaver scoring reset');

	if (quaver_replaceScoreText)
		quaver_updateScoreText();
}

/**
 * Enables or disables score text replacement.
 * @param replace Whether to replace Psych Engine's default score text
 */
function quaver_setReplaceScoreText(replace:Bool) {
	quaver_replaceScoreText = replace;
	setVar('quaver_replaceScoreText', quaver_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

/**
 * Returns whether score text replacement is enabled.
 * @return Current state of score text replacement
 */
function quaver_getReplaceScoreText():Bool {
	return quaver_replaceScoreText;
}

/**
 * Sets the score text format style.
 * @param kadeStyle If true, uses Kade Engine format; if false, uses Psych Engine format
 */
function quaver_setKadeEngineStyle(kadeStyle:Bool) {
	quaver_kadeEngineStyle = kadeStyle;
	setVar('quaver_kadeEngineStyle', quaver_kadeEngineStyle);
	debug('Kade Engine style score text ' + (kadeStyle ? 'enabled' : 'disabled'));
}

/**
 * Returns the current score text format style.
 * @return True if using Kade Engine style, false if using Psych Engine style
 */
function quaver_getKadeEngineStyle():Bool {
	return quaver_kadeEngineStyle;
}

// ========================================
// SCORE TEXT
// ========================================

/**
 * Updates the score text with Quaver scoring information.
 * Format: Score: X | Misses: Y | Rating: GRADE (ACC%) - FC
 */
function quaver_updateScoreText() {
	if (!quaver_enabled || !quaver_replaceScoreText)
		return;

	var score = quaver_getScore();
	var misses = game.songMisses;
	var hasHitNotes = (quaver_totalNotes > 0);

	var scoreText = '';

	if (hasHitNotes) {
		var accuracy = quaver_getAccuracy();
		var formattedPercent = quaver_formatPercent(accuracy);
		var grade = quaver_getGrade(accuracy);
		var ratingFC = quaver_getRatingFC();

		scoreText = quaver_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ' + formattedPercent + ' % | (' + ratingFC
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
		scoreText = quaver_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ?' : 'Score: '
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
 * Registers all Quaver scoring functions as global callbacks.
 * Makes these functions accessible from other scripts via setVar() and createGlobalCallback().
 */
function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['quaver_getAccuracy', quaver_getAccuracy],
		['quaver_getScore', quaver_getScore],
		['quaver_getGrade', quaver_getGrade],
		['quaver_getCombo', quaver_getCombo],
		['quaver_getMarvelousHits', quaver_getMarvelousHits],
		['quaver_getPerfectHits', quaver_getPerfectHits],
		['quaver_getGreatHits', quaver_getGreatHits],
		['quaver_getGoodHits', quaver_getGoodHits],
		['quaver_getOkayHits', quaver_getOkayHits],
		['quaver_getMissHits', quaver_getMissHits],
		['quaver_getTotalNotes', quaver_getTotalNotes],
		['quaver_formatPercent', quaver_formatPercent],
		['quaver_getRatingFC', quaver_getRatingFC],
		['quaver_getHitWindow', quaver_getHitWindow],
		['quaver_getJudgement', quaver_getJudgement],
		['quaver_setEnabled', quaver_setEnabled],
		['quaver_resetScoring', quaver_resetScoring],
		['quaver_setReplaceScoreText', quaver_setReplaceScoreText],
		['quaver_getReplaceScoreText', quaver_getReplaceScoreText],
		['quaver_updateScoreText', quaver_updateScoreText],
		['quaver_setKadeEngineStyle', quaver_setKadeEngineStyle],
		['quaver_getKadeEngineStyle', quaver_getKadeEngineStyle]
	];

	for (callback in callbacks) {
		createGlobalCallback(callback[0], callback[1]);
		setVar(callback[0], callback[1]);
	}
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	loadSettings();
	registerCallbacks();

	debug('Quaver functions registered - accessible from other scripts');
	debug('Quaver Scoring System Initialized');
}

function onCreatePost() {
	quaver_resetScoring();

	// Override Psych Engine's safe zone to match Quaver's miss window
	// Psych default is ~166.67ms (10 safeFrames / 60 * 1000)
	// Without this, presets with wider windows (Peaceful=218ms, Lenient=198ms, etc.)
	// would have notes auto-missed by Psych before Quaver can judge them
	if (quaver_isActiveSystem) {
		var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
		Conductor.safeZoneOffset = quaver_missWindow * playbackRate;
		debug('Overrode safeZoneOffset to ' + Conductor.safeZoneOffset + 'ms (missWindow=' + quaver_missWindow + 'ms)');
	}

	debug('Quaver scoring ready');
}

function preUpdateScore(miss:Bool) {
	if (quaver_isActiveSystem && quaver_replaceScoreText) {
		if (!miss)
			game.doScoreBop();
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (quaver_isActiveSystem && quaver_replaceScoreText)
		quaver_updateScoreText();
}

function goodNoteHit(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;
	if (!quaver_enabled)
		return;

	// Calculate timing offset
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;
	var offsetMs = Math.abs(noteDiff);

	// Process the hit
	processHit(offsetMs);

	if (quaver_replaceScoreText)
		quaver_updateScoreText();
}

function noteMiss(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;
	if (!quaver_enabled)
		return;

	// Process the miss
	processMiss();

	if (quaver_replaceScoreText)
		quaver_updateScoreText();
}

function onDestroy() {
	// Cleanup handled by other scripts
}
