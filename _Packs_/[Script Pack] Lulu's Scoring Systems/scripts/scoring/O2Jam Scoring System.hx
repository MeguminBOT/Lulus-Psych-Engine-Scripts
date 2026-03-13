/*
	>>> O2Jam Scoring System for Psych Engine
		HScript-based scoring system that implements O2Jam's judgement and scoring system.
		This replaces Psych Engine's default scoring system.
		Can be used with Custom HUDs in Lua/HScript by using the provided global callbacks.

		Features:
			- O2Jam judgement windows: COOL (±33ms), GOOD (±67ms), BAD (±100ms), MISS (>100ms)
			- Optional BPM-based timing windows (authentic O2Jam behavior):
				COOL = 7500/BPM ms, GOOD = 22500/BPM ms, BAD = 31250/BPM ms
				Windows update dynamically when BPM changes mid-song
			- Judgement-weighted accuracy: COOL=1.0, GOOD=0.7, BAD=0.4, MISS=0
			- O2Jam combo scoring: score += judgement_value × combo
			- BAD and MISS break combo (O2Jam rules)
			- *Optional* Kade Engine style score text formatting
			- Settings.json support (when using "Lulu's Feature Pack")
				- Configure settings through the mod settings menu
				- Settings from settings.json will override the default values in the script

		O2Jam Note Hit Explanation (based on hi-speed X1):
			A COOL is registered when at least 80% of the note hit the target bar.
			A GOOD is registered when at least 50% but less than 80% of the note hit the target bar.
			A BAD is registered when at least about 20% but less than 50% of the note hit the target bar.
			A MISS is registered when the note missed the target bar entirely.
			BAD and MISS both break the combo.

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var o2jam_enabled = true;
var o2jam_isActiveSystem = false;
var o2jam_debug = false;
var o2jam_replaceScoreText = true;
var o2jam_kadeEngineStyle = false; // Whether to use Kade Engine style scoreText or Psych Engine style.
var o2jam_useBPMWindows = false; // If true, timing windows scale with BPM (authentic O2Jam behavior)
// --- Timing Windows ---
// Fixed windows (used when o2jam_useBPMWindows = false)
var o2jam_fixedCoolWindow = 33.0; // COOL: ±33ms
var o2jam_fixedGoodWindow = 67.0; // GOOD: ±67ms
var o2jam_fixedBadWindow = 100.0; // BAD: ±100ms (beyond = MISS)
// Active windows (updated dynamically when using BPM mode, Do Not Modify)
var o2jam_coolWindow = 33.0;
var o2jam_goodWindow = 67.0;
var o2jam_badWindow = 100.0;

// --- Judgement Weights (Do Not Modify) ---
var o2jam_coolWeight = 1.0;
var o2jam_goodWeight = 0.7;
var o2jam_badWeight = 0.4;
var o2jam_missWeight = 0.0;

// --- Score State (Do Not Modify) ---
var o2jam_songScore = 0; // Displayed song score
var o2jam_combo = 0; // O2Jam internal combo tracker
// --- Accuracy Tracking (Do Not Modify) ---
var o2jam_weightedSum = 0.0; // Sum of judgement weights for accuracy calculation
var o2jam_totalNotes = 0; // Total notes judged (hits + misses)
// --- Judgement Tracking (Do Not Modify) ---
var o2jam_coolHits = 0; // COOL (<=33ms)
var o2jam_goodHits = 0; // GOOD (<=67ms)
var o2jam_badHits = 0; // BAD (<=100ms)

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
		o2jam_isActiveSystem = (value == 'O2Jam');
		o2jam_enabled = o2jam_isActiveSystem;
	}

	if (!o2jam_enabled) {
		var cmpEnabled:Dynamic = getModSetting('scoring_showComparison');
		var cmpShow:Dynamic = getModSetting('cmp_showO2Jam');
		if (cmpEnabled == true && cmpShow == true)
			o2jam_enabled = true;
	}

	if (!o2jam_enabled)
		return;

	trace('[O2Jam] settings.json found, loading settings...');

	if ((value = getModSetting('scoring_debug')) != null)
		o2jam_debug = value;

	if ((value = getModSetting('scoring_replaceScoreText')) != null)
		o2jam_replaceScoreText = value;

	if ((value = getModSetting('scoring_kadeEngineStyle')) != null)
		o2jam_kadeEngineStyle = value;

	if ((value = getModSetting('o2jam_useBPMWindows')) != null)
		o2jam_useBPMWindows = value;
}

// ========================================
// DEBUG HELPER
// ========================================

/**
 * Helper function to print debug messages only when o2jam_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!o2jam_debug || !o2jam_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[O2Jam] ' + message, color);
}

// ========================================
// BPM-BASED WINDOW CALCULATION
// ========================================

/**
 * Recalculates timing windows based on the current BPM.
 * Uses the authentic O2Jam tick-based formula:
 *   Tick = 60000 / BPM / 48 (minimum note placement interval)
 *   COOL = 6 ticks  = 7500 / BPM ms
 *   GOOD = 18 ticks = 22500 / BPM ms
 *   BAD  = 25 ticks = 31250 / BPM ms
 *
 * Only updates windows when o2jam_useBPMWindows is true.
 * Called automatically on song start and whenever BPM changes.
 *
 * @param bpm Current beats per minute
 */
