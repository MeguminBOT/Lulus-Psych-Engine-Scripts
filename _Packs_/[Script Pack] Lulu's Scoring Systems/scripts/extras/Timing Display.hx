/*
	>>> Timing Display for Psych Engine
		Decoupled timing feedback display that works with any scoring system.
		Automatically detects the active scoring system (Wife3 / OsuMania / OsuManiaV2 / O2Jam / DJMAX / IIDX / Quaver / Psych)
		and color-codes the timing feedback accordingly.

		Requires: scoring_system and scoring_showTimingDisplay settings in settings.json.
		Uses Wife3's judge scale or osu!mania's OD to determine color thresholds.

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================

var td_enabled = true;
var td_scoringSystem = 'Psych'; // 'Psych', 'Wife3', 'OsuMania', 'ITG', or 'Ruthless'
// --- Timing Display Objects (Do Not Modify) ---
var td_timingText:FlxText = null;
var td_timingTween:FlxTween = null;

// --- Wife3 Judge Scale (read from Wife3 script or settings, Do Not Modify) ---
var td_judgeScale = 1.0;

// --- osu!mania OD (read from osu!mania script or settings, Do Not Modify) ---
var td_od = 8.0;

// --- ITG Window Scale (read from ITG script or settings, Do Not Modify) ---
var td_itgWindowScale = 1.0;

// --- Ruthless Perfect Window (read from Ruthless script or settings, Do Not Modify) ---
var td_ruthlessPerfectWindow = 10.0;

// ========================================
// SETTINGS LOADER
// ========================================

function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath))) {
		trace('[TimingDisplay] settings.json not found, using default values');
		return;
	}

	var value:Dynamic;

	if ((value = getModSetting('scoring_showTimingDisplay')) != null)
		td_enabled = value;

	if ((value = getModSetting('scoring_system')) != null)
		td_scoringSystem = value;

	// Load Wife3 judge scale for color thresholds
	if ((value = getModSetting('wife3_judgePreset')) != null) {
		var JUDGE_WINDOWS:Array<Float> = [4.0, 3.0, 2.0, 1.0, 0.9, 0.75, 0.6, 0.5, 0.4];
		var judgePreset:Int = Std.int(value);
		if (judgePreset >= 1 && judgePreset <= 9)
			td_judgeScale = JUDGE_WINDOWS[judgePreset - 1];
	}

	if ((value = getModSetting('wife3_judgeScale')) != null) {
		var customScale:Float = value;
		if (customScale >= 0.009 && customScale <= 4.0)
			td_judgeScale = customScale;
	}

	// Load osu!mania OD for color thresholds
	if ((value = getModSetting('osu_od')) != null) {
		var od:Float = value;
		if (od >= 0.0 && od <= 10.0)
			td_od = od;
	}

	// Load ITG window scale for color thresholds
	if ((value = getModSetting('itg_windowScale')) != null) {
		var scale:Float = value;
		if (scale >= 0.1 && scale <= 4.0)
			td_itgWindowScale = scale;
	}

	// Load Ruthless perfect window for color thresholds
	if ((value = getModSetting('ruthless_perfectWindow')) != null) {
		var window:Float = value;
		if (window >= 0.0 && window <= 25.0)
			td_ruthlessPerfectWindow = window;
	}
}

// ========================================
// TIMING DISPLAY
// ========================================

/**
 * Creates and initializes the timing display text object.
 */
function createTimingDisplay() {
	if (td_timingText != null)
		return;

	td_timingText = new FlxText(0, 0, 200, '');
	td_timingText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
	td_timingText.scrollFactor.set();
	td_timingText.borderSize = 1.5;
	td_timingText.cameras = [game.camHUD];
	td_timingText.alpha = 0;

	positionTimingDisplay();

	game.add(td_timingText);
}

/**
 * Positions the timing display text in the center of the player's strum line.
 */
function positionTimingDisplay() {
	if (td_timingText == null)
		return;

	if (game.playerStrums != null && game.playerStrums.members.length >= 4) {
		var firstStrumX = game.playerStrums.members[0].x;
		var lastStrumX = game.playerStrums.members[3].x;
		var strumWidth = game.playerStrums.members[0].width;
		var totalWidth = (lastStrumX + strumWidth) - firstStrumX;

		td_timingText.x = firstStrumX + (totalWidth / 2) - (td_timingText.width / 2);
		td_timingText.y = FlxG.height / 2;
	} else {
		td_timingText.x = FlxG.width / 2 - 100;
		td_timingText.y = FlxG.height / 2;
	}
}

/**
 * Gets the timing color based on the active scoring system.
 * Wife3: Marvelous(white) > Perfect(yellow) > Great(green) > Good(cyan) > Bad(magenta) > Miss(red)
 * OsuMania: MAX(cyan) > 300(yellow) > 200(green) > 100(blue) > 50(gray)
 * Psych: Uses default Psych Engine-style coloring.
 */
