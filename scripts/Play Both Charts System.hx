// THIS IS AN EARLY RELEASE OF THE SCRIPT, EXPECT BUGS AND PERFORMANCE ISSUES.
/*
	>>> Play Both Charts System for Psych Engine
		"Note Cache System" script is currently required for this script to function.
		
		This script implements double chart functionality where both BF and Dad notes can be played on the same side.
		Based on Rhythm Engine's double chart system, ported to HScript to work with Psych Engine 1.0.4.

		Features:
		- Supports four double chart modes:
			- Player: Prioritize BF's notes when both sides has notes.
			- Opponent: Prioritize Dad's notes when both sides has notes.
			- Density: Play the side with more notes in the section.
			- Unmodified: No filtering, both sides notes are played as is, this is not recommended and just for fun.
		

		To do:
		- A LOT of Optimizations, don't kill me, I know how inefficient this is right now.
		- Fix animations being wonky during certain situations
		- Fix short sustains being cut off earlier than they should.
		- Make a version without relying on Note Cache System (as it's technically not required)
		- More testing
 
	Script by AutisticLulu.
*/

// ========================================
// CONFIGURATION & VARIABLES
// ========================================

var doubleChart:Bool = false;
var doubleChartType:String = 'Player'; // Options: 'Player', 'Opponent', 'Density', 'Unmodified'
var opponentIsPlaying:Bool = false;

// Debug settings
var debug_enabled:Bool = false;
var debug_showNoteAssignment:Bool = false; // Temporary: enable detailed logging for troubleshooting
// Cache system integration
var noteCacheEnabled:Bool = true;
var cachedNoteData:Array<Dynamic> = [];

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Logs debug messages to the console when debug mode is enabled.
 * @param message The debug message to log
 */
function debug(message:String) {
	if (!debug_enabled)
		return;
	trace('[Play Both Chart] ' + message);
}

/**
 * Adds an index to an array only if it doesn't already exist and is valid (>= 0).
 * @param list The array to add the index to
 * @param index The index to add
 */
function addIndexUnique(list:Array<Int>, index:Int) {
	if (index < 0)
		return;
	if (list.indexOf(index) == -1) {
		list.push(index);
	}
}

/**
 * Adds all sustain note indices associated with a head note to the provided list.
 * @param headIndex The index of the head note in the cache
 * @param list The list to add sustain indices to
 * @param sustainLookup The lookup table mapping head notes to their sustain chains
 */
function includeSustainChainIndices(headIndex:Int, list:Array<Int>, sustainLookup:Array<Array<Int>>) {
	if (sustainLookup == null || headIndex < 0 || headIndex >= sustainLookup.length)
		return;
	var entries:Array<Int> = sustainLookup[headIndex];
	if (entries == null)
		return;
	for (entry in entries) {
		addIndexUnique(list, entry);
	}
}

/**
 * Builds a lookup table that maps each head note to its sustain note chain.
 * @param noteDataList Array of cached note data
 * @param noteObjects Array of actual note objects
 * @return Array where each index corresponds to a head note, containing indices of its sustain notes
 */
function buildSustainIndexLookup(noteDataList:Array<Dynamic>, noteObjects:Array<Dynamic>):Array<Array<Int>> {
	var lookup:Array<Array<Int>> = [];
	if (noteDataList == null)
		return lookup;

	var total:Int = noteDataList.length;
	for (i in 0...total) {
		lookup.push(null);
	}

	if (noteObjects != null) {
		for (i in 0...noteObjects.length) {
			var noteObj = noteObjects[i];
			if (noteObj != null && noteObj.extraData != null) {
				noteObj.extraData.set('doubleChartCacheIndex', i);
			}
		}
	}

	for (i in 0...total) {
		var data = noteDataList[i];
		if (data == null || !data.isSustainNote)
			continue;

		var parentNote = data.parent;
		if (parentNote == null)
			continue;

		var parentIndex:Int = -1;
		if (parentNote.extraData != null) {
			var storedIndex = parentNote.extraData.get('doubleChartCacheIndex');
			if (storedIndex != null)
				parentIndex = storedIndex;
		}

		if (parentIndex < 0 && noteObjects != null) {
			for (j in 0...noteObjects.length) {
				if (noteObjects[j] == parentNote) {
					parentIndex = j;
					break;
				}
			}
		}

		if (parentIndex >= 0) {
			if (lookup[parentIndex] == null)
				lookup[parentIndex] = [];
			lookup[parentIndex].push(i);
		}
	}

	return lookup;
}

