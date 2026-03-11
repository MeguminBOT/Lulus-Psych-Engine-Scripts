/*
	>>> ITG Scoring System for Psych Engine
		HScript-based scoring system that implements In The Groove (ITG) / StepMania's
		DDR MAX2-style scoring and dance point accuracy.
		This replaces Psych Engine's default scoring system.
		Can be used with Custom HUDs in Lua/HScript by using the provided global callbacks.

		Features:
			- Full DDR MAX2-style point scoring (max 10,000,000 per song).
			- Dance Point percentage accuracy (0-100%).
			- ITG timing windows: Fantastic (±22.5ms), Excellent (±45ms), Great (±90ms),
			  Decent (±135ms), Way Off (±180ms).
			- Hold note judgements (OK/NG) with dance point and score integration.
			- Window Scale support for customizable timing difficulty.
			- Playback rate support.
			- Settings.json support (when using "Lulu's Feature Pack")
				- Configure settings through the mod settings menu
				- Settings from settings.json will override the default values in the script

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var itg_enabled = true;
var itg_debug = false;
var itg_replaceScoreText = true;
var itg_kadeEngineStyle = false; // Whether to use Kade Engine style scoreText or Psych Engine style.
// --- Timing Window Scale (1.0 = default ITG windows, lower = stricter) ---
var itg_windowScale = 1.0;

// --- Score Constants (Do Not Modify) ---
var itg_maxDisplayScore = 10000000;

// --- DDR MAX2 Score State (Do Not Modify) ---
var itg_totalNotes = 0; // Total scoring events (taps + holds)
var itg_stepCount = 0; // Running step counter (always increments, even on miss)
var itg_earnedPoints = 0.0; // Accumulated weighted points
var itg_currentScore = 0; // Displayed score (0 to 10,000,000)
var itg_notesCounted = false;

// --- Dance Point Accuracy (Do Not Modify) ---
// Dance Points (ITG theme): Fantastic=5, Excellent=4, Great=2, Decent=0, WayOff=-6, Miss=-12, HoldOK=5, HoldNG=0
var itg_earnedDP = 0.0;
var itg_maxDP = 0.0;

// --- Judgement Tracking (Do Not Modify) ---
var itg_fantasticHits = 0; // Fantastic (±22.5ms * scale)
var itg_excellentHits = 0; // Excellent (±45ms * scale)
var itg_greatHits = 0; // Great (±90ms * scale)
var itg_decentHits = 0; // Decent (±135ms * scale)
var itg_wayOffHits = 0; // Way Off (±180ms * scale)
// --- Hold Tracking (Do Not Modify) ---
var itg_holdOKs = 0; // Holds completed successfully
var itg_holdNGs = 0; // Holds dropped early

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
		trace('[ITG] settings.json not found, using default values from script');
		return;
	}
	trace('[ITG] settings.json found, loading settings...');

	var value:Dynamic;

	if ((value = getModSetting('scoring_system')) != null)
		itg_enabled = (value == 'ITG');

	if ((value = getModSetting('scoring_debug')) != null)
		itg_debug = value;

	if ((value = getModSetting('scoring_replaceScoreText')) != null)
		itg_replaceScoreText = value;

	if ((value = getModSetting('scoring_kadeEngineStyle')) != null)
		itg_kadeEngineStyle = value;

	if ((value = getModSetting('itg_windowScale')) != null) {
		var scale:Float = value;
		if (scale >= 0.1 && scale <= 4.0) {
			itg_windowScale = scale;
			debug('Loaded itg_windowScale from settings: ' + itg_windowScale);
		} else {
			debug('Invalid window scale: ' + scale + ', must be between 0.1 and 4.0');
		}
	}
}

// ========================================
// DEBUG HELPER
// ========================================

/**
 * Helper function to print debug messages only when itg_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!itg_debug || !itg_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[ITG] ' + message, color);
}

// ========================================
// HIT WINDOW FUNCTIONS
// ========================================

/**
 * Gets the hit window (in ms) for a judgement at the current window scale.
 *
 * ITG timing windows (default, before scaling):
 *   Fantastic: ±22.5ms
 *   Excellent: ±45.0ms
 *   Great:     ±90.0ms
 *   Decent:    ±135.0ms
 *   Way Off:   ±180.0ms
 *
 * @param judgement Judgement name: 'fantastic', 'excellent', 'great', 'decent', 'wayoff'
 * @return Hit window in milliseconds (scaled by itg_windowScale)
 */
