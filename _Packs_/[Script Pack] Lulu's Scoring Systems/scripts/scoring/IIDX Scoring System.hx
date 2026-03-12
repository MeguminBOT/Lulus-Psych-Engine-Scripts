/*
	>>> Beatmania IIDX EX Score System for Psych Engine
		HScript-based scoring system that implements beatmania IIDX's EX Score system.
		This replaces Psych Engine's default scoring system.
		Can be used with Custom HUDs in Lua/HScript by using the provided global callbacks.

		Features:
			- IIDX judgement windows (PC normalized): PGREAT (±16.67ms), GREAT (±33.33ms), GOOD (±100ms), BAD (±180ms), POOR (miss)
			- EX Score: 2 per PGREAT, 1 per GREAT, 0 for GOOD/BAD/POOR
			- EX Rate = EX Score / (2 × total notes) × 100
			- IIDX grade thresholds: AAA (8/9), AA (7/9), A (6/9), B (5/9), C (4/9), D (3/9), E (2/9), F (<2/9)
			- PGREAT, GREAT, and GOOD maintain combo; BAD and POOR break combo
			- *Optional* Kade Engine style score text formatting
			- Settings.json support (when using "Lulu's Scoring Systems" pack)
				- Configure settings through the mod settings menu
				- Settings from settings.json will override the default values in the script

		Beatmania IIDX Judgement System (PC normalized):
			Timing windows derived from arcade frame timings converted to milliseconds.
			PGREAT = 1 frame at 60fps = ±16.67ms
			GREAT  = 2 frames at 60fps = ±33.33ms
			GOOD   = ±100ms
			BAD    = ±180ms
			POOR   = Beyond BAD window or complete miss

			- PGREAT: Perfect timing. +2 EX. Combo continues.
			- GREAT:  Slightly off. +1 EX. Combo continues.
			- GOOD:   Noticeably off. +0 EX. Combo continues.
			- BAD:    Greatly off. +0 EX. Combo breaks.
			- POOR:   Complete miss. +0 EX. Combo breaks.

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var iidx_enabled = true;
var iidx_isActiveSystem = false;
var iidx_debug = false;
var iidx_replaceScoreText = true;
var iidx_kadeEngineStyle = false;

// --- Timing Windows (PC normalized - fixed) ---
var iidx_pgreatWindow = 16.67; // PGREAT: ±16.67ms (1 frame @ 60fps)
var iidx_greatWindow = 33.33; // GREAT:  ±33.33ms (2 frames @ 60fps)
var iidx_goodWindow = 100.0; // GOOD:   ±100ms
var iidx_badWindow = 180.0; // BAD:    ±180ms (beyond = POOR/miss)
// --- Score State (Do Not Modify) ---
var iidx_combo = 0;
var iidx_maxCombo = 0;

// --- EX Score Tracking (Do Not Modify) ---
var iidx_exScore = 0;
var iidx_totalNotes = 0;

// --- Judgement Tracking (Do Not Modify) ---
var iidx_pgreatHits = 0;
var iidx_greatHits = 0;
var iidx_goodHits = 0;
var iidx_badHits = 0;

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
		iidx_isActiveSystem = (value == 'IIDX');
		iidx_enabled = iidx_isActiveSystem;
	}

	if (!iidx_enabled) {
		var cmpEnabled:Dynamic = getModSetting('scoring_showComparison');
		var cmpShow:Dynamic = getModSetting('cmp_showIIDX');
		if (cmpEnabled == true && cmpShow == true)
			iidx_enabled = true;
	}

	if (!iidx_enabled)
		return;

	trace('[IIDX] settings.json found, loading settings...');

	if ((value = getModSetting('scoring_debug')) != null)
		iidx_debug = value;

	if ((value = getModSetting('scoring_replaceScoreText')) != null)
		iidx_replaceScoreText = value;

	if ((value = getModSetting('scoring_kadeEngineStyle')) != null)
		iidx_kadeEngineStyle = value;
}

// ========================================
// DEBUG HELPER
// ========================================

/**
 * Helper function to print debug messages only when iidx_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!iidx_debug || !iidx_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[IIDX] ' + message, color);
}

// ========================================
// HIT WINDOW FUNCTIONS
// ========================================

/**
 * Gets the hit window (in ms) for a judgement.
 *
 * Beatmania IIDX timing windows (PC normalized):
 *   PGREAT: ±16.67ms
 *   GREAT:  ±33.33ms
 *   GOOD:   ±100ms
 *   BAD:    ±180ms
 *
 * @param judgement Judgement name: 'pgreat', 'great', 'good', 'bad'
 * @return Hit window in milliseconds
 */
