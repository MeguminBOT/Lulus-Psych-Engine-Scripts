/*
	>>> Custom Rating Popups for Psych Engine
		HScript-based custom rating popup system that replaces Psych Engine's
		hardcoded rating popups (sick/good/bad/shit) with custom sprites
		matching the active scoring system's judgement tiers.

		Supported Scoring Systems:
			- Psych:    sick, good, bad, shit
			- Wife3:    marvelous, perfect, great, good, bad
			- OsuMania: MAX, 300, 200, 100, 50
			- OsuManiaV2: MAX, 300, 200, 100, 50
			- ITG:      fantastic, excellent, great, decent, wayoff
			- Ruthless:  flawless, precise, great, good, ok, sloppy, barely
			- O2Jam:    cool, good, bad
			- DJMAX:    max100, max90, good, bad
			- IIDX:     pgreat, great, good, bad
			- Quaver:   marvelous, perfect, great, good

		Image Paths:
			Place rating images in: mods/YourMod/images/ratings/[system]/
			Example: images/ratings/ruthless/flawless.png

			If a custom image is not found, the popup is skipped for that tier
			(the default Psych popup is already hidden).

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================

var ratingPopups_enabled = true;
var ratingPopups_debug = false;
var ratingPopups_activeSystem = 'Psych';

// ========================================
// SETTINGS LOADER
// ========================================

function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath)))
		return;

	var value:Dynamic;

	if ((value = getModSetting('scoring_system')) != null)
		ratingPopups_activeSystem = value;

	if ((value = getModSetting('scoring_ratingPopups')) != null)
		ratingPopups_enabled = value;

	if ((value = getModSetting('scoring_debug')) != null)
		ratingPopups_debug = value;
}

// ========================================
// DEBUG HELPER
// ========================================

function debug(message:String) {
	if (!ratingPopups_debug || !ratingPopups_enabled)
		return;
	debugPrint('[Rating Popups] ' + message, FlxColor.WHITE);
}

// ========================================
// JUDGEMENT LOOKUP
// ========================================

/**
 * Gets the judgement name for the active scoring system based on timing offset.
 * Calls into each scoring system's registered callback to determine the judgement.
 *
 * @param offsetMs Absolute timing offset in milliseconds
 * @return Judgement name string (lowercase for file lookup)
 */
function getJudgementForSystem(offsetMs:Float):String {
	switch (ratingPopups_activeSystem) {
		case 'Ruthless':
			var fn = getVar('ruthless_getJudgement');
			if (fn != null)
				return fn(offsetMs);
			return getRuthlessJudgementFromWindows(offsetMs);

		case 'Wife3':
			return getWife3Judgement(offsetMs);

		case 'OsuMania':
			var fn = getVar('osu_getJudgement');
			if (fn != null)
				return fn(offsetMs);
			return getOsuJudgementFromWindows(offsetMs);

		case 'OsuManiaV2':
			var fn = getVar('osuv2_getJudgement');
			if (fn != null)
				return fn(offsetMs);
			return getOsuJudgementFromWindows(offsetMs);

		case 'ITG':
			var fn = getVar('itg_getJudgement');
			if (fn != null)
				return fn(offsetMs);
			return getItgJudgementFromWindows(offsetMs);

		case 'O2Jam':
			var fn = getVar('o2jam_getJudgement');
			if (fn != null)
				return fn(offsetMs);
			return getO2JamJudgementFromWindows(offsetMs);

		case 'DJMAX':
			var fn = getVar('djmax_getJudgement');
			if (fn != null)
				return fn(offsetMs);
			return getDJMAXJudgementFromWindows(offsetMs);

		case 'IIDX':
			var fn = getVar('iidx_getJudgement');
			if (fn != null)
				return fn(offsetMs);
			return getIIDXJudgementFromWindows(offsetMs);

		case 'Quaver':
			var fn = getVar('quaver_getJudgement');
			if (fn != null)
				return fn(offsetMs);
			return getQuaverJudgementFromWindows(offsetMs);

		default: // Psych
			return getPsychJudgement(offsetMs);
	}
}