function itg_getHitWindow(judgement:String):Float {
	var base = 0.0;
	switch (judgement.toLowerCase()) {
		case 'fantastic':
			base = 22.5;
		case 'excellent':
			base = 45.0;
		case 'great':
			base = 90.0;
		case 'decent':
			base = 135.0;
		case 'wayoff':
			base = 180.0;
		default:
			return 0.0;
	}
	return base * itg_windowScale;
}

/**
 * Determines the ITG judgement for a given timing offset.
 * @param offsetMs Timing offset in milliseconds (absolute value used for judgement)
 * @return Judgement string: 'Fantastic', 'Excellent', 'Great', 'Decent', 'Way Off'
 */
function itg_getJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= itg_getHitWindow('fantastic'))
		return 'Fantastic';
	if (absMs <= itg_getHitWindow('excellent'))
		return 'Excellent';
	if (absMs <= itg_getHitWindow('great'))
		return 'Great';
	if (absMs <= itg_getHitWindow('decent'))
		return 'Decent';
	return 'Way Off';
}

// ========================================
// SCORING ALGORITHM
// ========================================

/**
 * Counts total scoring events from the chart.
 * Each regular tap note = 1 event. Each hold note = 2 events (head tap + tail OK/NG).
 * Should be called after all chart modifications (e.g., double chart) are complete.
 */
function countTotalNotes() {
	itg_totalNotes = itg_stepCount; // Include already processed steps

	if (game.unspawnNotes != null) {
		for (note in game.unspawnNotes) {
			if (note != null && note.mustPress) {
				if (!note.isSustainNote) {
					itg_totalNotes = itg_totalNotes + 1;
					// Each hold adds one more scoring event for the tail (OK/NG)
					if (note.tail != null && note.tail.length > 0)
						itg_totalNotes = itg_totalNotes + 1;
				}
			}
		}
	}

	if (game.notes != null && game.notes.members != null) {
		for (note in game.notes.members) {
			if (note != null && note.mustPress && note.alive) {
				if (!note.isSustainNote) {
					itg_totalNotes = itg_totalNotes + 1;
					if (note.tail != null && note.tail.length > 0)
						itg_totalNotes = itg_totalNotes + 1;
				}
			}
		}
	}

	if (itg_totalNotes <= 0)
		itg_totalNotes = 1;

	debug('Total scoring events (taps + holds): ' + itg_totalNotes);
}

/**
 * Ensures note count is accurate by recounting on first note interaction.
 * This catches chart modifications made by other scripts (e.g., Play Both Charts).
 */
function ensureNotesCounted() {
	if (!itg_notesCounted) {
		itg_notesCounted = true;
		countTotalNotes();
	}
}

/**
 * Calculates the maximum possible DDR MAX2 points for the chart.
 * max = 10 * N * (N + 1) / 2 where N = total scoring events and 10 = Fantastic weight
 * @return Maximum possible weighted points
 */
function getMaxPossiblePoints():Float {
	return 10.0 * itg_totalNotes * (itg_totalNotes + 1) / 2.0;
}

/**
 * Processes a tap note hit and updates DDR MAX2 score and dance points.
 *
 * DDR MAX2 scoring formula:
 *   For each scoring event (step), the step counter increments.
 *   earnedPoints += scoreWeight * stepCount
 *   Score weights: Fantastic=10, Excellent=9, Great=5, Decent/WayOff=0
 *   displayedScore = earnedPoints / maxPossiblePoints * 10,000,000
 *
 * Dance Point weights (ITG theme):
 *   Fantastic=5, Excellent=4, Great=2, Decent=0, WayOff=-6, Miss=-12
 *
 * @param offsetMs Timing offset in milliseconds
 */
