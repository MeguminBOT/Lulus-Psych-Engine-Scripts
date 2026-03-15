/*
	>>> Hit Error Bar for Psych Engine
		HScript-based hit error bar that displays timing accuracy for note hits.
		Similar to osu!'s HitError implementation with a horizontal bar
		showing early/late timing windows color-coded per scoring system.

		Automatically detects the active scoring system and uses its
		timing windows and colors to build the error bar segments.

		Supported Scoring Systems:
			- Wife3:      marvelous, perfect, great, good, bad
			- OsuMania:   MAX, 300, 200, 100, 50
			- OsuManiaV2: MAX, 300, 200, 100, 50
			- ITG:        fantastic, excellent, great, decent, wayoff
			- Ruthless:   flawless, precise, great, good, ok, sloppy, barely
			- O2Jam:      cool, good, bad
			- DJMAX:      max100, max90, good, bad
			- IIDX:       pgreat, great, good, bad
			- Quaver:     marvelous, perfect, great, good, okay
			- Psych:      sick, good, bad (default)

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */

// ========================================
// CONFIGURATION & VARIABLES
// ========================================

var heb_enabled = true;
var heb_scoringSystem = 'Psych';

// --- Bar dimensions ---
var heb_barWidth = 400;
var heb_barHeight = 4;
var heb_markerHeight = 16;
var heb_markerWidth = 2;
var heb_maxMarkers = 100;
var heb_bgAlpha = 0.25;

// --- Timing ---
var heb_fadeInDuration = 0.1;
var heb_fadeOutDuration = 3.0;
var heb_quickFadeOutDuration = 1.0;

// --- Display options ---
var heb_simpleColors = false;

// --- Scaling params from scoring systems ---
var heb_judgeScale = 1.0;
var heb_od = 8.0;
var heb_itgWindowScale = 1.0;
var heb_ruthlessPerfectWindow = 10.0;

// --- Internal ---
var heb_baseX = 0.0;
var heb_baseY = 0.0;
var heb_allSprites = [];
var heb_markerPool = [];
var heb_poolIndex = 0;
var heb_maxHitWindow = 135.0;
var heb_timingAverage = 0.0;

// ========================================
// SETTINGS LOADER
// ========================================

function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath)))
		return;

	var value:Dynamic;

	if ((value = getModSetting('scoring_showHitErrorBar')) != null)
		heb_enabled = value;

	if ((value = getModSetting('scoring_hitErrorBarWidth')) != null) {
		var w:Int = Std.int(value);
		if (w >= 100 && w <= 800)
			heb_barWidth = w;
	}

	if ((value = getModSetting('scoring_hitErrorBarBgAlpha')) != null) {
		var a:Int = Std.int(value);
		if (a >= 0 && a <= 100)
			heb_bgAlpha = a / 100.0;
	}

	if ((value = getModSetting('scoring_hitErrorBarSimpleColors')) != null)
		heb_simpleColors = value;

	if ((value = getModSetting('scoring_system')) != null)
		heb_scoringSystem = value;

	if ((value = getModSetting('wife3_judgePreset')) != null) {
		var JUDGE_WINDOWS:Array<Float> = [4.0, 3.0, 2.0, 1.0, 0.9, 0.75, 0.6, 0.5, 0.4];
		var judgePreset:Int = Std.int(value);
		if (judgePreset >= 1 && judgePreset <= 9)
			heb_judgeScale = JUDGE_WINDOWS[judgePreset - 1];
	}

	if ((value = getModSetting('wife3_judgeScale')) != null) {
		var customScale:Float = value;
		if (customScale >= 0.009 && customScale <= 4.0)
			heb_judgeScale = customScale;
	}

	if ((value = getModSetting('osu_od')) != null) {
		var od:Float = value;
		if (od >= 0.0 && od <= 10.0)
			heb_od = od;
	}

	if ((value = getModSetting('itg_windowScale')) != null) {
		var scale:Float = value;
		if (scale >= 0.1 && scale <= 4.0)
			heb_itgWindowScale = scale;
	}

	if ((value = getModSetting('ruthless_perfectWindow')) != null) {
		var window:Float = value;
		if (window >= 0.0 && window <= 15.0)
			heb_ruthlessPerfectWindow = window;
	}
}