/**
 * Checks if a note originally belonged to the Dad/Opponent character.
 * @param note The note object to check
 * @return True if the note originated from Dad's chart
 */
function noteCameFromDad(note:Dynamic):Bool {
	if (note == null || note.extraData == null)
		return false;
	var originFlag = note.extraData.get('noteOriginDad');
	return originFlag != null && originFlag == true;
}

/**
 * Gets the base sing animation name for a note based on its lane.
 * @param noteData The note's data value (0-7 range)
 * @return The base animation name ('singLEFT', 'singDOWN', 'singUP', or 'singRIGHT')
 */
function getSingAnimBase(noteData:Int):String {
	var lane:Int = noteData % 4;
	if (lane < 0)
		lane += 4;
	switch (lane) {
		case 0:
			return 'singLEFT';
		case 1:
			return 'singDOWN';
		case 2:
			return 'singUP';
		case 3:
			return 'singRIGHT';
	}
}

/**
 * Plays the appropriate sing animation for a character based on the note hit.
 * Handles sustain notes, note suffixes, and special animations like 'Hey!'.
 * @param char The character object to animate
 * @param note The note that was hit
 */
function playCharacterSingAnimation(char:Dynamic, note:Dynamic) {
	if (char == null || note == null)
		return;
	var baseName:String = getSingAnimBase(note.noteData);
	var suffix:String = note.animSuffix;
	if (suffix == null)
		suffix = '';
	var animToPlay:String = baseName + suffix;
	var canPlay:Bool = true;

	if (note.isSustainNote) {
		var holdAnim:String = animToPlay + '-hold';
		if (char.animation != null && char.animation.exists(holdAnim)) {
			animToPlay = holdAnim;
		}
		var currentName:String = char.getAnimationName();
		if (currentName == animToPlay || currentName == animToPlay + '-loop' || currentName == holdAnim || currentName == holdAnim + '-loop') {
			canPlay = false;
		}
	}

	if (canPlay) {
		char.playAnim(animToPlay, true);
		char.holdTimer = 0;

		if (note.noteType == 'Hey!' && char.hasAnimation('hey')) {
			char.playAnim('hey', true);
			char.specialAnim = true;
			char.heyTimer = 0.6;
		}
	}
}

/**
 * Plays the appropriate miss animation for a character when they miss a note.
 * @param char The character object to animate
 * @param note The note that was missed
 */
function playCharacterMissAnimation(char:Dynamic, note:Dynamic) {
	if (char == null || note == null)
		return;
	if (!char.hasMissAnimations)
		return;
	var baseName:String = getSingAnimBase(note.noteData);
	var suffix:String = note.animSuffix;
	if (suffix == null)
		suffix = '';
	var missAnim:String = baseName + 'miss' + suffix;
	if (char.hasAnimation(missAnim)) {
		char.playAnim(missAnim, true);
	}
}

/**
 * Builds an array of section boundaries with timing information.
 * Each boundary contains start/end times and whether it's a mustHitSection.
 * @return Array of section boundary objects with start, end, and mustHitSection properties
 */
function buildSectionBoundaries():Array<Dynamic> {
	var boundaries:Array<Dynamic> = [];
	var songData = PlayState.SONG;
	if (songData == null || songData.notes == null)
		return boundaries;

	var currentTime:Float = 0;
	var currentBpm:Float = songData.bpm;
	if (Math.isNaN(currentBpm) || currentBpm <= 0)
		currentBpm = Conductor.bpm;
	if (Math.isNaN(currentBpm) || currentBpm <= 0)
		currentBpm = 120;

	var crochet:Float = 60000 / currentBpm;
	var stepCrochet:Float = crochet / 4;

	for (section in songData.notes) {
		if (section == null)
			continue;
		var beats:Float = section.sectionBeats;
		if (Math.isNaN(beats) || beats <= 0)
			beats = 4;

		var sectionLength:Float = stepCrochet * beats * 4;
		var endTime:Float = currentTime + sectionLength;

		boundaries.push({
			start: currentTime,
			end: endTime,
			mustHitSection: section.mustHitSection
		});

		currentTime = endTime;

		if (section.changeBPM != null && section.changeBPM) {
			var newBpm:Float = section.bpm;
			if (!Math.isNaN(newBpm) && newBpm > 0) {
				currentBpm = newBpm;
				crochet = 60000 / currentBpm;
				stepCrochet = crochet / 4;
			}
		}
	}

	return boundaries;
}