function getTimingColor(absOffset:Float):FlxColor {
	if (td_scoringSystem == 'Wife3') {
		if (absOffset <= 22.0 * td_judgeScale)
			return FlxColor.WHITE; // Marvelous
		if (absOffset <= 45.0 * td_judgeScale)
			return FlxColor.YELLOW; // Perfect
		if (absOffset <= 90.0 * td_judgeScale)
			return FlxColor.GREEN; // Great
		if (absOffset <= 135.0 * td_judgeScale)
			return FlxColor.CYAN; // Good
		if (absOffset <= 180.0 * td_judgeScale)
			return FlxColor.MAGENTA; // Bad
		return FlxColor.RED;
	}

	if (td_scoringSystem == 'OsuMania' || td_scoringSystem == 'OsuManiaV2') {
		if (absOffset <= 16.0)
			return FlxColor.CYAN; // MAX
		if (absOffset <= 64.0 - 3.0 * td_od)
			return FlxColor.YELLOW; // 300
		if (absOffset <= 97.0 - 3.0 * td_od)
			return FlxColor.GREEN; // 200
		if (absOffset <= 127.0 - 3.0 * td_od)
			return FlxColor.BLUE; // 100
		return FlxColor.GRAY; // 50
	}

	if (td_scoringSystem == 'ITG') {
		if (absOffset <= 22.5 * td_itgWindowScale)
			return FlxColor.CYAN; // Fantastic
		if (absOffset <= 45.0 * td_itgWindowScale)
			return FlxColor.YELLOW; // Excellent
		if (absOffset <= 90.0 * td_itgWindowScale)
			return FlxColor.GREEN; // Great
		if (absOffset <= 135.0 * td_itgWindowScale)
			return FlxColor.MAGENTA; // Decent
		if (absOffset <= 180.0 * td_itgWindowScale)
			return FlxColor.ORANGE; // Way Off
		return FlxColor.RED; // Miss
	} else if (td_scoringSystem == 'Ruthless') {
		if (absOffset <= td_ruthlessPerfectWindow)
			return 0xFFFFD700; // Flawless (gold)
		if (absOffset <= 20.0)
			return FlxColor.GREEN; // Precise
		if (absOffset <= 30.0)
			return 0xFF88FF00; // Great (yellow-green)
		if (absOffset <= 40.0)
			return FlxColor.CYAN; // Good
		if (absOffset <= 50.0)
			return FlxColor.YELLOW; // Ok
		if (absOffset <= 75.0)
			return FlxColor.ORANGE; // Sloppy
		if (absOffset <= 100.0)
			return FlxColor.MAGENTA; // Barely
		return FlxColor.RED; // Miss
	} else if (td_scoringSystem == 'O2Jam') {
		// Use dynamic windows from O2Jam script (supports BPM-based mode)
		var o2jamHitWindow = getVar('o2jam_getHitWindow');
		var coolW = o2jamHitWindow != null ? o2jamHitWindow('cool') : 33.0;
		var goodW = o2jamHitWindow != null ? o2jamHitWindow('good') : 67.0;
		var badW = o2jamHitWindow != null ? o2jamHitWindow('bad') : 100.0;

		if (absOffset <= coolW)
			return FlxColor.YELLOW; // COOL
		if (absOffset <= goodW)
			return FlxColor.CYAN; // GOOD
		if (absOffset <= badW)
			return FlxColor.MAGENTA; // BAD
		return FlxColor.ORANGE; // MISS
	} else if (td_scoringSystem == 'DJMAX') {
		if (absOffset <= 16.0)
			return FlxColor.CYAN; // MAX 100%
		if (absOffset <= 33.0)
			return FlxColor.YELLOW; // MAX 90%
		if (absOffset <= 66.0)
			return FlxColor.GREEN; // GOOD
		if (absOffset <= 100.0)
			return FlxColor.ORANGE; // BAD
		return FlxColor.RED; // BREAK
	} else if (td_scoringSystem == 'IIDX') {
		if (absOffset <= 16.67)
			return FlxColor.CYAN; // PGREAT
		if (absOffset <= 33.33)
			return FlxColor.YELLOW; // GREAT
		if (absOffset <= 100.0)
			return FlxColor.GREEN; // GOOD
		if (absOffset <= 180.0)
			return FlxColor.MAGENTA; // BAD
		return FlxColor.RED; // POOR
	} else if (td_scoringSystem == 'Quaver') {
		var quaverMarvWindow = getVar('quaver_marvelousWindow');
		var quaverPerfWindow = getVar('quaver_perfectWindow');
		var quaverGreatWindow = getVar('quaver_greatWindow');
		var quaverGoodWindow = getVar('quaver_goodWindow');
		if (quaverMarvWindow == null)
			quaverMarvWindow = 18.0;
		if (quaverPerfWindow == null)
			quaverPerfWindow = 43.0;
		if (quaverGreatWindow == null)
			quaverGreatWindow = 76.0;
		if (quaverGoodWindow == null)
			quaverGoodWindow = 106.0;
		if (absOffset <= quaverMarvWindow)
			return FlxColor.WHITE; // Marvelous
		if (absOffset <= quaverPerfWindow)
			return 0xFFFFE76B; // Perfect
		if (absOffset <= quaverGreatWindow)
			return 0xFF5FFF7B; // Great
		if (absOffset <= quaverGoodWindow)
			return 0xFF00EFFF; // Good
		return 0xFFF877EB; // Okay
	} else {
		if (absOffset <= 22.0)
			return FlxColor.CYAN;
		if (absOffset <= 45.0)
			return FlxColor.GREEN;
		if (absOffset <= 90.0)
			return FlxColor.YELLOW;
		if (absOffset <= 135.0)
			return FlxColor.ORANGE;
		return FlxColor.RED;
	}
}