function o2jam_updateBPMWindows(bpm:Float) {
	if (!o2jam_useBPMWindows || bpm <= 0)
		return;

	o2jam_coolWindow = 7500.0 / bpm;
	o2jam_goodWindow = 22500.0 / bpm;
	o2jam_badWindow = 31250.0 / bpm;

	debug('BPM windows updated (' + bpm + ' BPM): COOL=' + Math.round(o2jam_coolWindow * 100) / 100 + 'ms | GOOD='
		+ Math.round(o2jam_goodWindow * 100) / 100 + 'ms | BAD=' + Math.round(o2jam_badWindow * 100) / 100 + 'ms');
}

/**
 * Returns whether BPM-based windows are enabled.
 * @return True if using BPM-based windows, false if using fixed windows
 */
function o2jam_getUseBPMWindows():Bool {
	return o2jam_useBPMWindows;
}

/**
 * Enables or disables BPM-based timing windows.
 * When enabled, windows are recalculated from the current BPM.
 * When disabled, windows revert to fixed values (33/67/100ms).
 * @param useBPM Whether to use BPM-based windows
 */
function o2jam_setUseBPMWindows(useBPM:Bool) {
	o2jam_useBPMWindows = useBPM;
	setVar('o2jam_useBPMWindows', o2jam_useBPMWindows);

	if (useBPM) {
		o2jam_updateBPMWindows(Conductor.bpm);
	} else {
		o2jam_coolWindow = o2jam_fixedCoolWindow;
		o2jam_goodWindow = o2jam_fixedGoodWindow;
		o2jam_badWindow = o2jam_fixedBadWindow;
		debug('Reverted to fixed windows: COOL='
			+ o2jam_coolWindow
			+ 'ms | GOOD='
			+ o2jam_goodWindow
			+ 'ms | BAD='
			+ o2jam_badWindow
			+ 'ms');
	}
}

// ========================================
// HIT WINDOW FUNCTIONS
// ========================================

/**
 * Gets the hit window (in ms) for a judgement.
 *
 * O2Jam timing windows (fixed mode):
 *   COOL: ±33ms
 *   GOOD: ±67ms
 *   BAD:  ±100ms
 *
 * When BPM mode is enabled, windows scale with BPM:
 *   COOL = 7500/BPM ms (6 ticks)
 *   GOOD = 22500/BPM ms (18 ticks)
 *   BAD  = 31250/BPM ms (25 ticks)
 *
 * @param judgement Judgement name: 'cool', 'good', 'bad'
 * @return Hit window in milliseconds
 */
function o2jam_getHitWindow(judgement:String):Float {
	switch (judgement.toLowerCase()) {
		case 'cool':
			return o2jam_coolWindow;
		case 'good':
			return o2jam_goodWindow;
		case 'bad':
			return o2jam_badWindow;
		default:
			return 0.0;
	}
}

