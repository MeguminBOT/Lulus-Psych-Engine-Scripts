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
			- IIDX:     pgreat, great, good, bad, awful
			- Quaver:   marvelous, perfect, great, good

		Image Paths (Individual Images):
			Place rating images in: mods/YourMod/images/ratings/[system]/
			Example: images/ratings/ruthless/flawless.png

			Individual images take priority over spritesheets.
			If neither an individual image nor a spritesheet animation is found,
			the popup is skipped for that tier (the default Psych popup
			is already hidden).

		Spritesheet (Animated Popups):
			Place a Sparrow atlas spritesheet in: mods/YourMod/images/ratings/[system]/
			Filename must be: spritesheet.png + spritesheet.xml
			Example: images/ratings/ruthless/spritesheet.png
			         images/ratings/ruthless/spritesheet.xml

			Animation prefixes in the XML must match the judgement names.
			Example prefixes for Ruthless: flawless, precise, great, good, ok, sloppy, barely

			Numeric Name Handling:
				osu!mania's numeric judgements (300, 200, 100, 50) are
				automatically mapped to spelled-out names for both individual
				images and spritesheet prefixes:
					300 → threehundred
					200 → twohundred
					100 → hundred
					50  → fifty
					max → max (unchanged)
				Example files: threehundred.png, or spritesheet prefix 'threehundred'.

			All spritesheet popups are auto-centered using centerOffsets() so
			frames with different dimensions still appear aligned.

			Individual images override the spritesheet per judgement.
			For example, if both flawless.png and a 'flawless' animation exist
			in the spritesheet, the individual flawless.png is used.

		Theme Settings (theme.json):
			Place a theme.json in: images/ratings/[system]/theme.json

			Controls per-system visual settings and per-judgement offsets.

			Format:
				{
					"antialiasing": true,
					"offsets": {
						"flawless": [10, -5],
						"precise":  [0, 0],
						"great":    [-3, 2]
					}
				}

			Fields:
				antialiasing  - Default antialiasing for this system's popups.
				                Only used when the setting is set to "Theme Default".
				offsets       - Per-judgement [x, y] position adjustments.
				                Applied after positioning. Works for both
				                individual images and spritesheet animations.

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
import tjson.TJSON;
import Reflect;

// ========================================
// CONFIGURATION & VARIABLES
// ========================================

var ratingPopups_enabled = true;
var ratingPopups_debug = false;
var ratingPopups_activeSystem = 'Psych';
var ratingPopups_scale = 1.0;
var ratingPopups_antialiasing = 'ClientPrefs';
var ratingPopups_themeAA = true;
var ratingPopups_spritesheetFrames = null;
var ratingPopups_offsets = null;
var ratingPopups_graphicCache = null;

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

	if ((value = getModSetting('scoring_ratingScale')) != null)
		ratingPopups_scale = value;

	if ((value = getModSetting('scoring_ratingAntialiasing')) != null)
		ratingPopups_antialiasing = value;

	if ((value = getModSetting('scoring_debug')) != null)
		ratingPopups_debug = value;
}

// ========================================
// ANTIALIASING RESOLVER
// ========================================

/**
 * Resolves the antialiasing value based on the user's setting.
 *
 * @return true/false for antialiasing
 */
