/*
	>>> Wife3 Scoring Script for Psych Engine
		HScript-based scoring system that implements Etterna's Wife3 accuracy calculation.
		This script does NOT include any HUD elements by default - it only provides the scoring backend.
		You can create your own custom UI using the provided global callbacks, edit an existing one or use the scuffed Wife3 UI.hx script.

		Features:
			- Full Wife3 port using Etterna source code as reference
			- Wife3-inspired song score calculation
			- Judge 1-9 presets for customizable difficulty
			- Fully customizable judge scale instead of being limited to presets only.

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'

		See the wiki for API reference and usage examples.
		https://github.com/MeguminBOT/Lulus-Psych-Engine-Scripts/wiki/Wife3-Scoring-System.hx

	Script by AutisticLulu.
*/

// ========================================
// VARIABLES AND CONSTANTS
// ========================================
// --- General Settings ---
var wife3_enabled = true;
var wife3_debug = false;

// --- Algorithm Constants (Do Not Modify) ---
var wife3_miss_weight = -5.5;
var wife3_max_points = 2.0;
var wife3_j_pow = 0.75;
var wife3_judge_scale = 1; // Baseline judge scale (1.0 = J4)
var JUDGE_WINDOWS:Array<Float> = [4.0, 3.0, 2.0, 1.0, 0.9, 0.75, 0.6, 0.5, 0.4];

// --- Accuracy Tracking (Do Not Modify) ---
var wife3_curAccuracy = 0.0;
var wife3_maxAccuracy = 0.0;
var wife3_songScore = 0;

// --- Judgement Tracking (Do Not Modify) ---
var wife3_marvelousHits = 0; // <= 22ms * judge scale
var wife3_perfectHits = 0; // <= 45ms * judge scale
var wife3_greatHits = 0; // <= 90ms * judge scale
var wife3_goodHits = 0; // <= 135ms * judge scale
var wife3_badHits = 0; // <= 180ms * judge scale

function registerCallbacks() {
	createGlobalCallback('wife3_getAccuracy', wife3_getAccuracy);
	createGlobalCallback('wife3_getScore', wife3_getScore);
	createGlobalCallback('wife3_getGrade', wife3_getGrade);
	createGlobalCallback('wife3_getJudgeScale', wife3_getJudgeScale);
	createGlobalCallback('wife3_getJudgePreset', wife3_getJudgePreset);
	createGlobalCallback('wife3_getMarvelousHits', wife3_getMarvelousHits);
	createGlobalCallback('wife3_getPerfectHits', wife3_getPerfectHits);
	createGlobalCallback('wife3_getGreatHits', wife3_getGreatHits);
	createGlobalCallback('wife3_getGoodHits', wife3_getGoodHits);
	createGlobalCallback('wife3_getBadHits', wife3_getBadHits);
	createGlobalCallback('wife3_formatPercent', wife3_formatPercent);
	createGlobalCallback('wife3_getTimingWindow', wife3_getTimingWindow);
	createGlobalCallback('wife3_setEnabled', wife3_setEnabled);
	createGlobalCallback('wife3_setJudgeScale', wife3_setJudgeScale);
	createGlobalCallback('wife3_setJudgePreset', wife3_setJudgePreset);
	createGlobalCallback('wife3_resetAccuracy', wife3_resetAccuracy);

	setVar('wife3_getAccuracy', wife3_getAccuracy);
	setVar('wife3_getScore', wife3_getScore);
	setVar('wife3_getGrade', wife3_getGrade);
	setVar('wife3_getJudgeScale', wife3_getJudgeScale);
	setVar('wife3_getJudgePreset', wife3_getJudgePreset);
	setVar('wife3_getMarvelousHits', wife3_getMarvelousHits);
	setVar('wife3_getPerfectHits', wife3_getPerfectHits);
	setVar('wife3_getGreatHits', wife3_getGreatHits);
	setVar('wife3_getGoodHits', wife3_getGoodHits);
	setVar('wife3_getBadHits', wife3_getBadHits);
	setVar('wife3_formatPercent', wife3_formatPercent);
	setVar('wife3_getTimingWindow', wife3_getTimingWindow);
	setVar('wife3_setEnabled', wife3_setEnabled);
	setVar('wife3_setJudgeScale', wife3_setJudgeScale);
	setVar('wife3_setJudgePreset', wife3_setJudgePreset);
	setVar('wife3_resetAccuracy', wife3_resetAccuracy);
}

// ========================================
// DEBUG HELPER
// ========================================

/**
 * Helper function to print debug messages only when wife3debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!wife3_debug || !wife3_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[Wife3] ' + message, color);
}

// ========================================
// WIFE3 ALGORITHM
// ========================================

/**
 * Error function approximation using Abramowitz & Stegun formula 7.1.26
 * @param x Input value
 * @return Approximated erf(x)
 */