/**
 * Determines the O2Jam judgement for a given timing offset.
 * @param offsetMs Timing offset in milliseconds (absolute value used for judgement)
 * @return Judgement string: 'cool', 'good', 'bad'
 */
function o2jam_getJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= o2jam_coolWindow)
		return 'cool';
	if (absMs <= o2jam_goodWindow)
		return 'good';
	if (absMs <= o2jam_badWindow)
		return 'bad';
	return 'miss';
}

// ========================================
// SCORING ALGORITHM
// ========================================

/**
 * Processes a note hit and updates O2Jam score and accuracy.
 *
 * O2Jam scoring:
 *   - COOL: combo continues, score += 1.0 × combo
 *   - GOOD: combo continues, score += 0.7 × combo
 *   - BAD:  combo breaks (resets to 0), score += 0.4 × 0 (no combo points)
 *   - MISS: combo breaks (resets to 0), score += 0
 *
 * Accuracy = (1.0 × N_COOL + 0.7 × N_GOOD + 0.4 × N_BAD) / N_total
 *
 * @param offsetMs Timing offset in milliseconds
 */
function processHit(offsetMs:Float) {
	var judgement = o2jam_getJudgement(offsetMs);

	var weight = 0.0;

	if (judgement == 'cool') {
		weight = o2jam_coolWeight;
		o2jam_combo = o2jam_combo + 1;
		o2jam_coolHits = o2jam_coolHits + 1;
		setVar('o2jam_coolHits', o2jam_coolHits);
	} else if (judgement == 'good') {
		weight = o2jam_goodWeight;
		o2jam_combo = o2jam_combo + 1;
		o2jam_goodHits = o2jam_goodHits + 1;
		setVar('o2jam_goodHits', o2jam_goodHits);
	} else {
		// BAD - combo breaks
		weight = o2jam_badWeight;
		o2jam_combo = 0;
		o2jam_badHits = o2jam_badHits + 1;
		setVar('o2jam_badHits', o2jam_badHits);
	}

	// Score += judgement_value × combo
	o2jam_songScore = o2jam_songScore + Math.round(weight * o2jam_combo);

	// Update accuracy tracking
	o2jam_weightedSum = o2jam_weightedSum + weight;
	o2jam_totalNotes = o2jam_totalNotes + 1;

	debug('Hit: '
		+ judgement
		+ ' ('
		+ Math.round(offsetMs * 100) / 100
		+ 'ms) | Combo: '
		+ o2jam_combo
		+ ' | Score: '
		+ o2jam_songScore);
}

/**
 * Processes a tap miss. Resets combo and adds 0 to accuracy.
 */
