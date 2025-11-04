/*
	Lane Underlay for Psych Engine
	--------------------------------
	Adds a colored sprite behind note lanes to improve visibility for both player and opponent.

	Features:
	- Moves with the strum notes if moved during gameplay.
	- Adjustable alpha (transparency)
	- Adjustable extra width (padding)
	- Toggle opponent underlay on/off independently
	- 14 color options (BLACK, WHITE, GRAY, RED, ORANGE, YELLOW, GREEN, LIME, BLUE, PURPLE, PINK, BROWN, CYAN, MAGENTA)
	- Per-column underlay mode (one underlay per strum note)
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

// --- General Settings ---
var laneUnderlay_enabled:Bool = true;
var laneUnderlay_showOpponentUnderlay:Bool = true;
var laneUnderlay_alpha:Float = 0.35;
var laneUnderlay_colorSetting:String = 'BLACK';
var laneUnderlay_extraWidth:Int = 50;
var laneUnderlay_individualLanes:Bool = false;
var laneUnderlay_strumMoveThreshold:Float = 0.1;

// --- Internal Variables (DO NOT MODIFY) ---
var laneUnderlay:FlxSprite = null;
var laneUnderlayOpponent:FlxSprite = null;
var laneUnderlayColor:Int = FlxColor.BLACK;
var playerLaneUnderlays:Array<FlxSprite> = [];
var opponentLaneUnderlays:Array<FlxSprite> = [];
var cachedPlayerStrumPositions:Array<Float> = [];
var cachedOpponentStrumPositions:Array<Float> = [];

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
		trace('[Lane Underlay] settings.json not found, using default values from script');
		return;
	}
	trace('[Lane Underlay] settings.json found, loading settings...');

	var value:Dynamic;

	if ((value = getModSetting('laneUnderlay_enabled')) != null)
		laneUnderlay_enabled = value;

	if ((value = getModSetting('laneUnderlay_showOpponentUnderlay')) != null)
		laneUnderlay_showOpponentUnderlay = value;

	if ((value = getModSetting('laneUnderlay_individualLanes')) != null)
		laneUnderlay_individualLanes = value;

	if ((value = getModSetting('laneUnderlay_alpha')) != null)
		laneUnderlay_alpha = FlxMath.bound(Std.parseFloat(Std.string(value)), 0, 1);

	if ((value = getModSetting('laneUnderlay_color')) != null)
		laneUnderlay_colorSetting = Std.string(value);

	if ((value = getModSetting('laneUnderlay_width')) != null) {
		var extraValue:Float = Std.parseFloat(Std.string(value));
		if (extraValue == extraValue)
			laneUnderlay_extraWidth = Std.int(FlxMath.bound(extraValue, 0, 200));
	}
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Converts a string color name to a FlxColor constant.
 * @param setting The color name as a string.
 * @return The FlxColor value.
 */
function parseColorFromString(setting:String):Int {
	if (setting == null)
		return FlxColor.BLACK;

	switch (setting.toUpperCase()) {
		case 'WHITE':
			return FlxColor.WHITE;
		case 'GRAY':
			return FlxColor.GRAY;
		case 'GREEN':
			return FlxColor.GREEN;
		case 'LIME':
			return FlxColor.LIME;
		case 'YELLOW':
			return FlxColor.YELLOW;
		case 'ORANGE':
			return FlxColor.ORANGE;
		case 'RED':
			return FlxColor.RED;
		case 'PURPLE':
			return FlxColor.PURPLE;
		case 'BLUE':
			return FlxColor.BLUE;
		case 'BROWN':
			return FlxColor.BROWN;
		case 'PINK':
			return FlxColor.PINK;
		case 'MAGENTA':
			return FlxColor.MAGENTA;
		case 'CYAN':
			return FlxColor.CYAN;
		default:
			return FlxColor.BLACK;
	}
}

/**
 * Applies the current color to all underlay sprites.
 */