// ========================================
// TIMING WINDOWS
// ========================================

/**
 * Returns the timing windows for the active scoring system.
 * Each entry: { window: ms, color: FlxColor }
 * Ordered from tightest to widest. The widest window is the max hit window.
 */
function getTimingWindows():Array<Dynamic> {
	switch (heb_scoringSystem) {
		case 'Wife3':
			return [
				{window: 22.0 * heb_judgeScale, color: FlxColor.WHITE},
				{window: 45.0 * heb_judgeScale, color: FlxColor.YELLOW},
				{window: 90.0 * heb_judgeScale, color: FlxColor.GREEN},
				{window: 135.0 * heb_judgeScale, color: FlxColor.CYAN},
				{window: 180.0 * heb_judgeScale, color: FlxColor.MAGENTA}
			];

		case 'OsuMania', 'OsuManiaV2':
			return [
				{window: 64.0 - 3.0 * heb_od, color: FlxColor.CYAN},
				{window: 97.0 - 3.0 * heb_od, color: FlxColor.LIME},
				{window: 127.0 - 3.0 * heb_od, color: FlxColor.ORANGE}
			];

		case 'ITG':
			return [
				{window: 21.5 * heb_itgWindowScale, color: FlxColor.CYAN},
				{window: 43.0 * heb_itgWindowScale, color: FlxColor.YELLOW},
				{window: 102.0 * heb_itgWindowScale, color: FlxColor.GREEN},
				{window: 135.0 * heb_itgWindowScale, color: FlxColor.MAGENTA},
				{window: 180.0 * heb_itgWindowScale, color: FlxColor.ORANGE}
			];

		case 'Ruthless':
			return [
				{window: heb_ruthlessPerfectWindow, color: 0xFFE6FFFF},
				{window: 20.0, color: 0xFF7DF9FF},
				{window: 30.0, color: 0xFF4CFF6A},
				{window: 40.0, color: 0xFF00CC44},
				{window: 50.0, color: 0xFFFFE066},
				{window: 75.0, color: 0xFFFF9A3D},
				{window: 100.0, color: 0xFFFF4DB8}
			];

		case 'O2Jam':
			var o2jamHitWindow = getVar('o2jam_getHitWindow');
			var coolW = o2jamHitWindow != null ? o2jamHitWindow('cool') : 33.0;
			var goodW = o2jamHitWindow != null ? o2jamHitWindow('good') : 67.0;
			var badW = o2jamHitWindow != null ? o2jamHitWindow('bad') : 100.0;
			return [
				{window: coolW, color: FlxColor.YELLOW},
				{window: goodW, color: FlxColor.CYAN},
				{window: badW, color: FlxColor.MAGENTA}
			];

		case 'DJMAX':
			return [
				{window: 16.0, color: FlxColor.CYAN},
				{window: 33.0, color: FlxColor.YELLOW},
				{window: 66.0, color: FlxColor.GREEN},
				{window: 100.0, color: FlxColor.ORANGE}
			];

		case 'IIDX':
			return [
				{window: 16.67, color: FlxColor.CYAN},
				{window: 33.33, color: FlxColor.YELLOW},
				{window: 66.67, color: FlxColor.GREEN},
				{window: 100.0, color: FlxColor.BLUE}
			];

		case 'Quaver':
			var quaverGetWindow = getVar('quaver_getHitWindow');
			var marvW = quaverGetWindow != null ? quaverGetWindow('marvelous') : 18.0;
			var perfW = quaverGetWindow != null ? quaverGetWindow('perfect') : 43.0;
			var greatW = quaverGetWindow != null ? quaverGetWindow('great') : 76.0;
			var goodW = quaverGetWindow != null ? quaverGetWindow('good') : 106.0;
			var okayW = quaverGetWindow != null ? quaverGetWindow('okay') : 127.0;
			return [
				{window: marvW, color: FlxColor.WHITE},
				{window: perfW, color: 0xFFFFE76B},
				{window: greatW, color: 0xFF5FFF7B},
				{window: goodW, color: 0xFF00EFFF},
				{window: okayW, color: 0xFFF877EB}
			];

		default: // Psych
			return [
				{window: ClientPrefs.data.sickWindow, color: FlxColor.CYAN},
				{window: ClientPrefs.data.goodWindow, color: FlxColor.LIME},
				{window: ClientPrefs.data.badWindow, color: FlxColor.ORANGE}
			];
	}
}

