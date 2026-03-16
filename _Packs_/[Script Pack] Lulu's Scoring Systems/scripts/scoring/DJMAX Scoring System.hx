/*
	>>> DJMAX Scoring System for Psych Engine
		HScript-based scoring system that implements DJMAX RESPECT V's judgement and scoring system.
		This replaces Psych Engine's default scoring system.
		Can be used with Custom HUDs in Lua/HScript by using the provided global callbacks.

		Features:
			- DJMAX judgement windows: MAX100% (±16ms), MAX90% (±33ms), GOOD (±66ms), BAD (±100ms), MISS/BREAK (>100ms)
			- Accuracy-weighted scoring: MAX100%=1.0, MAX90%=0.9, GOOD=0.5, BAD=0.1, MISS=0
			- Score = 1,000,000 × Accuracy (normalized to total notes)
			- DJMAX-style grade thresholds: S (97%+), A (90%+), B (80%+), C (<80%)
			- BREAK (MISS) and BAD break combo
			- *Optional* Kade Engine style score text formatting
			- Settings.json support (when using "Lulu's Scoring Systems" pack)
				- Configure settings through the mod settings menu
				- Settings from settings.json will override the default values in the script

		DJMAX RESPECT V Judgement System (PC version):
			The PC version uses unified timing windows regardless of BPM (~2.5 frames).
			MAX percentage is continuous (100% down to 1%), but for gameplay purposes
			we use simplified tiers: MAX 100%, MAX 90%, GOOD, BAD, BREAK.

			- MAX 100%: Perfect timing. Combo continues.
			- MAX 90%:  Slightly off timing. Combo continues.
			- GOOD:     Noticeably off timing. Combo breaks.
			- BAD:      Greatly off timing. Combo breaks.
			- BREAK:    Complete miss. Combo breaks.

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
*/

// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var djmax_enabled = true;
var djmax_isActiveSystem = false;
var djmax_debug = false;
var djmax_replaceScoreText = true;
var djmax_kadeEngineStyle = false;

// --- Timing Windows (PC version - fixed, BPM-independent) ---
var djmax_max100Window = 16.0;
var djmax_max90Window = 33.0;
var djmax_goodWindow = 66.0;
var djmax_badWindow = 100.0;

// --- Judgement Weights (Do Not Modify) ---
var djmax_max100Weight = 1.0;
var djmax_max90Weight = 0.9;
var djmax_goodWeight = 0.5;
var djmax_badWeight = 0.1;

// --- Score State (Do Not Modify) ---
var djmax_combo = 0;
var djmax_maxCombo = 0;

// --- Accuracy Tracking (Do Not Modify) ---
var djmax_weightedSum = 0.0;
var djmax_totalNotes = 0;

// --- Judgement Tracking (Do Not Modify) ---
var djmax_max100Hits = 0;
var djmax_max90Hits = 0;
var djmax_goodHits = 0;
var djmax_badHits = 0;

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
		djmax_isActiveSystem = (value == 'DJMAX');
		djmax_enabled = djmax_isActiveSystem;
	}

	if (!djmax_enabled) {
		var cmpEnabled:Dynamic = getModSetting('scoring_showComparison');
		var cmpShow:Dynamic = getModSetting('cmp_showDJMAX');
		if (cmpEnabled == true && cmpShow == true)
			djmax_enabled = true;
	}

	if (!djmax_enabled)
		return;

	trace('[DJMAX] settings.json found, loading settings...');

	if ((value = getModSetting('scoring_debug')) != null)
		djmax_debug = value;

	if ((value = getModSetting('scoring_replaceScoreText')) != null)
		djmax_replaceScoreText = value;

	if ((value = getModSetting('scoring_kadeEngineStyle')) != null)
		djmax_kadeEngineStyle = value;
}

// ========================================
// DEBUG HELPER
// ========================================

/**
 * Helper function to print debug messages only when djmax_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!djmax_debug || !djmax_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[DJMAX] ' + message, color);
}

// ========================================
// HIT WINDOW FUNCTIONS
// ========================================

/**
 * Gets the hit window (in ms) for a judgement.
 *
 * DJMAX RESPECT V timing windows (PC version, fixed):
 *   MAX 100%: ±16ms
 *   MAX 90%:  ±33ms
 *   GOOD:     ±66ms
 *   BAD:      ±100ms
 *
 * @param judgement Judgement name: 'max100', 'max90', 'good', 'bad'
 * @return Hit window in milliseconds
 */