/**
 * Finds which section index a note belongs to based on its strum time.
 * @param strumTime The time of the note in milliseconds
 * @param boundaries Array of section boundaries from buildSectionBoundaries()
 * @param fallbackLength Fallback section length if boundaries are unavailable
 * @return The section index the note belongs to
 */
function findSectionForTime(strumTime:Float, boundaries:Array<Dynamic>, fallbackLength:Float):Int {
	if (boundaries == null || boundaries.length == 0) {
		if (fallbackLength <= 0)
			return 0;
		var idx:Int = Math.floor(strumTime / fallbackLength);
		if (idx < 0)
			idx = 0;
		return idx;
	}

	var epsilon:Float = 0.1;
	for (i in 0...boundaries.length) {
		var bound = boundaries[i];
		if (strumTime <= bound.end - epsilon) {
			return i;
		}
	}

	return boundaries.length - 1;
}

/**
 * Maps each base (non-sustain) note to its section index based on chart data.
 * @param noteDataList Array of cached note data
 * @return Array mapping each note index to its section index
 */
function mapBaseNotesToSections(noteDataList:Array<Dynamic>):Array<Int> {
	var mapping:Array<Int> = [];
	if (noteDataList == null)
		return mapping;
	for (i in 0...noteDataList.length) {
		mapping.push(-1);
	}

	var songData = PlayState.SONG;
	if (songData == null || songData.notes == null || songData.notes.length == 0) {
		return mapping;
	}

	var sections = songData.notes;
	var cacheIndex:Int = 0;

	for (secIdx in 0...sections.length) {
		var section = sections[secIdx];
		if (section == null || section.sectionNotes == null)
			continue;

		for (noteEntry in section.sectionNotes) {
			while (cacheIndex < noteDataList.length && noteDataList[cacheIndex].isSustainNote) {
				cacheIndex++;
			}
			if (cacheIndex >= noteDataList.length) {
				break;
			}
			mapping[cacheIndex] = secIdx;
			cacheIndex++;
		}
	}

	return mapping;
}

/**
 * Gets the original mustPress value for a note before double chart modifications.
 * Stores the value if it hasn't been cached yet.
 * @param noteData The note data object
 * @return The original mustPress value
 */
function getOriginalMustPress(noteData:Dynamic):Bool {
	if (noteData == null)
		return false;
	if (noteData.doubleChartOriginalMustPress == null) {
		noteData.doubleChartOriginalMustPress = noteData.mustPress;
	}
	return noteData.doubleChartOriginalMustPress;
}

/**
 * Prepares a note for use in the double chart system by setting proper flags and properties.
 * @param note The note object to prepare
 * @param noteData The cached note data
 * @param originFromDad Whether this note originally came from Dad's chart
 * @param isPlayer Whether this note should be assigned to the player
 */
function prepareNoteForDoubleChart(note:Dynamic, noteData:Dynamic, originFromDad:Bool, isPlayer:Bool) {
	note.extraData.set('noteOriginDad', originFromDad);
	note.extraData.set('doubleChartOriginalMustPress', getOriginalMustPress(noteData));
	var storedNoAnim = note.extraData.get('doubleChartOriginalNoAnimation');
	if (storedNoAnim == null)
		storedNoAnim = note.noAnimation;
	note.extraData.set('doubleChartOriginalNoAnimation', storedNoAnim);
	var storedNoMiss = note.extraData.get('doubleChartOriginalNoMissAnimation');
	if (storedNoMiss == null)
		storedNoMiss = note.noMissAnimation;
	note.extraData.set('doubleChartOriginalNoMissAnimation', storedNoMiss);
	note.mustPress = isPlayer;
	note.hitByOpponent = false;

	note.wasGoodHit = false;
	note.canBeHit = false;
	note.tooLate = false;
	note.missed = false;
	note.spawned = false;
	noteData.mustPress = note.mustPress;
	noteData.hitByOpponent = false;

	var shouldSuppressAnimation:Bool = (isPlayer && originFromDad) || (!isPlayer && !originFromDad);

	if (shouldSuppressAnimation) {
		note.noAnimation = true;
		note.noMissAnimation = true;
		if (noteData != null) {
			noteData.noAnimation = true;
			noteData.noMissAnimation = true;
		}
	} else {
		note.noAnimation = storedNoAnim;
		note.noMissAnimation = storedNoMiss;
		if (noteData != null) {
			noteData.noAnimation = storedNoAnim;
			noteData.noMissAnimation = storedNoMiss;
		}
	}

	repositionNoteForDoubleChart(note, isPlayer);
}

