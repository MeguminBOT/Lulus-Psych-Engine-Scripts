/*
	>>> Replay System for Psych Engine
		* Script version: v1
		* Replay Data version: v1
		-------------------------------
		HScript-based Replay System that records, saves, and plays back player inputs.

		Features:
			- Records all player inputs (key press/release events).
			- Note hit data with timestamps for accuracy verification in case of desyncs.
			- Automatic saving. *OPTIONAL*
			- View and playback replays using the "Replay Viewer" song in Freeplay Menu.
			- Multiple fallbacks for mod folder/chart detection to hopefully support sharing replays, including:
				- Stored mod directory in replay file.
				- Current mod directory
				- Global mods folder
				- Other mod folders that are enabled.
			- Uses gameplay settings from the replay file to match original conditions when it was recorded.
				- Backups your current ClientPrefs and gameplay settings.
				- Applies the replay's stored settings.
				- Restores your settings when replay is finished or exited.

		Compatibility:
			Made for Psych Engine 1.0.4.

			NO HELP/SUPPORT WILL BE GIVEN IF ANY ISSUES HAPPENS:
			- Using on older versions.
			- Using Psych Engine forks that had their backend modified. (e.g. P-Slice).
			- Using Android builds.

		Usage:
		- This script relies on its own modfolder to function.
		- Edit the configuration variables if desired.

	Script by AutisticLulu. 
	Give credit if used elsewhere or a special thanks if using parts of the code, I worked hard on this!
 */

import tjson.TJSON;
import backend.MusicBeatState;
import states.LoadingState;
import flixel.group.FlxGroup.FlxTypedGroup;
import backend.Song;
import backend.Difficulty;
import backend.Mods;
import backend.StageData;
import backend.WeekData;
import Reflect;
import Date;
import DateTools;

// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var replay_enabled:Bool = true;
var replay_autoSaveReplays:Bool = true; // Auto-save replays (prompts once for name, then never asks again)
var replay_useFancyJSON:Bool = true; // Use 'fancy' format for readable JSON at the cost of disk space.
var replay_debug:Bool = false;

// --- Internal variables, do NOT modify unless you know what you're doing ---
var curPlayerName:String = '';
var saveFolder:String = 'replays/';
var replayMenuSong:String = 'replay-viewer';
var pendingDataFile:String = 'mods/replays/.pending-replay.json'; // Temporary file for replay data handoff between PlayState reset.
var playerNameFile:String = 'mods/replays/.player-name.json';

// ========================================
// GENERAL HELPER FUNCTIONS
// ========================================

/**
 * Helper function to print debug messages or traces only if replay_debug is true.
 * @param msg Message to print
 */
function debug(msg:String) {
	if (!replay_debug)
		return;
	trace('[Replay System] ' + msg);
}

/**
 * Loads saved player name from file if it exists.
 * @return Saved player name, or empty string if not found
 */
function loadSavedPlayerName():String {
	if (!FileSystem.exists(playerNameFile)) {
		return '';
	}

	try {
		var content = File.getContent(playerNameFile);
		var data = TJSON.parse(content);
		if (Reflect.hasField(data, 'name')) {
			return Std.string(data.name);
		}
		return '';
	} catch (e:Dynamic) {
		debug('Failed to load saved player name: ' + e);
		return '';
	}
}

/**
 * Saves player name to file for future use.
 * @param name Player name to save
 * @param dontAskAgain Whether to skip the prompt in the future
 */
function savePlayerName(name:String, dontAskAgain:Bool = false) {
	var folderPath = 'mods/' + saveFolder;
	if (!FileSystem.exists(folderPath)) {
		FileSystem.createDirectory(folderPath);
	}

	try {
		var data = {
			name: name,
			dontAskAgain: dontAskAgain
		};
		File.saveContent(playerNameFile, TJSON.encode(data, 'fancy'));
		debug('Player name saved: ' + name + ' (dontAskAgain: ' + dontAskAgain + ')');
	} catch (e:Dynamic) {
		debug('Failed to save player name: ' + e);
	}
}

/**
 * Creates a styled FlxText with common formatting.
 * @param text Text content to display
 * @param x X position
 * @param y Y position
 * @param width Text field width (0 for auto)
 * @param size Font size
 * @param color Text color (hex int)
 * @param align Text alignment ('left', 'center', 'right')
 * @param borderSize Outline thickness
 * @return Configured FlxText object
 */
function createText(text:String, x:Float, y:Float, width:Float = 0, size:Int = 20, color:Int = 0xFFFFFFFF, align:String = 'left', borderSize:Float = 2):FlxText {
	var txt = new FlxText(x, y, width, text, size);
	txt.setFormat(Paths.font('vcr.ttf'), size, color, align, 'outline', FlxColor.BLACK);
	txt.borderSize = borderSize;
	txt.scrollFactor.set();
	return txt;
}

/**
 * Creates a FlxSprite with a solid color graphic.
 * @param x X position
 * @param y Y position
 * @param width Sprite width
 * @param height Sprite height
 * @param color Fill color (hex int)
 * @param alpha Alpha transparency (0 to 1)
 * @return Configured FlxSprite object
 */
function createSprite(x:Float, y:Float, width:Int, height:Int, color:Int, alpha:Float = 1.0):FlxSprite {
	var sprite = new FlxSprite(x, y).makeGraphic(width, height, color);
	sprite.alpha = alpha;
	sprite.scrollFactor.set();
	return sprite;
}

// ========================================
// RECORDING: CORE
// ========================================
// --- Recording State Variables ---
var isRecording:Bool = false;
var recordingStartTime:Float = 0;
var replayData:Dynamic = null;
var noteHitRecordings:Array<Dynamic> = [];
var inputEventRecordings:Array<Dynamic> = [];
var songCompleted:Bool = false;
var highestCombo:Int = 0;
var savedReplayFilename:String = null;

/**
 * Starts recording a new replay for the current song.
 * Initializes recording state and creates the replay data structure.
 */
function startRecording() {
	isRecording = true;
	recordingStartTime = Conductor.songPosition;
	noteHitRecordings = [];
	inputEventRecordings = [];
	songCompleted = false;
	highestCombo = 0;
	savedReplayFilename = null;

	var diffName = game.storyDifficultyText;
	var currentDate = DateTools.format(Date.now(), '%Y-%m-%d %H:%M:%S');

	var savedName = loadSavedPlayerName();
	var playerName = savedName.length > 0 ? savedName : curPlayerName;

	debug('startRecording - savedName: "' + savedName + '" | playerName: "' + playerName + '"');

	replayData = {
		noteHits: [],
		inputEvents: [],
		version: 1,
		song: PlayState.SONG.song,
		diff: diffName,
		playedOn: currentDate,
		playerName: playerName,
		modDirectory: (Mods.currentModDirectory != null ? Mods.currentModDirectory : ''),
		result: {},
		clientPrefs: {
			downScroll: ClientPrefs.data.downScroll,
			middleScroll: ClientPrefs.data.middleScroll,
			opponentStrums: ClientPrefs.data.opponentStrums,
			ghostTapping: ClientPrefs.data.ghostTapping,
			guitarHeroSustains: ClientPrefs.data.guitarHeroSustains,
			ratingOffset: ClientPrefs.data.ratingOffset,
			sickWindow: ClientPrefs.data.sickWindow,
			goodWindow: ClientPrefs.data.goodWindow,
			badWindow: ClientPrefs.data.badWindow,
			safeFrames: ClientPrefs.data.safeFrames
		},
		gameplaySettings: {
			scrollType: ClientPrefs.getGameplaySetting('scrolltype'),
			scrollSpeed: ClientPrefs.getGameplaySetting('scrollspeed'),
			playbackRate: ClientPrefs.getGameplaySetting('songspeed'),
			healthGain: ClientPrefs.getGameplaySetting('healthgain'),
			healthLoss: ClientPrefs.getGameplaySetting('healthloss')
		}
	};

	debug('Recording started: ' + PlayState.SONG.song + ' (' + diffName + ')');
}