/**
 * Collapses any window set into 3 tiers (CYAN/LIME/ORANGE) using the first, middle, and last windows.
 * Keeps each system's actual ms values but standardizes colors to match osu!'s 3-color look.
 */
function simplifyWindows(windows:Array<Dynamic>):Array<Dynamic> {
	if (windows.length <= 3) {
		var colors = [FlxColor.CYAN, FlxColor.LIME, FlxColor.ORANGE];
		var result = [];
		for (i in 0...windows.length) {
			result.push({window: windows[i].window, color: colors[i]});
		}
		return result;
	}
	var mid = Std.int((windows.length - 1) / 2);
	return [
		{window: windows[0].window, color: FlxColor.CYAN},
		{window: windows[mid].window, color: FlxColor.LIME},
		{window: windows[windows.length - 1].window, color: FlxColor.ORANGE}
	];
}

/**
 * Gets the color for a timing offset based on the active scoring system's windows.
 */
function getColorForOffset(absOffset:Float):Int {
	var windows = getTimingWindows();
	if (heb_simpleColors)
		windows = simplifyWindows(windows);
	for (w in windows) {
		if (absOffset <= w.window)
			return w.color;
	}
	return FlxColor.WHITE;
}

// ========================================
// BAR CREATION
// ========================================

/**
 * Builds the hit error bar: mirrored color segments, center marker, labels, and marker pool.
 */