/**
 * Wife3 doesn't have a getJudgement callback, so we build one from its timing windows.
 */
function getWife3Judgement(offsetMs:Float):String {
	var fn = getVar('wife3_getTimingWindow');
	if (fn == null)
		return getFallbackJudgement(offsetMs);

	if (offsetMs <= fn('marvelous'))
		return 'marvelous';
	if (offsetMs <= fn('perfect'))
		return 'perfect';
	if (offsetMs <= fn('great'))
		return 'great';
	if (offsetMs <= fn('good'))
		return 'good';
	return 'bad';
}

/**
 * Psych Engine default judgement lookup using game.ratingsData hit windows.
 */
function getPsychJudgement(offsetMs:Float):String {
	if (game.ratingsData != null) {
		for (rating in game.ratingsData) {
			if (rating.hitWindow != null && offsetMs <= rating.hitWindow)
				return rating.name;
		}
		// If beyond all windows, return the last rating
		if (game.ratingsData.length > 0)
			return game.ratingsData[game.ratingsData.length - 1].name;
	}
	return 'shit';
}

/**
 * Fallback for Ruthless using its window callback.
 */
function getRuthlessJudgementFromWindows(offsetMs:Float):String {
	var fn = getVar('ruthless_getTimingWindow');
	if (fn == null)
		return getPsychJudgement(offsetMs);

	if (offsetMs <= fn('flawless'))
		return 'flawless';
	if (offsetMs <= fn('precise'))
		return 'precise';
	if (offsetMs <= fn('great'))
		return 'great';
	if (offsetMs <= fn('good'))
		return 'good';
	if (offsetMs <= fn('ok'))
		return 'ok';
	if (offsetMs <= fn('sloppy'))
		return 'sloppy';
	return 'barely';
}

/**
 * Fallback for OsuMania using its window callback.
 */
function getOsuJudgementFromWindows(offsetMs:Float):String {
	var fn = getVar('osu_getHitWindow');
	if (fn == null)
		return getPsychJudgement(offsetMs);

	if (offsetMs <= fn('max'))
		return 'max';
	if (offsetMs <= fn('300'))
		return '300';
	if (offsetMs <= fn('200'))
		return '200';
	if (offsetMs <= fn('100'))
		return '100';
	return '50';
}

/**
 * Fallback for ITG using its window callback.
 */
function getItgJudgementFromWindows(offsetMs:Float):String {
	var fn = getVar('itg_getHitWindow');
	if (fn == null)
		return getPsychJudgement(offsetMs);

	if (offsetMs <= fn('fantastic'))
		return 'fantastic';
	if (offsetMs <= fn('excellent'))
		return 'excellent';
	if (offsetMs <= fn('great'))
		return 'great';
	if (offsetMs <= fn('decent'))
		return 'decent';
	return 'wayoff';
}

/**
 * Fallback for O2Jam using its window callback.
 */
function getO2JamJudgementFromWindows(offsetMs:Float):String {
	var fn = getVar('o2jam_getHitWindow');
	if (fn == null)
		return getPsychJudgement(offsetMs);

	if (offsetMs <= fn('cool'))
		return 'cool';
	if (offsetMs <= fn('good'))
		return 'good';
	return 'bad';
}

/**
 * Fallback for DJMAX using its window callback.
 */
function getDJMAXJudgementFromWindows(offsetMs:Float):String {
	var fn = getVar('djmax_getHitWindow');
	if (fn == null)
		return getPsychJudgement(offsetMs);

	if (offsetMs <= fn('max100'))
		return 'max100';
	if (offsetMs <= fn('max90'))
		return 'max90';
	if (offsetMs <= fn('good'))
		return 'good';
	return 'bad';
}

/**
 * Fallback for IIDX using its window callback.
 */