/**
 * Stops the current recording and finalizes the replay data.
 * If auto-save is enabled and score is valid, saves the replay automatically.
 */
function stopRecording() {
	if (!isRecording)
		return;

	isRecording = false;
	replayData.noteHits = noteHitRecordings;
	replayData.inputEvents = inputEventRecordings;

	replayData.result = {
		score: game.songScore,
		misses: game.songMisses,
		hits: game.songHits,
		acc: game.ratingPercent * 100,
		rating: game.ratingName,
		sicks: game.ratingsData[0].hits,
		goods: game.ratingsData[1].hits,
		bads: game.ratingsData[2].hits,
		shits: game.ratingsData[3].hits,
		maxCombo: highestCombo
	};

	debug('Recording stopped. Note Hits: ' + noteHitRecordings.length + ' | Input Events: ' + inputEventRecordings.length);
	debug('Score: ' + replayData.result.score + ' | Acc: ' + replayData.result.acc + '%');

	if (replay_autoSaveReplays && isValidScore()) {
		savedReplayFilename = saveReplay(replayData);
	} else if (!isValidScore()) {
		debug('Score not valid (practice/botplay/charting mode) - replay not saved');
	}
}

/**
 * Records a single input event (key press or release).
 * @param lane Note lane/column (0-3 for left, down, up, right)
 * @param isPressed True for key press, false for key release
 */
function recordInputEvent(lane:Int, isPressed:Bool) {
	var timeStamp = getAccurateSongTime();
	inputEventRecordings.push({
		time: timeStamp,
		col: lane,
		pressed: isPressed
	});
}

/**
 * Gets the most accurate current song time, accounting for audio offset.
 * @return Current song time in milliseconds
 */
function getAccurateSongTime():Float {
	if (FlxG != null && FlxG.sound != null && FlxG.sound.music != null) {
		return FlxG.sound.music.time + Conductor.offset;
	}
	return Conductor.songPosition;
}

/**
 * Checks if the current score is valid for saving.
 * Invalid if: song not completed, practice mode, botplay, or charting mode.
 * @return True if score is valid for leaderboard/saving
 */
function isValidScore():Bool {
	if (!songCompleted) {
		debug('Song not completed - score not valid');
		return false;
	}

	var practiceMode = ClientPrefs.getGameplaySetting('practice');
	var botplay = ClientPrefs.getGameplaySetting('botplay');
	var chartingMode = PlayState.chartingMode;

	if (practiceMode || botplay || chartingMode) {
		debug('Score not valid (practice: ' + practiceMode + ', botplay: ' + botplay + ', charting: ' + chartingMode + ')');
		return false;
	}

	return true;
}

/**
 * Saves a replay to disk as a JSON file.
 * @param replay The replay data object to save
 * @return Filename of the saved replay, or null if save failed
 */
function saveReplay(replay:Dynamic):String {
	var folderPath = Paths.mods(saveFolder);
	if (!FileSystem.exists(folderPath)) {
		FileSystem.createDirectory(folderPath);
	}

	var filename = generateFilename(folderPath, replay);
	var fullPath = folderPath + filename;

	try {
		var jsonFormat = replay_useFancyJSON ? 'fancy' : null;
		File.saveContent(fullPath, TJSON.encode(replay, jsonFormat));
		debug('Replay saved: ' + fullPath);
		return filename;
	} catch (e:Dynamic) {
		debug('Failed to save replay: ' + e);
		return null;
	}
}

/**
 * Generates the filename.
 * Format: "PlayerName - SongName [Difficulty] (YYYY-MM-DD HH-MM-SS).json"
 * @param folderPath Path to check for existing files
 * @param replay The replay data object containing player name, song, and difficulty
 * @return Filename with .json extension
 */
function generateFilename(folderPath:String, replay:Dynamic):String {
	try {
		var now = Date.now();
		var timestamp = DateTools.format(now, '%Y-%m-%d %H-%M-%S');

		var playerName = (replay.playerName != null && replay.playerName.length > 0) ? replay.playerName : 'Player';
		var songName = replay.song;
		var difficulty = replay.diff;

		debug('generateFilename - replay.playerName: "' + replay.playerName + '" | using: "' + playerName + '"');

		// Format: PlayerName - SongName [Difficulty] (YYYY-MM-DD HH-MM-SS).json
		var filename = playerName + ' - ' + songName + ' [' + difficulty + '] (' + timestamp + ').json';

		if (!FileSystem.exists(folderPath + filename)) {
			return filename;
		}

		// If somehow the exact timestamp exists, add a counter
		var counter = 1;
		while (FileSystem.exists(folderPath + filename)) {
			filename = playerName + ' - ' + songName + ' [' + difficulty + '] (' + timestamp + '-' + counter + ').json';
			counter = counter + 1;
			if (counter > 999)
				break;
		}

		return filename;
	} catch (e:Dynamic) {
		debug('Failed to get system date/time: ' + e);
	}

	return filename;
}

// ========================================
// RECORDING: SAVE PROMPT UI
// ========================================
// --- Save Prompt State Variables ---
var savePromptActive:Bool = false;
var savePromptCompleted:Bool = false;
var savePromptInputText:String = '';
var savePromptTexts:Array<FlxText> = [];
var savePromptInputDisplay:FlxText = null;
var savePromptCursorBlink:Float = 0;

/**
 * Opens the save prompt interface as a CustomSubstate.
 * Allows player to enter/edit their name before saving the replay.
 */
function createSaveInterface() {
	if (savePromptActive)
		return;

	if (replay_autoSaveReplays) {
		var savedName = loadSavedPlayerName();
		if (savedName.length > 0) {
			debug('Skipping prompt (autosave enabled, name exists) - using: ' + savedName);
			savePromptCompleted = true;
			game.endSong();
			return;
		}
		debug('Autosave enabled but no saved name - showing prompt');
	}

	debug('Creating save interface - opening substate');

	var savedName = loadSavedPlayerName();
	savePromptInputText = savedName.length > 0 ? savedName : curPlayerName;
	savePromptCursorBlink = 0;
	savePromptCompleted = false;

	CustomSubstate.openCustomSubstate('ReplaySavePrompt');
	savePromptActive = true;
}

/**
 * Builds the visual elements of the save prompt interface.
 * Called when the ReplaySavePrompt substate is created.
 */
function buildSaveInterface() {
	var overlay = createSprite(0, 0, FlxG.width, FlxG.height, FlxColor.BLACK, 0.7);
	customSubstate.add(overlay);

	var centerX = FlxG.width / 2;
	var centerY = FlxG.height / 2;

	var titleText = createText('Save Replay', 0, centerY - 120, FlxG.width, 32, FlxColor.WHITE, 'center', 2);
	customSubstate.add(titleText);
	savePromptTexts.push(titleText);

	var labelText = createText('Player Name:', 0, centerY - 60, FlxG.width, 20, FlxColor.fromRGB(200, 200, 200), 'center', 2);
	customSubstate.add(labelText);
	savePromptTexts.push(labelText);

	var inputBg = createSprite(centerX - 155, centerY - 25, 310, 40, FlxColor.fromRGB(40, 40, 40), 1.0);
	customSubstate.add(inputBg);

	var inputBorder = createSprite(centerX - 157, centerY - 27, 314, 44, FlxColor.WHITE, 1.0);
	customSubstate.add(inputBorder);
	customSubstate.remove(inputBorder);
	customSubstate.insert(customSubstate.members.indexOf(inputBg), inputBorder);

	savePromptInputDisplay = createText(savePromptInputText, centerX - 145, centerY - 15, 290, 18, FlxColor.WHITE, 'left', 0);
	customSubstate.add(savePromptInputDisplay);

	var instructText = createText('[ENTER] Save  |  [ESC] ' + (replay_autoSaveReplays ? 'Cancel' : 'Discard'), 0, centerY + 30, FlxG.width, 16,
		FlxColor.fromRGB(150, 150, 150), 'center', 2);
	customSubstate.add(instructText);
	savePromptTexts.push(instructText);

	if (replay_autoSaveReplays) {
		var infoText = createText('(Auto-save enabled, enter a name for future saves)', 0, centerY + 60, FlxG.width, 14, FlxColor.fromRGB(100, 100, 255),
			'center', 1);
		customSubstate.add(infoText);
		savePromptTexts.push(infoText);
	}

	debug('Save interface created');
}