function processHit(offsetMs:Float) {
	var judgement = itg_getJudgement(offsetMs);

	var scoreWeight = 0;
	var dpWeight = 0.0;

	if (judgement == 'Fantastic') {
		scoreWeight = 10;
		dpWeight = 5.0;
		itg_fantasticHits = itg_fantasticHits + 1;
		setVar('itg_fantasticHits', itg_fantasticHits);
	} else if (judgement == 'Excellent') {
		scoreWeight = 9;
		dpWeight = 4.0;
		itg_excellentHits = itg_excellentHits + 1;
		setVar('itg_excellentHits', itg_excellentHits);
	} else if (judgement == 'Great') {
		scoreWeight = 5;
		dpWeight = 2.0;
		itg_greatHits = itg_greatHits + 1;
		setVar('itg_greatHits', itg_greatHits);
	} else if (judgement == 'Decent') {
		scoreWeight = 0;
		dpWeight = 0.0;
		itg_decentHits = itg_decentHits + 1;
		setVar('itg_decentHits', itg_decentHits);
	} else {
		// Way Off
		scoreWeight = 0;
		dpWeight = -6.0;
		itg_wayOffHits = itg_wayOffHits + 1;
		setVar('itg_wayOffHits', itg_wayOffHits);
	}

	// Update DDR MAX2 score - step counter always increments
	itg_stepCount = itg_stepCount + 1;
	itg_earnedPoints = itg_earnedPoints + scoreWeight * itg_stepCount;

	var maxPossible = getMaxPossiblePoints();
	if (maxPossible > 0)
		itg_currentScore = Math.round(itg_earnedPoints / maxPossible * itg_maxDisplayScore);

	// Update dance points
	itg_earnedDP = itg_earnedDP + dpWeight;
	itg_maxDP = itg_maxDP + 5.0;

	debug('Hit: ' + judgement + ' (' + Math.round(offsetMs * 100) / 100 + 'ms) | Score: ' + itg_currentScore + ' | DP: ' + Math.round(itg_earnedDP) + '/'
		+ Math.round(itg_maxDP));
}

/**
 * Processes a hold note OK (successfully held to the end).
 * DDR MAX2: Scored as Marvelous/Fantastic (weight=10).
 * Dance Points: Hold OK = 5 DP (ITG theme).
 */
function processHoldOK() {
	itg_holdOKs = itg_holdOKs + 1;
	setVar('itg_holdOKs', itg_holdOKs);

	// DDR MAX2: Hold OK scored as Marvelous (weight=10)
	itg_stepCount = itg_stepCount + 1;
	itg_earnedPoints = itg_earnedPoints + 10 * itg_stepCount;

	var maxPossible = getMaxPossiblePoints();
	if (maxPossible > 0)
		itg_currentScore = Math.round(itg_earnedPoints / maxPossible * itg_maxDisplayScore);

	// Dance points: Hold OK = 5 (ITG theme)
	itg_earnedDP = itg_earnedDP + 5.0;
	itg_maxDP = itg_maxDP + 5.0;

	debug('Hold OK | Score: ' + itg_currentScore + ' | DP: ' + Math.round(itg_earnedDP) + '/' + Math.round(itg_maxDP));
}

/**
 * Processes a hold note NG (released early / dropped hold).
 * DDR MAX2: Scored as Good/Decent (weight=0).
 * Dance Points: Hold NG = 0 DP (ITG theme).
 */
function processHoldNG() {
	itg_holdNGs = itg_holdNGs + 1;
	setVar('itg_holdNGs', itg_holdNGs);

	// DDR MAX2: Hold NG scored as Good (weight=0)
	itg_stepCount = itg_stepCount + 1;
	// earnedPoints += 0 * stepCount (no score added)

	var maxPossible = getMaxPossiblePoints();
	if (maxPossible > 0)
		itg_currentScore = Math.round(itg_earnedPoints / maxPossible * itg_maxDisplayScore);

	// Dance points: Hold NG = 0, but max still increases
	itg_maxDP = itg_maxDP + 5.0;

	debug('Hold NG | Score: ' + itg_currentScore + ' | DP: ' + Math.round(itg_earnedDP) + '/' + Math.round(itg_maxDP));
}

/**
 * Processes a tap miss. Weight=0 for DDR MAX2, -12 dance points (ITG theme).
 * The step counter still increments to maintain proper score scaling.
 */