function erf(x:Float):Float {
	var a1 = 0.254829592;
	var a2 = -0.284496736;
	var a3 = 1.421413741;
	var a4 = -1.453152027;
	var a5 = 1.061405429;
	var p = 0.3275911;

	var sign = x < 0 ? -1 : 1;
	x = Math.abs(x);

	var t = 1.0 / (1.0 + p * x);
	var y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);

	return sign * y;
}

/**
 * Wife3 scoring algorithm - calculates accuracy points based on timing offset
 * @param offset Time difference from perfect hit (in seconds)
 * @param judgeScale Timing scale (1.0 = J4, higher = easier, lower = harder)
 * @return Wife3 accuracy points (-5.5 to 2.0)
 */
function wife3(offset:Float, judgeScale:Float):Float {
	var offsetMs = Math.abs(offset * 1000.0);

	// Calculate timing thresholds
	var ridic = 5.0 * judgeScale;
	var zero = 65.0 * Math.pow(judgeScale, wife3_j_pow);
	var dev = 22.7 * Math.pow(judgeScale, wife3_j_pow);
	var maxBooWeight = 180.0 * judgeScale;

	// Region 1: Perfect hits
	if (offsetMs <= ridic)
		return wife3_max_points;

	// Region 2: Good hits (error function curve)
	if (offsetMs <= zero)
		return wife3_max_points * erf((zero - offsetMs) / dev);

	// Region 3: Bad hits (linear interpolation to miss)
	if (offsetMs <= maxBooWeight) {
		return (offsetMs - zero) * wife3_miss_weight / (maxBooWeight - zero);
	}

	// Region 4: Miss
	return wife3_miss_weight;
}

/**
 * Calculates song score points from Wife3 accuracy
 * @param accuracy Wife3 points for a note (-5.5 to 2.0)
 * @return Song score points to add
 */
function calculateSongScore(accuracy:Float):Int {
	var maxSongPoints = 350;
	var wife3Ratio = accuracy / wife3_max_points;

	if (wife3Ratio >= 0) {
		return Math.round(wife3Ratio * maxSongPoints);
	} else {
		return Math.round(wife3Ratio * 200);
	}
}

// ========================================
// HELPER FUNCTIONS
// ========================================

function wife3_setEnabled(enabled:Bool) {
	wife3_enabled = enabled;
	setVar('wife3_enabled', wife3_enabled);
	debug('Wife3 scoring ' + (enabled ? 'enabled' : 'disabled'));
}

function wife3_setJudgeScale(scale:Float) {
	wife3_judge_scale = Math.max(0.009, Math.min(0.090, scale));
	var ms = Math.round(wife3_judge_scale * 10000) / 10;
	debug('Wife3 Judge Scale set to: ' + wife3_judge_scale + 's (' + ms + 'ms Marvelous window)');
}

function wife3_setJudgePreset(judgeNumber:Int) {
	if (judgeNumber < 1 || judgeNumber > 9) {
		debug('Invalid judge number: ' + judgeNumber + '. Must be 1-9.');
		return;
	}

	wife3_judge_scale = JUDGE_WINDOWS[judgeNumber - 1];
	var judgeName = (judgeNumber == 9) ? 'J9 (JUSTICE)' : 'J' + judgeNumber;
	debug('Wife3 Judge Preset set to: '
		+ judgeName
		+ ' (scale: '
		+ wife3_judge_scale
		+ ', window: '
		+ Math.round(wife3_judge_scale * 1000)
		+ 'ms)');
}

function wife3_resetAccuracy() {
	wife3_curAccuracy = 0.0;
	wife3_maxAccuracy = 0.0;
	wife3_songScore = 0;
	wife3_marvelousHits = 0;
	wife3_perfectHits = 0;
	wife3_greatHits = 0;
	wife3_goodHits = 0;
	wife3_badHits = 0;
	debug('Wife3 accuracy reset');
}

function wife3_getAccuracy():Float {
	if (wife3_maxAccuracy <= 0)
		return 0.0;
	var percent = (wife3_curAccuracy / wife3_maxAccuracy) * 100.0;
	return Math.max(0, Math.min(100, percent));
}

function wife3_getScore():Int {
	return wife3_songScore;
}

/**
 * Gets letter grade for a given percentage
 * @param percent Wife3 percentage (0-100)
 * @return Letter grade string
 */
function wife3_getGrade(percent:Float):String {
	if (percent >= 99.70)
		return 'AAAAA';
	if (percent >= 99.50)
		return 'AAAA';
	if (percent >= 99.00)
		return 'AAA';
	if (percent >= 98.00)
		return 'AA';
	if (percent >= 96.50)
		return 'A';
	if (percent >= 93.00)
		return 'B';
	if (percent >= 90.00)
		return 'C';
	if (percent >= 80.00)
		return 'D';
	return 'F';
}

/**
 * Gets a timing window (in ms) based on current judge scale
 * @param windowType Window type: 'marvelous', 'perfect', 'great', 'good', 'bad'
 * @return Timing window in milliseconds
 */