function attachSustainToParent(sustainNote:Dynamic, parentNote:Dynamic) {
	sustainNote.parent = parentNote;
	if (parentNote == null)
		return;
	if (parentNote.tail == null)
		parentNote.tail = [];
	var existingIndex:Int = parentNote.tail.indexOf(sustainNote);
	if (existingIndex != -1) {
		parentNote.tail.splice(existingIndex, 1);
	}
	parentNote.tail.push(sustainNote);
}

/**
 * Links notes together in a chain using prevNote and nextNote references.
 * @param previousNote The note that comes before
 * @param currentNote The note to link
 */
function linkPrevNext(previousNote:Dynamic, currentNote:Dynamic) {
	currentNote.nextNote = null;
	if (previousNote != null) {
		previousNote.nextNote = currentNote;
		currentNote.prevNote = previousNote;
	} else {
		currentNote.prevNote = currentNote;
	}
}

/**
 * Clears all elements from an array efficiently.
 * @param array The array to clear
 */
function clearArray(array:Array<Dynamic>) {
	if (array == null)
		return;
	while (array.length > 0) {
		array.pop();
	}
}

/**
 * Updates the Note Cache System's player and opponent note buckets with the new double chart assignments.
 * @param playerIndices Array of note indices assigned to the player
 * @param opponentIndices Array of note indices assigned to the opponent
 * @param cachedNoteObjects Array of cached note objects
 */
function updateCacheBuckets(playerIndices:Array<Int>, opponentIndices:Array<Int>, cachedNoteObjects:Array<Dynamic>) {
	var playerCache:Array<Dynamic> = getVar('noteCacher_totalPlayerNotes');
	if (playerCache != null) {
		clearArray(playerCache);
		for (idx in playerIndices) {
			var noteObj = cachedNoteObjects[idx];
			if (noteObj != null)
				playerCache.push(noteObj);
		}
	}

	var opponentCache:Array<Dynamic> = getVar('noteCacher_totalOpponentNotes');
	if (opponentCache != null) {
		clearArray(opponentCache);
		for (idx in opponentIndices) {
			var oppNote = cachedNoteObjects[idx];
			if (oppNote != null)
				opponentCache.push(oppNote);
		}
	}

	var replacementLookup:Array<Dynamic> = getVar('noteCacher_replacementLookup');
	clearArray(replacementLookup);
}

/**
 * Rebuilds the chart from the Note Cache System based on the current double chart mode and type.
 * This is the main function that implements the double chart logic.
 */
