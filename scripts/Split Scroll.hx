/*
	Split Scroll for Psych Engine
	------------------------------
	Creates a split scroll effect where half of the player strums scroll in one direction
	and the other half scroll in the opposite direction. 
	Essentially playing down and upscroll simultaneously.

	Features:
	- Configurable scroll direction (Left Up/Right Down OR Left Down/Right Up)
	- Proper sustain note rendering with flip and clipping
	- Preserves user's original downscroll settings.
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
var splitScroll_enabled:Bool = true;
var splitScroll_invertDirection:Bool = false; // Inverts the scroll direction (left up/right down becomes left down/right up)

// --- Internal Variables (DO NOT MODIFY) ---
var playerScrollSpeeds:Array<Float> = [];
var playerStrumYPositions:Array<Float> = [];
var opponentScrollSpeeds:Array<Float> = [];
var opponentStrumYPositions:Array<Float> = [];
var initialized:Bool = false;
var userScrollSetting:Bool = null;

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
		trace('[Split Scroll] settings.json not found, using default values from script');
		return;
	}
	trace('[Split Scroll] settings.json found, loading settings...');

	var value:Dynamic;

	if ((value = getModSetting('splitScroll_enabled')) != null)
		splitScroll_enabled = value;

	if ((value = getModSetting('splitScroll_invertDirection')) != null)
		splitScroll_invertDirection = value;
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Determines if a strum should use downscroll based on its index and the current direction setting.
 * @param strumIndex The index of the strum (0-3).
 * @return True if the strum should scroll downward, false for upscroll.
 */
function shouldStrumBeDownscroll(strumIndex:Int):Bool {
	var isLeftHalf:Bool = (strumIndex < 2);

	// Base behavior: left half up (false), right half down (true)
	// Invert direction flips this: left half down (true), right half up (false)
	var isDownscroll:Bool = isLeftHalf == splitScroll_invertDirection;

	return isDownscroll;
}

/**
 * Calculates the Y position for a strum based on its scroll direction.
 * @param isDownscroll Whether the strum uses downscroll.
 * @return The Y position for the strum.
 */
function calculateStrumYPosition(isDownscroll:Bool):Float {
	return isDownscroll ? FlxG.height - 150 : 50;
}

/**
 * Initializes strum positions and scroll speeds for player and opponent strums.
 */
function initializeStrumPositions() {
	// Initialize player strums
	for (i in 0...4) {
		var strum = playerStrums.members[i];
		var isDownscroll:Bool = shouldStrumBeDownscroll(i);
		var yPosition:Float = calculateStrumYPosition(isDownscroll);

		playerScrollSpeeds.push(isDownscroll ? 1 : -1);
		playerStrumYPositions.push(yPosition);

		strum.y = yPosition;
		strum.downScroll = isDownscroll;
	}

	// Initialize opponent strums
	for (i in 0...4) {
		var strum = opponentStrums.members[i];
		var isDownscroll:Bool = shouldStrumBeDownscroll(i);
		var yPosition:Float = calculateStrumYPosition(isDownscroll);

		opponentScrollSpeeds.push(isDownscroll ? 1 : -1);
		opponentStrumYPositions.push(yPosition);

		strum.y = yPosition;
		strum.downScroll = isDownscroll;
	}

	initialized = true;
}

/**
 * Updates sustain note rendering properties based on strum scroll direction.
 * @param note The sustain note to update.
 * @param strum The strum line the note belongs to.
 */
function updateSustainNoteRendering(note:Note, strum:StrumNote) {
	if (strum.downScroll) {
		// Downscroll: strums at bottom, notes come from top and scroll down
		// Need to flip the sustain since ClientPrefs.downScroll is false
		note.flipY = true;
		// Adjust offset to compensate for the flip
		note.offset.y = note.frameHeight - 56; // 56 = Note.swagWidth / 2
	} else {
		// Upscroll: strums at top, notes come from bottom and scroll up
		// Works correctly with ClientPrefs.downScroll = false (default behavior)
		note.flipY = false;
		// Don't touch offset.y - let Psych Engine handle it naturally
	}
}

/**
 * Updates the clip rectangle for a sustain note to ensure proper clipping at the strum line.
 * @param note The sustain note to clip.
 * @param strum The strum line the note belongs to.
 */
function updateSustainNoteClipping(note:Note, strum:StrumNote) {
	if (note.clipRect == null)
		return;

	var swagRect = note.clipRect;

	if (strum.downScroll) {
		// Downscroll clipping: strums at bottom, clip from top as note passes through
		if (note.y > strum.y) {
			swagRect.y = (note.y - strum.y) / note.scale.y;
			swagRect.height = (note.height / note.scale.y) - swagRect.y;
		}
	} else {
		// Upscroll clipping: strums at top, clip from bottom as note passes through
		if (note.y + note.height < strum.y) {
			swagRect.y = 0;
			swagRect.height = 0;
		} else if (note.y < strum.y) {
			swagRect.height = (strum.y - note.y) / note.scale.y;
			swagRect.y = swagRect.height;
		}
	}

	note.clipRect = swagRect;
}

/**
 * Processes all active sustain notes, updating their rendering and clipping.
 */
function processSustainNotes() {
	notes.forEachAlive(function(note) {
		if (note.isSustainNote) {
			var noteData:Int = note.noteData % 4;
			var strum = note.mustPress ? playerStrums.members[noteData] : opponentStrums.members[noteData];

			updateSustainNoteRendering(note, strum);
			updateSustainNoteClipping(note, strum);
		}
	});
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	loadSettings();

	if (!splitScroll_enabled)
		return;

	userScrollSetting = ClientPrefs.data.downScroll;
	ClientPrefs.data.downScroll = false;
}

function onCreatePost() {
	if (!splitScroll_enabled)
		return;

	initializeStrumPositions();
}

function onUpdatePost(elapsed:Float) {
	if (!splitScroll_enabled || !initialized)
		return;

	// Update player strum positions
	for (i in 0...4) {
		playerStrums.members[i].y = playerStrumYPositions[i];
	}

	// Update opponent strum positions
	for (i in 0...4) {
		opponentStrums.members[i].y = opponentStrumYPositions[i];
	}

	processSustainNotes();
}

function onDestroy() {
	if (userScrollSetting != null) {
		ClientPrefs.data.downScroll = userScrollSetting;
	}
}