function getIIDXJudgementFromWindows(offsetMs:Float):String {
	var fn = getVar('iidx_getHitWindow');
	if (fn == null)
		return getPsychJudgement(offsetMs);

	if (offsetMs <= fn('pgreat'))
		return 'pgreat';
	if (offsetMs <= fn('great'))
		return 'great';
	if (offsetMs <= fn('good'))
		return 'good';
	return 'bad';
}

/**
 * Fallback for Quaver using its window callback.
 */
function getQuaverJudgementFromWindows(offsetMs:Float):String {
	var fn = getVar('quaver_getHitWindow');
	if (fn == null)
		return getPsychJudgement(offsetMs);

	if (offsetMs <= fn('marvelous'))
		return 'marvelous';
	if (offsetMs <= fn('perfect'))
		return 'perfect';
	if (offsetMs <= fn('great'))
		return 'great';
	return 'good';
}

// ========================================
// IMAGE PATH LOOKUP
// ========================================

/**
 * Gets the image path for a judgement popup based on the active scoring system.
 * Looks in: images/ratings/[system]/[judgement]
 *
 * @param judgement Judgement name from the scoring system
 * @return Image path string for Paths.image(), or null if not found
 */
function getPopupImagePath(judgement:String):String {
	var system = ratingPopups_activeSystem.toLowerCase();
	// Normalize judgement name to lowercase for file paths
	var normalized = StringTools.replace(judgement.toLowerCase(), ' ', '');
	return 'ratings/' + system + '/' + normalized;
}

// ========================================
// POPUP CREATION
// ========================================

/**
 * Spawns a custom rating popup sprite that mimics Psych Engine's default behavior
 * (position, velocity, acceleration, fade-out timing) but uses a custom image.
 *
 * @param judgement Judgement name string
 */
function spawnPopup(judgement:String) {
	var imagePath = getPopupImagePath(judgement);

	// Check if custom image exists before creating the sprite
	var fullPath = Paths.image(imagePath);
	if (fullPath == null) {
		debug('No image found for: ' + imagePath);
		return;
	}

	var placement = FlxG.width * 0.35;
	var popup = new FlxSprite();

	popup.loadGraphic(fullPath);
	popup.screenCenter();
	popup.x = placement - 40;
	popup.y = popup.y - 60;
	popup.acceleration.y = 550 * game.playbackRate * game.playbackRate;
	popup.velocity.y = -FlxG.random.int(140, 175) * game.playbackRate;
	popup.velocity.x = -FlxG.random.int(0, 10) * game.playbackRate;
	popup.x = popup.x + ClientPrefs.data.comboOffset[0];
	popup.y = popup.y - ClientPrefs.data.comboOffset[1];
	popup.antialiasing = ClientPrefs.data.antialiasing;
	popup.visible = !ClientPrefs.data.hideHud;

	if (!PlayState.isPixelStage)
		popup.setGraphicSize(Std.int(popup.width * 0.7));
	else
		popup.setGraphicSize(Std.int(popup.width * PlayState.daPixelZoom * 0.85));

	popup.updateHitbox();
	popup.cameras = [game.camHUD];

	game.comboGroup.add(popup);

	FlxTween.tween(popup, {alpha: 0}, 0.2 / game.playbackRate, {
		onComplete: function(tween:FlxTween) {
			popup.destroy();
		},
		startDelay: Conductor.crochet * 0.001 / game.playbackRate
	});

	debug('Popup: ' + judgement + ' (' + imagePath + ')');
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	loadSettings();

	if (!ratingPopups_enabled || ratingPopups_activeSystem == 'Psych')
		return;

	// Hide default rating popup (sprite still created but invisible)
	game.showRating = false;

	debug('Custom rating popups enabled for: ' + ratingPopups_activeSystem);
}

function goodNoteHit(note:Note) {
	if (!ratingPopups_enabled || ratingPopups_activeSystem == 'Psych')
		return;

	if (note.isSustainNote || !note.mustPress)
		return;

	// Calculate timing offset (same method as scoring systems)
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;
	var offsetMs = Math.abs(noteDiff);

	var judgement = getJudgementForSystem(offsetMs);
	spawnPopup(judgement);
}