function rebuildChartFromCache() {
	// Get the cached note data from Note Cache System
	cachedNoteData = getVar('noteCacher_noteDataCache');
	var cachedNoteObjects:Array<Dynamic> = getVar('noteCacher_totalCachedNotes');

	if (cachedNoteData == null || cachedNoteData.length == 0) {
		debug('ERROR: Note Cache System data not available!');
		return;
	}

	if (cachedNoteObjects == null || cachedNoteObjects.length == 0) {
		debug('ERROR: Note Cache System object cache not available!');
		return;
	}

	debug('Retrieved ' + cachedNoteData.length + ' cached notes');

	var sustainLookup:Array<Array<Int>> = buildSustainIndexLookup(cachedNoteData, cachedNoteObjects);

	// Group cached notes by sections
	var sectionBoundaries:Array<Dynamic> = buildSectionBoundaries();
	var fallbackSectionLength:Float = Conductor.stepCrochet * 16;
	var baseNoteSectionMap:Array<Int> = mapBaseNotesToSections(cachedNoteData);
	var songSections:Int = PlayState.SONG != null && PlayState.SONG.notes != null ? PlayState.SONG.notes.length : 0;
	var notesBySection:Array<Array<Dynamic>> = [];
	if (songSections > 0) {
		for (i in 0...songSections) {
			notesBySection.push([]);
		}
	} else if (sectionBoundaries != null && sectionBoundaries.length > 0) {
		for (i in 0...sectionBoundaries.length) {
			notesBySection.push([]);
		}
	}

	// Build section groupings
	for (i in 0...cachedNoteData.length) {
		var noteData = cachedNoteData[i];
		// Skip sustain notes in grouping
		if (noteData.isSustainNote)
			continue;

		var sectionIndex:Int = -1;
		if (baseNoteSectionMap != null && baseNoteSectionMap.length > i) {
			sectionIndex = baseNoteSectionMap[i];
		}
		if (sectionIndex < 0) {
			sectionIndex = findSectionForTime(noteData.strumTime, sectionBoundaries, fallbackSectionLength);
		}

		// Ensure array has enough elements
		while (notesBySection.length <= sectionIndex) {
			notesBySection.push([]);
		}

		notesBySection[sectionIndex].push({index: i, data: noteData});
	}

	debug('Grouped notes into ' + notesBySection.length + ' sections');

	// Determine which notes should be playable per section
	var playerNoteIndices:Array<Int> = [];
	var opponentNoteIndices:Array<Int> = [];

	for (secIdx in 0...notesBySection.length) {
		if (notesBySection[secIdx] == null || notesBySection[secIdx].length == 0)
			continue;

		var notesInSection:Array<Dynamic> = notesBySection[secIdx];
		var mustHitBfSide:Bool = determineMustHitBfSideFromCache(notesInSection);

		// Mark notes that should be respawned
		for (noteInfo in notesInSection) {
			var noteData = noteInfo.data;
			var shouldBePlayer:Bool = shouldNoteBePlayable(noteData, mustHitBfSide);

			if (shouldBePlayer) {
				addIndexUnique(playerNoteIndices, noteInfo.index);
				includeSustainChainIndices(noteInfo.index, playerNoteIndices, sustainLookup);
			} else {
				addIndexUnique(opponentNoteIndices, noteInfo.index);
				includeSustainChainIndices(noteInfo.index, opponentNoteIndices, sustainLookup);
			}
		}
	}

	var sortFunc = function(a, b) {
		var dataA = cachedNoteData[a];
		var dataB = cachedNoteData[b];
		if (dataA != null && dataB != null) {
			if (dataA.strumTime < dataB.strumTime)
				return -1;
			if (dataA.strumTime > dataB.strumTime)
				return 1;
		}
		if (a < b)
			return -1;
		if (a > b)
			return 1;
		return 0;
	};

	playerNoteIndices.sort(sortFunc);
	opponentNoteIndices.sort(sortFunc);

	var totalSelected:Int = playerNoteIndices.length + opponentNoteIndices.length;
	debug('Selected '
		+ playerNoteIndices.length
		+ ' player notes and '
		+ opponentNoteIndices.length
		+ ' opponent notes for rebuild');

	if (totalSelected == 0) {
		debug('ERROR: No notes selected for rebuild!');
		return;
	}

	game.notes.clear();

	debug('Starting rebuild pass for ' + totalSelected + ' notes...');

	var processList:Array<Dynamic> = [];
	for (idx in playerNoteIndices) {
		processList.push({index: idx, toPlayer: true});
	}
	for (idx in opponentNoteIndices) {
		processList.push({index: idx, toPlayer: false});
	}
	processList.sort(function(a, b) {
		var dataA = cachedNoteData[a.index];
		var dataB = cachedNoteData[b.index];
		if (dataA != null && dataB != null) {
			if (dataA.strumTime < dataB.strumTime)
				return -1;
			if (dataA.strumTime > dataB.strumTime)
				return 1;
		}
		if (a.index < b.index)
			return -1;
		if (a.index > b.index)
			return 1;
		return 0;
	});

	var rebuiltNotes:Array<Dynamic> = [];
	var sustainHeadPerLane:Array<Dynamic> = [null, null, null, null, null, null, null, null];
	var lastNoteOverall:Dynamic = null;
	var processedCount:Int = 0;

	for (entry in processList) {
		var noteIndex:Int = entry.index;
		try {
			debug('Processing note index: ' + noteIndex);
			var noteData = cachedNoteData[noteIndex];
			var noteObj = cachedNoteObjects[noteIndex];

			if (noteData == null || noteObj == null) {
				debug('WARNING: Missing cached entry for index ' + noteIndex);
				continue;
			}

			var toPlayer:Bool = entry.toPlayer;
			var originFromDad:Bool = !getOriginalMustPress(noteData);
			prepareNoteForDoubleChart(noteObj, noteData, originFromDad, toPlayer);

			var lane:Int = noteData.noteData % 4;
			if (lane < 0)
				lane += 4;
			if (!toPlayer)
				lane = lane + 4;

			var previousNote:Dynamic = lastNoteOverall;

			if (noteObj.isSustainNote) {
				var headNote:Dynamic = sustainHeadPerLane[lane];
				if (headNote == null && previousNote != null && !previousNote.isSustainNote) {
					headNote = previousNote;
				}
				attachSustainToParent(noteObj, headNote);
				if (previousNote == null && headNote != null) {
					previousNote = headNote;
				}
				linkPrevNext(previousNote, noteObj);
				noteObj.tail = [];
			} else {
				noteObj.parent = null;
				noteObj.tail = [];
				linkPrevNext(previousNote, noteObj);
				sustainHeadPerLane[lane] = noteObj;
			}

			lastNoteOverall = noteObj;

			noteData.prevNote = noteObj.prevNote;
			noteData.parent = noteObj.parent;

			rebuiltNotes.push(noteObj);

			processedCount = processedCount + 1;
			debug('Successfully processed note ' + processedCount + '/' + totalSelected);
		} catch (e:Dynamic) {
			debug('ERROR processing note index ' + noteIndex + ': ' + e);
		}
	}

	rebuiltNotes.sort(function(a, b) {
		if (a == null || b == null)
			return 0;
		if (a.strumTime < b.strumTime)
			return -1;
		if (a.strumTime > b.strumTime)
			return 1;
		if (a.noteData < b.noteData)
			return -1;
		if (a.noteData > b.noteData)
			return 1;
		return 0;
	});

	game.unspawnNotes = rebuiltNotes.copy();

	updateCacheBuckets(playerNoteIndices, opponentNoteIndices, cachedNoteObjects);

	debug('Finished rebuilding chart - prepared ' + rebuiltNotes.length + ' notes');
	debug('unspawnNotes currently holds ' + game.unspawnNotes.length + ' notes');
}