function processMiss() {
	o2jam_combo = 0;
	o2jam_totalNotes = o2jam_totalNotes + 1;
	// weightedSum += 0 (miss weight is 0)

	debug('Miss! | Combo: 0 | Score: ' + o2jam_songScore);
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Enables or disables the O2Jam scoring system
 * @param enabled Whether to enable O2Jam scoring
 */
function o2jam_setEnabled(enabled:Bool) {
	o2jam_enabled = enabled;
	setVar('o2jam_enabled', o2jam_enabled);
	debug('O2Jam scoring ' + (enabled ? 'enabled' : 'disabled'));
}

/**
 * Returns the current O2Jam accuracy as a percentage.
 * Accuracy = (1.0 × N_COOL + 0.7 × N_GOOD + 0.4 × N_BAD) / N_total × 100
 * @return Accuracy percentage (0-100)
 */
function o2jam_getAccuracy():Float {
	if (o2jam_totalNotes <= 0)
		return 0.0;
	var percent = (o2jam_weightedSum / o2jam_totalNotes) * 100.0;
	if (percent < 0.0)
		percent = 0.0;
	if (percent > 100.0)
		percent = 100.0;
	return percent;
}

/**
 * Returns the current song score.
 * @return Total song score
 */
function o2jam_getScore():Int {
	return o2jam_songScore;
}

/**
 * Returns the current O2Jam combo.
 * @return Current combo count
 */
function o2jam_getCombo():Int {
	return o2jam_combo;
}

/**
 * Gets letter grade for a given percentage.
 * Uses O2Jam-style grade thresholds.
 * @param percent O2Jam percentage (0-100)
 * @return Letter grade string
 */
function o2jam_getGrade(percent:Float):String {
	if (percent >= 100.0)
		return 'SSS';
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
	if (percent >= 60.0)
		return 'D';
	return 'F';
}

/**
 * Gets the FC (Full Combo) tier based on judgement counts and misses.
 *   AFC  = All COOLs, no misses (All Cool Full Combo)
 *   FC   = No misses, no BADs (Full Combo - COOLs and GOODs only)
 *   SDCB = <10 misses (Single Digit Combo Break)
 *   Clear = 10+ misses
 *
 * @return FC tier string
 */
function o2jam_getRatingFC():String {
	var misses = game.songMisses;
	var comboBreaks = misses + o2jam_badHits; // BAD and MISS both break combo

	if (comboBreaks > 0) {
		if (comboBreaks < 10)
			return 'SDCB';
		return 'Clear';
	}

	if (o2jam_goodHits == 0)
		return 'AFC'; // All Cool Full Combo

	return 'FC'; // Full Combo (COOLs + GOODs only)
}

/**
 * Returns the total number of COOL hits.
 * @return Count of COOL judgements (<=33ms)
 */
function o2jam_getCoolHits():Int {
	return o2jam_coolHits;
}

/**
 * Returns the total number of GOOD hits.
 * @return Count of GOOD judgements (<=67ms)
 */
function o2jam_getGoodHits():Int {
	return o2jam_goodHits;
}

/**
 * Returns the total number of BAD hits.
 * @return Count of BAD judgements (<=100ms)
 */
function o2jam_getBadHits():Int {
	return o2jam_badHits;
}

/**
 * Returns the total number of notes judged so far.
 * @return Total note count (hits + misses)
 */
function o2jam_getTotalNotes():Int {
	return o2jam_totalNotes;
}

/**
 * Formats percentage to 2 decimal places.
 * @param value Percentage value
 * @return Formatted string
 */
function o2jam_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

/**
 * Resets all scoring state to initial values.
 */
function o2jam_resetScoring() {
	o2jam_songScore = 0;
	o2jam_combo = 0;
	o2jam_weightedSum = 0.0;
	o2jam_totalNotes = 0;
	o2jam_coolHits = 0;
	o2jam_goodHits = 0;
	o2jam_badHits = 0;
	debug('O2Jam scoring reset');

	if (o2jam_replaceScoreText)
		o2jam_updateScoreText();
}

/**
 * Enables or disables score text replacement.
 * @param replace Whether to replace Psych Engine's default score text
 */
function o2jam_setReplaceScoreText(replace:Bool) {
	o2jam_replaceScoreText = replace;
	setVar('o2jam_replaceScoreText', o2jam_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

/**
 * Returns whether score text replacement is enabled.
 * @return Current state of score text replacement
 */
function o2jam_getReplaceScoreText():Bool {
	return o2jam_replaceScoreText;
}

/**
 * Sets the score text format style.
 * @param kadeStyle If true, uses Kade Engine format; if false, uses Psych Engine format
 */
function o2jam_setKadeEngineStyle(kadeStyle:Bool) {
	o2jam_kadeEngineStyle = kadeStyle;
	setVar('o2jam_kadeEngineStyle', o2jam_kadeEngineStyle);
	debug('Kade Engine style score text ' + (kadeStyle ? 'enabled' : 'disabled'));
}

/**
 * Returns the current score text format style.
 * @return True if using Kade Engine style, false if using Psych Engine style
 */
function o2jam_getKadeEngineStyle():Bool {
	return o2jam_kadeEngineStyle;
}

// ========================================
// SCORE TEXT
// ========================================

/**
 * Updates the score text with O2Jam scoring information.
 * Format: Score: X | Misses: Y | Rating: GRADE (ACC%) - FC
 */
function o2jam_updateScoreText() {
	if (!o2jam_enabled || !o2jam_replaceScoreText)
		return;

	var score = o2jam_getScore();
	var misses = game.songMisses;
	var hasHitNotes = (o2jam_totalNotes > 0);

	var scoreText = '';

	if (hasHitNotes) {
		var accuracy = o2jam_getAccuracy();
		var formattedPercent = o2jam_formatPercent(accuracy);
		var grade = o2jam_getGrade(accuracy);
		var ratingFC = o2jam_getRatingFC();

		scoreText = o2jam_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ' + formattedPercent + ' % | (' + ratingFC
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
		scoreText = o2jam_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ?' : 'Score: '
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
 * Registers all O2Jam scoring functions as global callbacks.
 * Makes these functions accessible from other scripts via setVar() and createGlobalCallback().
 */
function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['o2jam_getAccuracy', o2jam_getAccuracy],
		['o2jam_getScore', o2jam_getScore],
		['o2jam_getGrade', o2jam_getGrade],
		['o2jam_getCombo', o2jam_getCombo],
		['o2jam_getCoolHits', o2jam_getCoolHits],
		['o2jam_getGoodHits', o2jam_getGoodHits],
		['o2jam_getBadHits', o2jam_getBadHits],
		['o2jam_getTotalNotes', o2jam_getTotalNotes],
		['o2jam_formatPercent', o2jam_formatPercent],
		['o2jam_getRatingFC', o2jam_getRatingFC],
		['o2jam_getHitWindow', o2jam_getHitWindow],
		['o2jam_getJudgement', o2jam_getJudgement],
		['o2jam_setEnabled', o2jam_setEnabled],
		['o2jam_resetScoring', o2jam_resetScoring],
		['o2jam_setReplaceScoreText', o2jam_setReplaceScoreText],
		['o2jam_getReplaceScoreText', o2jam_getReplaceScoreText],
		['o2jam_updateScoreText', o2jam_updateScoreText],
		['o2jam_setKadeEngineStyle', o2jam_setKadeEngineStyle],
		['o2jam_getKadeEngineStyle', o2jam_getKadeEngineStyle],
		['o2jam_getUseBPMWindows', o2jam_getUseBPMWindows],
		['o2jam_setUseBPMWindows', o2jam_setUseBPMWindows],
		['o2jam_updateBPMWindows', o2jam_updateBPMWindows]
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

	debug('O2Jam functions registered - accessible from other scripts');
	debug('O2Jam Scoring System Initialized' + (o2jam_useBPMWindows ? ' (BPM-based windows)' : ' (Fixed windows)'));
}

function onCreatePost() {
	o2jam_resetScoring();

	// Initialize BPM-based windows if enabled
	if (o2jam_useBPMWindows)
		o2jam_updateBPMWindows(Conductor.bpm);

	debug('O2Jam scoring ready');

	if (o2jam_isActiveSystem) {
		var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
		Conductor.safeZoneOffset = o2jam_badWindow * playbackRate;
		debug('Overrode safeZoneOffset to ' + Conductor.safeZoneOffset + 'ms (badWindow=' + o2jam_badWindow + 'ms)');
	}
}

function onBeatHit() {
	// Update windows when BPM changes mid-song (BPM mode only)
	if (o2jam_useBPMWindows && o2jam_enabled) {
		var currentBPM = Conductor.bpm;
		var expectedCool = 7500.0 / currentBPM;
		// Only recalculate if BPM actually changed (compare with tolerance)
		if (Math.abs(o2jam_coolWindow - expectedCool) > 0.01)
			o2jam_updateBPMWindows(currentBPM);
	}
}

function preUpdateScore(miss:Bool) {
	if (o2jam_isActiveSystem && o2jam_replaceScoreText) {
		if (!miss)
			game.doScoreBop();
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (o2jam_isActiveSystem && o2jam_replaceScoreText)
		o2jam_updateScoreText();
}

function goodNoteHit(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;
	if (!o2jam_enabled)
		return;

	// Calculate timing offset
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;
	var offsetMs = Math.abs(noteDiff);

	// Process the hit
	processHit(offsetMs);

	if (o2jam_replaceScoreText)
		o2jam_updateScoreText();
}

function noteMiss(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;
	if (!o2jam_enabled)
		return;

	// Process the miss
	processMiss();

	if (o2jam_replaceScoreText)
		o2jam_updateScoreText();
}

function onDestroy() {
	// Cleanup handled by other scripts
}
