/*
	>>> Rewind NoteCacher for Psych Engine
		"Note Cache System" script is required for this script to function.
		
		Rewind system using my Note Cache System as a proof of concept.
		Feel free to modify the settings and logic to suit your mod's needs.

		Features:
		- Rewind to a specific time or relative backwards without resetting the state.
		- Respawns notes when rewinding backwards
		- Restore player stats (score, combo, misses, health, ratings) from cached data
		- Prune old stats to save memory
		- Configurable input settings (keyboard/gamepad)
		- Smooth camera transition after rewind

		To do:
		- Optimizations
		- Find a better solution for MusicBeatSubstate fuckery

	Script by AutisticLulu.
*/

import Reflect;

// ========================================
// VARIABLES
// ========================================
// --- Input Settings ---
var useGamepad:Bool = false; // Set to true to use gamepad input instead of keyboard
var gamepadID:Int = 0; // Gamepad ID to use when useGamepad is true
var rewindButton:String = 'B'; // Button for keyboard (e.g., 'G') or gamepad (e.g., 'X', 'Y', 'A', 'B')

// --- Rewind Settings ---
var useSpecificTime:Bool = false; // true = rewind to specific time, false = relative backwards
var specificTime:Float = 10000;
var relativeTime:Float = 10000;

// --- Stat Restoration Settings ---
var restoreStatsOnRewind:Bool = true; // true = restore stats from target time, false = reset to zero
var enableStatPruning:Bool = false; // false = prune old stats to save memory, false = keep all stats.
var pruneInterval:Float = 10000; // Interval to prune old stats from timeline (in ms) *Requires some tinkering*
var statsRestoreTolerance:Float = 2000; // Max time difference for stat restoration (in ms) *Requires some tinkering*

// --- Camera Settings ---
var tempCameraSpeed:Float = 2; // Temporary camera speed after rewind for faster transition
var cameraResetDelay:Float = 0.1; // Delay before resetting camera speed

// --- Trackers ---
var maxTimelineEntries:Int = 1000; // Max number of stat entries to keep in memory. Used by pruning system.
var statTimeline:Array<Dynamic> = []; // Buffer of recorded stats *DO NOT MODIFY*
var lastSectionForRewind:Int = -1; // Track last section *DO NOT MODIFY*

// ========================================
// PSYCH FUNCTIONS
// ========================================
function onUpdate(elapsed:Float) {
	// Check for rewind input
	if (checkRewindInput()) {
		var targetTime:Float = useSpecificTime ? specificTime : Math.max(0, Conductor.songPosition - relativeTime);
		goToTime(targetTime);
	}
}

function onUpdatePost(elapsed:Float) {
	// Record stats every frame for restoration
	if (restoreStatsOnRewind && Conductor.songPosition > 0) {
		recordCurrentStats();
		if (enableStatPruning) {
			pruneOldStats();
		}
	}
}

// ========================================
// CUSTOM FUNCTIONS
// ========================================
/**
 * Records current game stats to timeline buffer.
 */
function recordCurrentStats():Void {
	statTimeline.push({
		time: Conductor.songPosition,
		score: game.songScore,
		combo: game.combo,
		misses: game.songMisses,
		hits: game.songHits,
		health: game.health,
		ratingName: game.ratingName,
		ratingPercent: game.ratingPercent,
		ratingFC: game.ratingFC,
		totalPlayed: game.totalPlayed,
		totalNotesHit: game.totalNotesHit,
		// Track individual rating hits for accurate FC calculation
		sickHits: game.ratingsData[0].hits,
		goodHits: game.ratingsData[1].hits,
		badHits: game.ratingsData[2].hits,
		shitHits: game.ratingsData[3].hits
	});
}

/**
 * Removes outdated stats from timeline to prevent memory bloat.
 * Only runs if enableStatPruning is true. Keeps stats within rewind distance + buffer, or limits to maxTimelineEntries.
 */