/**
 * Updates the text display to show current input text.
 */
function updateInputDisplay() {
	if (savePromptInputDisplay != null) {
		savePromptInputDisplay.text = savePromptInputText;
	}
}

/**
 * Handles keyboard input for the save prompt interface.
 * Processes text input, backspace, enter (save), and escape (cancel).
 * @param elapsed Delta time for cursor blink animation
 */
function handleSaveInterfaceInput(elapsed:Float) {
	if (!savePromptActive || savePromptInputDisplay == null)
		return;

	var controls = game.controls;
	var shiftPressed = FlxG.keys.pressed.SHIFT;

	// Check letter keys (A-Z)
	var letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	for (i in 0...letters.length) {
		var upperChar = letters.charAt(i);
		var keyCode = upperChar.charCodeAt(0);

		if (FlxG.keys.checkStatus(keyCode, 2)) { // 2 = JUST_PRESSED
			if (savePromptInputText.length < 30) {
				var charToAdd = shiftPressed ? upperChar : upperChar.toLowerCase();
				savePromptInputText += charToAdd;
				updateInputDisplay();
			}
		}
	}

	// Check number and special character keys
	var otherChars = '0123456789 -_.,!?@#';
	for (i in 0...otherChars.length) {
		var char = otherChars.charAt(i);
		var keyCode = char.charCodeAt(0);

		if (FlxG.keys.checkStatus(keyCode, 2)) { // 2 = JUST_PRESSED
			if (savePromptInputText.length < 30) {
				savePromptInputText += char;
				updateInputDisplay();
			}
		}
	}

	if (FlxG.keys.justPressed.BACKSPACE) {
		if (savePromptInputText.length > 0) {
			savePromptInputText = savePromptInputText.substring(0, savePromptInputText.length - 1);
			updateInputDisplay();
		}
		return;
	}

	var cursorVisible = (savePromptCursorBlink % 1.0) < 0.5;
	var displayText = savePromptInputText;
	if (cursorVisible) {
		displayText += '|';
	}
	savePromptInputDisplay.text = displayText;

	if (FlxG.keys.justPressed.ENTER) {
		debug('Save button pressed');

		if (replayData != null) {
			replayData.playerName = savePromptInputText;

			// Save player name to file for future use
			if (savePromptInputText.length > 0) {
				savePlayerName(savePromptInputText, false);
				debug('Saved player name: ' + savePromptInputText);
			}

			// Delete old file with incorrect name if it exists
			if (savedReplayFilename != null) {
				var folderPath = Paths.mods(saveFolder);
				var oldFullPath = folderPath + savedReplayFilename;
				try {
					if (FileSystem.exists(oldFullPath)) {
						FileSystem.deleteFile(oldFullPath);
						debug('Deleted old replay file: ' + savedReplayFilename);
					}
				} catch (e:Dynamic) {
					debug('Failed to delete old replay: ' + e);
				}
			}

			// Save with new filename using updated player name
			var filename = saveReplay(replayData);
			if (filename != null) {
				debug('Replay saved with player name: ' + savePromptInputText);
				FlxG.sound.play(Paths.sound('confirmMenu'));
			}
		}

		closeSaveInterface();
	}

	if (FlxG.keys.justPressed.ESCAPE) {
		debug('Cancel/Discard pressed');
		FlxG.sound.play(Paths.sound('cancelMenu'));

		if (!replay_autoSaveReplays && replayData != null) {
			debug('Replay discarded (auto-save disabled, user cancelled)');
		}

		closeSaveInterface();
	}
}

/**
 * Closes the save prompt interface and proceeds to end the song.
 */
function closeSaveInterface() {
	savePromptActive = false;
	savePromptCompleted = true;
	CustomSubstate.closeCustomSubstate();
	savePromptInputText = '';
	savePromptInputDisplay = null;
	savePromptTexts = [];
	debug('Save interface closed - song can now end');

	game.endSong();
}

// ========================================
// PLAYBACK: CORE
// ========================================
// --- Playback State Variables ---
var isPlayingReplay:Bool = false;
var currentReplay:Dynamic = null;
var noteHitIndex:Int = 0;
var playbackStartTime:Float = 0;
var isHittingNoteFromReplay:Bool = false;
var useInputEventPlayback:Bool = false;
var inputEventIndex:Int = 0;
var simulatedControls:Array<Bool> = [false, false, false, false];
var prevControls:Array<Bool> = [false, false, false, false];
var replayTxt:FlxText = null;
var replaySine:Float = 0;
var originalClientPrefs:Dynamic = null;
var originalGameplaySettings:Dynamic = null;
var settingsBackedUp:Bool = false;

/**
 * Backs up the user's current ClientPrefs and gameplay settings.
 * Called before applying replay settings to allow restoration later.
 */
function backupUserSettings() {
	if (settingsBackedUp) {
		debug('Settings already backed up, skipping');
		return;
	}

	// Backup ClientPrefs
	var prefs = ClientPrefs.data;
	originalClientPrefs = {
		downScroll: prefs.downScroll,
		middleScroll: prefs.middleScroll,
		opponentStrums: prefs.opponentStrums,
		ghostTapping: prefs.ghostTapping,
		guitarHeroSustains: prefs.guitarHeroSustains,
		ratingOffset: prefs.ratingOffset,
		sickWindow: prefs.sickWindow,
		goodWindow: prefs.goodWindow,
		badWindow: prefs.badWindow,
		safeFrames: prefs.safeFrames
	};

	// Backup gameplay settings
	originalGameplaySettings = {
		scrollType: ClientPrefs.getGameplaySetting('scrolltype'),
		scrollSpeed: ClientPrefs.getGameplaySetting('scrollspeed'),
		playbackRate: ClientPrefs.getGameplaySetting('songspeed'),
		healthGain: ClientPrefs.getGameplaySetting('healthgain'),
		healthLoss: ClientPrefs.getGameplaySetting('healthloss')
	};

	settingsBackedUp = true;
	debug('User settings backed up');
}

/**
 * Restores the user's original ClientPrefs and gameplay settings.
 * Called after replay ends to return settings to their pre-replay state.
 */