/**
 * Determines which side (BF or Dad) should be the "must hit" side for a section based on the double chart type.
 * @param notesInSection Array of note info objects in the section
 * @return True if BF side should be must hit, false if Dad side should be
 */
function determineMustHitBfSideFromCache(notesInSection:Array<Dynamic>):Bool {
	if (doubleChartType == 'Unmodified') {
		return true;
	}

	var bfNoteAmount:Int = 0;
	var dadNoteAmount:Int = 0;

	for (noteInfo in notesInSection) {
		var noteData = noteInfo.data;
		// Skip sustain notes in counting
		if (noteData.isSustainNote)
			continue;
		var originalMustPress:Bool = getOriginalMustPress(noteData);

		if (originalMustPress) {
			bfNoteAmount = bfNoteAmount + 1;
		} else {
			dadNoteAmount = dadNoteAmount + 1;
		}
	}

	if (debug_showNoteAssignment) {
		debug('Section analysis -> Player notes: ' + bfNoteAmount + ', Opponent notes: ' + dadNoteAmount);
	}

	switch (doubleChartType) {
		case 'Player':
			// Force BF side whenever he has notes; only borrow opponent when BF is empty
			var result:Bool = bfNoteAmount > 0;
			if (debug_showNoteAssignment) {
				debug('Player mode decision: mustHitBfSide = ' + result);
			}
			return result;
		case 'Opponent':
			// Use Dad side if Dad has notes, otherwise use BF side
			var oppResult:Bool = dadNoteAmount == 0;
			if (debug_showNoteAssignment) {
				debug('Opponent mode decision: mustHitBfSide = ' + oppResult);
			}
			return oppResult;
		case 'Density':
			// Use whichever side has more notes; tie defaults to player side
			var densityResult:Bool = true;
			if (bfNoteAmount > dadNoteAmount) {
				densityResult = true;
			} else if (dadNoteAmount > bfNoteAmount) {
				densityResult = false;
			}
			if (debug_showNoteAssignment) {
				debug('Density mode decision: mustHitBfSide = ' + densityResult);
			}
			return densityResult;
		default:
			return true;
	}
}