function pruneOldStats():Void {
	var cacheWindow:Float = useSpecificTime ? pruneInterval : (relativeTime + pruneInterval);
	var cutoffTime:Float = Conductor.songPosition - cacheWindow;

	// Remove entries older than cutoff time
	while (statTimeline.length > 0 && statTimeline[0].time < cutoffTime) {
		statTimeline.shift();
	}

	// Enforce max entry limit
	while (statTimeline.length > maxTimelineEntries) {
		statTimeline.shift();
	}
}

/**
 * // Prevent stupidity MusicBeatSubstate from breaking shit, best solution I have for now at least.
 * Recalculates and updates the current section state based on the given step values.
 * Sets the current section and steps to do, and calls rollbackSection if available.
 * This lets the game properly register sections after rewinding. Fixing the camera getting stuck.
 *
 * @param curStep The current step (integer) to use for recalculation.
 * @param curDecStep The current step as a float (for more precise positioning).
 */
function recalcSectionState(curStep:Int, curDecStep:Float):Void {
	Reflect.setField(game, 'curStep', curStep);
	Reflect.setField(game, 'curDecStep', curDecStep);

	var rollbackFunc:Dynamic = Reflect.field(game, 'rollbackSection');
	if (rollbackFunc != null) {
		Reflect.callMethod(game, rollbackFunc, []);
		return;
	}

	if (game.SONG == null || game.SONG.notes == null) {
		return;
	}

	var notes:Array<Dynamic> = game.SONG.notes;
	var totalSections:Int = notes.length;
	var cumulativeSteps:Int = 0;
	var targetSection:Int = 0;
	var found:Bool = false;

	for (i in 0...totalSections) {
		var section:Dynamic = notes[i];
		if (section == null) continue;

		var sectionBeats:Float = section.sectionBeats;
		if (sectionBeats == null || sectionBeats <= 0) sectionBeats = 4;

		cumulativeSteps += Math.round(sectionBeats * 4);

		if (curStep < cumulativeSteps) {
			targetSection = i;
			found = true;
			break;
		}
	}

	if (!found) {
		targetSection = Math.max(0, totalSections - 1);
	}

	Reflect.setField(game, 'curSection', targetSection);

	if (cumulativeSteps <= curStep) {
		var beatsAhead:Float = 4;
		var sectionData:Dynamic = notes[targetSection];
		if (sectionData != null) {
			beatsAhead = sectionData.sectionBeats;
			if (beatsAhead == null || beatsAhead <= 0) beatsAhead = 4;
		}
		cumulativeSteps = curStep + Math.round(beatsAhead * 4);
	}

	Reflect.setField(game, 'stepsToDo', cumulativeSteps);
}

/**
 * Finds cached stats closest to target time.
 * @param targetTime Time in milliseconds to find stats for
 * @return Stats object or null if not found within tolerance
 */
function findClosestStats(targetTime:Float):Dynamic {
	if (statTimeline.length == 0) return null;

	var closestEntry:Dynamic = null;
	var closestDiff:Float = Math.POSITIVE_INFINITY;

	for (entry in statTimeline) {
		var diff:Float = Math.abs(entry.time - targetTime);
		if (diff < closestDiff) {
			closestDiff = diff;
			closestEntry = entry;
		}
	}

	// Return entry only if within statsRestoreTolerance
	return (closestDiff < statsRestoreTolerance) ? closestEntry : null;
}

/**
 * Applies stats to game state.
 * @param stats Stats object to apply
 */
function applyStats(stats:Dynamic):Void {
	game.songScore = stats.score;
	game.songMisses = stats.misses;
	game.songHits = stats.hits;
	game.health = stats.health;
	game.ratingName = stats.ratingName;
	game.ratingPercent = stats.ratingPercent;
	game.totalPlayed = Std.int(stats.totalPlayed);
	game.totalNotesHit = stats.totalNotesHit;
	game.combo = stats.combo;
	game.ratingFC = stats.ratingFC;
	game.ratingsData[0].hits = stats.sickHits;
	game.ratingsData[1].hits = stats.goodHits;
	game.ratingsData[2].hits = stats.badHits;
	game.ratingsData[3].hits = stats.shitHits;

	game.updateScoreText();
}

/**
 * Checks if rewind input was triggered this frame.
 * @return True if rewind button was just pressed
 */