function applyColorToUnderlays() {
	laneUnderlayColor = parseColorFromString(laneUnderlay_colorSetting);

	if (laneUnderlay_individualLanes) {
		for (underlay in playerLaneUnderlays) {
			if (underlay != null)
				underlay.color = laneUnderlayColor;
		}
		for (underlay in opponentLaneUnderlays) {
			if (underlay != null)
				underlay.color = laneUnderlayColor;
		}
	} else {
		if (laneUnderlay != null) {
			laneUnderlay.color = laneUnderlayColor;
		}
		if (laneUnderlayOpponent != null) {
			laneUnderlayOpponent.color = laneUnderlayColor;
		}
	}
}

/**
 * Applies the current alpha to all underlay sprites.
 */
function applyAlphaToUnderlays() {
	if (laneUnderlay_individualLanes) {
		for (underlay in playerLaneUnderlays) {
			if (underlay != null)
				underlay.alpha = laneUnderlay_alpha;
		}
		for (underlay in opponentLaneUnderlays) {
			if (underlay != null)
				underlay.alpha = laneUnderlay_alpha;
		}
	} else {
		if (laneUnderlay != null) {
			laneUnderlay.alpha = laneUnderlay_alpha;
		}
		if (laneUnderlayOpponent != null) {
			laneUnderlayOpponent.alpha = laneUnderlay_alpha;
		}
	}
}

/**
 * Calculates the width for the underlay.
 * @return The width in pixels.
 */
function calculateTotalUnderlayWidth():Int {
	var baseWidth:Float = getReferenceStrumWidth() * 4;
	return Std.int(baseWidth + laneUnderlay_extraWidth);
}

/**
 * Calculates the width for column underlays.
 * @return The width in pixels.
 */
function calculateSingleLaneWidth():Int {
	return Std.int(getReferenceStrumWidth() + laneUnderlay_extraWidth);
}

/**
 * Retrieves the current width of a strum note, falling back to the default swag width.
 * @return The width in pixels.
 */
function getReferenceStrumWidth():Float {
	var strumWidth:Float = 0;
	if (game.playerStrums != null && game.playerStrums.members.length > 0 && game.playerStrums.members[0] != null) {
		strumWidth = game.playerStrums.members[0].width;
	}
	if (strumWidth <= 0
		&& game.opponentStrums != null
		&& game.opponentStrums.members.length > 0
		&& game.opponentStrums.members[0] != null) {
		strumWidth = game.opponentStrums.members[0].width;
	}
	if (strumWidth <= 0) {
		strumWidth = 112; // Note.swagWidth fallback (160 * 0.7)
	}
	return strumWidth;
}

/**
 * Caches the current X positions of all strums for movement tracking.
 */
function cacheStrumPositions() {
	cachedPlayerStrumPositions = [];
	cachedOpponentStrumPositions = [];

	if (game.playerStrums != null) {
		for (i in 0...game.playerStrums.members.length) {
			cachedPlayerStrumPositions.push(game.playerStrums.members[i].x);
		}
	}

	if (game.opponentStrums != null) {
		for (i in 0...game.opponentStrums.members.length) {
			cachedOpponentStrumPositions.push(game.opponentStrums.members[i].x);
		}
	}
}

/**
 * Checks if any strum has moved more than the threshold since last cache.
 * @return True if any strum moved significantly, false otherwise.
 */
function haveStrumsMovedSignificantly():Bool {
	if (game.playerStrums != null) {
		for (i in 0...game.playerStrums.members.length) {
			if (i >= cachedPlayerStrumPositions.length)
				return true;
			if (Math.abs(game.playerStrums.members[i].x - cachedPlayerStrumPositions[i]) > laneUnderlay_strumMoveThreshold) {
				return true;
			}
		}
	}

	if (game.opponentStrums != null) {
		for (i in 0...game.opponentStrums.members.length) {
			if (i >= cachedOpponentStrumPositions.length)
				return true;
			if (Math.abs(game.opponentStrums.members[i].x - cachedOpponentStrumPositions[i]) > laneUnderlay_strumMoveThreshold) {
				return true;
			}
		}
	}

	return false;
}

