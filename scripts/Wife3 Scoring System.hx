/*
    >>> Wife3 Scoring Script for Psych Engine
        HScript-based scoring system that implements Etterna's Wife3 accuracy calculation.
        Can run alongside or replace Psych Engine's default scoring system.

        Features:
            - Full Wife3 port using Etterna source code as reference
            - Wife3-inspired song score calculation
            - Judge 1-9 presets for customizable difficulty
            - Various display modes (default, separate, custom) for score/accuracy.
            - Optional hit timing display (Early/Late feedback)
            - Global callbacks for Lua/HScript access to Wife3 data for custom UI implementations.

        Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'

        See the wiki for API reference and usage examples.
        https://github.com/MeguminBOT/Lulus-Psych-Engine-Scripts/wiki/Wife3-Scoring-System.hx

    Script by AutisticLulu.
*/
        

// ========================================
// Variables
// ========================================

// --- User Settings (Safe to Modify) ---
var wife3Enabled = true;

var displayMode = 'separate'; // 'default', 'separate', 'custom'
var scoreZoom = true;
var textSize = 20;
var textFont = 'vcr.ttf';
var showTimingDisplay = true;
var timingDisplayDuration = 0.8;

// --- Algorithm Constants (Do Not Modify) ---
var wife3_miss_weight = -5.5;
var wife3_max_points = 2.0;
var wife3_j_pow = 0.75;
var wife3_judge_scale = 1.0; // Baseline judge scale (1.0 = J4)
var JUDGE_WINDOWS = [4.0, 3.0, 2.0, 1.0, 0.9, 0.75, 0.6, 0.5, 0.4];

// --- Accuracy Tracking (Do Not Modify) ---
var curWifeAccuracy = 0.0;
var maxWifeAccuracy = 0.0;
var totalWifeAccuracy = 0.0;
var wife3SongScore = 0;

// --- UI State (Do Not Modify) ---
var wifeScoreText:FlxText = null;
var wifeScoreTween:FlxTween = null;
var timingText:FlxText = null;
var timingFadeTween:FlxTween = null;
var timingMoveTween:FlxTween = null;


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
    if (offsetMs <= ridic) return wife3_max_points;
    
    // Region 2: Good hits (error function curve)
    if (offsetMs <= zero) return wife3_max_points * erf((zero - offsetMs) / dev);
    
    // Region 3: Bad hits (linear interpolation to miss)
    if (offsetMs <= maxBooWeight) {
        return (offsetMs - zero) * wife3_miss_weight / (maxBooWeight - zero);
    }
    
    // Region 4: Miss
    return wife3_miss_weight;
}

/**
 * Calculates song score points from Wife3 accuracy
 * @param noteWifeAccuracy Wife3 points for a note (-5.5 to 2.0)
 * @return Song score points to add
 */
function calculateSongScore(noteWifeAccuracy:Float):Int {
    var maxSongPoints = 350;
    var wife3Ratio = noteWifeAccuracy / wife3_max_points;
    
    if (wife3Ratio >= 0) {
        return Math.round(wife3Ratio * maxSongPoints);
    } else {
        return Math.round(wife3Ratio * 200);
    }
}

// ========================================
// UI CREATION AND UPDATING
// ========================================

/**
 * Initializes all display elements based on display mode
 */
function initializeDisplay() {
    if (displayMode == 'custom') {
        trace('Wife3 display disabled - calculations only');
        return;
    }
    
    if (displayMode == 'separate') {
        createSeparateScoreDisplay();
    }
    
    if (showTimingDisplay) {
        createTimingDisplay();
    }
    
    updateAllDisplays();
}

/**
 * Creates the separate Wife3 score text below default scoreTxt
 */
function createSeparateScoreDisplay() {
    var healthBarY = game.healthBar != null ? game.healthBar.y : 0;
    wifeScoreText = new FlxText(0, healthBarY + 60, FlxG.width, '', textSize);
    wifeScoreText.setFormat(Paths.font(textFont), textSize, 0xFFFFFFFF, 'center', 'outline', 0xFF000000);
    wifeScoreText.scrollFactor.set();
    wifeScoreText.borderSize = 1.25;
    wifeScoreText.cameras = [game.camHUD];
    game.add(wifeScoreText);
    
    trace('Wife3 separate display created');
}

/**
 * Creates timing display text (Early/Late indicator)
 */