function checkRewindInput():Bool {
	return useGamepad ? gamepadJustPressed(gamepadID, rewindButton) : keyboardJustPressed(rewindButton);
}

/**
 * Rewinds the song and game state to the specified time.
 * @param time Target time in milliseconds to rewind to
 */
function goToTime(time:Float) {
	var currentTime = Conductor.songPosition;

	// Respawn notes if we're going backwards
	if (time < currentTime) {
		// Call the HScript functions directly from the Note Cache System script
		for (script in game.hscriptArray) {
			if (script != null && script.origin != null && script.origin.indexOf('Note Cache System') != -1) {
				script.call('clearNotesInRange', [time, currentTime]);
				script.call('respawnNotesInRange', [time, currentTime]);
				break;
			} else {
				debugPrint('Note Cache System script is required for this rewind script to function.');
			}
		}
	}

	// Set audio time positions
	if (FlxG.sound.music != null) {
		FlxG.sound.music.time = time;
	}
	if (game.vocals != null) {
		game.vocals.time = time;
	}
	if (game.opponentVocals != null) {
		game.opponentVocals.time = time;
	}

	// Calculate current step/beat/section
	Conductor.songPosition = time;
	var curStep:Int = Math.floor(time / Conductor.stepCrochet);
	var curBeat:Int = Math.floor(curStep / 4);
	var curDecStep:Float = time / Conductor.stepCrochet;
	var curDecBeat:Float = curDecStep / 4;

	// Update game state with the calculated values
	Reflect.setField(game, 'curStep', curStep);
	Reflect.setField(game, 'curBeat', curBeat);
	Reflect.setField(game, 'curDecStep', curDecStep);
	Reflect.setField(game, 'curDecBeat', curDecBeat);

	// Recalculate again and re-register section hit. This fixes camera issues after rewinding.
	// Prevent stupidity MusicBeatSubstate from breaking shit, best solution I have for now at least
	recalcSectionState(curStep, curDecStep);
	var recalculatedSectionDynamic:Dynamic = Reflect.field(game, 'curSection');
	var curSectionIndex:Int = (recalculatedSectionDynamic == null) ? 0 : Std.int(recalculatedSectionDynamic);

	// Restore stats when rewinding backwards (if enabled)
	if (time < currentTime && restoreStatsOnRewind) {
		var statsToRestore:Dynamic = findClosestStats(time);
		trace("Stats restoration: " + (statsToRestore != null ? "Found stats at time " + statsToRestore.time + " (diff: " + Math.abs(statsToRestore.time - time) + "ms)" : "No stats found within tolerance"));
		
		if (statsToRestore != null) {
			applyStats(statsToRestore);
		} else {
			// Reset to zero if no cached stats available
			game.combo = 0;
			game.ratingName = '?';
			game.ratingPercent = 0;
			game.ratingFC = '';
			game.updateScoreText();
		}
	}

	// Clear note splashes when rewinding
	if (time < currentTime && game.grpNoteSplashes != null) {
		game.grpNoteSplashes.forEachAlive(function(splash:Dynamic) {
			splash.kill();
		});
	}

	var preSectionHitFollowX:Float = game.camFollow.x;
	var preSectionHitFollowY:Float = game.camFollow.y;

	game.sectionHit();

	var sectionHitMoved:Bool = (game.camFollow.x != preSectionHitFollowX || game.camFollow.y != preSectionHitFollowY);

	if (!sectionHitMoved) {
		game.moveCameraSection();
	}

	var originalCameraSpeed:Float = game.cameraSpeed;
	game.cameraSpeed = tempCameraSpeed;

	new FlxTimer().start(cameraResetDelay, function(tmr:FlxTimer) {
		game.cameraSpeed = originalCameraSpeed;
	});

	// Reset step/beat trackers so animations can play after rewind
	// These variables prevent duplicate curStep/curBeat hits and blocks certain updates from happening.
	Reflect.setField(game, 'lastStepHit', curStep - 1);
	Reflect.setField(game, 'lastBeatHit', curBeat - 1);
	
	// IMPORTANT: Reset our section tracker so we can detect section changes after rewind
	// This enables automatic camera switching as the song progresses
	lastSectionForRewind = curSectionIndex - 1;
}