/**
 * Ensures underlays are layered behind the strum line.
 */
function repositionUnderlaysBehindStrums() {
	var strumIndex:Int = game.members.indexOf(game.strumLineNotes);
	if (strumIndex <= 0)
		return;

	if (laneUnderlay_individualLanes) {
		for (underlay in opponentLaneUnderlays) {
			if (underlay != null) {
				game.remove(underlay);
				game.insert(strumIndex - 1, underlay);
			}
		}
		for (underlay in playerLaneUnderlays) {
			if (underlay != null) {
				game.remove(underlay);
				game.insert(strumIndex - 1, underlay);
			}
		}
	} else {
		if (laneUnderlayOpponent != null) {
			game.remove(laneUnderlayOpponent);
		}
		if (laneUnderlay != null) {
			game.remove(laneUnderlay);
		}
		if (laneUnderlayOpponent != null) {
			game.insert(strumIndex - 1, laneUnderlayOpponent);
		}
		if (laneUnderlay != null) {
			game.insert(strumIndex - 1, laneUnderlay);
		}
	}
}

/**
 * Updates the position of all underlay sprites to follow their strums.
 */
function updateUnderlayPositions() {
	if (laneUnderlay_individualLanes) {
		var underlayHeight:Int = Std.int(FlxG.height * 2);
		var centerY:Float = (FlxG.height - underlayHeight) * 0.5;
		if (game.playerStrums != null) {
			for (i in 0...game.playerStrums.members.length) {
				if (i < playerLaneUnderlays.length && playerLaneUnderlays[i] != null) {
					var strum = game.playerStrums.members[i];
					var strumWidth:Float = strum != null && strum.width > 0 ? strum.width : getReferenceStrumWidth();
					var desiredWidth:Int = Std.int(strumWidth + laneUnderlay_extraWidth);
					refreshUnderlayGraphic(playerLaneUnderlays[i], desiredWidth, underlayHeight);
					playerLaneUnderlays[i].x = strum.x - (laneUnderlay_extraWidth * 0.5);
					playerLaneUnderlays[i].y = centerY;
				}
			}
		}

		if (game.opponentStrums != null) {
			for (i in 0...game.opponentStrums.members.length) {
				if (i < opponentLaneUnderlays.length && opponentLaneUnderlays[i] != null) {
					var strum = game.opponentStrums.members[i];
					var strumWidth:Float = strum != null && strum.width > 0 ? strum.width : getReferenceStrumWidth();
					var desiredWidth:Int = Std.int(strumWidth + laneUnderlay_extraWidth);
					refreshUnderlayGraphic(opponentLaneUnderlays[i], desiredWidth, underlayHeight);
					opponentLaneUnderlays[i].x = strum.x - (laneUnderlay_extraWidth * 0.5);
					opponentLaneUnderlays[i].y = centerY;
				}
			}
		}
	} else {
		var centerY:Float = (FlxG.height - (laneUnderlay != null ? laneUnderlay.height : 0)) * 0.5;

		if (laneUnderlay != null && game.playerStrums != null && game.playerStrums.members.length >= 4) {
			var strumWidth:Float = getReferenceStrumWidth();
			var firstStrumX:Float = game.playerStrums.members[0].x;
			var lastStrumX:Float = game.playerStrums.members[3].x;
			var playerFieldCenterX:Float = (firstStrumX + lastStrumX + strumWidth) * 0.5;
			laneUnderlay.x = playerFieldCenterX - (laneUnderlay.width * 0.5);
			laneUnderlay.y = centerY;
		}
		if (laneUnderlayOpponent != null && game.opponentStrums != null && game.opponentStrums.members.length >= 4) {
			var strumWidth:Float = getReferenceStrumWidth();
			var firstStrumX:Float = game.opponentStrums.members[0].x;
			var lastStrumX:Float = game.opponentStrums.members[3].x;
			var opponentFieldCenterX:Float = (firstStrumX + lastStrumX + strumWidth) * 0.5;
			laneUnderlayOpponent.x = opponentFieldCenterX - (laneUnderlayOpponent.width * 0.5);
			laneUnderlayOpponent.y = centerY;
		}
	}
}