/**
 * Determines if a specific note should be assigned to the player based on the double chart type.
 * @param noteData The note's cached data
 * @param mustHitBfSide Whether BF side is the must hit side for this section
 * @return True if the note should be playable by the player
 */
function shouldNoteBePlayable(noteData:Dynamic, mustHitBfSide:Bool):Bool {
	if (doubleChartType == 'Unmodified') {
		return noteData.mustPress;
	}

	var originalMustPress:Bool = getOriginalMustPress(noteData);

	switch (doubleChartType) {
		case 'Player':
			// Always include BF notes, plus Dad notes if BF side is empty for this section
			if (originalMustPress)
				return true;
			return !mustHitBfSide;
		case 'Opponent':
			// Always include Dad notes, plus BF notes if Dad side is empty for this section
			if (!originalMustPress)
				return true;
			return mustHitBfSide;
		case 'Density':
			// Include whichever side the density check selected
			return (mustHitBfSide && originalMustPress) || (!mustHitBfSide && !originalMustPress);
		default:
			return originalMustPress;
	}
}

/**
 * Repositions a note's X coordinate based on whether it's for player or opponent.
 * Accounts for middle scroll and double chart settings.
 * @param note The note object to reposition
 * @param isPlayer Whether this note is assigned to the player
 */
function repositionNoteForDoubleChart(note:Dynamic, isPlayer:Bool) {
	var middleScroll:Bool = ClientPrefs.data.middleScroll;
	var daNoteData:Int = note.noteData % 4;

	var baseX:Float = (middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
	baseX += Note.swagWidth * daNoteData;

	if (isPlayer) {
		note.x = baseX + FlxG.width / 2;
	} else if (middleScroll || doubleChart) {
		note.x = baseX + 310;
		if (daNoteData > 1) {
			note.x += FlxG.width / 2 + 25;
		}
	} else {
		note.x = baseX;
	}
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	debug('Double Chart System initialized');
	debug('Mode: ' + doubleChartType);

	// Check if Note Cache System is available by searching hscript array
	if (game.hscriptArray != null) {
		for (script in game.hscriptArray) {
			if (script != null && script.origin != null && script.origin.indexOf('Note Cache System') != -1) {
				noteCacheEnabled = true;
				debug('Note Cache System detected - using cache-based approach');
				break;
			} else {
				debug('Note Cache System script is required for "Play Both Chart" script to function.');
			}
		}
	}
}

function onCreatePost() {
	if (!doubleChart)
		return;

	if (noteCacheEnabled) {
		// Use cache system to rebuild chart
		debug('Building double chart from Note Cache System...');
		rebuildChartFromCache();
	} else {
		debug('ERROR: Note Cache System is required! Please enable Note Cache System.hx');
	}
}

function onUpdatePost(elapsed:Float) {
	if (!doubleChart)
		return;

	var songData = PlayState.SONG;
	if (songData != null && songData.notes != null && game.curSection >= 0 && game.curSection < songData.notes.length) {
		var section = songData.notes[game.curSection];
		opponentIsPlaying = !section.mustHitSection;
	}
}

function goodNoteHit(note:Dynamic) {
	if (!doubleChart)
		return;
	if (note == null)
		return;

	var char:Dynamic = game.boyfriend;
	if (note.gfNote && game.gf != null) {
		char = game.gf;
	}

	if (noteCameFromDad(note)) {
		char = game.dad;
	}

	if (char == game.dad) {
		playCharacterSingAnimation(game.dad, note);
	}
}

function opponentNoteHit(note:Dynamic) {
	if (!doubleChart)
		return;
	if (note == null)
		return;

	var opponentChar:Dynamic = game.dad;
	if (noteCameFromDad(note)) {
		opponentChar = game.boyfriend;
	}

	playCharacterSingAnimation(opponentChar, note);
}

function noteMiss(note:Dynamic) {
	if (!doubleChart)
		return;
	if (note == null)
		return;

	var char:Dynamic = game.boyfriend;
	if (note.gfNote && game.gf != null) {
		char = game.gf;
	}

	if (noteCameFromDad(note)) {
		char = game.dad;
	}

	if (char == game.dad) {
		playCharacterMissAnimation(game.dad, note);
	}
}