function processMiss() {
	// DDR MAX2: Miss weight=0, step counter still increments
	itg_stepCount = itg_stepCount + 1;
	// earnedPoints += 0 * stepCount (no score added)

	var maxPossible = getMaxPossiblePoints();
	if (maxPossible > 0)
		itg_currentScore = Math.round(itg_earnedPoints / maxPossible * itg_maxDisplayScore);

	// Dance points: Miss = -12 (ITG theme)
	itg_earnedDP = itg_earnedDP - 12.0;
	itg_maxDP = itg_maxDP + 5.0;

	debug('Miss! | Score: ' + itg_currentScore + ' | DP: ' + Math.round(itg_earnedDP) + '/' + Math.round(itg_maxDP));
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Enables or disables the ITG scoring system
 * @param enabled Whether to enable ITG scoring
 */
function itg_setEnabled(enabled:Bool) {
	itg_enabled = enabled;
	setVar('itg_enabled', itg_enabled);
	debug('ITG scoring ' + (enabled ? 'enabled' : 'disabled'));
}

/**
 * Sets the timing window scale.
 * @param scale Window scale value (clamped between 0.1 and 4.0)
 */
function itg_setWindowScale(scale:Float) {
	itg_windowScale = Math.max(0.1, Math.min(4.0, scale));
	debug('Window Scale set to: ' + itg_windowScale + ' (Fantastic window: +/-' + itg_getHitWindow('fantastic') + 'ms)');
}

/**
 * Returns the current window scale value.
 * @return Window scale (1.0 = default ITG windows)
 */
function itg_getWindowScale():Float {
	return itg_windowScale;
}

/**
 * Returns the current dance point accuracy as a percentage.
 * @return Accuracy percentage (0-100)
 */
function itg_getAccuracy():Float {
	if (itg_maxDP <= 0)
		return 0.0;
	var percent = (itg_earnedDP / itg_maxDP) * 100.0;
	return Math.min(100, percent);
}

/**
 * Returns the current DDR MAX2 score.
 * @return Current score (0 to 10,000,000)
 */
function itg_getScore():Int {
	return itg_currentScore;
}

/**
 * Returns the maximum achievable score.
 * @return Maximum possible score (10,000,000)
 */
function itg_getMaxPossibleScore():Int {
	return itg_maxDisplayScore;
}

/**
 * Gets the ITG letter grade for a given dance point percentage.
 *
 * ITG grade thresholds:
 *   ****  = 100%     ***   = >=99%    **    = >=98%    *     = >=96%
 *   S+    = >=94%    S     = >=92%    S-    = >=89%
 *   A+    = >=86%    A     = >=83%    A-    = >=80%
 *   B+    = >=76%    B     = >=72%    B-    = >=68%
 *   C+    = >=64%    C     = >=60%    C-    = >=55%
 *   D     = <55%
 *
 * @param percent Dance point percentage (0-100)
 * @return Grade string
 */
function itg_getGrade(percent:Float):String {
	if (percent >= 100.0)
		return '****';
	if (percent >= 99.0)
		return '***';
	if (percent >= 98.0)
		return '**';
	if (percent >= 96.0)
		return '*';
	if (percent >= 94.0)
		return 'S+';
	if (percent >= 92.0)
		return 'S';
	if (percent >= 89.0)
		return 'S-';
	if (percent >= 86.0)
		return 'A+';
	if (percent >= 83.0)
		return 'A';
	if (percent >= 80.0)
		return 'A-';
	if (percent >= 76.0)
		return 'B+';
	if (percent >= 72.0)
		return 'B';
	if (percent >= 68.0)
		return 'B-';
	if (percent >= 64.0)
		return 'C+';
	if (percent >= 60.0)
		return 'C';
	if (percent >= 55.0)
		return 'C-';
	return 'D';
}

/**
 * Gets the FC (Full Combo) tier based on judgement counts and misses.
 *   FFC  = All Fantastics, no misses (Full Fantastic Combo)
 *   FEC  = Fantastics + Excellents only, no misses (Full Excellent Combo)
 *   FGC  = All Greats or better, no misses (Full Great Combo)
 *   FC   = No misses (Full Combo)
 *   SDCB = <10 misses (Single Digit Combo Break)
 *   Clear = 10+ misses
 *
 * @return FC tier string
 */
function itg_getRatingFC():String {
	var misses = game.songMisses;

	if (misses > 0) {
		if (misses < 10)
			return 'SDCB';
		return 'Clear';
	}

	if (itg_excellentHits == 0 && itg_greatHits == 0 && itg_decentHits == 0 && itg_wayOffHits == 0)
		return 'FFC';

	if (itg_greatHits == 0 && itg_decentHits == 0 && itg_wayOffHits == 0)
		return 'FEC';

	if (itg_decentHits == 0 && itg_wayOffHits == 0)
		return 'FGC';

	return 'FC';
}

/**
 * Returns the total number of Fantastic judgements.
 * @return Count of Fantastic hits (<=22.5ms * scale)
 */
function itg_getFantasticHits():Int {
	return itg_fantasticHits;
}

/**
 * Returns the total number of Excellent judgements.
 * @return Count of Excellent hits (<=45ms * scale)
 */
function itg_getExcellentHits():Int {
	return itg_excellentHits;
}

/**
 * Returns the total number of Great judgements.
 * @return Count of Great hits (<=90ms * scale)
 */
function itg_getGreatHits():Int {
	return itg_greatHits;
}

/**
 * Returns the total number of Decent judgements.
 * @return Count of Decent hits (<=135ms * scale)
 */
function itg_getDecentHits():Int {
	return itg_decentHits;
}

/**
 * Returns the total number of Way Off judgements.
 * @return Count of Way Off hits (<=180ms * scale)
 */
function itg_getWayOffHits():Int {
	return itg_wayOffHits;
}

/**
 * Returns the total number of Hold OKs (holds completed).
 * @return Count of Hold OK results
 */
function itg_getHoldOKs():Int {
	return itg_holdOKs;
}

/**
 * Returns the total number of Hold NGs (holds dropped).
 * @return Count of Hold NG results
 */
function itg_getHoldNGs():Int {
	return itg_holdNGs;
}

/**
 * Returns the total number of scoring events in the chart.
 * @return Total scoring event count (taps + holds)
 */
function itg_getTotalNotes():Int {
	return itg_totalNotes;
}

/**
 * Returns the current earned dance points.
 * @return Earned dance points
 */
function itg_getEarnedDP():Float {
	return itg_earnedDP;
}

/**
 * Returns the current maximum possible dance points.
 * @return Maximum dance points so far
 */
function itg_getMaxDP():Float {
	return itg_maxDP;
}

/**
 * Formats percentage to 2 decimal places.
 * @param value Percentage value
 * @return Formatted string
 */
function itg_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

/**
 * Resets all scoring state to initial values.
 */
function itg_resetScoring() {
	itg_stepCount = 0;
	itg_earnedPoints = 0.0;
	itg_currentScore = 0;
	itg_earnedDP = 0.0;
	itg_maxDP = 0.0;
	itg_fantasticHits = 0;
	itg_excellentHits = 0;
	itg_greatHits = 0;
	itg_decentHits = 0;
	itg_wayOffHits = 0;
	itg_holdOKs = 0;
	itg_holdNGs = 0;
	itg_notesCounted = false;
	debug('ITG scoring reset');

	if (itg_replaceScoreText)
		itg_updateScoreText();
}

/**
 * Recounts total notes. Call this after chart modifications (e.g., double chart).
 */
function itg_recountNotes() {
	itg_notesCounted = false;
	ensureNotesCounted();
}

/**
 * Enables or disables score text replacement.
 * @param replace Whether to replace Psych Engine's default score text
 */
function itg_setReplaceScoreText(replace:Bool) {
	itg_replaceScoreText = replace;
	setVar('itg_replaceScoreText', itg_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

/**
 * Returns whether score text replacement is enabled.
 * @return Current state of score text replacement
 */
function itg_getReplaceScoreText():Bool {
	return itg_replaceScoreText;
}

/**
 * Sets the score text format style.
 * @param kadeStyle If true, uses Kade Engine format; if false, uses Psych Engine format
 */
function itg_setKadeEngineStyle(kadeStyle:Bool) {
	itg_kadeEngineStyle = kadeStyle;
	setVar('itg_kadeEngineStyle', itg_kadeEngineStyle);
	debug('Kade Engine style score text ' + (kadeStyle ? 'enabled' : 'disabled'));
}

/**
 * Returns the current score text format style.
 * @return True if using Kade Engine style, false if using Psych Engine style
 */
function itg_getKadeEngineStyle():Bool {
	return itg_kadeEngineStyle;
}

// ========================================
// SCORE TEXT
// ========================================

/**
 * Updates the score text with ITG scoring information.
 * Format: Score: X | Misses: Y | Rating: GRADE (ACC%) - FC
 */
function itg_updateScoreText() {
	if (!itg_enabled || !itg_replaceScoreText)
		return;

	var score = itg_getScore();
	var misses = game.songMisses;
	var hasHitNotes = (itg_maxDP > 0);

	var scoreText = '';

	if (hasHitNotes) {
		var accuracy = itg_getAccuracy();
		var formattedPercent = itg_formatPercent(accuracy);
		var grade = itg_getGrade(accuracy);
		var ratingFC = itg_getRatingFC();

		scoreText = itg_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ' + formattedPercent + ' % | (' + ratingFC + ') '
			+ grade : 'Score: '
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
		scoreText = itg_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ?' : 'Score: '
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
 * Registers all ITG scoring functions as global callbacks.
 * Makes these functions accessible from other scripts via setVar() and createGlobalCallback().
 */
function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['itg_getAccuracy', itg_getAccuracy],
		['itg_getScore', itg_getScore],
		['itg_getGrade', itg_getGrade],
		['itg_getWindowScale', itg_getWindowScale],
		['itg_setWindowScale', itg_setWindowScale],
		['itg_getFantasticHits', itg_getFantasticHits],
		['itg_getExcellentHits', itg_getExcellentHits],
		['itg_getGreatHits', itg_getGreatHits],
		['itg_getDecentHits', itg_getDecentHits],
		['itg_getWayOffHits', itg_getWayOffHits],
		['itg_getHoldOKs', itg_getHoldOKs],
		['itg_getHoldNGs', itg_getHoldNGs],
		['itg_getTotalNotes', itg_getTotalNotes],
		['itg_getEarnedDP', itg_getEarnedDP],
		['itg_getMaxDP', itg_getMaxDP],
		['itg_getMaxPossibleScore', itg_getMaxPossibleScore],
		['itg_formatPercent', itg_formatPercent],
		['itg_getRatingFC', itg_getRatingFC],
		['itg_getHitWindow', itg_getHitWindow],
		['itg_getJudgement', itg_getJudgement],
		['itg_setEnabled', itg_setEnabled],
		['itg_resetScoring', itg_resetScoring],
		['itg_recountNotes', itg_recountNotes],
		['itg_setReplaceScoreText', itg_setReplaceScoreText],
		['itg_getReplaceScoreText', itg_getReplaceScoreText],
		['itg_updateScoreText', itg_updateScoreText],
		['itg_setKadeEngineStyle', itg_setKadeEngineStyle],
		['itg_getKadeEngineStyle', itg_getKadeEngineStyle]
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
	// Load settings from settings.json if available
	loadSettings();
	registerCallbacks();

	debug('ITG functions registered - accessible from other scripts');
	debug('ITG Scoring System Initialized (Window Scale: ' + itg_windowScale + ')');
}

function onCreatePost() {
	countTotalNotes();
	itg_resetScoring();

	debug('Total scoring events: ' + itg_totalNotes + ' | Max score: ' + itg_maxDisplayScore);
}

function preUpdateScore(miss:Bool) {
	if (itg_enabled && itg_replaceScoreText) {
		if (!miss)
			game.doScoreBop();
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (itg_enabled && itg_replaceScoreText)
		itg_updateScoreText();
}

function goodNoteHit(note:Note) {
	if (!note.mustPress)
		return;

	// Handle sustain notes - only process the LAST tail piece as Hold OK
	if (note.isSustainNote) {
		if (note.parent == null)
			return;

		// Check if this is the last tail piece of the sustain
		var isLastTail = false;
		var parentTail = note.parent.tail;
		if (parentTail != null && parentTail.length > 0) {
			var lastNote = parentTail[parentTail.length - 1];
			if (lastNote == note)
				isLastTail = true;
		}

		if (!isLastTail)
			return;

		// Ensure accurate note count
		ensureNotesCounted();

		// Process as Hold OK (successfully held)
		processHoldOK();

		if (itg_replaceScoreText)
			itg_updateScoreText();
		return;
	}

	// Regular (non-sustain) note hit
	// Ensure accurate note count (catches double chart modifications)
	ensureNotesCounted();

	// Calculate timing offset
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;

	// Process the hit using absolute offset
	processHit(noteDiff);

	if (itg_replaceScoreText)
		itg_updateScoreText();
}

function noteMiss(note:Note) {
	if (!note.mustPress)
		return;

	// Handle sustain note misses - only process last tail as Hold NG
	if (note.isSustainNote) {
		if (note.parent == null)
			return;

		// Check if this is the last tail piece of the sustain
		var isLastTail = false;
		var parentTail = note.parent.tail;
		if (parentTail != null && parentTail.length > 0) {
			var lastNote = parentTail[parentTail.length - 1];
			if (lastNote == note)
				isLastTail = true;
		}

		if (!isLastTail)
			return;

		// Ensure accurate note count
		ensureNotesCounted();

		// Process as Hold NG (dropped hold)
		processHoldNG();

		if (itg_replaceScoreText)
			itg_updateScoreText();
		return;
	}

	// Regular (non-sustain) note miss
	// Ensure accurate note count
	ensureNotesCounted();

	// Process the miss
	processMiss();

	if (itg_replaceScoreText)
		itg_updateScoreText();
}