function createTimingDisplay() {
    timingText = new FlxText(0, 0, 200, '', 24);
    timingText.setFormat(Paths.font(textFont), 24, 0xFFFFFFFF, 'center', 'outline', 0xFF000000);
    timingText.scrollFactor.set();
    timingText.borderSize = 2;
    timingText.cameras = [game.camHUD];
    timingText.alpha = 0;
    game.add(timingText);
    
    trace('Wife3 timing display created');
}

/**
 * Updates all active displays
 */
function updateAllDisplays() {
    if (displayMode == 'custom') return;
    
    var displayText = buildScoreDisplayString();
    
    if (displayMode == 'default' && game.scoreTxt != null) {
        game.scoreTxt.text = displayText;
    } else if (displayMode == 'separate' && wifeScoreText != null) {
        wifeScoreText.text = displayText;
    }
}

/**
 * Builds the formatted score display string
 * @return Formatted score string
 */
function buildScoreDisplayString():String {
    var percent = getWifePercent();
    var grade = getWifeGrade(percent);
    return 'Score: ' + wife3SongScore + ' | Misses: ' + game.songMisses + ' | Rating: ' + formatPercent(percent) + '% - (' + grade + ')';
}

/**
 * Performs score text "bop" animation
 */
function performScoreBop() {
    if (!scoreZoom) return;
    
    var targetText = (displayMode == 'default') ? game.scoreTxt : wifeScoreText;
    if (targetText == null) return;
    
    cancelTween(wifeScoreTween);
    
    targetText.scale.x = 1.075;
    targetText.scale.y = 1.075;
    
    wifeScoreTween = FlxTween.tween(targetText.scale, {x: 1, y: 1}, 0.2, {
        onComplete: function(twn:FlxTween) {
            wifeScoreTween = null;
        }
    });
}

/**
 * Shows timing feedback (Early/Late) on screen
 * @param msOffset Timing offset in milliseconds (signed)
 * @param offsetSeconds Timing offset in seconds (for future use)
 */
function showTimingFeedback(msOffset:Float, offsetSeconds:Float) {
    if (!showTimingDisplay || timingText == null) return;
    
    cancelTween(timingFadeTween);
    cancelTween(timingMoveTween);
    
    var isEarly = msOffset > 0;
    var absMs = Math.round(Math.abs(msOffset));
    
    // Build timing text and color
    var timingData = getTimingDisplayData(absMs, isEarly);
    timingText.text = timingData.text;
    timingText.color = timingData.color;
    
    // Position in center
    positionTimingText();
    
    // Animate in
    animateTimingTextIn();
}

/**
 * Gets display text and color for timing feedback
 * @param absMs Absolute milliseconds offset
 * @param isEarly Whether hit was early (vs late)
 * @return Object with text and color properties
 */
function getTimingDisplayData(absMs:Int, isEarly:Bool):{text:String, color:Int} {
    if (absMs < 5) {
        return {text: 'PERFECT!', color: 0xFF00FF00};
    } else if (isEarly) {
        return {text: absMs + 'ms Early', color: 0xFF00BFFF};
    } else {
        return {text: absMs + 'ms Late', color: 0xFFFF6B6B};
    }
}

/**
 * Positions timing text in center of screen
 */
function positionTimingText() {
    var screenCenterX = FlxG.width / 2;
    var screenCenterY = FlxG.height / 2;
    timingText.x = screenCenterX - (timingText.width / 2);
    timingText.y = screenCenterY + 20;
}

/**
 * Animates timing text in and out
 */
function animateTimingTextIn() {
    timingText.alpha = 0;
    
    timingFadeTween = FlxTween.tween(timingText, {alpha: 1, y: timingText.y - 20}, 0.1, {
        onComplete: function(twn:FlxTween) {
            timingFadeTween = FlxTween.tween(timingText, {alpha: 0, y: timingText.y - 10}, 0.3, {
                startDelay: timingDisplayDuration - 0.4,
                onComplete: function(twn:FlxTween) {
                    timingFadeTween = null;
                }
            });
        }
    });
}


// ========================================
// EVENT HANDLERS
// ========================================

function onCreate() {
    resetWifeAccuracy();
    registerGlobalCallbacks();
    trace('Wife3 Scoring System Initialized (Display Mode: ' + displayMode + ')');
}

function onCreatePost() {
    calculateTotalWifeAccuracy();
    initializeDisplay();
}

/**
 * Registers all Wife3 functions as global callbacks for Lua/HScript access
 */