function restoreUserSettings() {
	if (!settingsBackedUp) {
		debug('No settings to restore');
		return;
	}

	if (originalClientPrefs != null) {
		var prefs = ClientPrefs.data;
		prefs.downScroll = originalClientPrefs.downScroll;
		prefs.middleScroll = originalClientPrefs.middleScroll;
		prefs.opponentStrums = originalClientPrefs.opponentStrums;
		prefs.ghostTapping = originalClientPrefs.ghostTapping;
		prefs.guitarHeroSustains = originalClientPrefs.guitarHeroSustains;
		prefs.ratingOffset = originalClientPrefs.ratingOffset;
		prefs.sickWindow = originalClientPrefs.sickWindow;
		prefs.goodWindow = originalClientPrefs.goodWindow;
		prefs.badWindow = originalClientPrefs.badWindow;
		prefs.safeFrames = originalClientPrefs.safeFrames;
		debug('ClientPrefs restored');
	}

	if (originalGameplaySettings != null) {
		var gs = ClientPrefs.data.gameplaySettings;
		debug('Restoring scrolltype to ' + originalGameplaySettings.scrollType);
		gs.set('scrolltype', originalGameplaySettings.scrollType);
		debug('Restoring scrollspeed to ' + originalGameplaySettings.scrollSpeed);
		gs.set('scrollspeed', originalGameplaySettings.scrollSpeed);
		debug('Restoring songspeed to ' + originalGameplaySettings.playbackRate);
		gs.set('songspeed', originalGameplaySettings.playbackRate);
		debug('Restoring healthgain to ' + originalGameplaySettings.healthGain);
		gs.set('healthgain', originalGameplaySettings.healthGain);
		debug('Restoring healthloss to ' + originalGameplaySettings.healthLoss);
		gs.set('healthloss', originalGameplaySettings.healthLoss);
		debug('Gameplay settings restored');
	}

	settingsBackedUp = false;
	originalClientPrefs = null;
	originalGameplaySettings = null;
	debug('User settings fully restored');
}

/**
 * Applies replay settings to match the original recording conditions.
 * Sets ClientPrefs and gameplay settings from the replay data.
 * @param replay The replay data object containing settings
 */
function applyReplaySettings(replay:Dynamic) {
	if (replay == null) {
		debug('Cannot apply settings - null replay');
		return;
	}

	if (Reflect.hasField(replay, 'clientPrefs')) {
		var replayPrefs = replay.clientPrefs;
		if (replayPrefs != null) {
			var prefs = ClientPrefs.data;
			var prefFields = [
				'downScroll',
				'middleScroll',
				'opponentStrums',
				'ghostTapping',
				'guitarHeroSustains',
				'ratingOffset',
				'sickWindow',
				'goodWindow',
				'badWindow',
				'safeFrames'
			];

			for (field in prefFields) {
				if (Reflect.hasField(replayPrefs, field)) {
					Reflect.setField(prefs, field, Reflect.field(replayPrefs, field));
				}
			}
			debug('Applied ClientPrefs from replay');
		}
	}

	if (Reflect.hasField(replay, 'gameplaySettings')) {
		var replayGS = replay.gameplaySettings;
		if (replayGS != null) {
			var gs = ClientPrefs.data.gameplaySettings;
			var settingsMap = [
				{replay: 'scrollType', game: 'scrolltype'},
				{replay: 'scrollSpeed', game: 'scrollspeed'},
				{replay: 'playbackRate', game: 'songspeed'},
				{replay: 'healthGain', game: 'healthgain'},
				{replay: 'healthLoss', game: 'healthloss'}
			];

			for (setting in settingsMap) {
				if (Reflect.hasField(replayGS, setting.replay)) {
					var value = Reflect.field(replayGS, setting.replay);
					debug('Setting ' + setting.game + ' to ' + value);
					gs.set(setting.game, value);
				}
			}
			debug('Applied gameplay settings from replay');
		}
	}
}

/**
 * Starts playback of a replay.
 * Initializes playback state and displays the REPLAY indicator.
 * @param replay The replay data object to play
 */
function startPlayback(replay:Dynamic) {
	if (replay == null || replay.inputEvents == null) {
		debug('Invalid replay data');
		return;
	}

	currentReplay = replay;
	isPlayingReplay = true;
	noteHitIndex = 0;
	playbackStartTime = Conductor.songPosition;
	replaySine = 0;

	simulatedControls = [false, false, false, false];
	prevControls = [false, false, false, false];

	inputEventIndex = 0;
	useInputEventPlayback = (Reflect.hasField(replay, 'inputEvents') && replay.inputEvents != null && replay.inputEvents.length > 0);

	var healthBar = game.healthBar;
	var yPos = ClientPrefs.data.downScroll ? healthBar.y + 70 : healthBar.y - 90;

	replayTxt = createText('REPLAY', 400, yPos, FlxG.width - 800, 32, FlxColor.WHITE, 'center', 1.25);
	replayTxt.cameras = [game.camHUD];
	game.add(replayTxt);

	var hasNoteHits = (Reflect.hasField(replay, 'noteHits') && replay.noteHits != null && replay.noteHits.length > 0);
	var version = Reflect.hasField(replay, 'version') ? replay.version : 1;

	if (hasNoteHits) {
		var eventInfo = useInputEventPlayback ? (' | input events: ' + currentReplay.inputEvents.length) : '';
		debug('Playback started with ' + currentReplay.noteHits.length + ' note hits (v' + version + ')' + eventInfo);
	}
}

/**
 * Stops playback and cleans up replay state.
 */
function stopPlayback() {
	isPlayingReplay = false;
	currentReplay = null;
	noteHitIndex = 0;
	inputEventIndex = 0;
	useInputEventPlayback = false;

	if (replayTxt != null) {
		game.remove(replayTxt);
		replayTxt.destroy();
		replayTxt = null;
	}

	modDirectoryOverrideActive = false;
	pendingReplayModDirectory = null;
	debug('Playback stopped');
}

/**
 * Main playback update loop. Called every frame during replay playback.
 * Handles input events, note hits, animations, and sustains.
 */
function updatePlayback() {
	if (!isPlayingReplay || currentReplay == null || game == null)
		return;

	var currentTime = Conductor.songPosition;

	updatePlaybackFrameStates(currentTime);
	hitNotesFromRecording(currentTime);
	animateGhostInputs();
	checkSustainNotes();

	syncPrevControlsWithSimulated();
}

/**
 * Processes input events from the replay at the current song time.
 * Updates simulatedControls array based on recorded press/release events.
 * @param currentTime Current song position in milliseconds
 */
function updatePlaybackFrameStates(currentTime:Float) {
	if (!useInputEventPlayback || currentReplay.inputEvents == null)
		return;

	var events = currentReplay.inputEvents;
	var processed:Bool = false;
	var prevStates = [
		simulatedControls[0],
		simulatedControls[1],
		simulatedControls[2],
		simulatedControls[3]
	];

	while (inputEventIndex < events.length) {
		var event = events[inputEventIndex];
		var eventTime = Std.parseFloat(Std.string(event.time));
		if (eventTime > currentTime)
			break;

		processed = true;
		var col = Std.int(event.col);
		simulatedControls[col] = (event.pressed == true);
		inputEventIndex = inputEventIndex + 1;
	}

	if (processed) {
		for (i in 0...4)
			prevControls[i] = prevStates[i];
	}
}

/**
 * Processes note hit events from the replay at the current song time.
 * Finds and hits matching notes using game.goodNoteHit().
 * @param currentTime Current song position in milliseconds
 */
function hitNotesFromRecording(currentTime:Float) {
	if (currentReplay == null || game == null)
		return;

	var noteHits = currentReplay.noteHits;
	if (noteHits == null || noteHits.length == 0)
		return;

	while (noteHitIndex < noteHits.length) {
		var hitData = noteHits[noteHitIndex];
		var hitTime = Std.parseFloat(Std.string(hitData.hitTime));

		if (hitTime > currentTime)
			break;

		noteHitIndex = noteHitIndex + 1;

		var col = Std.int(hitData.col);
		var note = findNoteForRecordedHit(col, hitData);
		if (note != null) {
			var originalSongPos:Float = Conductor.songPosition;
			var restoreSongPos:Bool = false;
			if (hitData != null && Reflect.hasField(hitData, 'hitTime')) {
				var recordedHit = Std.parseFloat(Std.string(hitData.hitTime));
				if (!Math.isNaN(recordedHit)) {
					restoreSongPos = true;
					Conductor.songPosition = recordedHit;
				}
			}
			isHittingNoteFromReplay = true;
			game.goodNoteHit(note);
			isHittingNoteFromReplay = false;
			if (restoreSongPos) {
				Conductor.songPosition = originalSongPos;
			}
		}
	}
}

