/*
	Hidden Modifier for Psych Engine
	--------------------------------
	Notes fade out before reaching the strumline, increasing in coverage with combo.
	Inspired by osu!mania's Hidden mod.
	Source: https://github.com/ppy/osu/blob/master/osu.Game.Rulesets.Mania/Mods/ManiaModHidden.cs

	Features:
	- Two modes:
		- Dynamic Coverage: Fade distance increases with combo (osu!mania style)
		- Static Coverage: Constant fade distance. Never changing.

	- Settings.json support (when using "Lulu's Feature Pack")
		- Configure settings through the mod settings menu
		- Settings from settings.json override the default values in the script

	Usage:
	- Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.
	- Edit the config variables at the top, or use the mod settings menu if available.

	Script by AutisticLulu.
*/
// ========================================
// CONFIGURATION & VARIABLES
// ========================================
import flixel.util.FlxGradient;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.math.FlxRect;

// --- General Settings ---
var hiddenMod_enabled = false;
var hiddenMod_dynamicCoverage = true;
var hiddenMod_mode = 'Gradient'; // 'Gradient' or 'FadeOut'

// Dynamic coverage settings (in pixels from strumline)
// Scaled from osu!mania (160/400) for Psych Engine's 720px height (vs mania's 768px)
// Original mania values × (720/768) = × 0.9375
var hiddenMod_dynMinCoverage = 150.0;
var hiddenMod_dynMaxCoverage = 375.0;
var hiddenMod_dynCoverageIncreasePerCombo = 0.5;

// Static coverage settings (in pixels from strumline)
var hiddenMod_staticCoverage = 200.0;

// Gradient settings
var hiddenMod_gradientHeight = 300.0; // Height of the gradient overlay
var hiddenMod_gradientTransparentFraction = 0.66; // Portion of the gradient reserved for the fade (0-1)

// --- Internal Variables (DO NOT MODIFY) ---
var currentCoverage = 0.0;
var fadeStartDistance = 0.0;
var fadeEndDistance = 0.0;
var lastCoverage = -1.0;
// Gradient sprites (created once, reused)
var gradientPlayer:FlxSprite = null;
var gradientOpponent:FlxSprite = null;
var gradientMaxHeight:Float = 800.0; // Pre-create at max size to avoid recreation

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
		trace('[Hidden Modifier] settings.json not found, using default values from script');
		return;
	}
	trace('[Hidden Modifier] settings.json found, loading settings...');

	var value:Dynamic;

	if ((value = getModSetting('hiddenMod_enabled')) != null)
		hiddenMod_enabled = value;

	if ((value = getModSetting('hiddenMod_dynamicCoverage')) != null)
		hiddenMod_dynamicCoverage = value;

	if ((value = getModSetting('hiddenMod_mode')) != null)
		hiddenMod_mode = value;

	if ((value = getModSetting('hiddenMod_dynMinCoverage')) != null)
		hiddenMod_dynMinCoverage = FlxMath.bound(value, 100.0, 300.0);

	if ((value = getModSetting('hiddenMod_dynMaxCoverage')) != null)
		hiddenMod_dynMaxCoverage = FlxMath.bound(value, 200.0, 500.0);

	if ((value = getModSetting('hiddenMod_dynCoverageIncreasePerCombo')) != null)
		hiddenMod_dynCoverageIncreasePerCombo = FlxMath.bound(value, 0.0, 5.0);

	if ((value = getModSetting('hiddenMod_staticCoverage')) != null)
		hiddenMod_staticCoverage = FlxMath.bound(value, 100.0, 400.0);

	if ((value = getModSetting('hiddenMod_gradientHeight')) != null)
		hiddenMod_gradientHeight = FlxMath.bound(value, 100.0, 600.0);

	if ((value = getModSetting('hiddenMod_gradientTransparentFraction')) != null)
		hiddenMod_gradientTransparentFraction = FlxMath.bound(value, 0.05, 0.5);
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Updates the fade zone distances based on current coverage.
 */
function updateCoverageDistances() {
	if (currentCoverage == lastCoverage)
		return;

	fadeEndDistance = currentCoverage;
	fadeStartDistance = currentCoverage * 1.5;
	lastCoverage = currentCoverage;
}

/**
 * Creates a gradient sprite at maximum size (created once, clipped dynamically).
 * @param width Width of the gradient sprite
 * @param reverse If true, creates black to transparent (for downscroll)
 * @return FlxSprite with gradient
 */