function registerGlobalCallbacks() {
    createGlobalCallback('wife3_setEnabled', setWife3Enabled);
    createGlobalCallback('wife3_setDisplayMode', setDisplayMode);
    createGlobalCallback('wife3_setScoreZoom', setScoreZoom);
    createGlobalCallback('wife3_setJudgeScale', setJudgeScale);
    createGlobalCallback('wife3_setJudgePreset', setJudgePreset);
    createGlobalCallback('wife3_setShowTimingDisplay', setShowTimingDisplay);
    createGlobalCallback('wife3_setTimingDisplayDuration', setTimingDisplayDuration);
    createGlobalCallback('wife3_resetAccuracy', resetWifeAccuracy);
    createGlobalCallback('wife3_getPercent', getWifePercent);
    createGlobalCallback('wife3_getTotalPercent', getTotalPercent);
    createGlobalCallback('wife3_getScore', getWifeScore);
    createGlobalCallback('wife3_getGrade', getWifeGradeString);
    createGlobalCallback('wife3_getFormattedString', getFormattedWifeString);
    createGlobalCallback('wife3_getCurrentAccuracy', function() { return curWifeAccuracy; });
    createGlobalCallback('wife3_getMaxAccuracy', function() { return maxWifeAccuracy; });
    createGlobalCallback('wife3_getTotalAccuracy', function() { return totalWifeAccuracy; });
    createGlobalCallback('wife3_getSongScore', function() { return wife3SongScore; });
    createGlobalCallback('wife3_calculateGrade', getWifeGrade);
    createGlobalCallback('wife3_formatPercent', formatPercent);
    trace('Wife3 global callbacks registered - accessible from all scripts');
}

function goodNoteHit(note:Note) {
    if (!wife3Enabled || note.isSustainNote || !note.mustPress) return;
    
    // Calculate timing offset
    var noteDiff = note.strumTime - Conductor.songPosition;
    var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
    noteDiff = noteDiff / playbackRate;
    var offsetSeconds = noteDiff / 1000.0;
    
    // Calculate Wife3 accuracy
    var noteWifeAccuracy = wife3(offsetSeconds, wife3_judge_scale);
    
    // Update tracking
    curWifeAccuracy += noteWifeAccuracy;
    maxWifeAccuracy += wife3_max_points;
    wife3SongScore += calculateSongScore(noteWifeAccuracy);
    
    // Update displays
    updateAllDisplays();
    if (displayMode != 'custom') {
        performScoreBop();
    }
    if (showTimingDisplay) {
        showTimingFeedback(noteDiff, offsetSeconds);
    }
}

function noteMiss(note:Note) {
    if (!wife3Enabled || note.isSustainNote || !note.mustPress) return;
    
    curWifeAccuracy += wife3_miss_weight;
    maxWifeAccuracy += wife3_max_points;
    wife3SongScore += calculateSongScore(wife3_miss_weight);
    
    updateAllDisplays();
    
    trace('Note missed - Wife Penalty: ' + wife3_miss_weight + ', Total: ' + curWifeAccuracy + '/' + maxWifeAccuracy);
}

function onUpdatePost(elapsed:Float) {
    if (displayMode == 'separate' && wifeScoreText != null && game.scoreTxt != null) {
        wifeScoreText.y = game.scoreTxt.y + 20;
    }
}

function onRecalculateRating() {
    updateAllDisplays();
}

function onDestroy() {
    cleanupDisplay();
}


// ========================================
// HELPER FUNCTIONS
// ========================================

function setWife3Enabled(enabled:Bool) {
    wife3Enabled = enabled;
    trace('Wife3 scoring ' + (enabled ? 'enabled' : 'disabled'));
}

function setDisplayMode(mode:String) {
    if (mode == 'default' || mode == 'separate' || mode == 'custom') {
        displayMode = mode;
        trace('Wife3 display mode set to: ' + mode);
    } else {
        trace('Invalid display mode: ' + mode + '. Valid options: default, separate, custom');
    }
}

function setJudgeScale(scale:Float) {
    wife3_judge_scale = Math.max(0.009, Math.min(0.090, scale));
    var ms = Math.round(wife3_judge_scale * 10000) / 10;
    trace('Wife3 Judge Scale set to: ' + wife3_judge_scale + 's (' + ms + 'ms Marvelous window)');
}

