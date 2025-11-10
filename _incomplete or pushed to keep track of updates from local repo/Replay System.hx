/*
	>>> Replay System Alpha
	Testing approach using Controls.pressed/justPressed/justReleased
	- Records actual control states every frame
	- No input blocking (for now)
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
var replay_enabled:Bool = true;
var replay_autoRecord:Bool = true;
var replay_autoSaveReplays:Bool = false;
var replay_playerName:String = '';
var replay_saveFolder:String = 'replays/';
var replay_viewerSongName:String = 'replay-viewer';
var replay_pendingDataFile:String = 'mods/replays/.pending-replay.json';
var replay_debug:Bool = false;
var replay_useFancyJSON:Bool = false; // Use 'fancy' format for readable JSON, false for compact

// --- Internal Variables (DO NOT MODIFY) ---
var isRecording:Bool = false;
var replayData:Dynamic = null;
var recordingStartTime:Float = 0;
var songCompleted:Bool = false;
var highestCombo:Int = 0;
var savedReplayFilename:String = null;
var noteHitRecordings:Array<Dynamic> = [];
var inputEventRecordings:Array<Dynamic> = [];
var isPlayingReplay:Bool = false;
var currentReplay:Dynamic = null;
var playbackIndex:Int = 0;
var noteHitIndex:Int = 0;
var playbackStartTime:Float = 0;
var isHittingNoteFromReplay:Bool = false;
var useInputEventPlayback:Bool = false;
var inputEventIndex:Int = 0;
var simulatedControls:Array<Bool> = [false, false, false, false];
var prevControls:Array<Bool> = [false, false, false, false];
var replayTxt:FlxText = null;
var replaySine:Float = 0;
var replayMenu:FlxTypedGroup = null;
var replayMenuActive:Bool = false;
var replayMenuSelection:Int = 0;
var replayMenuScroll:Float = 0;
var replayMenuItems:Array<String> = [];
var replayMenuTexts:Array<Dynamic> = [];
var replayMenuTitle:FlxText = null;
var replayMenuInstructions:FlxText = null;
var savePromptActive:Bool = false;
var savePromptCompleted:Bool = false;
var savePromptInputText:String = '';
var savePromptTexts:Array<FlxText> = [];
var savePromptInputDisplay:FlxText = null;
var savePromptCursorBlink:Float = 0;
var pendingReplayFilename:String = null;
var pendingReplayModDirectory:String = null;
var previousModDirectory:String = null;
var modDirectoryOverrideActive:Bool = false;

// ========================================
// DEBUG HELPERS
// ========================================

/**
 * Helper function to print debug messages or traces only if replay_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(msg:String) {
	if (!replay_debug)
		return;
	trace('[Replay System] ' + msg);
}

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
		trace('[Replay System] settings.json not found, using default values from script');
		return;
	}
	trace('[Replay System] settings.json found, loading settings...');

	var value:Dynamic;

	if ((value = getModSetting('replaySystem_enabled')) != null)
		replay_enabled = value;

	if ((value = getModSetting('replaySystem_debug')) != null)
		replay_debug = value;

	debug('Settings loaded - Enabled: ' + replay_enabled + ', Player Name: "' + replay_playerName + '", Debug: ' + replay_debug);
}

// ========================================
// CUSTOM FUNCTIONS
// ========================================

function startRecording() {
	isRecording = true;
	recordingStartTime = Conductor.songPosition;
	noteHitRecordings = [];
	inputEventRecordings = [];
	songCompleted = false;
	highestCombo = 0;
	savedReplayFilename = null;

	var diffName = game.storyDifficultyText;
	var timestamp = Std.int(FlxG.game.ticks / 1000);

	replayData = {
		version: 3,
		song: PlayState.SONG.song,
		diff: diffName,
		timestamp: timestamp,
		playerName: replay_playerName,
		modDirectory: (Mods.currentModDirectory != null ? Mods.currentModDirectory : ''),
		noteHits: [],
		inputEvents: [],
		result: {}
	};

	debug('Recording started: ' + PlayState.SONG.song + ' (' + diffName + ')');
}

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

function startPlayback(replay:Dynamic) {
	if (replay == null || replay.inputEvents == null) {
		debug('Invalid replay data');
		return;
	}

	currentReplay = replay;
	isPlayingReplay = true;
	playbackIndex = 0;
	noteHitIndex = 0;
	playbackStartTime = Conductor.songPosition;
	replaySine = 0;

	simulatedControls = [false, false, false, false];
	prevControls = [false, false, false, false];

	inputEventIndex = 0;
	useInputEventPlayback = (Reflect.hasField(replay, 'inputEvents') && replay.inputEvents != null && replay.inputEvents.length > 0);

	var healthBar = game.healthBar;
	var yPos = ClientPrefs.data.downScroll ? healthBar.y + 70 : healthBar.y - 90;

	replayTxt = new FlxText(400, yPos, FlxG.width - 800, 'REPLAY', 32);
	replayTxt.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
	replayTxt.borderSize = 1.25;
	replayTxt.scrollFactor.set();
	replayTxt.cameras = [game.camHUD];
	game.add(replayTxt);

	var hasNoteHits = (Reflect.hasField(replay, 'noteHits') && replay.noteHits != null && replay.noteHits.length > 0);
	var version = Reflect.hasField(replay, 'version') ? replay.version : 1;

	if (hasNoteHits) {
		var eventInfo = useInputEventPlayback ? (' | input events: ' + currentReplay.inputEvents.length) : '';
		debug('Playback started with ' + currentReplay.noteHits.length + ' note hits (v' + version + ')' + eventInfo);
	} else {
		debug('Playback started (v' + version + ' - legacy mode without note hits)');
	}
}

function stopPlayback() {
	isPlayingReplay = false;
	currentReplay = null;
	playbackIndex = 0;
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
		var eventTime = Std.parseFloat(Std.string(event.t));
		if (eventTime > currentTime)
			break;

		processed = true;
		var lane = Std.int(event.lane);
		simulatedControls[lane] = (event.down == true);
		inputEventIndex = inputEventIndex + 1;
	}

	if (processed) {
		for (i in 0...4)
			prevControls[i] = prevStates[i];
	}
}

function hitNotesFromRecording(currentTime:Float) {
	if (currentReplay == null || game == null)
		return;

	var noteHits = currentReplay.noteHits;
	if (noteHits == null || noteHits.length == 0)
		return;

	while (noteHitIndex < noteHits.length) {
		var hitData = noteHits[noteHitIndex];
		var hitTime = Std.parseFloat(Std.string(hitData.hit));

		if (hitTime > currentTime)
			break;

		noteHitIndex = noteHitIndex + 1;

		var lane = Std.int(hitData.lane);
		var note = findNoteForRecordedHit(lane, hitData);
		if (note != null) {
			var originalSongPos:Float = Conductor.songPosition;
			var restoreSongPos:Bool = false;
			if (hitData != null && Reflect.hasField(hitData, 'hit')) {
				var recordedHit = Std.parseFloat(Std.string(hitData.hit));
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

function findNoteForRecordedHit(lane:Int, hitData:Dynamic):Dynamic {
	if (game == null || game.notes == null)
		return null;

	var members = game.notes.members;
	if (members == null)
		return null;

	var targetTime:Null<Float> = null;
	if (hitData != null && Reflect.hasField(hitData, 't')) {
		targetTime = Std.parseFloat(Std.string(hitData.t));
	}

	var expectSustain:Bool = (hitData != null && hitData.sus == true);
	var bestNote:Dynamic = null;
	var bestScore:Float = 1.0e9;

	for (candidate in members) {
		if (candidate == null)
			continue;
		if (!candidate.mustPress)
			continue;
		if (candidate.noteData != lane)
			continue;
		if (candidate.wasGoodHit)
			continue;
		if (candidate.ignoreNote)
			continue;
		if (expectSustain && !candidate.isSustainNote)
			continue;
		if (!expectSustain && candidate.isSustainNote)
			continue;

		var score:Float;
		if (targetTime != null) {
			score = Math.abs(candidate.strumTime - targetTime);
		} else {
			score = Math.abs(candidate.strumTime - Conductor.songPosition);
		}

		if (score < bestScore) {
			bestScore = score;
			bestNote = candidate;
		}
	}

	return bestNote;
}

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

function checkSustainNotes() {
	if (game == null || game.notes == null)
		return;

	var members = game.notes.members;
	if (members == null)
		return;

	for (lane in 0...4) {
		if (!simulatedControls[lane])
			continue;

		for (note in members) {
			if (note == null)
				continue;
			if (!note.mustPress)
				continue;
			if (note.noteData != lane)
				continue;
			if (!note.isSustainNote)
				continue;

			if (note.wasGoodHit)
				continue;
			if (note.tooLate)
				continue;
			if (!note.canBeHit)
				continue;
			if (note.blockHit)
				continue;

			if (game.guitarHeroSustains) {
				if (note.parent == null)
					continue;
				if (!note.parent.wasGoodHit)
					continue;
			}

			game.goodNoteHit(note);
		}
	}
}

function recordInputEvent(lane:Int, isDown:Bool) {
	var timeStamp = getAccurateSongTime();
	inputEventRecordings.push({
		t: timeStamp,
		lane: lane,
		down: isDown
	});
}

function getAccurateSongTime():Float {
	if (FlxG != null && FlxG.sound != null && FlxG.sound.music != null) {
		return FlxG.sound.music.time + Conductor.offset;
	}
	return Conductor.songPosition;
}

function syncPrevControlsWithSimulated() {
	for (i in 0...4)
		prevControls[i] = simulatedControls[i];
}

function saveReplay(replay:Dynamic):String {
	var folderPath = Paths.mods(replay_saveFolder);
	if (!FileSystem.exists(folderPath)) {
		FileSystem.createDirectory(folderPath);
	}

	var baseFilename = replay.song + '-' + replay.diff;
	var filename = generateUniqueFilename(folderPath, baseFilename);
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

function generateUniqueFilename(folderPath:String, baseName:String):String {
	try {
		var now = Date.now();
		var timestamp = DateTools.format(now, '%Y%m%d-%H%M%S');
		var filename = baseName + '-' + timestamp + '.json';

		if (!FileSystem.exists(folderPath + filename)) {
			return filename;
		}
	} catch (e:Dynamic) {
		debug('Failed to get system date/time: ' + e);
	}

	var counter = 1;
	var filename = baseName + '-' + counter + '.json';

	while (FileSystem.exists(folderPath + filename)) {
		counter = counter + 1;
		filename = baseName + '-' + counter + '.json';

		if (counter > 9999) {
			filename = baseName + '-' + Std.string(Math.floor(Math.random() * 999999)) + '.json';
			break;
		}
	}

	return filename;
}

function loadReplay(filename:String):Dynamic {
	var fullPath = Paths.mods(replay_saveFolder + filename);

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

function getReplayList():Array<String> {
	var folderPath = Paths.mods(replay_saveFolder);

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

function loadPendingReplaySelection():Dynamic {
	var path = replay_pendingDataFile;
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

function storePendingReplaySelection(filename:String, modDirectory:String) {
	var folderPath = 'mods/' + replay_saveFolder;
	if (!FileSystem.exists(folderPath)) {
		FileSystem.createDirectory(folderPath);
	}

	var path = replay_pendingDataFile;
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

function clearPendingReplaySelection() {
	var path = replay_pendingDataFile;
	if (FileSystem.exists(path)) {
		try {
			FileSystem.deleteFile(path);
		} catch (e:Dynamic) {}
	}
}

function openReplayViewerSubstate() {
	debug('Opening replay viewer as CustomSubstate');
	CustomSubstate.openCustomSubstate('ReplayViewer', true);
}

function createReplayViewerMenu() {
	replayMenu = new FlxTypedGroup();
	customSubstate.add(replayMenu);

	var bgOverlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	bgOverlay.alpha = 0.7;
	bgOverlay.scrollFactor.set();
	customSubstate.add(bgOverlay);

	var headerBg = new FlxSprite(0, 20).makeGraphic(FlxG.width, 100, FlxColor.fromRGB(20, 20, 40));
	headerBg.alpha = 0.85;
	headerBg.scrollFactor.set();
	customSubstate.add(headerBg);

	replayMenuTitle = createText('♪ REPLAY VIEWER ♪', 0, 35, FlxG.width, 36, FlxColor.fromRGB(100, 200, 255), 'center', 3);
	customSubstate.add(replayMenuTitle);

	var replayCountTxt = createText(replayMenuItems.length + ' replay(s) available', 0, 80, FlxG.width, 18, FlxColor.fromRGB(180, 180, 200), 'center', 2);
	customSubstate.add(replayCountTxt);

	var footerBg = new FlxSprite(0, FlxG.height - 80).makeGraphic(FlxG.width, 80, FlxColor.fromRGB(20, 20, 40));
	footerBg.alpha = 0.85;
	footerBg.scrollFactor.set();
	customSubstate.add(footerBg);

	replayMenuInstructions = createText('▲▼ Navigate  •  ENTER Play  •  ESC Exit', 0, FlxG.height - 65, FlxG.width, 20, FlxColor.fromRGB(180, 180, 200),
		'center', 2);
	customSubstate.add(replayMenuInstructions);

	var startY = 155;
	var itemHeight = 105;

	for (i in 0...replayMenuItems.length) {
		var itemName = replayMenuItems[i];
		var replay = loadReplay(itemName);

		var itemBox = new FlxSprite(60, startY + (i * itemHeight) - 8).makeGraphic(FlxG.width - 120, 95, FlxColor.fromRGB(30, 30, 50));
		itemBox.alpha = 0.4;
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

		var hasPlayerName = (replay != null
			&& Reflect.hasField(replay, 'playerName')
			&& replay.playerName != null
			&& replay.playerName.length > 0);
		var hasModDir = (replay != null
			&& Reflect.hasField(replay, 'modDirectory')
			&& replay.modDirectory != null
			&& replay.modDirectory.length > 0);

		if (hasPlayerName && hasModDir) {
			var playerText = createText('👤 ' + replay.playerName, 80, startY + (i * itemHeight) + 58, (FlxG.width / 2) - 90, 14,
				FlxColor.fromRGB(120, 255, 120), 'left', 1.5);
			customSubstate.add(playerText);
			replayMenuTexts.push(playerText);

			var modText = createText('📁 ' + replay.modDirectory, (FlxG.width / 2) + 10, startY + (i * itemHeight) + 58, (FlxG.width / 2) - 90, 14,
				FlxColor.fromRGB(120, 180, 255), 'left', 1.5);
			customSubstate.add(modText);
			replayMenuTexts.push(modText);
		} else if (hasPlayerName) {
			var playerText = createText('👤 ' + replay.playerName, 80, startY + (i * itemHeight) + 58, FlxG.width - 160, 14, FlxColor.fromRGB(120, 255, 120),
				'left', 1.5);
			customSubstate.add(playerText);
			replayMenuTexts.push(playerText);
		} else if (hasModDir) {
			var modText = createText('📁 ' + replay.modDirectory, 80, startY + (i * itemHeight) + 58, FlxG.width - 160, 14, FlxColor.fromRGB(120, 180, 255),
				'left', 1.5);
			customSubstate.add(modText);
			replayMenuTexts.push(modText);
		}
	}

	replayMenuActive = true;
	replayMenuSelection = 0;
	replayMenuScroll = 0;
	updateMenuSelection();

	debug('Replay menu created in substate');
}

function cleanupReplayFilename(filename:String):String {
	if (StringTools.endsWith(filename, '.json')) {
		filename = filename.substring(0, filename.length - 5);
	}

	var parts = filename.split('-');
	if (parts.length >= 3) {
		var lastPart = parts[parts.length - 1];
		var isTimestamp = true;
		for (i in 0...lastPart.length) {
			if (lastPart.charAt(i) < '0' || lastPart.charAt(i) > '9') {
				isTimestamp = false;
				break;
			}
		}
		if (isTimestamp) {
			parts.pop();
		}
	}

	return parts.join('-');
}

function showNoReplaysMessage() {
	var noReplaysText = createText('No replays found!\n\nPlay songs to create replays.\n\nPress [ESC] to exit.', 0, FlxG.height / 2 - 50, FlxG.width, 24,
		FlxColor.WHITE, 'center', 2);
	customSubstate.add(noReplaysText);
	replayMenuActive = true;
}

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
	if (replayMenuScroll < 0)
		replayMenuScroll = 0;
	if (replayMenuScroll > maxScroll)
		replayMenuScroll = maxScroll;

	var textsPerItem = Std.int(replayMenuTexts.length / replayMenuItems.length);

	for (i in 0...replayMenuItems.length) {
		var startIdx = i * textsPerItem;

		var yPos = startY + ((i - replayMenuScroll) * itemHeight);

		for (j in 0...textsPerItem) {
			var idx = startIdx + j;
			if (idx >= replayMenuTexts.length)
				break;

			var textElement = replayMenuTexts[idx];

			var yOffset = 0;
			if (j == 0)
				yOffset = -8; // Background box
			else if (j == 1)
				yOffset = 0; // Song name
			else if (j == 2)
				yOffset = 32; // Info text
			else if (j == 3)
				yOffset = 58; // Player name or mod (when only one exists)
			else if (j == 4)
				yOffset = 58; // Second item on same line (player + mod both exist)

			textElement.y = yPos + yOffset;

			textElement.visible = (textElement.y >= (startY - 20) && textElement.y < endY);

			if (i == replayMenuSelection) {
				if (j == 0) {
					// Background box - highlighted
					textElement.alpha = 0.8;
					textElement.color = FlxColor.fromRGB(60, 80, 120);
				} else if (j == 1) {
					// Song name - yellow/gold
					textElement.color = FlxColor.fromRGB(255, 220, 100);
				} else if (j == 2) {
					// Info text - white when selected
					textElement.color = FlxColor.WHITE;
				} else {
					// Player/Mod - keep original colors but brighter
					var textContent = Reflect.field(textElement, 'text');
					if (textContent != null) {
						var textStr = Std.string(textContent);
						if (textStr.indexOf('👤') >= 0) {
							textElement.color = FlxColor.fromRGB(150, 255, 150);
						} else {
							textElement.color = FlxColor.fromRGB(150, 200, 255);
						}
					}
				}
			} else {
				// Unselected styling
				if (j == 0) {
					// Background box - dimmed
					textElement.alpha = 0.4;
					textElement.color = FlxColor.fromRGB(30, 30, 50);
				} else if (j == 1) {
					// Song name - white
					textElement.color = FlxColor.WHITE;
				} else if (j == 2) {
					// Info text - gray
					textElement.color = FlxColor.GRAY;
				} else {
					// Player/Mod - original dimmed colors
					var textContent = Reflect.field(textElement, 'text');
					if (textContent != null) {
						var textStr = Std.string(textContent);
						if (textStr.indexOf('👤') >= 0) {
							textElement.color = FlxColor.fromRGB(120, 255, 120);
						} else {
							textElement.color = FlxColor.fromRGB(120, 180, 255);
						}
					}
				}
			}
		}
	}

	FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
}

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

function exitReplayMenu() {
	FlxG.sound.play(Paths.sound('cancelMenu'));

	replayMenuActive = false;

	CustomSubstate.closeCustomSubstate();

	replayMenuTexts = [];
	replayMenuItems = [];

	game.camHUD.visible = true;
	if (game.boyfriend != null)
		game.boyfriend.visible = true;
	if (game.dad != null)
		game.dad.visible = true;
	if (game.gf != null)
		game.gf.visible = true;
}

function createSaveInterface() {
	if (savePromptActive)
		return;

	debug('Creating save interface - opening substate');

	savePromptInputText = replay_playerName;
	savePromptCursorBlink = 0;
	savePromptCompleted = false;

	CustomSubstate.openCustomSubstate('ReplaySavePrompt');
	savePromptActive = true;
}

function buildSaveInterface() {
	var overlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	overlay.alpha = 0.7;
	overlay.scrollFactor.set();
	customSubstate.add(overlay);

	var centerX = FlxG.width / 2;
	var centerY = FlxG.height / 2;

	var titleText = createText('Save Replay', 0, centerY - 120, FlxG.width, 32, FlxColor.WHITE, 'center', 2);
	customSubstate.add(titleText);
	savePromptTexts.push(titleText);

	var labelText = createText('Player Name:', 0, centerY - 60, FlxG.width, 20, FlxColor.fromRGB(200, 200, 200), 'center', 2);
	customSubstate.add(labelText);
	savePromptTexts.push(labelText);

	var inputBg = new FlxSprite(centerX - 155, centerY - 25).makeGraphic(310, 40, FlxColor.fromRGB(40, 40, 40));
	inputBg.scrollFactor.set();
	customSubstate.add(inputBg);

	var inputBorder = new FlxSprite(centerX - 157, centerY - 27).makeGraphic(314, 44, FlxColor.WHITE);
	inputBorder.scrollFactor.set();
	customSubstate.add(inputBorder);
	customSubstate.remove(inputBorder);
	customSubstate.insert(customSubstate.members.indexOf(inputBg), inputBorder);

	savePromptInputDisplay = new FlxText(centerX - 145, centerY - 15, 290, savePromptInputText, 18);
	savePromptInputDisplay.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, 'left');
	savePromptInputDisplay.scrollFactor.set();
	customSubstate.add(savePromptInputDisplay);

	var instructText = createText('[ENTER] Save  |  [ESC] ' + (replay_autoSaveReplays ? 'Cancel' : 'Discard'), 0, centerY + 30, FlxG.width, 18,
		FlxColor.fromRGB(150, 150, 150), 'center', 2);
	customSubstate.add(instructText);
	savePromptTexts.push(instructText);

	if (replay_autoSaveReplays) {
		var infoText = createText('(Replay already auto-saved, this updates the name)', 0, centerY + 60, FlxG.width, 14, FlxColor.fromRGB(100, 100, 255),
			'center', 1);
		customSubstate.add(infoText);
		savePromptTexts.push(infoText);
	}

	debug('Save interface created');
}

function handleSaveInterfaceInput(elapsed:Float) {
	if (!savePromptActive || savePromptInputDisplay == null)
		return;

	var controls = game.controls;

	var validChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_.,!?@#';

	for (i in 0...validChars.length) {
		var char = validChars.charAt(i);
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

			if (savedReplayFilename != null) {
				var folderPath = Paths.mods(replay_saveFolder);
				var fullPath = folderPath + savedReplayFilename;
				try {
					File.saveContent(fullPath, TJSON.encode(replayData, 'fancy'));
					debug('Replay updated with player name: ' + savePromptInputText);
					FlxG.sound.play(Paths.sound('confirmMenu'));
				} catch (e:Dynamic) {
					debug('Failed to update replay: ' + e);
				}
			} else {
				var filename = saveReplay(replayData);
				if (filename != null) {
					debug('Replay saved with player name: ' + savePromptInputText);
					FlxG.sound.play(Paths.sound('confirmMenu'));
				}
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

function updateInputDisplay() {
	if (savePromptInputDisplay != null) {
		savePromptInputDisplay.text = savePromptInputText;
	}
}

function handleReplayViewerInput() {
	var controls = game.controls;
	if (controls.UI_UP_P) {
		trace('[Replay] UP pressed');
		replayMenuSelection = replayMenuSelection - 1;
		if (replayMenuSelection < 0)
			replayMenuSelection = replayMenuItems.length - 1;
		updateMenuSelection();
	}
	if (controls.UI_DOWN_P) {
		trace('[Replay] DOWN pressed');
		replayMenuSelection = replayMenuSelection + 1;
		if (replayMenuSelection >= replayMenuItems.length)
			replayMenuSelection = 0;
		updateMenuSelection();
	}
	if (controls.ACCEPT) {
		trace('[Replay] ACCEPT pressed');
		selectReplay();
	}
	if (controls.BACK) {
		trace('[Replay] BACK pressed');
		exitReplayMenu();
	}
}

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

function createText(text:String, x:Float, y:Float, width:Float = 0, size:Int = 20, color:Int = 0xFFFFFFFF, align:String = 'left',
		borderSize:Float = 2):FlxText {
	var txt = new FlxText(x, y, width, text, size);
	txt.setFormat(Paths.font('vcr.ttf'), size, color, align, 'outline', FlxColor.BLACK);
	txt.borderSize = borderSize;
	txt.scrollFactor.set();
	return txt;
}

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

	return info;
}

function formatAccuracy(acc:Float):String {
	return Std.string(Math.round(acc * 100) / 100);
}

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

function getChartIdForReplay(songPath:String, diffName:String):String {
	return songPath + getDifficultySuffix(diffName);
}

function getDifficultySuffix(diff:String):String {
	var formatted = Paths.formatToSongPath(diff);
	return (formatted != 'normal') ? '-' + formatted : '';
}

function getReplayModDirectory(replay:Dynamic, songPath:String, chartId:String):String {
	if (Reflect.hasField(replay, 'modDirectory') && replay.modDirectory != null) {
		var modDir:String = Std.string(replay.modDirectory);
		if (modDir.length > 0 && chartExistsInMod(modDir, songPath, chartId)) {
			return modDir;
		}
	}

	return detectModDirectory(songPath, chartId);
}

function chartExistsInMod(modName:String, songPath:String, chartId:String):Bool {
	var path = 'mods/' + modName + '/data/' + songPath + '/' + chartId + '.json';
	return FileSystem.exists(path);
}

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

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	loadSettings();

	if (!replay_enabled) {
		return;
	}

	debug('Mods.currentModDirectory at onCreate: ' + Mods.currentModDirectory);

	registerCallbacks();

	var pendingFromFile = loadPendingReplaySelection();
	if (pendingFromFile != null) {
		pendingReplayFilename = pendingFromFile.filename;
		pendingReplayModDirectory = pendingFromFile.modDirectory;
		clearPendingReplaySelection();
		debug('Loaded pending replay from file: ' + pendingReplayFilename);

		var replay = loadReplay(pendingReplayFilename);
		if (replay != null) {
			debug('Replay loaded: ' + pendingReplayFilename);

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
	if (currentSong == replay_viewerSongName) {
		debug('Detected replay viewer song, opening menu...');
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			openReplayViewerSubstate();
		});
	}
}

function onCreatePost() {
	if (!replay_enabled)
		return;

	try {
		var testDate = Date.now();
		var testTimestamp = DateTools.format(testDate, '%Y%m%d-%H%M%S');
		trace('[Replay System] Date/DateTools test successful: ' + testTimestamp);
	} catch (e:Dynamic) {
		trace('[Replay System] Date/DateTools test FAILED: ' + e);
	}

	var replayToLoad = getVar('loadReplayAfterCreate');
	if (replayToLoad != null) {
		setVar('loadReplayAfterCreate', null);
		debug('Starting replay playback...');
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			startPlayback(replayToLoad);
		});
		return;
	}

	var currentSong = Paths.formatToSongPath(PlayState.SONG.song);
	if (currentSong == replay_viewerSongName) {
		debug('Replay viewer song - skipping auto-record');
		return;
	}

	if (replay_autoRecord && !isPlayingReplay) {
		debug('Auto-starting recording...');
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			startRecording();
		});
	}
}

function onStartCountdown() {
	if (!replay_enabled)
		return Function_Continue;
	if (replayMenuActive)
		return Function_Stop;
	if (isPlayingReplay)
		return Function_Stop;
	return Function_Continue;
}

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
	if (!isRecording || isPlayingReplay)
		return;
	if (key < 0 || key > 3)
		return;
	recordInputEvent(key, true);
}

function onKeyRelease(key:Int) {
	if (!isRecording || isPlayingReplay)
		return;
	if (key < 0 || key > 3)
		return;
	recordInputEvent(key, false);
}

function goodNoteHit(note:Dynamic) {
	if (!replay_enabled)
		return;

	if (isHittingNoteFromReplay)
		return;

	if (isRecording && !isPlayingReplay) {
		if (note.mustPress) {
			var noteHit = {
				t: note.strumTime,
				lane: note.noteData,
				sus: note.isSustainNote,
				hit: getAccurateSongTime()
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
	trace('[Replay] onCustomSubstateCreate called with name: ' + name);

	if (name == 'ReplayViewer') {
		trace('[Replay] Creating replay viewer substate');
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
		trace('[Replay] Found ' + replayMenuItems.length + ' replays');

		if (replayMenuItems.length == 0) {
			showNoReplaysMessage();
			return;
		}

		createReplayViewerMenu();
	} else if (name == 'ReplaySavePrompt') {
		trace('[Replay] Creating save prompt substate');
		debug('Creating save prompt substate');
		buildSaveInterface();
	}
}

function onCustomSubstateUpdate(name:String, elapsed:Float) {
	if (name == 'ReplaySavePrompt') {
		savePromptCursorBlink += elapsed;
		handleSaveInterfaceInput(elapsed);
	} else if (name == 'ReplayViewer') {
		handleReplayViewerInput();
	}
}

function onCustomSubstateDestroy(name:String) {
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
		savePromptTexts = [];
	}
}
