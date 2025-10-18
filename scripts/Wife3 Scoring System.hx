/*
	>>> Wife3 Scoring Script for Psych Engine
		HScript-based scoring system that implements Etterna's Wife3 accuracy calculation.
		This by default replaces Psych Engine's default scoring system.
		Can be used with Custom HUDs in Lua/HScript by using the provided global callbacks. 

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
var wife3_replaceScoreText = true;
var wife3_showTimingDisplay = true;

// --- Timing Display Variables ---
var timingText:FlxText = null;
var timingTween:FlxTween = null;

// --- Algorithm Constants (Do Not Modify) ---
var wife3_miss_weight = -5.5;
var wife3_max_points = 2.0;
var wife3_j_pow = 0.75;
var JUDGE_WINDOWS:Array<Float> = [4.0, 3.0, 2.0, 1.0, 0.9, 0.75, 0.6, 0.5, 0.4];

// -- Judge Scale (modifiable, not recommended unless you know what you're doing) --
var wife3_judge_scale = 1.0; // Baseline judge scale (1.0 = J4)

// --- Accuracy Tracking (Do Not Modify) ---
var wife3_curAccuracy = 0.0;
var wife3_maxAccuracy = 0.0;
var wife3_songScore = 0;

// --- Judgement Tracking (Do Not Modify) ---
var wife3_marvelousHits = 0; // <= 22ms * judge scale)
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
	createGlobalCallback('wife3_setReplaceScoreText', wife3_setReplaceScoreText);
	createGlobalCallback('wife3_getReplaceScoreText', wife3_getReplaceScoreText);
	createGlobalCallback('wife3_updateScoreText', wife3_updateScoreText);
	createGlobalCallback('wife3_setShowTimingDisplay', wife3_setShowTimingDisplay);
	createGlobalCallback('wife3_getShowTimingDisplay', wife3_getShowTimingDisplay);

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
	setVar('wife3_setReplaceScoreText', wife3_setReplaceScoreText);
	setVar('wife3_getReplaceScoreText', wife3_getReplaceScoreText);
	setVar('wife3_updateScoreText', wife3_updateScoreText);
	setVar('wife3_setShowTimingDisplay', wife3_setShowTimingDisplay);
	setVar('wife3_getShowTimingDisplay', wife3_getShowTimingDisplay);
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
	
	// Update score text only if replacement is enabled
	if (wife3_replaceScoreText) {
		wife3_updateScoreText();
	}
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

function wife3_setReplaceScoreText(replace:Bool) {
	wife3_replaceScoreText = replace;
	setVar('wife3_replaceScoreText', wife3_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

function wife3_getReplaceScoreText():Bool {
	return wife3_replaceScoreText;
}

function wife3_setShowTimingDisplay(show:Bool) {
	wife3_showTimingDisplay = show;
	setVar('wife3_showTimingDisplay', wife3_showTimingDisplay);
	
	if (!show && timingText != null) {
		// Hide timing display if disabled
		timingText.visible = false;
		if (timingTween != null) {
			timingTween.cancel();
			timingTween = null;
		}
	} else if (show && timingText != null) {
		// Show timing display if enabled
		timingText.visible = true;
	}
	
	debug('Timing display ' + (show ? 'enabled' : 'disabled'));
}

function wife3_getShowTimingDisplay():Bool {
	return wife3_showTimingDisplay;
}

function createTimingDisplay() {
	if (timingText != null) return; // Already created
	
	// Create timing display text
	timingText = new FlxText(0, 0, 200, '');
	timingText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
	timingText.scrollFactor.set();
	timingText.borderSize = 1.5;
	timingText.cameras = [game.camHUD];
	timingText.alpha = 0;
	
	// Position timing display in the middle of the playfield
	positionTimingDisplay();
	
	// Add to scene
	game.add(timingText);
	
	debug('Timing display created');
}

function positionTimingDisplay() {
	if (timingText == null) return;
	
	// Position timing display in the middle of the playfield
	if (game.playerStrums != null && game.playerStrums.members.length >= 4) {
		var firstStrumX = game.playerStrums.members[0].x;
		var lastStrumX = game.playerStrums.members[3].x;
		var strumWidth = game.playerStrums.members[0].width;
		var totalWidth = (lastStrumX + strumWidth) - firstStrumX;
		
		// Center the timing text in the middle of the playfield
		timingText.x = firstStrumX + (totalWidth / 2) - (timingText.width / 2);
		timingText.y = FlxG.height / 2; // Always use screen center for Y position
	} else {
		// Fallback to screen center
		timingText.x = FlxG.width / 2 - 100;
		timingText.y = FlxG.height / 2;
	}
}

function showTimingFeedback(offset:Float) {
	// Only show timing feedback if timing display is enabled and text exists
	if (!wife3_enabled || !wife3_showTimingDisplay || timingText == null)
		return;
	
	var absOffset = Math.abs(offset);
	var prefix = offset > 0 ? '+' : '';
	var roundedOffset = Math.round(offset * 100) / 100;
	var timingStr = prefix + roundedOffset + 'ms';
	
	// Determine color based on timing windows
	var color = FlxColor.WHITE; // Default/Marvelous
	
	// Check timing windows using Wife3 system
	if (absOffset > wife3_getTimingWindow('marvelous'))
		color = FlxColor.YELLOW; // Perfect
	if (absOffset > wife3_getTimingWindow('perfect'))
		color = FlxColor.GREEN; // Great
	if (absOffset > wife3_getTimingWindow('great'))
		color = FlxColor.CYAN; // Good
	if (absOffset > wife3_getTimingWindow('good'))
		color = FlxColor.MAGENTA; // Bad
	if (absOffset > wife3_getTimingWindow('bad'))
		color = FlxColor.RED; // Way off
	
	timingText.text = timingStr;
	timingText.color = color;
	
	// Cancel existing tween
	if (timingTween != null) {
		timingTween.cancel();
	}
	
	// Animate in
	timingText.alpha = 0;
	// Always start from screen center
	timingText.y = FlxG.height / 2;
	timingText.scale.set(1.05, 1.05);
	
	timingTween = FlxTween.tween(timingText, {
		alpha: 1,
		y: (FlxG.height / 2) - 15,
		'scale.x': 1,
		'scale.y': 1
	}, 0.1, {
		onComplete: function(twn:FlxTween) {
			// Fade out
			timingTween = FlxTween.tween(timingText, {
				alpha: 0,
				y: (FlxG.height / 2) - 25
			}, 0.3, {
				startDelay: 0.3,
				onComplete: function(twn:FlxTween) {
					// Reset to screen center when animation completes
					timingText.y = FlxG.height / 2;
					timingTween = null;
				}
			});
		}
	});
}

/**
 * Updates the score text with Wife3 information
 * This function replaces Psych Engine's default score text format
 */