/**
 * Changes the underlay alpha and applies it to all underlays.
 * @param alpha The new alpha value (0-1).
 */
function changeUnderlayAlpha(alpha:Float) {
	laneUnderlay_alpha = FlxMath.bound(alpha, 0, 1);
	applyAlphaToUnderlays();
}

/**
 * Changes the underlay color and applies it to all underlays.
 * @param color The new color as a string.
 */
function changeUnderlayColor(color:String) {
	laneUnderlay_colorSetting = color;
	applyColorToUnderlays();
}

/**
 * Changes the extra width for underlays and rebuilds their graphics.
 * @param extra The new extra width in pixels.
 */
function changeUnderlayExtraWidth(extra:Float) {
	laneUnderlay_extraWidth = Std.int(FlxMath.bound(extra, 0, 200));
	rebuildUnderlayGraphics();
}

/**
 * Checks if opponent underlays should be created based on all conditions.
 * @return True if opponent underlays should be created.
 */
function shouldCreateOpponentUnderlays():Bool {
	return laneUnderlay_showOpponentUnderlay && ClientPrefs.data.opponentStrums && !ClientPrefs.data.middleScroll && game.opponentStrums != null;
}

/**
 * Sets the visibility of all underlay sprites.
 * @param visible Whether the underlays should be visible.
 */
function toggleUnderlayVisibility(visible:Bool) {
	var opponentVisible:Bool = visible && !ClientPrefs.data.middleScroll;

	if (laneUnderlay_individualLanes) {
		for (underlay in playerLaneUnderlays) {
			if (underlay != null)
				underlay.visible = visible;
		}
		for (underlay in opponentLaneUnderlays) {
			if (underlay != null)
				underlay.visible = opponentVisible;
		}
	} else {
		if (laneUnderlay != null) {
			laneUnderlay.visible = visible;
		}
		if (laneUnderlayOpponent != null) {
			laneUnderlayOpponent.visible = opponentVisible;
		}
	}
}

/**
 * Creates a new underlay sprite with the given dimensions and color.
 * @param width The width of the underlay.
 * @param height The height of the underlay.
 * @return The created FlxSprite.
 */
function createUnderlaySprite(width:Int, height:Int):FlxSprite {
	var spr:FlxSprite = new FlxSprite(0, 0);
	spr.makeGraphic(width, height, laneUnderlayColor);
	spr.alpha = laneUnderlay_alpha;
	spr.scrollFactor.set(0, 0);
	spr.cameras = [game.camHUD];
	return spr;
}

/**
 * Ensures an underlay sprite has the desired dimensions.
 * @param underlay The underlay sprite to refresh.
 * @param width Desired width in pixels.
 * @param height Desired height in pixels.
 */
function refreshUnderlayGraphic(underlay:FlxSprite, width:Int, height:Int) {
	if (underlay == null)
		return;
	if (underlay.width != width || underlay.height != height) {
		underlay.makeGraphic(width, height, laneUnderlayColor);
		underlay.alpha = laneUnderlay_alpha;
		underlay.color = laneUnderlayColor;
	}
}

/**
 * Creates individual underlay sprites for each note column (player and opponent if enabled).
 */