/**
 * Displays timing feedback for a note hit with color-coded accuracy.
 * @param offset Timing offset in milliseconds (positive = late, negative = early)
 */
function showTimingFeedback(offset:Float) {
	if (!td_enabled || td_timingText == null)
		return;

	var absOffset = Math.abs(offset);
	var prefix = offset > 0 ? '+' : '';
	var roundedOffset = Math.round(offset * 100) / 100;
	var timingStr = prefix + roundedOffset + 'ms';

	var color = getTimingColor(absOffset);

	td_timingText.text = timingStr;
	td_timingText.color = color;

	if (td_timingTween != null)
		td_timingTween.cancel();

	td_timingText.alpha = 0;
	td_timingText.y = FlxG.height / 2;
	td_timingText.scale.set(1.05, 1.05);

	td_timingTween = FlxTween.tween(td_timingText, {
		alpha: 1,
		y: (FlxG.height / 2) - 15,
		'scale.x': 1,
		'scale.y': 1
	}, 0.1, {
		onComplete: function(twn:FlxTween) {
			td_timingTween = FlxTween.tween(td_timingText, {
				alpha: 0,
				y: (FlxG.height / 2) - 25
			}, 0.3, {
				startDelay: 0.3,
				onComplete: function(twn:FlxTween) {
					td_timingText.y = FlxG.height / 2;
					td_timingTween = null;
				}
			});
		}
	});
}

// ========================================
// PUBLIC API
// ========================================

/**
 * Sets whether the timing display is shown.
 * @param show Whether to show the timing display
 */
function td_setEnabled(show:Bool) {
	td_enabled = show;
	setVar('td_enabled', td_enabled);

	if (!show && td_timingText != null) {
		td_timingText.visible = false;
		if (td_timingTween != null) {
			td_timingTween.cancel();
			td_timingTween = null;
		}
	} else if (show && td_timingText != null) {
		td_timingText.visible = true;
	}
}

/**
 * Returns whether the timing display is enabled.
 * @return Current state of timing display
 */
function td_getEnabled():Bool {
	return td_enabled;
}

/**
 * Updates the scoring system the timing display uses for color coding.
 * @param system Scoring system name: 'Psych', 'Wife3', 'OsuMania', 'ITG', 'Ruthless', or 'O2Jam'
 */
function td_setScoringSystem(system:String) {
	td_scoringSystem = system;
	setVar('td_scoringSystem', td_scoringSystem);
}

/**
 * Updates the Wife3 judge scale used for color thresholds.
 * @param scale Judge scale value
 */
function td_setJudgeScale(scale:Float) {
	td_judgeScale = scale;
}

/**
 * Updates the osu!mania OD used for color thresholds.
 * @param od OD value (0-10)
 */
function td_setOD(od:Float) {
	td_od = od;
}

/**
 * Updates the ITG window scale used for color thresholds.
 * @param scale Window scale value
 */
function td_setITGWindowScale(scale:Float) {
	td_itgWindowScale = scale;
}

// ========================================
// CALLBACK REGISTRATION
// ========================================

function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['td_setEnabled', td_setEnabled],
		['td_getEnabled', td_getEnabled],
		['td_setScoringSystem', td_setScoringSystem],
		['td_setJudgeScale', td_setJudgeScale],
		['td_setOD', td_setOD],
		['td_setITGWindowScale', td_setITGWindowScale],
		['showTimingFeedback', showTimingFeedback]
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
}

function onCreatePost() {
	if (td_enabled)
		createTimingDisplay();
}

function goodNoteHit(note:Note) {
	if (!td_enabled || note.isSustainNote || !note.mustPress)
		return;

	// Calculate timing offset
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;

	showTimingFeedback(noteDiff);
}

function onDestroy() {
	if (td_timingTween != null) {
		td_timingTween.cancel();
		td_timingTween = null;
	}
}