function wife3_updateScoreText() {
	// Only update score text if Wife3 is enabled AND score text replacement is enabled
	if (!wife3_enabled || !wife3_replaceScoreText) return;
	
	var accuracy = wife3_getAccuracy();
	var grade = wife3_getGrade(accuracy);
	var score = wife3_getScore();
	var formattedPercent = wife3_formatPercent(accuracy);
	
	// Get current misses from the game
	var misses = game.songMisses;
	
	// Create Wife3 score text format
	var scoreText = 'Score: ' + score + ' | Misses: ' + misses + ' | Rating: ' + formattedPercent + '% (' + grade + ')';
	
	// Update the score text
	game.scoreTxt.text = scoreText;
}

// ========================================
// EVENT HANDLERS
// ========================================

function onCreate() {
	registerCallbacks();
	debug('Wife3 functions registered - accessible from other scripts');
	debug('Wife3 Scoring System Initialized');
}

function onCreatePost() {
	wife3_resetAccuracy();
	
	// Create timing display if enabled
	if (wife3_showTimingDisplay) {
		createTimingDisplay();
	}
}

function preUpdateScore(miss:Bool) {
	// Only prevent default score text update if Wife3 score text replacement is enabled
	// This allows Wife3 to run in the background while keeping Psych Engine's score text
	if (wife3_enabled && wife3_replaceScoreText) {
		if (!miss) {
			game.doScoreBop();
		}
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (wife3_enabled && wife3_replaceScoreText) {
		wife3_updateScoreText();
	}
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
	
	// Show timing feedback if enabled
	if (wife3_showTimingDisplay) {
		showTimingFeedback(noteDiff);
	}

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
	
	// Update score text only if replacement is enabled
	if (wife3_replaceScoreText) {
		wife3_updateScoreText();
	}
}

function noteMiss(note:Note) {
	if (!wife3_enabled || note.isSustainNote || !note.mustPress)
		return;

	wife3_curAccuracy += wife3_miss_weight;
	wife3_maxAccuracy += wife3_max_points;
	wife3_songScore += calculateSongScore(wife3_miss_weight);

	debug('Note missed - Wife Penalty: ' + wife3_miss_weight + ', Total: ' + wife3_curAccuracy + '/' + wife3_maxAccuracy);

	// Update score text only if replacement is enabled
	if (wife3_replaceScoreText) {
		wife3_updateScoreText();
	}
}

function onDestroy() {
	// Clean up timing display tween
	if (timingTween != null) {
		timingTween.cancel();
		timingTween = null;
	}
}