function createIndividualLaneUnderlays() {
	var underlayWidth:Int = calculateSingleLaneWidth();
	var underlayHeight:Int = Std.int(FlxG.height * 2);

	opponentLaneUnderlays = [];
	if (shouldCreateOpponentUnderlays()) {
		for (i in 0...4) {
			var opponentUnderlay:FlxSprite = createUnderlaySprite(underlayWidth, underlayHeight);
			opponentLaneUnderlays.push(opponentUnderlay);
			game.add(opponentUnderlay);
		}
	}

	playerLaneUnderlays = [];
	for (i in 0...4) {
		var playerUnderlay:FlxSprite = createUnderlaySprite(underlayWidth, underlayHeight);
		playerLaneUnderlays.push(playerUnderlay);
		game.add(playerUnderlay);
	}
}

/**
 * Destroys all individual lane underlay sprites (player and optional opponent) and clears their arrays.
 */
function destroyIndividualLaneUnderlays() {
	for (underlay in playerLaneUnderlays) {
		if (underlay != null) {
			underlay.kill();
			underlay.destroy();
		}
	}
	for (underlay in opponentLaneUnderlays) {
		if (underlay != null) {
			underlay.kill();
			underlay.destroy();
		}
	}
	playerLaneUnderlays = [];
	opponentLaneUnderlays = [];
}

/**
 * Rebuilds the graphics for all underlay sprites (e.g., after resizing or color change).
 */
function rebuildUnderlayGraphics() {
	var underlayHeight:Int = Std.int(FlxG.height * 2);

	if (laneUnderlay_individualLanes) {
		var underlayWidth:Int = calculateSingleLaneWidth();
		for (underlay in playerLaneUnderlays) {
			if (underlay != null) {
				underlay.makeGraphic(underlayWidth, underlayHeight, laneUnderlayColor);
			}
		}
		for (underlay in opponentLaneUnderlays) {
			if (underlay != null) {
				underlay.makeGraphic(underlayWidth, underlayHeight, laneUnderlayColor);
			}
		}
	} else {
		var underlayWidth:Int = calculateTotalUnderlayWidth();
		if (laneUnderlay != null) {
			laneUnderlay.makeGraphic(underlayWidth, underlayHeight, laneUnderlayColor);
		}
		if (laneUnderlayOpponent != null) {
			laneUnderlayOpponent.makeGraphic(underlayWidth, underlayHeight, laneUnderlayColor);
		}
	}

	applyAlphaToUnderlays();
	applyColorToUnderlays();
	updateUnderlayPositions();
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	loadSettings();
	if (!laneUnderlay_enabled)
		return;

	applyColorToUnderlays();

	if (laneUnderlay_individualLanes) {
		createIndividualLaneUnderlays();
	} else {
		var underlayWidth:Int = calculateTotalUnderlayWidth();
		var underlayHeight:Int = Std.int(FlxG.height * 2);

		if (shouldCreateOpponentUnderlays()) {
			laneUnderlayOpponent = createUnderlaySprite(underlayWidth, underlayHeight);
			game.add(laneUnderlayOpponent);
		} else {
			laneUnderlayOpponent = null;
		}

		laneUnderlay = createUnderlaySprite(underlayWidth, underlayHeight);
		game.add(laneUnderlay);
	}
}

function onCreatePost() {
	if (!laneUnderlay_enabled) {
		return;
	}

	updateUnderlayPositions();
	repositionUnderlaysBehindStrums();
	cacheStrumPositions();
	toggleUnderlayVisibility(true);
}

function onUpdatePost(elapsed:Float) {
	if (!laneUnderlay_enabled) {
		return;
	}

	if (haveStrumsMovedSignificantly()) {
		updateUnderlayPositions();
		cacheStrumPositions();
	}
}

function onDestroy() {
	if (laneUnderlay_individualLanes) {
		destroyIndividualLaneUnderlays();
	} else {
		if (laneUnderlay != null) {
			laneUnderlay.kill();
			laneUnderlay.destroy();
			laneUnderlay = null;
		}
		if (laneUnderlayOpponent != null) {
			laneUnderlayOpponent.kill();
			laneUnderlayOpponent.destroy();
			laneUnderlayOpponent = null;
		}
	}

	cachedPlayerStrumPositions = [];
	cachedOpponentStrumPositions = [];
}
