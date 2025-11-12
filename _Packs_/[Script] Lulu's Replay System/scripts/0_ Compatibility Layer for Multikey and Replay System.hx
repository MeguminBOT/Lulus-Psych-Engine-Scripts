/*
	Compatibility layer for Vortex Multikey script and Lulus Replay System.
	----------------------------------------------
	Purpose:
	- Injects keyCount into replay data during recording.
	- Makes sure Multikey and Replay System work together as both scripts tries to reload the PlayState when trying to start playback session of a replay.
 */

import backend.Difficulty;
import tjson.TJSON;
import StringTools;
import Reflect;

// Configuration
var compat_enabled:Bool = true;
var compat_debug:Bool = true;

// State tracking
var pendingKeyCount:Null<Int> = null;
var isReplayPlayback:Bool = false;
var currentKeyCount:Int = 4;

function debug(msg:String) {
	if (!compat_debug)
		return;
	trace('[Multikey-Replay Bridge] ' + msg);
}

/**
 * Detects keyCount from playerStrums (most reliable source)
 */
function detectKeyCount():Int {
	if (game != null && game.playerStrums != null && game.playerStrums.length > 0) {
		var count = game.playerStrums.length;
		if (count <= 9) {
			return count;
		}
	}
	return 4; // Default fallback
}

/**
 * Injects keyCount into replay additionalData
 */
function injectKeyCount(keyCount:Int):Bool {
	var additionalData = getVar('replayAdditionalData');
	if (additionalData == null) {
		additionalData = {};
	}
	
	Reflect.setField(additionalData, 'keyCount', keyCount);
	setVar('replayAdditionalData', additionalData);
	setVar('keyCount', keyCount);
	
	debug('Injected keyCount: ' + keyCount);
	return true;
}

function getKeyCountFromReplay(replayData:Dynamic):Int {
	if (replayData == null || !Reflect.hasField(replayData, 'additionalData'))
		return 4;

	var additionalData = Reflect.field(replayData, 'additionalData');
	if (additionalData != null && Reflect.hasField(additionalData, 'keyCount')) {
		var kc = Reflect.field(additionalData, 'keyCount');
		debug('Found keyCount in replay additionalData: ' + kc);
		return kc;
	}
	
	return 4; // Default fallback
}

function loadPendingReplayData():Dynamic {
	var pendingFile = 'mods/replays/.pending-replay.json';

	if (!FileSystem.exists(pendingFile))
		return null;

	try {
		var content = File.getContent(pendingFile);
		if (content == null || StringTools.trim(content).length == 0)
			return null;

		var pendingData = TJSON.parse(content);
		if (pendingData == null || !Reflect.hasField(pendingData, 'filename'))
			return null;

		var filename:String = Reflect.field(pendingData, 'filename');
		var replayPath = 'mods/replays/' + filename;

		if (!FileSystem.exists(replayPath))
			return null;

		var replayData = TJSON.parse(File.getContent(replayPath));
		debug('Loaded replay data from: ' + filename);
		return replayData;
	} catch (e:Dynamic) {
		debug('Error loading pending replay: ' + e);
		return null;
	}
}

function initReplayPlayback() {
	var pendingReplay = loadPendingReplayData();
	if (pendingReplay == null)
		return;

	isReplayPlayback = true;
	pendingKeyCount = getKeyCountFromReplay(pendingReplay);

	// Set keyCount BEFORE multikey's onCreate runs
	if (pendingKeyCount != null) {
		FlxG.save.data.lastKeyCount = pendingKeyCount;
		debug('Set keyCount for multikey at script init: ' + pendingKeyCount);
	}

	// Ensure difficulty exists in Difficulty.list
	if (Reflect.hasField(pendingReplay, 'diff')) {
		var diffName:String = Reflect.field(pendingReplay, 'diff');
		if (diffName != null && diffName.length > 0) {
			var diffIndex = -1;

			// Check if difficulty exists
			for (i in 0...Difficulty.list.length) {
				if (Difficulty.list[i] == diffName) {
					diffIndex = i;
					break;
				}
			}

			// Add if not found
			if (diffIndex == -1) {
				Difficulty.list.push(diffName);
				diffIndex = Difficulty.list.length - 1;
				debug('Added difficulty to list: ' + diffName + ' at index ' + diffIndex);
			} else {
				debug('Found existing difficulty: ' + diffName + ' at index ' + diffIndex);
			}

			PlayState.storyDifficulty = diffIndex;
		}
	}
}

function onCreate() {
	if (!compat_enabled)
		return;

	initReplayPlayback();

	if (pendingKeyCount != null) {
		var currentKeyCount = getVar('keyCount');
		if (currentKeyCount != null && currentKeyCount == pendingKeyCount) {
			debug('KeyCount successfully applied: ' + currentKeyCount);
		} else {
			debug('WARNING: KeyCount mismatch! Expected ' + pendingKeyCount + ', got ' + currentKeyCount);
			setVar('keyCount', pendingKeyCount);
		}
	}
}

function onCreatePost() {
	if (!compat_enabled)
		return;

	var isRecording = getVar('isRecording');
	if (isRecording) {
		var detected = detectKeyCount();
		currentKeyCount = detected;
		injectKeyCount(detected);
	}
}

function onDestroy() {
	if (!compat_enabled)
		return;
	
	// Reset state for next song
	isReplayPlayback = false;
	pendingKeyCount = null;
}