function iidx_getHitWindow(judgement:String):Float {
	switch (judgement.toLowerCase()) {
		case 'pgreat':
			return iidx_pgreatWindow;
		case 'great':
			return iidx_greatWindow;
		case 'good':
			return iidx_goodWindow;
		case 'bad':
			return iidx_badWindow;
		default:
			return 0.0;
	}
}

/**
 * Determines the IIDX judgement for a given timing offset.
 * @param offsetMs Timing offset in milliseconds (absolute value used for judgement)
 * @return Judgement string: 'pgreat', 'great', 'good', 'bad', 'poor'
 */
function iidx_getJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= iidx_pgreatWindow)
		return 'pgreat';
	if (absMs <= iidx_greatWindow)
		return 'great';
	if (absMs <= iidx_goodWindow)
		return 'good';
	if (absMs <= iidx_badWindow)
		return 'bad';
	return 'poor';
}

// ========================================
// SCORING ALGORITHM
// ========================================

/**
 * Processes a note hit and updates IIDX EX Score.
 *
 * Beatmania IIDX EX Score:
 *   EX Score = 2 × PGREAT + 1 × GREAT
 *   PGREAT, GREAT, GOOD maintain combo.
 *   BAD breaks combo.
 *
 * @param offsetMs Timing offset in milliseconds
 */
function processHit(offsetMs:Float) {
	var judgement = iidx_getJudgement(offsetMs);

	if (judgement == 'pgreat') {
		iidx_exScore = iidx_exScore + 2;
		iidx_combo = iidx_combo + 1;
		iidx_pgreatHits = iidx_pgreatHits + 1;
		setVar('iidx_pgreatHits', iidx_pgreatHits);
	} else if (judgement == 'great') {
		iidx_exScore = iidx_exScore + 1;
		iidx_combo = iidx_combo + 1;
		iidx_greatHits = iidx_greatHits + 1;
		setVar('iidx_greatHits', iidx_greatHits);
	} else if (judgement == 'good') {
		// GOOD: +0 EX, combo continues
		iidx_combo = iidx_combo + 1;
		iidx_goodHits = iidx_goodHits + 1;
		setVar('iidx_goodHits', iidx_goodHits);
	} else {
		// BAD: +0 EX, combo breaks
		iidx_combo = 0;
		iidx_badHits = iidx_badHits + 1;
		setVar('iidx_badHits', iidx_badHits);
	}

	// Track max combo
	if (iidx_combo > iidx_maxCombo)
		iidx_maxCombo = iidx_combo;

	// Update total notes
	iidx_totalNotes = iidx_totalNotes + 1;

	debug('Hit: ' + judgement + ' (' + Math.round(offsetMs * 100) / 100 + 'ms) | EX: ' + iidx_exScore + '/' + (iidx_totalNotes * 2) + ' | Combo: ' +
		iidx_combo);
}

/**
 * Processes a POOR (complete miss). Resets combo and adds 0 to EX Score.
 */