/**
 * Finds the best matching note for a recorded hit event.
 * Matches by lane, strumTime, sustain status, and filters out already-hit notes.
 * @param lane Note column (0-3)
 * @param hitData Recorded hit data containing timing and sustain info
 * @return The matching note object, or null if not found
 */
function findNoteForRecordedHit(lane:Int, hitData:Dynamic):Dynamic {
	if (game == null || game.notes == null)
		return null;

	var members = game.notes.members;
	if (members == null)
		return null;

	var targetTime:Null<Float> = null;
	if (hitData != null && Reflect.hasField(hitData, 'time')) {
		targetTime = Std.parseFloat(Std.string(hitData.time));
	}

	var expectSustain:Bool = (hitData != null && hitData.isSustain == true);
	var bestNote:Dynamic = null;
	var bestScore:Float = 1.0e9;
	var compareTime = targetTime != null ? targetTime : Conductor.songPosition;

	for (candidate in members) {
		if (candidate == null || !candidate.mustPress || candidate.noteData != lane)
			continue;

		if (candidate.wasGoodHit || candidate.ignoreNote)
			continue;

		if ((expectSustain && !candidate.isSustainNote) || (!expectSustain && candidate.isSustainNote))
			continue;

		var score = Math.abs(candidate.strumTime - compareTime);

		if (score < bestScore) {
			bestScore = score;
			bestNote = candidate;
		}
	}

	return bestNote;
}

/**
 * Animates strums based on control state changes (press/release).
 * Shows visual feedback for ghost inputs during replay playback.
 */
function animateGhostInputs() {
	if (game == null || game.playerStrums == null)
		return;

	var strums = game.playerStrums.members;
	if (strums == null)
		return;

	for (i in 0...4) {
		if (!prevControls[i] && simulatedControls[i])
			showGhostPress(i);
		if (prevControls[i] && !simulatedControls[i])
			showGhostRelease(i);
	}
}

/**
 * Shows strum press animation for a ghost input.
 * @param lane Strum lane (0-3)
 */
function showGhostPress(lane:Int) {
	if (game == null || game.playerStrums == null)
		return;
	var strums = game.playerStrums.members;
	if (lane >= 0 && lane < strums.length) {
		var strum = strums[lane];
		if (strum != null && strum.animation.curAnim.name != 'confirm') {
			strum.playAnim('pressed');
			strum.resetAnim = 0;
		}
	}
}

/**
 * Shows strum release animation for a ghost input.
 * @param lane Strum lane (0-3)
 */
function showGhostRelease(lane:Int) {
	if (game == null || game.playerStrums == null)
		return;
	var strums = game.playerStrums.members;
	if (lane >= 0 && lane < strums.length) {
		var strum = strums[lane];
		if (strum != null) {
			strum.playAnim('static');
			strum.resetAnim = 0;
		}
	}
}

/**
 * Checks and hits sustain notes that should be held based on current control states.
 * Runs every frame to ensure sustains are hit properly during replay.
 */
function checkSustainNotes() {
	if (game == null || game.notes == null)
		return;

	var members = game.notes.members;
	if (members == null)
		return;

	var guitarHero = game.guitarHeroSustains;

	for (lane in 0...4) {
		if (!simulatedControls[lane])
			continue;

		for (note in members) {
			if (note == null || !note.mustPress || note.noteData != lane || !note.isSustainNote)
				continue;

			if (note.wasGoodHit || note.tooLate || !note.canBeHit || note.blockHit)
				continue;

			if (guitarHero && (note.parent == null || !note.parent.wasGoodHit))
				continue;

			game.goodNoteHit(note);
		}
	}
}

/**
 * Syncs the previous control states with current simulated states.
 * Called at end of updatePlayback() to prepare for next frame.
 */
function syncPrevControlsWithSimulated() {
	for (i in 0...4)
		prevControls[i] = simulatedControls[i];
}

// ========================================
// REPLAY VIEWER: UI CREATION
// ========================================
// --- Replay Viewer State Variables ---
var replayMenu:FlxTypedGroup = null;
var replayMenuActive:Bool = false;
var replayMenuSelection:Int = 0;
var replayMenuScroll:Float = 0;
var replayMenuItems:Array<String> = [];
var replayMenuTexts:Array<Dynamic> = [];
var replayMenuTitle:FlxText = null;
var replayMenuInstructions:FlxText = null;

/**
 * Creates and displays the replay viewer menu interface.
 * Shows list of available replays with metadata and selection UI.
 */
function createReplayViewerMenu() {
	replayMenu = new FlxTypedGroup();
	customSubstate.add(replayMenu);

	var bgOverlay = createSprite(0, 0, FlxG.width, FlxG.height, FlxColor.BLACK, 0.7);
	customSubstate.add(bgOverlay);

	var headerBg = createSprite(0, 20, FlxG.width, 100, FlxColor.fromRGB(20, 20, 40), 0.85);
	customSubstate.add(headerBg);

	replayMenuTitle = createText('REPLAY VIEWER', 0, 35, FlxG.width, 36, FlxColor.fromRGB(100, 200, 255), 'center', 3);
	customSubstate.add(replayMenuTitle);

	var replayCountTxt = createText(replayMenuItems.length + ' replay(s) available', 0, 80, FlxG.width, 18, FlxColor.fromRGB(180, 180, 200), 'center', 2);
	customSubstate.add(replayCountTxt);

	var footerBg = createSprite(0, FlxG.height - 80, FlxG.width, 80, FlxColor.fromRGB(20, 20, 40), 0.85);
	customSubstate.add(footerBg);

	replayMenuInstructions = createText('[▲▼] Navigate  •  [ENTER] Play  •  [ESC] Exit', 0, FlxG.height - 65, FlxG.width, 20, FlxColor.fromRGB(180, 180, 200),
		'center', 2);
	customSubstate.add(replayMenuInstructions);

	var startY = 155;
	var itemHeight = 105;

	for (i in 0...replayMenuItems.length) {
		var itemName = replayMenuItems[i];
		var replay = loadReplay(itemName);

		var itemBox = createSprite(60, startY + (i * itemHeight) - 8, FlxG.width - 120, 95, FlxColor.fromRGB(30, 30, 50), 0.4);
		customSubstate.add(itemBox);
		replayMenuTexts.push(itemBox);

		var displayName = cleanupReplayFilename(itemName);
		var itemText = createText(displayName, 80, startY + (i * itemHeight), FlxG.width - 160, 24, FlxColor.WHITE, 'left', 2.5);
		customSubstate.add(itemText);
		replayMenuTexts.push(itemText);

		var replayInfo = getReplayInfo(replay);
		var infoText = createText(replayInfo, 80, startY + (i * itemHeight) + 32, FlxG.width - 160, 16, FlxColor.GRAY, 'left', 1.5);
		customSubstate.add(infoText);
		replayMenuTexts.push(infoText);
	}

	replayMenuActive = true;
	replayMenuSelection = 0;
	replayMenuScroll = 0;
	updateMenuSelection();

	debug('Replay menu created in substate');
}

/**
 * Shows a message when no replays are found in the replays folder.
 */
function showNoReplaysMessage() {
	var noReplaysText = createText('No replays found!\n\nPlay songs to create replays.\n\nPress [ESC] to exit.', 0, FlxG.height / 2 - 50, FlxG.width, 24,
		FlxColor.WHITE, 'center', 2);
	customSubstate.add(noReplaysText);
	replayMenuActive = true;
}

/**
 * Updates visual styling and positions of menu items based on current selection.
 * Handles scrolling, highlighting, and color changes for selected items.
 */