function createHitErrorBar() {
	var windows = getTimingWindows();
	if (heb_simpleColors)
		windows = simplifyWindows(windows);
	if (windows.length == 0)
		return;

	heb_maxHitWindow = windows[windows.length - 1].window;
	var halfWidth = heb_barWidth / 2.0;

	// Base position: centered on player strum lane (works for both normal and middlescroll)
	var barCenterX = FlxG.width * 0.5;
	if (game.playerStrums != null && game.playerStrums.members.length >= 4) {
		var firstStrumX = game.playerStrums.members[0].x;
		var lastStrumX = game.playerStrums.members[3].x;
		var strumWidth = game.playerStrums.members[0].width;
		var totalWidth = (lastStrumX + strumWidth) - firstStrumX;
		barCenterX = firstStrumX + (totalWidth / 2);
	}
	heb_baseX = barCenterX - heb_barWidth * 0.5;
	heb_baseY = FlxG.height - 30;
	var barY = heb_baseY + 8.0;

	// Transparent background
	if (heb_bgAlpha > 0) {
		var bg = new FlxSprite(heb_baseX - 40, heb_baseY - 4);
		bg.makeGraphic(Std.int(heb_barWidth + 80), Std.int(heb_markerHeight + 16), FlxColor.BLACK);
		bg.scrollFactor.set();
		bg.cameras = [game.camOther];
		bg.alpha = heb_bgAlpha;
		game.add(bg);
		heb_allSprites.push(bg);
	}

	// Build mirrored color bar segments (integer pixel boundaries to avoid gaps)
	var prevEdge = 0;
	for (w in windows) {
		var curEdge = Std.int(Math.round((w.window / heb_maxHitWindow) * halfWidth));
		var segmentPixels = curEdge - prevEdge;

		if (segmentPixels < 1)
			segmentPixels = 1;

		// Late side (right of center)
		var lateX = heb_baseX + halfWidth + prevEdge;
		var barLate = new FlxSprite(lateX, barY);
		barLate.makeGraphic(segmentPixels, heb_barHeight, w.color);
		barLate.scrollFactor.set();
		barLate.cameras = [game.camOther];
		game.add(barLate);
		heb_allSprites.push(barLate);

		// Early side (left of center, mirrored)
		var earlyX = heb_baseX + halfWidth - curEdge;
		var barEarly = new FlxSprite(earlyX, barY);
		barEarly.makeGraphic(segmentPixels, heb_barHeight, w.color);
		barEarly.scrollFactor.set();
		barEarly.cameras = [game.camOther];
		game.add(barEarly);
		heb_allSprites.push(barEarly);

		prevEdge = curEdge;
	}

	// Window boundary labels — show ms value at each window edge above the bar (both sides)
	var heb_labelIndex = 0;
	for (w in windows) {
		var boundaryFrac = (w.window / heb_maxHitWindow) * 0.5;
		var msVal = Std.int(Math.round(w.window));
		var msStr = '' + msVal + 'ms';
		var lblW = 40;
		var lblY = barY - 14 - (heb_labelIndex % 2) * 12;

		// Late side (right of center)
		var latePixel = heb_baseX + halfWidth + boundaryFrac * heb_barWidth;
		var lblLate = new FlxText(latePixel - lblW * 0.5, lblY, lblW, msStr, 8);
		lblLate.setFormat(Paths.font('vcr.ttf'), 8, w.color, 'center');
		lblLate.borderColor = FlxColor.BLACK;
		lblLate.borderSize = 1;
		lblLate.scrollFactor.set();
		lblLate.cameras = [game.camOther];
		game.add(lblLate);
		heb_allSprites.push(lblLate);
		FlxTween.tween(lblLate, {alpha: 0}, 2.0, {startDelay: 1.0});

		// Early side (left of center, mirrored)
		var earlyPixel = heb_baseX + halfWidth - boundaryFrac * heb_barWidth;
		var lblEarly = new FlxText(earlyPixel - lblW * 0.5, lblY, lblW, msStr, 8);
		lblEarly.setFormat(Paths.font('vcr.ttf'), 8, w.color, 'center');
		lblEarly.borderColor = FlxColor.BLACK;
		lblEarly.borderSize = 1;
		lblEarly.scrollFactor.set();
		lblEarly.cameras = [game.camOther];
		game.add(lblEarly);
		heb_allSprites.push(lblEarly);
		FlxTween.tween(lblEarly, {alpha: 0}, 2.0, {startDelay: 1.0});

		heb_labelIndex = heb_labelIndex + 1;
	}

	// Center marker
	var centerMarker = new FlxSprite(heb_baseX + halfWidth - 1, barY - 2);
	centerMarker.makeGraphic(2, heb_barHeight + 4, FlxColor.WHITE);
	centerMarker.scrollFactor.set();
	centerMarker.cameras = [game.camOther];
	game.add(centerMarker);
	heb_allSprites.push(centerMarker);

	// Early / Late labels
	var earlyLabel = new FlxText(heb_baseX - 35, barY - 3, 0, 'Early', 10);
	earlyLabel.setFormat(Paths.font('vcr.ttf'), 10, FlxColor.WHITE, 'center');
	earlyLabel.scrollFactor.set();
	earlyLabel.cameras = [game.camOther];
	game.add(earlyLabel);
	heb_allSprites.push(earlyLabel);
	FlxTween.tween(earlyLabel, {alpha: 0}, 2.0, {startDelay: 1.0});

	var lateLabel = new FlxText(heb_baseX + heb_barWidth + 5, barY - 3, 0, 'Late', 10);
	lateLabel.setFormat(Paths.font('vcr.ttf'), 10, FlxColor.WHITE, 'center');
	lateLabel.scrollFactor.set();
	lateLabel.cameras = [game.camOther];
	game.add(lateLabel);
	heb_allSprites.push(lateLabel);
	FlxTween.tween(lateLabel, {alpha: 0}, 2.0, {startDelay: 1.0});

	// Pre-allocate marker pool
	for (i in 0...heb_maxMarkers) {
		var marker = new FlxSprite();
		marker.makeGraphic(heb_markerWidth, heb_markerHeight, FlxColor.WHITE);
		marker.scrollFactor.set();
		marker.cameras = [game.camOther];
		marker.alpha = 0;
		marker.kill();
		heb_markerPool.push(marker);
	}
}