function resolveAntialiasing():Bool {
	switch (ratingPopups_antialiasing) {
		case 'Theme Default': return ratingPopups_themeAA;
		case 'On': return true;
		case 'Off': return false;
		default: return ClientPrefs.data.antialiasing;
	}
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
	if (offsetMs <= fn('bad'))
		return 'bad';
	return 'awful';
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
// ASSET NAME MAPPING
// ========================================

/**
 * Returns an asset-safe name for a judgement.
 * osu!mania's numeric judgements (300, 200, 100, 50) are spelled out
 * to avoid conflicts with Sparrow XML's frame-numbering convention.
 *
 * Mapping: 300 → threehundred, 200 → twohundred, 100 → hundred, 50 → fifty
 *
 * Used for both individual image filenames and spritesheet prefixes.
 *
 * @param normalized Lowercase, space-stripped judgement name
 * @return Asset-safe name string
 */
function getAssetName(normalized:String):String {
	switch (normalized) {
		case '300': return 'threehundred';
		case '200': return 'twohundred';
		case '100': return 'hundred';
		case '50': return 'fifty';
		default: return normalized;
	}
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
	var assetName = getAssetName(normalized);
	return 'ratings/' + system + '/' + assetName;
}

// ========================================
// SPRITESHEET LOADER
// ========================================

/**
 * Detects and caches a Sparrow atlas spritesheet for the active scoring system.
 * Looks for: images/ratings/[system]/spritesheet.png + .xml
 *
 * Called once in onCreate(). The cached frames are shared across all popup sprites.
 */
function loadSpritesheet() {
	var system = ratingPopups_activeSystem.toLowerCase();
	var sheetPath = 'ratings/' + system + '/spritesheet';

	// Load theme settings (offsets, antialiasing)
	var themePath = Paths.modFolders('images/ratings/' + system + '/theme.json');
	if (FileSystem.exists(themePath)) {
		var theme = TJSON.parse(File.getContent(themePath));
		if (Reflect.hasField(theme, 'offsets'))
			ratingPopups_offsets = Reflect.field(theme, 'offsets');
		if (Reflect.hasField(theme, 'antialiasing'))
			ratingPopups_themeAA = Reflect.field(theme, 'antialiasing');
		debug('Theme loaded: ' + themePath);
	}

	var xmlPath = Paths.modFolders('images/' + sheetPath + '.xml');
	if (!FileSystem.exists(xmlPath)) {
		debug('No spritesheet XML at: ' + xmlPath);
		return; 
	}

	ratingPopups_spritesheetFrames = Paths.getSparrowAtlas(sheetPath);
	debug('Spritesheet loaded: ' + sheetPath);
}

/**
 * Returns the list of judgement names for the active scoring system.
 * Used to pre-cache individual image graphics at startup.
 */
function getSystemJudgements():Array<String> {
	switch (ratingPopups_activeSystem) {
		case 'Wife3': return ['marvelous', 'perfect', 'great', 'good', 'bad'];
		case 'OsuMania': return ['max', '300', '200', '100', '50'];
		case 'OsuManiaV2': return ['max', '300', '200', '100', '50'];
		case 'ITG': return ['fantastic', 'excellent', 'great', 'decent', 'wayoff'];
		case 'Ruthless': return ['flawless', 'precise', 'great', 'good', 'ok', 'sloppy', 'barely'];
		case 'O2Jam': return ['cool', 'good', 'bad'];
		case 'DJMAX': return ['max100', 'max90', 'good', 'bad'];
		case 'IIDX': return ['pgreat', 'great', 'good', 'bad', 'awful'];
		case 'Quaver': return ['marvelous', 'perfect', 'great', 'good'];
		default: return ['sick', 'good', 'bad', 'shit'];
	}
}

/**
 * Pre-caches individual image graphics for all judgements at startup.
 * Avoids file lookups during gameplay.
 */
function cacheGraphics() {
	ratingPopups_graphicCache = new haxe.ds.StringMap();
	var system = ratingPopups_activeSystem.toLowerCase();
	var judgements = getSystemJudgements();

	for (j in judgements) {
		var assetName = getAssetName(j);
		var path = 'ratings/' + system + '/' + assetName;
		var graphic = Paths.image(path);
		if (graphic != null) {
			ratingPopups_graphicCache.set(assetName, graphic);
			debug('Cached graphic: ' + path);
		}
	}
}

// ========================================
// POPUP CREATION
// ========================================

/**
 * Spawns a custom rating popup sprite that mimics Psych Engine's default behavior
 * (position, velocity, acceleration, fade-out timing) but uses a custom image
 * or an animated spritesheet frame.
 *
 * Priority: individual image > spritesheet animation > skip
 *
 * @param judgement Judgement name string
 */
function spawnPopup(judgement:String) {
	var normalized = StringTools.replace(judgement.toLowerCase(), ' ', '');
	var assetName = getAssetName(normalized);

	// Clear old popups when comboStacking is disabled
	if (!ClientPrefs.data.comboStacking && game.comboGroup.members.length > 0) {
		for (spr in game.comboGroup) {
			if (spr == null) continue;
			game.comboGroup.remove(spr);
			spr.destroy();
		}
	}

	var placement = FlxG.width * 0.35;
	var popup = new FlxSprite();
	var isAnimated = false;

	// Priority 1: Cached individual image (no file lookup during gameplay)
	var cachedGraphic = ratingPopups_graphicCache != null ? ratingPopups_graphicCache.get(assetName) : null;
	if (cachedGraphic != null) {
		popup.loadGraphic(cachedGraphic);
		debug('Popup (cached image): ' + judgement + ' (' + assetName + ')');
	}
	// Priority 2: Spritesheet animation
	else if (ratingPopups_spritesheetFrames != null) {
		popup.frames = ratingPopups_spritesheetFrames;
		popup.animation.addByPrefix(assetName, assetName, 24, false);
		if (popup.animation.getByName(assetName) == null) {
			popup.destroy();
			debug('No animation prefix "' + assetName + '" in spritesheet');
			return;
		}
		popup.animation.play(assetName, true);
		isAnimated = true;
		debug('Popup (spritesheet): ' + judgement + ' (' + assetName + ')');
	}
	// Nothing found
	else {
		debug('No graphic found for: ' + assetName);
		return;
	}

	// Auto-center spritesheet popups so different frame sizes stay aligned
	if (isAnimated) {
		popup.centerOffsets();
		popup.centerOrigin();
	}

	popup.screenCenter();
	popup.x = placement - 40;
	popup.y = popup.y - 60;
	popup.acceleration.y = 550 * game.playbackRate * game.playbackRate;
	popup.velocity.y = -FlxG.random.int(140, 175) * game.playbackRate;
	popup.velocity.x = -FlxG.random.int(0, 10) * game.playbackRate;
	popup.x = popup.x + ClientPrefs.data.comboOffset[0];
	popup.y = popup.y - ClientPrefs.data.comboOffset[1];

	// Apply per-judgement offset from offsets.json
	if (ratingPopups_offsets != null) {
		var off = Reflect.field(ratingPopups_offsets, assetName);
		if (off != null) {
			popup.x = popup.x + off[0];
			popup.y = popup.y + off[1];
		}
	}

	popup.antialiasing = resolveAntialiasing();
	popup.visible = !ClientPrefs.data.hideHud;

	if (!PlayState.isPixelStage)
		popup.setGraphicSize(Std.int(popup.width * 1 * ratingPopups_scale));
	else
		popup.setGraphicSize(Std.int(popup.width * PlayState.daPixelZoom * 0.25 * ratingPopups_scale));

	popup.updateHitbox();
	popup.cameras = [game.camHUD];

	game.comboGroup.add(popup);

	FlxTween.tween(popup, {alpha: 0}, 0.2 / game.playbackRate, {
		onComplete: function(tween:FlxTween) {
			game.comboGroup.remove(popup);
			popup.destroy();
		},
		startDelay: Conductor.crochet * 0.001 / game.playbackRate
	});
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

	loadSpritesheet();
	cacheGraphics();

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