function updateMenuSelection() {
	if (replayMenuTexts.length == 0)
		return;

	var startY = 155;
	var itemHeight = 105;
	var maxVisibleItems = 5;
	var endY = FlxG.height - 90;

	if (replayMenuSelection < replayMenuScroll) {
		replayMenuScroll = replayMenuSelection;
	} else if (replayMenuSelection >= replayMenuScroll + maxVisibleItems) {
		replayMenuScroll = replayMenuSelection - maxVisibleItems + 1;
	}

	var maxScroll = Math.max(0, replayMenuItems.length - maxVisibleItems);
	replayMenuScroll = Math.max(0, Math.min(replayMenuScroll, maxScroll));

	var textsPerItem = Std.int(replayMenuTexts.length / replayMenuItems.length);

	var bgHighlight = FlxColor.fromRGB(60, 80, 120);
	var bgNormal = FlxColor.fromRGB(30, 30, 50);
	var songSelected = FlxColor.fromRGB(255, 220, 100);

	var yOffsets = [-8, 0, 32];

	for (i in 0...replayMenuItems.length) {
		var isSelected = (i == replayMenuSelection);
		var yPos = startY + ((i - replayMenuScroll) * itemHeight);

		for (j in 0...textsPerItem) {
			var idx = (i * textsPerItem) + j;
			if (idx >= replayMenuTexts.length)
				break;

			var textElement = replayMenuTexts[idx];
			textElement.y = yPos + yOffsets[j];
			textElement.visible = (textElement.y >= (startY - 20) && textElement.y < endY);

			if (j == 0) {
				textElement.alpha = isSelected ? 0.8 : 0.4;
				textElement.color = isSelected ? bgHighlight : bgNormal;
			} else if (j == 1) {
				textElement.color = isSelected ? songSelected : FlxColor.WHITE;
			} else if (j == 2) {
				textElement.color = isSelected ? FlxColor.WHITE : FlxColor.GRAY;
			}
		}
	}

	FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
}

// ========================================
// REPLAY VIEWER: CORE LOGIC
// ========================================
// --- Replay Loading State Variables ---
var pendingReplayFilename:String = null;
var pendingReplayModDirectory:String = null;
var previousModDirectory:String = null;
var modDirectoryOverrideActive:Bool = false;

/**
 * Opens the replay viewer as a CustomSubstate.
 */
function openReplayViewerSubstate() {
	debug('Opening replay viewer as CustomSubstate');
	CustomSubstate.openCustomSubstate('ReplayViewer', true);
}

/**
 * Gets list of all replay files in the replay save folder.
 * @return Array of replay filenames (*.json files)
 */
function getReplayList():Array<String> {
	var folderPath = Paths.mods(saveFolder);

	if (!FileSystem.exists(folderPath)) {
		return [];
	}

	var files = FileSystem.readDirectory(folderPath);
	var replays = [];
	for (f in files) {
		if (StringTools.endsWith(f, '.json') && !StringTools.startsWith(f, '.')) {
			replays.push(f);
		}
	}

	debug('Found ' + replays.length + ' replays');
	return replays;
}

/**
 * Cleans up replay filename for display purposes.
 * New format: "PlayerName - SongName [Difficulty] (YYYY-MM-DD HH-MM-SS).json"
 * Just removes the .json extension for display.
 * @param filename Original filename
 * @return Cleaned up display name
 */
function cleanupReplayFilename(filename:String):String {
	if (StringTools.endsWith(filename, '.json')) {
		return filename.substring(0, filename.length - 5);
	}
	return filename;
}

/**
 * Formats replay result data into a display string.
 * @param replay Replay data object
 * @return Formatted info string with score, accuracy, ratings, etc.
 */
function getReplayInfo(replay:Dynamic):String {
	if (replay == null)
		return 'Invalid replay';
	var result = replay.result;
	if (result == null)
		return 'No result data';

	var accStr = formatAccuracy(result.acc);
	var scoreStr = formatScore(result.score);

	var info = 'Score: ' + scoreStr + ' | Acc: ' + accStr + '% | Rating: ' + result.rating;

	if (Reflect.hasField(result, 'misses') && result.misses > 0) {
		info += ' | Misses: ' + result.misses;
	}

	if (Reflect.hasField(result, 'maxCombo')) {
		info += ' | Max Combo: ' + result.maxCombo;
	}

	if (Reflect.hasField(result, 'sicks')) {
		info += '\nSicks: ' + result.sicks;
		if (Reflect.hasField(result, 'goods'))
			info += ' | Goods: ' + result.goods;
		if (Reflect.hasField(result, 'bads'))
			info += ' | Bads: ' + result.bads;
		if (Reflect.hasField(result, 'shits'))
			info += ' | Shits: ' + result.shits;
	}

	if (Reflect.hasField(replay, 'gameplaySettings')) {
		var gs = replay.gameplaySettings;
		if (gs != null && Reflect.hasField(gs, 'scrollSpeed')) {
			var speedLine = '\n';

			speedLine += 'Speed: ' + gs.scrollSpeed + 'x';

			if (Reflect.hasField(gs, 'scrollType')) {
				speedLine += ' (' + gs.scrollType + ')';
			}

			if (Reflect.hasField(gs, 'playbackRate') && gs.playbackRate != null) {
				speedLine += ' | Rate: ' + gs.playbackRate + 'x';
			}

			info += speedLine;
		}
	}

	if (Reflect.hasField(replay, 'clientPrefs')) {
		var prefs = replay.clientPrefs;
		if (prefs != null && Reflect.hasField(prefs, 'downScroll')) {
			info += ' | ' + (prefs.downScroll ? 'Downscroll' : 'Upscroll');
		}
	}

	return info;
}

/**
 * Formats accuracy float to 2 decimal places.
 * @param acc Accuracy value
 * @return Formatted string
 */
function formatAccuracy(acc:Float):String {
	return Std.string(Math.round(acc * 100) / 100);
}

/**
 * Formats score with comma separators for readability.
 * @param score Score integer
 * @return Formatted string (e.g., "1,234,567")
 */
function formatScore(score:Int):String {
	var str = Std.string(score);
	var result = '';
	var count = 0;

	for (i in 0...str.length) {
		var idx = str.length - 1 - i;
		if (count > 0 && count % 3 == 0) {
			result = ',' + result;
		}
		result = str.charAt(idx) + result;
		count = count + 1;
	}

	return result;
}

/**
 * Converts difficulty string to difficulty index.
 * @param diff Difficulty name string
 * @return Difficulty index (0=Easy, 1=Normal, 2=Hard, etc.)
 */
function getDifficultyFromString(diff:String):Int {
	var formatted = Paths.formatToSongPath(diff);
	var diffList = Difficulty.list;

	for (i in 0...diffList.length) {
		if (Paths.formatToSongPath(diffList[i]) == formatted) {
			return i;
		}
	}

	return 1;
}

/**
 * Gets the difficulty suffix for chart filenames.
 * @param diff Difficulty name
 * @return Suffix string (empty for normal, '-hard', '-easy', etc.)
 */
function getDifficultySuffix(diff:String):String {
	var formatted = Paths.formatToSongPath(diff);
	return (formatted != 'normal') ? '-' + formatted : '';
}

/**
 * Constructs the chart ID string for loading a specific difficulty.
 * @param songPath Formatted song name
 * @param diffName Difficulty name
 * @return Chart ID (e.g., 'songname' or 'songname-hard')
 */
function getChartIdForReplay(songPath:String, diffName:String):String {
	return songPath + getDifficultySuffix(diffName);
}

/**
 * Determines the correct mod directory for a replay.
 * Checks replay metadata first, then detects from file system.
 * @param replay Replay data object
 * @param songPath Formatted song name
 * @param chartId Chart identifier
 * @return Mod directory name, or null if not found
 */