function createGradientSprite(width:Int, reverse:Bool = false):FlxSprite {
	var sprite = new FlxSprite();
	var safeWidth = Math.max(1, width);
	var safeHeight = Math.max(1, Math.ceil(gradientMaxHeight));
	
	var clampedFraction = FlxMath.bound(hiddenMod_gradientTransparentFraction, 0.05, 0.5);
	var fadeHeight = Math.max(1, Math.round(safeHeight * clampedFraction));
	var solidHeight = safeHeight - fadeHeight;
	
	// Start with transparent background
	sprite.makeGraphic(safeWidth, safeHeight, 0x00000000, true);
	
	var colors = reverse ? [0x00000000, 0xFF000000] : [0xFF000000, 0x00000000];
	var gradientBmp = FlxGradient.createGradientBitmapData(safeWidth, fadeHeight, colors, 1, 90);

	if (reverse) {
		// Downscroll: fade at top, solid at bottom
		if (gradientBmp != null) {
			sprite.pixels.copyPixels(gradientBmp, gradientBmp.rect, new Point(0, 0), null, null, true);
		}
		if (solidHeight > 0) {
			sprite.pixels.fillRect(new Rectangle(0, fadeHeight, safeWidth, solidHeight), 0xFF000000);
		}
	} else {
		// Upscroll: solid at top, fade at bottom
		if (solidHeight > 0) {
			sprite.pixels.fillRect(new Rectangle(0, 0, safeWidth, solidHeight), 0xFF000000);
		}
		if (gradientBmp != null) {
			sprite.pixels.copyPixels(gradientBmp, gradientBmp.rect, new Point(0, solidHeight), null, null, true);
		}
	}

	if (gradientBmp != null) {
		gradientBmp.dispose();
	}

	sprite.cameras = [camHUD];
	sprite.scrollFactor.set(0, 0);
	sprite.active = false;
	sprite.dirty = true;
	sprite.updateHitbox();
	return sprite;
}

/**
 * Forces ordering between notes, gradient, strums, and splashes.
 * Desired draw order (back -> front): notes -> gradient -> strums -> splashes.
 * Keeps everything else in noteGroup untouched.
 */
function placeGradientBelowStrums(sprite:FlxSprite) {
	if (sprite == null || noteGroup == null)
		return;

	var members = noteGroup.members;
	if (members == null)
		return;

	// Remove if already present so we can reinsert cleanly without duplicates
	var gradientIndex = members.indexOf(sprite);
	if (gradientIndex != -1)
		noteGroup.remove(sprite, false);

	// Make sure notes bucket stays in the group and get its current location
	var notesIndex = (notes != null) ? members.indexOf(notes) : -1;
	if (notesIndex == -1)
		notesIndex = 0;

	// Insert gradient right after notes (draw above notes by default)
	noteGroup.insert(notesIndex + 1, sprite);

	// Always reposition strums immediately after the gradient so they draw on top of it
	if (strumLineNotes != null) {
		var currentStrumIndex = members.indexOf(strumLineNotes);
		if (currentStrumIndex != -1) {
			noteGroup.remove(strumLineNotes, false);
			var newGradientIndex = members.indexOf(sprite);
			noteGroup.insert(newGradientIndex + 1, strumLineNotes);
		}
	}

	// Splashes should remain above everything else
	if (grpNoteSplashes != null) {
		var splashIndex = members.indexOf(grpNoteSplashes);
		if (splashIndex != -1) {
			noteGroup.remove(grpNoteSplashes, false);
			noteGroup.add(grpNoteSplashes);
		}
	}
}

function destroyGradientSprite(ref:FlxSprite):Void {
	if (ref == null)
		return;

	if (noteGroup != null && noteGroup.members != null && noteGroup.members.indexOf(ref) != -1)
		noteGroup.remove(ref, true);
	else
		remove(ref, true);
}

/**
 * Updates only the Y position and clip height of gradients (no recreation, no reordering).
 * Called only when coverage changes.
 */
function updateGradientClipping() {
	var useGradient = (hiddenMod_mode == 'Gradient');
	if (!useGradient) return;

	// Extend gradient beyond fadeStartDistance to match where notes become fully invisible in FadeOut mode
	// In FadeOut mode, notes fade from fadeStartDistance to fadeEndDistance, so gradient should extend to fadeStartDistance
	// But extend a bit more to ensure full coverage
	var targetHeight = hiddenMod_dynamicCoverage ? (fadeStartDistance * 1.1) : hiddenMod_gradientHeight;
	var clippedHeight = Math.min(targetHeight, gradientMaxHeight);

	if (gradientPlayer != null) {
		// Clip from top down (show top portion with fade at bottom)
		gradientPlayer.clipRect = FlxRect.get(0, 0, gradientPlayer.frameWidth, clippedHeight);
		gradientPlayer.y = FlxG.height - clippedHeight;
	}

	if (gradientOpponent != null) {
		// Clip from top down (show top portion with fade at bottom)
		gradientOpponent.clipRect = FlxRect.get(0, 0, gradientOpponent.frameWidth, clippedHeight);
		gradientOpponent.y = FlxG.height - clippedHeight;
	}
}