function djmax_getHitWindow(judgement:String):Float {
	switch (judgement.toLowerCase()) {
		case 'max100':
			return djmax_max100Window;
		case 'max90':
			return djmax_max90Window;
		case 'good':
			return djmax_goodWindow;
		case 'bad':
			return djmax_badWindow;
		default:
			return djmax_badWindow;
	}
}

/**
 * Determines the DJMAX judgement for a given timing offset.
 * @param offsetMs Timing offset in milliseconds (absolute value used for judgement)
 * @return Judgement string: 'max100', 'max90', 'good', 'bad', 'break'
 */
function djmax_getJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= djmax_max100Window)
		return 'max100';
	if (absMs <= djmax_max90Window)
		return 'max90';
	if (absMs <= djmax_goodWindow)
		return 'good';
	if (absMs <= djmax_badWindow)
		return 'bad';
	return 'break';
}

// ========================================
// SCORING ALGORITHM
// ========================================

/**
 * Processes a note hit and updates DJMAX score and accuracy.
 *
 * DJMAX RESPECT V scoring:
 *   Score = 1,000,000 × (weighted_sum / total_notes)
 *   Only MAX 100% and MAX 90% maintain combo.
 *   GOOD and BAD break combo.
 *
 * Accuracy weights:
 *   MAX 100% = 1.00
 *   MAX 90%  = 0.90
 *   GOOD     = 0.50
 *   BAD      = 0.10
 *   BREAK    = 0.00
 *
 * @param offsetMs Absolute timing offset in milliseconds
 */