function getReplayModDirectory(replay:Dynamic, songPath:String, chartId:String):String {
	if (Reflect.hasField(replay, 'modDirectory') && replay.modDirectory != null) {
		var modDir:String = Std.string(replay.modDirectory);
		if (modDir.length > 0 && chartExistsInMod(modDir, songPath, chartId)) {
			return modDir;
		}
	}

	return detectModDirectory(songPath, chartId);
}

/**
 * Checks if a chart file exists in a specific mod folder.
 * @param modName Mod directory name
 * @param songPath Formatted song name
 * @param chartId Chart identifier
 * @return True if chart exists in that mod
 */
function chartExistsInMod(modName:String, songPath:String, chartId:String):Bool {
	var path = 'mods/' + modName + '/data/' + songPath + '/' + chartId + '.json';
	return FileSystem.exists(path);
}

/**
 * Detects which mod directory contains the chart for a replay.
 * Checks current mod, global mods, enabled mods, and shared folder.
 * @param songPath Formatted song name
 * @param chartId Chart identifier
 * @return Mod directory name, or null if not found
 */
function detectModDirectory(songPath:String, chartId:String):String {
	if (Mods.currentModDirectory != null
		&& Mods.currentModDirectory.length > 0
		&& chartExistsInMod(Mods.currentModDirectory, songPath, chartId)) {
		return Mods.currentModDirectory;
	}

	var globalMods = Mods.getGlobalMods();
	for (mod in globalMods) {
		if (chartExistsInMod(mod, songPath, chartId)) {
			return mod;
		}
	}

	var modList = Mods.parseList().enabled;
	for (mod in modList) {
		if (chartExistsInMod(mod, songPath, chartId)) {
			return mod;
		}
	}

	var sharedPath = Paths.mods('data/' + songPath + '/' + chartId + '.json');
	if (FileSystem.exists(sharedPath)) {
		return '';
	}

	debug('detectModDirectory - No mod directory found for ' + songPath + '/' + chartId);
	return null;
}

/**
 * Handles input for the replay viewer menu.
 * Processes up/down navigation, enter (select), and escape (exit).
 */
function handleReplayViewerInput() {
	var controls = game.controls;
	var itemCount = replayMenuItems.length;

	// Always allow escape/back regardless of replay count
	if (controls.BACK) {
		debug('BACK pressed');
		exitReplayMenu();
		return;
	}

	if (itemCount == 0)
		return;

	if (controls.UI_UP_P) {
		debug('[Replay] UP pressed');
		replayMenuSelection = (replayMenuSelection - 1 + itemCount) % itemCount;
		updateMenuSelection();
	} else if (controls.UI_DOWN_P) {
		debug('DOWN pressed');
		replayMenuSelection = (replayMenuSelection + 1) % itemCount;
		updateMenuSelection();
	} else if (controls.ACCEPT) {
		debug('ACCEPT pressed');
		selectReplay();
	}
}

/**
 * Handles selection of a replay from the menu.
 * Loads replay data, sets up mod directory, and switches to PlayState.
 */
function selectReplay() {
	if (replayMenuSelection < 0 || replayMenuSelection >= replayMenuItems.length)
		return;

	var filename = replayMenuItems[replayMenuSelection];
	var replay = loadReplay(filename);

	if (replay == null) {
		debug('Failed to load selected replay');
		return;
	}

	debug('Selected replay: ' + filename);
	FlxG.sound.play(Paths.sound('confirmMenu'));

	pendingReplayFilename = filename;

	var songPath = Paths.formatToSongPath(replay.song);
	var diffName = replay.diff;
	var chartId = getChartIdForReplay(songPath, diffName);
	var difficultyIndex = getDifficultyFromString(diffName);

	var targetMod = getReplayModDirectory(replay, songPath, chartId);
	if (previousModDirectory == null) {
		previousModDirectory = Mods.currentModDirectory;
	}
	pendingReplayModDirectory = targetMod;
	modDirectoryOverrideActive = true;
	storePendingReplaySelection(filename, targetMod);

	debug('Target mod directory: ' + targetMod);
	debug('Previous mod directory: ' + previousModDirectory);

	Mods.currentModDirectory = (targetMod != null && targetMod.length > 0) ? targetMod : '';
	debug('Set Mods.currentModDirectory to: "' + Mods.currentModDirectory + '"');

	PlayState.SONG = Song.loadFromJson(chartId, songPath);
	PlayState.isStoryMode = false;
	PlayState.storyWeek = 0;
	PlayState.storyPlaylist = [];
	PlayState.storyDifficulty = difficultyIndex;

	StageData.forceNextDirectory = Mods.currentModDirectory;
	debug('StageData.forceNextDirectory set to: "' + StageData.forceNextDirectory + '"');
	debug('About to switch to PlayState via LoadingState');
	debug('Current Mods.currentModDirectory: "' + Mods.currentModDirectory + '"');

	LoadingState.loadAndSwitchState(new PlayState());
}

/**
 * Loads a replay file from disk and parses the JSON data.
 * @param filename Replay filename (without path)
 * @return Parsed replay data object, or null if failed
 */
function loadReplay(filename:String):Dynamic {
	var fullPath = Paths.mods(saveFolder + filename);

	if (!FileSystem.exists(fullPath)) {
		debug('Replay not found: ' + fullPath);
		return null;
	}

	try {
		var content = File.getContent(fullPath);
		var replay = TJSON.parse(content);
		debug('Replay loaded: ' + filename);
		return replay;
	} catch (e:Dynamic) {
		debug('Failed to load replay: ' + e);
		return null;
	}
}

/**
 * Loads pending replay selection data from temporary file.
 * Used to pass replay info between menu state and PlayState.
 * @return Pending replay data, or null if none exists
 */
function loadPendingReplaySelection():Dynamic {
	var path = pendingDataFile;
	if (!FileSystem.exists(path))
		return null;

	try {
		var content = File.getContent(path);
		if (content == null || StringTools.trim(content).length == 0)
			return null;
		return TJSON.parse(content);
	} catch (e:Dynamic) {
		return null;
	}
}

/**
 * Stores pending replay selection to temporary file for next PlayState load.
 * @param filename Replay filename to load
 * @param modDirectory Mod directory to use
 */
function storePendingReplaySelection(filename:String, modDirectory:String) {
	var folderPath = 'mods/' + saveFolder;
	if (!FileSystem.exists(folderPath)) {
		FileSystem.createDirectory(folderPath);
	}

	var path = pendingDataFile;
	var data = {
		filename: filename,
		modDirectory: modDirectory
	};

	try {
		File.saveContent(path, TJSON.encode(data));
		debug('Stored pending replay handoff');
	} catch (e:Dynamic) {
		debug('Failed to store pending replay: ' + e);
	}
}

/**
 * Clears the pending replay selection file.
 */
function clearPendingReplaySelection() {
	var path = pendingDataFile;
	if (FileSystem.exists(path)) {
		try {
			FileSystem.deleteFile(path);
		} catch (e:Dynamic) {}
	}
}

/**
 * Exits the replay viewer menu and returns to the replay-viewer song.
 */