function wife3_getTimingWindow(windowType:String):Float {
	switch (windowType.toLowerCase()) {
		case 'marvelous':
			return 22.0 * wife3_judge_scale;
		case 'perfect':
			return 45.0 * wife3_judge_scale;
		case 'great':
			return 90.0 * wife3_judge_scale;
		case 'good':
			return 135.0 * wife3_judge_scale;
		case 'bad':
			return 180.0 * wife3_judge_scale;
		default:
			return 0.0;
	}
}

function wife3_getJudgeScale():Float {
	return wife3_judge_scale;
}

function wife3_getJudgePreset():Float {
	var currentScale = wife3_judge_scale;
	var judgeCount = JUDGE_WINDOWS.length;

	for (i in 0...judgeCount) {
		var windowScale = JUDGE_WINDOWS[i];

		if (Math.abs(currentScale - windowScale) < 0.001) {
			return i + 1;
		}

		if (i < judgeCount - 1) {
			var nextWindowScale = JUDGE_WINDOWS[i + 1];
			if (currentScale <= windowScale && currentScale >= nextWindowScale) {
				var factor = (windowScale - currentScale) / (windowScale - nextWindowScale);
				return (i + 1) + factor;
			}
		}
	}

	var firstWindow = JUDGE_WINDOWS[0];
	var lastWindow = JUDGE_WINDOWS[judgeCount - 1];
	
	if (currentScale >= firstWindow) {
		var extrapolation = (currentScale - firstWindow) / (firstWindow - JUDGE_WINDOWS[1]);
		return Math.max(0.1, 1.0 - extrapolation);
	}
	
	if (currentScale <= lastWindow) {
		var extrapolation = (lastWindow - currentScale) / (JUDGE_WINDOWS[judgeCount - 2] - lastWindow);
		return 9.0 + extrapolation;
	}

	return 4.0;
}

function wife3_getMarvelousHits():Int {
	return wife3_marvelousHits;
}

function wife3_getPerfectHits():Int {
	return wife3_perfectHits;
}

function wife3_getGreatHits():Int {
	return wife3_greatHits;
}

function wife3_getGoodHits():Int {
	return wife3_goodHits;
}

function wife3_getBadHits():Int {
	return wife3_badHits;
}

/**
 * Formats percentage to 2 decimal places
 * @param value Percentage value
 * @return Formatted string
 */
function wife3_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

// ========================================
// EVENT HANDLERS
// ========================================

function onCreate() {
	registerCallbacks();
	debug('Wife3 global callbacks registered - accessible from all scripts');
	debug('Wife3 Scoring System Initialized');
}

function onCreatePost() {
	wife3_resetAccuracy();
}

function goodNoteHit(note:Note) {
	if (!wife3_enabled || note.isSustainNote || !note.mustPress)
		return;

	// Calculate timing offset
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;
	var offsetSeconds = noteDiff / 1000.0;
	var offsetMs = Math.abs(noteDiff);

	// Calculate Wife3 accuracy
	var accuracy = wife3(offsetSeconds, wife3_judge_scale);

	// Track judgements based on timing windows (scaled by judge scale)
	// Note: We always increment a counter, even for notes outside bad window
	if (offsetMs <= wife3_getTimingWindow('marvelous')) {
		wife3_marvelousHits = wife3_marvelousHits + 1;
		setVar('wife3_marvelousHits', wife3_marvelousHits);
	} else if (offsetMs <= wife3_getTimingWindow('perfect')) {
		wife3_perfectHits = wife3_perfectHits + 1;
		setVar('wife3_perfectHits', wife3_perfectHits);
	} else if (offsetMs <= wife3_getTimingWindow('great')) {
		wife3_greatHits = wife3_greatHits + 1;
		setVar('wife3_greatHits', wife3_greatHits);
	} else if (offsetMs <= wife3_getTimingWindow('good')) {
		wife3_goodHits = wife3_goodHits + 1;
		setVar('wife3_goodHits', wife3_goodHits);
	} else {
		// Any hit worse than good window counts as bad (including hits outside 180ms)
		wife3_badHits = wife3_badHits + 1;
		setVar('wife3_badHits', wife3_badHits);
	}

	// Update tracking
	wife3_curAccuracy += accuracy;
	wife3_maxAccuracy += wife3_max_points;
	wife3_songScore += calculateSongScore(accuracy);
}

function noteMiss(note:Note) {
	if (!wife3_enabled || note.isSustainNote || !note.mustPress)
		return;

	wife3_curAccuracy += wife3_miss_weight;
	wife3_maxAccuracy += wife3_max_points;
	wife3_songScore += calculateSongScore(wife3_miss_weight);

	debug('Note missed - Wife Penalty: ' + wife3_miss_weight + ', Total: ' + wife3_curAccuracy + '/' + wife3_maxAccuracy);
}