function processHit(offsetMs:Float) {
	var weight:Float;
	var judgement:String;

	if (offsetMs <= djmax_max100Window) {
		weight = djmax_max100Weight;
		judgement = 'max100';
		djmax_combo = djmax_combo + 1;
		djmax_max100Hits = djmax_max100Hits + 1;
		setVar('djmax_max100Hits', djmax_max100Hits);

	} else if (offsetMs <= djmax_max90Window) {
		weight = djmax_max90Weight;
		judgement = 'max90';
		djmax_combo = djmax_combo + 1;
		djmax_max90Hits = djmax_max90Hits + 1;
		setVar('djmax_max90Hits', djmax_max90Hits);

	} else if (offsetMs <= djmax_goodWindow) {
		weight = djmax_goodWeight;
		judgement = 'good';
		djmax_combo = 0;
		djmax_goodHits = djmax_goodHits + 1;
		setVar('djmax_goodHits', djmax_goodHits);

	} else {
		weight = djmax_badWeight;
		judgement = 'bad';
		djmax_combo = 0;
		djmax_badHits = djmax_badHits + 1;
		setVar('djmax_badHits', djmax_badHits);
	}

	if (djmax_combo > djmax_maxCombo)
		djmax_maxCombo = djmax_combo;

	djmax_weightedSum = djmax_weightedSum + weight;
	djmax_totalNotes = djmax_totalNotes + 1;

	debug('Hit: '
		+ judgement
		+ ' ('
		+ Math.round(offsetMs * 100) / 100
		+ 'ms) | Combo: '
		+ djmax_combo
		+ ' | Score: '
		+ djmax_getScore());
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Overrides Conductor.safeZoneOffset to match DJMAX's bad window.
 * Uses djmax_badWindow * playbackRate.
 */
function djmax_applySafeZone() {
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	Conductor.safeZoneOffset = djmax_badWindow * playbackRate;
	debug('Overrode safeZoneOffset to ' + Conductor.safeZoneOffset + 'ms (badWindow=' + djmax_badWindow + 'ms)');
}

/**
 * Enables or disables the DJMAX scoring system
 * @param enabled Whether to enable DJMAX scoring
 */
function djmax_setEnabled(enabled:Bool) {
	djmax_enabled = enabled;
	setVar('djmax_enabled', djmax_enabled);
	debug('DJMAX scoring ' + (enabled ? 'enabled' : 'disabled'));
}

/**
 * Returns the current DJMAX accuracy as a percentage.
 * Accuracy = weighted_sum / total_notes × 100
 * @return Accuracy percentage (0-100)
 */
function djmax_getAccuracy():Float {
	if (djmax_totalNotes <= 0)
		return 0.0;
	var percent = (djmax_weightedSum / djmax_totalNotes) * 100.0;
	if (percent < 0.0)
		percent = 0.0;
	if (percent > 100.0)
		percent = 100.0;
	return percent;
}

/**
 * Returns the current DJMAX score.
 * Score = 1,000,000 × Accuracy (as decimal 0-1)
 * @return Total song score (0 - 1,000,000)
 */
function djmax_getScore():Int {
	if (djmax_totalNotes <= 0)
		return 0;
	var accuracy = djmax_weightedSum / djmax_totalNotes;
	return Math.round(accuracy * 1000000);
}

/**
 * Returns the current DJMAX combo.
 * @return Current combo count
 */
function djmax_getCombo():Int {
	return djmax_combo;
}

/**
 * Gets letter grade for a given percentage.
 * Uses DJMAX RESPECT V grade thresholds.
 * @param percent DJMAX percentage (0-100)
 * @return Letter grade string
 */
function djmax_getGrade(percent:Float):String {
	if (percent >= 97.0)
		return 'S';
	if (percent >= 90.0)
		return 'A';
	if (percent >= 80.0)
		return 'B';
	return 'C';
}

/**
 * Gets the FC (Full Combo) tier based on judgement counts and misses.
 *   PP   = Perfect Play (all MAX 100%, no misses)
 *   FC   = Full Combo (MAX 100% + MAX 90% only, no GOOD/BAD/BREAK)
 *   SDCB = <10 combo breaks (Single Digit Combo Break)
 *   Clear = 10+ combo breaks
 *
 * @return FC tier string
 */
function djmax_getRatingFC():String {
	var misses = game.songMisses;
	var comboBreaks = misses + djmax_goodHits + djmax_badHits; // GOOD, BAD, and BREAK all break combo

	if (comboBreaks > 0) {
		if (comboBreaks < 10)
			return 'SDCB';
		return 'Clear';
	}

	if (djmax_max90Hits == 0)
		return 'PP'; // Perfect Play - all MAX 100%

	return 'FC'; // Full Combo (MAX 100% + MAX 90% only)
}

/**
 * Returns the total number of MAX 100% hits.
 * @return Count of MAX 100% judgements (<=16ms)
 */
function djmax_getMax100Hits():Int {
	return djmax_max100Hits;
}

/**
 * Returns the total number of MAX 90% hits.
 * @return Count of MAX 90% judgements (<=33ms)
 */
function djmax_getMax90Hits():Int {
	return djmax_max90Hits;
}

/**
 * Returns the total number of GOOD hits.
 * @return Count of GOOD judgements (<=66ms)
 */
function djmax_getGoodHits():Int {
	return djmax_goodHits;
}

/**
 * Returns the total number of BAD hits.
 * @return Count of BAD judgements (<=100ms)
 */
function djmax_getBadHits():Int {
	return djmax_badHits;
}

/**
 * Returns the total number of notes judged so far.
 * @return Total note count (hits + misses)
 */
function djmax_getTotalNotes():Int {
	return djmax_totalNotes;
}

/**
 * Formats percentage to 2 decimal places.
 * @param value Percentage value
 * @return Formatted string
 */
function djmax_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

/**
 * Resets all scoring state to initial values.
 */
function djmax_resetScoring() {
	djmax_combo = 0;
	djmax_maxCombo = 0;
	djmax_weightedSum = 0.0;
	djmax_totalNotes = 0;
	djmax_max100Hits = 0;
	djmax_max90Hits = 0;
	djmax_goodHits = 0;
	djmax_badHits = 0;
	debug('DJMAX scoring reset');

	if (djmax_replaceScoreText)
		djmax_updateScoreText();
}

/**
 * Enables or disables score text replacement.
 * @param replace Whether to replace Psych Engine's default score text
 */
function djmax_setReplaceScoreText(replace:Bool) {
	djmax_replaceScoreText = replace;
	setVar('djmax_replaceScoreText', djmax_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

/**
 * Returns whether score text replacement is enabled.
 * @return Current state of score text replacement
 */
function djmax_getReplaceScoreText():Bool {
	return djmax_replaceScoreText;
}

/**
 * Sets the score text format style.
 * @param kadeStyle If true, uses Kade Engine format; if false, uses Psych Engine format
 */
function djmax_setKadeEngineStyle(kadeStyle:Bool) {
	djmax_kadeEngineStyle = kadeStyle;
	setVar('djmax_kadeEngineStyle', djmax_kadeEngineStyle);
	debug('Kade Engine style score text ' + (kadeStyle ? 'enabled' : 'disabled'));
}

/**
 * Returns the current score text format style.
 * @return True if using Kade Engine style, false if using Psych Engine style
 */
function djmax_getKadeEngineStyle():Bool {
	return djmax_kadeEngineStyle;
}

function processMiss() {
	djmax_combo = 0;
	djmax_totalNotes = djmax_totalNotes + 1;
}

function processNote(note:Note) {
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	var offsetMs = Math.abs(noteDiff / playbackRate);

	processHit(offsetMs);

	if (djmax_replaceScoreText)
		djmax_updateScoreText();
}

// ========================================
// SCORE TEXT
// ========================================

/**
 * Updates the score text with DJMAX scoring information.
 * Format: Score: X | Misses: Y | Rating: GRADE (ACC%) - FC
 */
function djmax_updateScoreText() {
	if (!djmax_enabled || !djmax_replaceScoreText)
		return;

	var score = djmax_getScore();
	var misses = game.songMisses;
	var prefix = djmax_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses : 'Score: ' + score + ' | Misses: ' + misses;

	if (djmax_totalNotes <= 0) {
		game.scoreTxt.text = prefix + (djmax_kadeEngineStyle ? ' | Accuracy: ?' : ' | Rating: ?');
		return;
	}

	var accuracy = djmax_getAccuracy();
	var percent = djmax_formatPercent(accuracy);
	var grade = djmax_getGrade(accuracy);
	var fc = djmax_getRatingFC();

	game.scoreTxt.text = djmax_kadeEngineStyle ? prefix + ' | Accuracy: ' + percent + ' % | (' + fc + ') ' + grade : prefix
		+ ' | Rating: '
		+ grade
		+ ' ('
		+ percent
		+ '%) - '
		+ fc;
}

// ========================================
// CALLBACK REGISTRATION
// ========================================

/**
 * Registers all DJMAX scoring functions as global callbacks.
 * Makes these functions accessible from other scripts via setVar() and createGlobalCallback().
 */
function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['djmax_getAccuracy', djmax_getAccuracy],
		['djmax_getScore', djmax_getScore],
		['djmax_getGrade', djmax_getGrade],
		['djmax_getCombo', djmax_getCombo],
		['djmax_getMax100Hits', djmax_getMax100Hits],
		['djmax_getMax90Hits', djmax_getMax90Hits],
		['djmax_getGoodHits', djmax_getGoodHits],
		['djmax_getBadHits', djmax_getBadHits],
		['djmax_getTotalNotes', djmax_getTotalNotes],
		['djmax_formatPercent', djmax_formatPercent],
		['djmax_getRatingFC', djmax_getRatingFC],
		['djmax_getHitWindow', djmax_getHitWindow],
		['djmax_getJudgement', djmax_getJudgement],
		['djmax_setEnabled', djmax_setEnabled],
		['djmax_resetScoring', djmax_resetScoring],
		['djmax_setReplaceScoreText', djmax_setReplaceScoreText],
		['djmax_getReplaceScoreText', djmax_getReplaceScoreText],
		['djmax_updateScoreText', djmax_updateScoreText],
		['djmax_setKadeEngineStyle', djmax_setKadeEngineStyle],
		['djmax_getKadeEngineStyle', djmax_getKadeEngineStyle]
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

	debug('DJMAX functions registered - accessible from other scripts');
	debug('DJMAX Scoring System Initialized (PC version - fixed windows)');
}

function onCreatePost() {
	djmax_resetScoring();
	debug('DJMAX scoring ready');

	if (djmax_isActiveSystem)
		djmax_applySafeZone();
}

function preUpdateScore(miss:Bool) {
	if (djmax_isActiveSystem && djmax_replaceScoreText) {
		if (!miss)
			game.doScoreBop();
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (djmax_isActiveSystem && djmax_replaceScoreText)
		djmax_updateScoreText();
}

function goodNoteHit(note:Note) {
	if (note.isSustainNote || !note.mustPress || !djmax_enabled)
		return;

	processNote(note);
}

function noteMiss(note:Note) {
	if (note.isSustainNote || !note.mustPress || !djmax_enabled)
		return;

	processMiss();

	debug('BREAK! | Combo: 0 | Score: ' + djmax_getScore());

	if (djmax_replaceScoreText)
		djmax_updateScoreText();
}

function onDestroy() {}