function processMiss() {
	iidx_combo = 0;
	iidx_totalNotes = iidx_totalNotes + 1;
	// EX += 0 (POOR gives nothing)

	debug('POOR! | Combo: 0 | EX: ' + iidx_exScore + '/' + (iidx_totalNotes * 2));
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Enables or disables the IIDX scoring system
 * @param enabled Whether to enable IIDX scoring
 */
function iidx_setEnabled(enabled:Bool) {
	iidx_enabled = enabled;
	setVar('iidx_enabled', iidx_enabled);
	debug('IIDX scoring ' + (enabled ? 'enabled' : 'disabled'));
}

/**
 * Returns the current IIDX EX Rate as a percentage.
 * EX Rate = EX Score / (2 × total notes) × 100
 * @return EX Rate percentage (0-100)
 */
function iidx_getAccuracy():Float {
	if (iidx_totalNotes <= 0)
		return 0.0;
	var exMax = iidx_totalNotes * 2;
	var percent = (iidx_exScore / exMax) * 100.0;
	if (percent < 0.0)
		percent = 0.0;
	if (percent > 100.0)
		percent = 100.0;
	return percent;
}

/**
 * Returns the current EX Score.
 * EX Score = 2 × PGREAT + GREAT
 * @return EX Score count
 */
function iidx_getScore():Int {
	return iidx_exScore;
}

/**
 * Returns the current IIDX combo.
 * @return Current combo count
 */
function iidx_getCombo():Int {
	return iidx_combo;
}

/**
 * Gets letter grade for a given EX Rate percentage.
 * Uses IIDX grade thresholds based on ninths.
 * @param percent EX Rate percentage (0-100)
 * @return Letter grade string
 */
function iidx_getGrade(percent:Float):String {
	if (percent >= 88.89)
		return 'AAA';
	if (percent >= 77.78)
		return 'AA';
	if (percent >= 66.67)
		return 'A';
	if (percent >= 55.56)
		return 'B';
	if (percent >= 44.44)
		return 'C';
	if (percent >= 33.33)
		return 'D';
	if (percent >= 22.22)
		return 'E';
	return 'F';
}

/**
 * Gets the FC (Full Combo) tier based on judgement counts and misses.
 *   PFC  = Perfect Full Combo (all PGREATs, no misses)
 *   FC   = Full Combo (no BADs or POORs; PGREATs + GREATs + GOODs only)
 *   SDCB = <10 combo breaks (Single Digit Combo Break)
 *   Clear = 10+ combo breaks
 *
 * @return FC tier string
 */
function iidx_getRatingFC():String {
	var misses = game.songMisses;
	var comboBreaks = misses + iidx_badHits; // BAD and POOR both break combo

	if (comboBreaks > 0) {
		if (comboBreaks < 10)
			return 'SDCB';
		return 'Clear';
	}

	// No BADs or POORs
	if (iidx_greatHits == 0 && iidx_goodHits == 0)
		return 'PFC'; // All PGREATs

	return 'FC'; // Full Combo (PGREATs + GREATs + GOODs, no BADs/POORs)
}

/**
 * Returns the total number of PGREAT hits.
 * @return Count of PGREAT judgements (<=16.67ms)
 */
function iidx_getPgreatHits():Int {
	return iidx_pgreatHits;
}

/**
 * Returns the total number of GREAT hits.
 * @return Count of GREAT judgements (<=33.33ms)
 */
function iidx_getGreatHits():Int {
	return iidx_greatHits;
}

/**
 * Returns the total number of GOOD hits.
 * @return Count of GOOD judgements (<=100ms)
 */
function iidx_getGoodHits():Int {
	return iidx_goodHits;
}

/**
 * Returns the total number of BAD hits.
 * @return Count of BAD judgements (<=180ms)
 */
function iidx_getBadHits():Int {
	return iidx_badHits;
}

/**
 * Returns the total number of notes judged so far.
 * @return Total note count (hits + misses)
 */
function iidx_getTotalNotes():Int {
	return iidx_totalNotes;
}

/**
 * Formats percentage to 2 decimal places.
 * @param value Percentage value
 * @return Formatted string
 */
function iidx_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

/**
 * Resets all scoring state to initial values.
 */
function iidx_resetScoring() {
	iidx_combo = 0;
	iidx_maxCombo = 0;
	iidx_exScore = 0;
	iidx_totalNotes = 0;
	iidx_pgreatHits = 0;
	iidx_greatHits = 0;
	iidx_goodHits = 0;
	iidx_badHits = 0;
	debug('IIDX scoring reset');

	if (iidx_replaceScoreText)
		iidx_updateScoreText();
}

/**
 * Enables or disables score text replacement.
 * @param replace Whether to replace Psych Engine's default score text
 */
function iidx_setReplaceScoreText(replace:Bool) {
	iidx_replaceScoreText = replace;
	setVar('iidx_replaceScoreText', iidx_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

/**
 * Returns whether score text replacement is enabled.
 * @return Current state of score text replacement
 */
function iidx_getReplaceScoreText():Bool {
	return iidx_replaceScoreText;
}

/**
 * Sets the score text format style.
 * @param kadeStyle If true, uses Kade Engine format; if false, uses Psych Engine format
 */
function iidx_setKadeEngineStyle(kadeStyle:Bool) {
	iidx_kadeEngineStyle = kadeStyle;
	setVar('iidx_kadeEngineStyle', iidx_kadeEngineStyle);
	debug('Kade Engine style score text ' + (kadeStyle ? 'enabled' : 'disabled'));
}

/**
 * Returns the current score text format style.
 * @return True if using Kade Engine style, false if using Psych Engine style
 */
function iidx_getKadeEngineStyle():Bool {
	return iidx_kadeEngineStyle;
}

// ========================================
// SCORE TEXT
// ========================================

/**
 * Updates the score text with IIDX EX Score information.
 * Shows EX Score as the primary metric with EX Rate as accuracy.
 */
function iidx_updateScoreText() {
	if (!iidx_enabled || !iidx_replaceScoreText)
		return;

	var misses = game.songMisses;
	var hasHitNotes = (iidx_totalNotes > 0);

	var scoreText = '';

	if (hasHitNotes) {
		var exRate = iidx_getAccuracy();
		var formattedPercent = iidx_formatPercent(exRate);
		var exMax = iidx_totalNotes * 2;
		var grade = iidx_getGrade(exRate);
		var ratingFC = iidx_getRatingFC();

		scoreText = iidx_kadeEngineStyle ? 'EX: ' + iidx_exScore + '/' + exMax + ' | Combo Breaks: ' + misses + ' | EX Rate: ' + formattedPercent + ' % | ('
			+ ratingFC + ') ' + grade : 'EX: '
			+ iidx_exScore
			+ '/'
			+ exMax
			+ ' | Misses: '
			+ misses
			+ ' | Rating: '
			+ grade
			+ ' ('
			+ formattedPercent
			+ '%) - '
			+ ratingFC;
	} else {
		scoreText = iidx_kadeEngineStyle ? 'EX: 0 | Combo Breaks: ' + misses + ' | EX Rate: ?' : 'EX: 0 | Misses: ' + misses + ' | Rating: ?';
	}

	game.scoreTxt.text = scoreText;
}

// ========================================
// CALLBACK REGISTRATION
// ========================================

/**
 * Registers all IIDX scoring functions as global callbacks.
 * Makes these functions accessible from other scripts via setVar() and createGlobalCallback().
 */
function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['iidx_getAccuracy', iidx_getAccuracy],
		['iidx_getScore', iidx_getScore],
		['iidx_getGrade', iidx_getGrade],
		['iidx_getCombo', iidx_getCombo],
		['iidx_getPgreatHits', iidx_getPgreatHits],
		['iidx_getGreatHits', iidx_getGreatHits],
		['iidx_getGoodHits', iidx_getGoodHits],
		['iidx_getBadHits', iidx_getBadHits],
		['iidx_getTotalNotes', iidx_getTotalNotes],
		['iidx_formatPercent', iidx_formatPercent],
		['iidx_getRatingFC', iidx_getRatingFC],
		['iidx_getHitWindow', iidx_getHitWindow],
		['iidx_getJudgement', iidx_getJudgement],
		['iidx_setEnabled', iidx_setEnabled],
		['iidx_resetScoring', iidx_resetScoring],
		['iidx_setReplaceScoreText', iidx_setReplaceScoreText],
		['iidx_getReplaceScoreText', iidx_getReplaceScoreText],
		['iidx_updateScoreText', iidx_updateScoreText],
		['iidx_setKadeEngineStyle', iidx_setKadeEngineStyle],
		['iidx_getKadeEngineStyle', iidx_getKadeEngineStyle]
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

	debug('IIDX functions registered - accessible from other scripts');
	debug('IIDX EX Score System Initialized (PC normalized windows)');
}

function onCreatePost() {
	iidx_resetScoring();
	debug('IIDX scoring ready');
}

function preUpdateScore(miss:Bool) {
	if (iidx_isActiveSystem && iidx_replaceScoreText) {
		if (!miss)
			game.doScoreBop();
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (iidx_isActiveSystem && iidx_replaceScoreText)
		iidx_updateScoreText();
}

function goodNoteHit(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;
	if (!iidx_enabled)
		return;

	// Calculate timing offset
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;
	var offsetMs = Math.abs(noteDiff);

	// Process the hit
	processHit(offsetMs);

	if (iidx_replaceScoreText)
		iidx_updateScoreText();
}

function noteMiss(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;
	if (!iidx_enabled)
		return;

	// Process the POOR
	processMiss();

	if (iidx_replaceScoreText)
		iidx_updateScoreText();
}

function onDestroy() {
	// Cleanup handled by other scripts
}