function exitReplayMenu() {
	FlxG.sound.play(Paths.sound('cancelMenu'));

	replayMenuActive = false;

	CustomSubstate.closeCustomSubstate();

	replayMenuTexts = [];
	replayMenuItems = [];

	game.camHUD.visible = true;
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	if (!replay_enabled) {
		return;
	}

	debug('Mods.currentModDirectory at onCreate: ' + Mods.currentModDirectory);

	var pendingFromFile = loadPendingReplaySelection();
	if (pendingFromFile != null) {
		pendingReplayFilename = pendingFromFile.filename;
		pendingReplayModDirectory = pendingFromFile.modDirectory;
		clearPendingReplaySelection();
		debug('Loaded pending replay from file: ' + pendingReplayFilename);

		var replay = loadReplay(pendingReplayFilename);
		if (replay != null) {
			debug('Replay loaded: ' + pendingReplayFilename);

			// Backup and apply replay settings BEFORE PlayState is fully created
			backupUserSettings();
			applyReplaySettings(replay);

			if (pendingReplayModDirectory != null && pendingReplayModDirectory.length > 0) {
				debug('Applying mod directory for replay: ' + pendingReplayModDirectory);
				if (previousModDirectory == null) {
					previousModDirectory = Mods.currentModDirectory;
				}
				modDirectoryOverrideActive = true;
				Mods.currentModDirectory = pendingReplayModDirectory;
			}

			setVar('loadReplayAfterCreate', replay);
			pendingReplayFilename = null;
			return;
		}
	}

	var currentSong = Paths.formatToSongPath(PlayState.SONG.song);
	if (currentSong == replayMenuSong) {
		debug('Detected replay viewer song, opening menu...');
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			openReplayViewerSubstate();
		});
	}
}

/**
 * Called after PlayState is fully created.
 * Starts replay playback if pending, or begins recording.
 */
function onCreatePost() {
	if (!replay_enabled) {
		return;
	}

	var replayToLoad = getVar('loadReplayAfterCreate');
	if (replayToLoad != null) {
		setVar('loadReplayAfterCreate', null);

		var scrollType = ClientPrefs.getGameplaySetting('scrolltype');
		var scrollSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		if (scrollType == 'multiplicative') {
			game.songSpeed = PlayState.SONG.speed * scrollSpeed;
		} else {
			game.songSpeed = scrollSpeed;
		}
		debug('Updated songSpeed to ' + game.songSpeed + ' (type: ' + scrollType + ')');

		var playbackRate = ClientPrefs.getGameplaySetting('songspeed');
		if (playbackRate != null) {
			game.playbackRate = playbackRate;
			debug('Updated playbackRate to ' + playbackRate);
		}

		debug('Starting replay playback...');
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			startPlayback(replayToLoad);
		});
		return;
	}

	var currentSong = Paths.formatToSongPath(PlayState.SONG.song);
	if (currentSong == replayMenuSong) {
		debug('Replay viewer song - skipping auto-record');
		return;
	}

	if (!isPlayingReplay) {
		debug('Auto-starting recording...');
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			startRecording();
		});
	}
}

/**
 * Called when countdown is about to start.
 * Prevents countdown if replay menu or playback is active.
 * @return Function_Continue or Function_Stop
 */
function onStartCountdown() {
	if (!replay_enabled)
		return Function_Continue;
	if (replayMenuActive)
		return Function_Stop;
	if (isPlayingReplay)
		return Function_Stop;
	return Function_Continue;
}

/**
 * Called every frame during gameplay.
 * Updates combo tracking, replay playback, and replay text animation.
 * @param elapsed Delta time in seconds
 */
function onUpdate(elapsed:Float) {
	if (!replay_enabled)
		return;

	if (isRecording && game != null && game.combo > highestCombo) {
		highestCombo = game.combo;
	}

	if (isPlayingReplay) {
		updatePlayback();

		if (replayTxt != null && replayTxt.visible) {
			replaySine = replaySine + (180 * elapsed);
			replayTxt.alpha = 1 - Math.sin((Math.PI * replaySine) / 180);
		}
	}
}

function onKeyPress(key:Int) {
	if (!replay_enabled || !isRecording || isPlayingReplay)
		return;
	if (key < 0 || key > 3)
		return;
	recordInputEvent(key, true);
}

function onKeyRelease(key:Int) {
	if (!replay_enabled || !isRecording || isPlayingReplay)
		return;
	if (key < 0 || key > 3)
		return;
	recordInputEvent(key, false);
}

function goodNoteHit(note:Dynamic) {
	if (!replay_enabled || isHittingNoteFromReplay)
		return;

	if (isRecording && !isPlayingReplay) {
		if (note.mustPress) {
			var noteHit = {
				time: note.strumTime,
				col: note.noteData,
				isSustain: note.isSustainNote,
				hitTime: getAccurateSongTime()
			};
			noteHitRecordings.push(noteHit);
		}
	}
}

function onPause() {
	if (!replay_enabled)
		return Function_Continue;
	if (replayMenuActive || savePromptActive) {
		return Function_Stop;
	}
	return Function_Continue;
}

function onResume() {
	if (!replay_enabled)
		return Function_Continue;
	if (replayMenuActive || savePromptActive) {
		return Function_Stop;
	}
	return Function_Continue;
}

function onEndSong() {
	if (!replay_enabled)
		return Function_Continue;

	if (replayMenuActive) {
		return Function_Stop;
	}

	if (savePromptActive) {
		return Function_Stop;
	}

	if (savePromptCompleted) {
		return Function_Continue;
	}

	if (isRecording) {
		songCompleted = true;
		stopRecording();

		if (!isPlayingReplay && replayData != null) {
			createSaveInterface();
			return Function_Stop;
		}
	}

	return Function_Continue;
}

function onDestroy() {
	if (!replay_enabled)
		return;

	if (isRecording) {
		debug('Song exited early - stopping recording without saving');
		isRecording = false;
	}

	if (isPlayingReplay) {
		stopPlayback();
	}

	// Restore user's original settings if they were backed up
	if (settingsBackedUp) {
		restoreUserSettings();
	}

	if (replayTxt != null) {
		replayTxt.destroy();
		replayTxt = null;
	}

	if (modDirectoryOverrideActive) {
		debug('Mod directory override still active; deferring restore');
	} else if (previousModDirectory != null) {
		debug('Restoring mod directory to: "' + previousModDirectory + '"');
		Mods.currentModDirectory = previousModDirectory;
		previousModDirectory = null;
	}

	debug('Cleanup complete');
}

function onCustomSubstateCreate(name:String) {
	if (!replay_enabled)
		return;

	debug('onCustomSubstateCreate called with name: ' + name);

	if (name == 'ReplayViewer') {
		debug('Creating replay viewer substate');

		if (game.vocals != null)
			game.vocals.pause();
		if (game.inst != null)
			game.inst.pause();
		if (FlxG.sound.music != null)
			FlxG.sound.music.pause();

		game.camHUD.visible = false;
		if (game.boyfriend != null)
			game.boyfriend.visible = false;
		if (game.dad != null)
			game.dad.visible = false;
		if (game.gf != null)
			game.gf.visible = false;

		replayMenuItems = getReplayList();
		debug('Found ' + replayMenuItems.length + ' replays');

		if (replayMenuItems.length == 0) {
			showNoReplaysMessage();
			return;
		}

		createReplayViewerMenu();
	} else if (name == 'ReplaySavePrompt') {
		debug('Creating save prompt substate');
		buildSaveInterface();
	}
}

function onCustomSubstateUpdate(name:String, elapsed:Float) {
	if (!replay_enabled)
		return;

	if (name == 'ReplaySavePrompt') {
		savePromptCursorBlink += elapsed;
		handleSaveInterfaceInput(elapsed);
	} else if (name == 'ReplayViewer') {
		handleReplayViewerInput();
	}
}

function onCustomSubstateDestroy(name:String) {
	if (!replay_enabled)
		return;

	if (name == 'ReplayViewer') {
		debug('Replay viewer substate destroyed');
		replayMenu = null;
		replayMenuTitle = null;
		replayMenuInstructions = null;
		replayMenuTexts = [];
		replayMenuActive = false;
	} else if (name == 'ReplaySavePrompt') {
		debug('Save prompt substate destroyed');
		savePromptActive = false;
		savePromptInputText = '';
		savePromptInputDisplay = null;
		savePromptCheckbox = null;
		savePromptDontAskAgain = false;
		savePromptTexts = [];
	}
}