function setJudgePreset(judgeNumber:Int) {
    if (judgeNumber < 1 || judgeNumber > 9) {
        trace('Invalid judge number: ' + judgeNumber + '. Must be 1-9.');
        return;
    }
    
    wife3_judge_scale = JUDGE_WINDOWS[judgeNumber - 1];
    var judgeName = (judgeNumber == 9) ? 'J9 (JUSTICE)' : 'J' + judgeNumber;
    trace('Wife3 Judge Preset set to: ' + judgeName + ' (scale: ' + wife3_judge_scale + ', window: ' + Math.round(wife3_judge_scale * 1000) + 'ms)');
}

function setScoreZoom(zoom:Bool) {
    scoreZoom = zoom;
    trace('Wife3 score bop animation ' + (zoom ? 'enabled' : 'disabled'));
}

function setShowTimingDisplay(show:Bool) {
    showTimingDisplay = show;
    if (!show && timingText != null) {
        timingText.alpha = 0;
    }
    trace('Wife3 timing display ' + (show ? 'enabled' : 'disabled'));
}

function setTimingDisplayDuration(duration:Float) {
    timingDisplayDuration = Math.max(0.2, Math.min(2.0, duration));
    trace('Wife3 timing display duration set to: ' + timingDisplayDuration + 's');
}

function resetWifeAccuracy() {
    curWifeAccuracy = 0.0;
    maxWifeAccuracy = 0.0;
    wife3SongScore = 0;
    updateAllDisplays();
    trace('Wife3 accuracy reset');
}

function getWifePercent():Float {
    if (maxWifeAccuracy <= 0) return 0.0;
    var percent = (curWifeAccuracy / maxWifeAccuracy) * 100.0;
    return Math.max(0, Math.min(100, percent));
}

function getTotalPercent():Float {
    if (totalWifeAccuracy <= 0) return 0.0;
    return (curWifeAccuracy / totalWifeAccuracy) * 100.0;
}

function getWifeScore():Int {
    return wife3SongScore;
}

function getWifeGradeString():String {
    return getWifeGrade(getWifePercent());
}

function getFormattedWifeString():String {
    return buildScoreDisplayString();
}

/**
 * Calculates total possible Wife3 accuracy from chart data
 */
function calculateTotalWifeAccuracy() {
    var noteCount = 0;
    
    try {
        if (game.SONG == null || game.SONG.notes == null) {
            trace('SONG data not available yet');
            return;
        }
        
        for (section in game.SONG.notes) {
            if (section == null || section.sectionNotes == null) continue;
            
            for (note in section.sectionNotes) {
                if (note == null) continue;
                
                var noteType = note[3];
                if (noteType == null || noteType == '' || noteType == 'Default Note') {
                    noteCount++;
                }
            }
        }
        
        totalWifeAccuracy = noteCount * wife3_max_points;
        trace('Total Wife Accuracy calculated: ' + totalWifeAccuracy + ' (' + noteCount + ' notes)');
    } catch(e:Dynamic) {
        trace('Error calculating total wife accuracy: ' + e);
        totalWifeAccuracy = 0;
    }
}

/**
 * Gets letter grade for a given percentage
 * @param percent Wife3 percentage (0-100)
 * @return Letter grade string
 */
function getWifeGrade(percent:Float):String {
    if (percent >= 99.70) return 'AAAAA';
    if (percent >= 99.50) return 'AAAA';
    if (percent >= 99.00) return 'AAA';
    if (percent >= 98.00) return 'AA';
    if (percent >= 96.50) return 'A';
    if (percent >= 93.00) return 'B';
    if (percent >= 90.00) return 'C';
    if (percent >= 80.00) return 'D';
    return 'F';
}

/**
 * Formats percentage to 2 decimal places
 * @param value Percentage value
 * @return Formatted string
 */
function formatPercent(value:Float):String {
    return Std.string(Math.floor(value * 100) / 100);
}

/**
 * Cancels a tween if it exists
 * @param tween Tween to cancel
 */
function cancelTween(tween:FlxTween) {
    if (tween != null) {
        tween.cancel();
    }
}

/**
 * Cleans up all display elements
 */
function cleanupDisplay() {
    cancelTween(wifeScoreTween);
    cancelTween(timingFadeTween);
    cancelTween(timingMoveTween);
    
    if (wifeScoreText != null) {
        wifeScoreText.destroy();
        wifeScoreText = null;
    }
    
    if (timingText != null) {
        timingText.destroy();
        timingText = null;
    }
}