/**
 * Applies the fade effect to a single note based on its distance from the strumline.
 * @param note The note to apply the fade effect to.
 */
function applyFadeToNote(note) {
	if (note == null)
		return;

	if (!note.mustPress && !ClientPrefs.data.opponentStrums)
		return;

	var strumLine = note.mustPress ? playerStrums : opponentStrums;
	if (strumLine == null || strumLine.members.length <= note.noteData)
		return;

	var strum = strumLine.members[note.noteData];
	if (strum == null)
		return;

	var distance = strum.downScroll ? (strum.y - note.y) : (note.y - strum.y);

	var useFadeOut = (hiddenMod_mode == 'FadeOut');
	if (useFadeOut) {
		var alpha = (distance > fadeStartDistance) ? 1.0 : 
					(distance <= fadeEndDistance) ? 0.0 :
					(distance - fadeEndDistance) / (fadeStartDistance - fadeEndDistance);

		note.alpha = alpha * note.multAlpha;
	}
}

// ========================================
// PSYCH FUNCTIONS
// ========================================
function onCreate() {
	// Load settings from settings.json if available
	loadSettings();
	if (!hiddenMod_enabled)
		return;

	updateCoverageDistances();
}

function onCreatePost() {
	if (!hiddenMod_enabled || hiddenMod_mode != 'Gradient')
		return;

	// Create gradients once at max size
	if (playerStrums != null && playerStrums.members.length >= 4) {
		var firstStrum = playerStrums.members[0];
		var lastStrum = playerStrums.members[3];
		if (firstStrum != null && lastStrum != null) {
			var strumWidth = firstStrum.width;
			var width = Math.round((lastStrum.x - firstStrum.x) + strumWidth);
			
			gradientPlayer = createGradientSprite(width, ClientPrefs.data.downScroll);
			var fieldCenterX = (firstStrum.x + lastStrum.x + strumWidth) * 0.5;
			gradientPlayer.x = fieldCenterX - (gradientPlayer.width * 0.5);
			placeGradientBelowStrums(gradientPlayer);
		}
	}

	if (ClientPrefs.data.opponentStrums && opponentStrums != null && opponentStrums.members.length >= 4) {
		var firstOppStrum = opponentStrums.members[0];
		var lastOppStrum = opponentStrums.members[3];
		if (firstOppStrum != null && lastOppStrum != null) {
			var oppStrumWidth = firstOppStrum.width;
			var width = Math.round((lastOppStrum.x - firstOppStrum.x) + oppStrumWidth);
			
			gradientOpponent = createGradientSprite(width, ClientPrefs.data.downScroll);
			var fieldCenterXOpp = (firstOppStrum.x + lastOppStrum.x + oppStrumWidth) * 0.5;
			gradientOpponent.x = fieldCenterXOpp - (gradientOpponent.width * 0.5);
			placeGradientBelowStrums(gradientOpponent);
		}
	}
	
	// Initial clip
	updateGradientClipping();
}

function onUpdate(elapsed) {
	if (!hiddenMod_enabled)
		return;
	
	var newCoverage = hiddenMod_dynamicCoverage ? Math.min(hiddenMod_dynMaxCoverage,
		hiddenMod_dynMinCoverage + combo * hiddenMod_dynCoverageIncreasePerCombo) : hiddenMod_staticCoverage;
	
	// Only update if coverage actually changed
	if (Math.abs(newCoverage - currentCoverage) > 0.5) {
		currentCoverage = newCoverage;
		updateCoverageDistances();
		updateGradientClipping();
	}
}

function onUpdatePost(elapsed) {
	if (!hiddenMod_enabled)
		return;

	for (note in notes.members) {
		if (note == null)
			continue;

		// Skip notes that have been hit or missed (except sustains which need continuous updates)
		if (!note.isSustainNote && (note.wasGoodHit || note.tooLate))
			continue;

		applyFadeToNote(note);
	}
}

function onPause() {
	if (!hiddenMod_enabled)
		return;

	if (hiddenMod_dynamicCoverage) {
		currentCoverage = hiddenMod_dynMinCoverage;
	}
}

function onResume() {
	if (!hiddenMod_enabled)
		return;

	updateCoverageDistances();
}