// ========================================
// HIT RECORDING
// ========================================

/**
 * Records a note hit and spawns a marker on the error bar.
 * @param timeOffset Timing offset in milliseconds (negative = early, positive = late)
 */
function addHit(timeOffset:Float) {
	if (!heb_enabled || heb_markerPool.length == 0)
		return;

	var maxWindow = heb_maxHitWindow;
	var clampedOffset = Math.max(-maxWindow, Math.min(timeOffset, maxWindow));

	// Exponential moving average
	heb_timingAverage = heb_timingAverage * 0.9 + clampedOffset * 0.1;
	heb_timingAverage = Math.max(-maxWindow, Math.min(heb_timingAverage, maxWindow));

	// Map offset to bar position (0.0 = left edge, 1.0 = right edge)
	var barPosition = ((clampedOffset / maxWindow) + 1) * 0.5;
	var markerColor = getColorForOffset(Math.abs(clampedOffset));

	// Get next marker from pool
	var marker = heb_markerPool[heb_poolIndex];
	heb_poolIndex = (heb_poolIndex + 1) % heb_maxMarkers;

	FlxTween.cancelTweensOf(marker);

	marker.revive();
	marker.x = heb_baseX + barPosition * heb_barWidth - 1;
	marker.y = heb_baseY;
	marker.color = markerColor;
	marker.alpha = 0;
	game.add(marker);

	// Fade in then fade out
	FlxTween.tween(marker, {alpha: 0.5}, heb_fadeInDuration, {
		ease: FlxEase.expoOut,
		onComplete: function(_) {
			FlxTween.tween(marker, {alpha: 0}, heb_fadeOutDuration, {
				ease: FlxEase.quadIn,
				onComplete: function(_) {
					marker.kill();
				}
			});
		}
	});
}

/**
 * Clears all markers (called on restart/seek).
 */
function clearHitData() {
	for (marker in heb_markerPool) {
		if (marker != null && marker.alive) {
			FlxTween.cancelTweensOf(marker);
			marker.kill();
		}
	}
	heb_poolIndex = 0;
	heb_timingAverage = 0;
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	loadSettings();
}

function onCreatePost() {
	if (!heb_enabled)
		return;

	createHitErrorBar();

	// Hide time bar, move time text to bottom-left corner
	if (game.timeBar != null)
		game.timeBar.visible = false;

	if (game.timeTxt != null) {
		game.timeTxt.x = 10;
		game.timeTxt.y = FlxG.height - 30;
		game.timeTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE);
		game.timeTxt.borderColor = FlxColor.BLACK;
		game.timeTxt.borderSize = 1.25;
		game.timeTxt.fieldWidth = 300;
	}

	// Expose API for other scripts
	setVar('heb_addHit', addHit);
	setVar('heb_clearHitData', clearHitData);
}

function goodNoteHit(note:Note) {
	if (!heb_enabled || !note.mustPress || note.isSustainNote)
		return;

	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;

	addHit(noteDiff);
}

function onDestroy() {
	// Cancel all active tweens on pooled markers
	for (marker in heb_markerPool) {
		if (marker != null)
			FlxTween.cancelTweensOf(marker);
	}
	heb_markerPool = [];
	heb_allSprites = [];
}
