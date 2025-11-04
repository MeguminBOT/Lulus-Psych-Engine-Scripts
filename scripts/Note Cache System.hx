/*
	>>> Note Cache System for Psych Engine
		This script does nothing on it's own but provides a set of functions.
		These functions can be used to cache, clear, respawn notes or just to get all data at once.
		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */

// ========================================
// CONFIGURATION & VARIABLES
// ========================================

// --- General Settings ---
var noteCache_enabled:Bool = true;

// --- Debug Settings ---
var noteCache_debug:Bool = true;
var noteCache_useTrace:Bool = true;
var noteCache_useDebugPrint:Bool = false;

// --- Internal Variables (DO NOT MODIFY) ---
var cachedNotes:Array<Dynamic> = [];
var cachedPlayerNotes:Array<Dynamic> = [];
var cachedOpponentNotes:Array<Dynamic> = [];
var noteDataCache:Array<Dynamic> = [];
var replacementLookup:Array<Dynamic> = [];

// ========================================
// DEBUG HELPERS
// ========================================

/**
 * Helper function to print debug messages or traces only if noteCache_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!noteCache_debug)
		return;

	if (color == null)
		color = FlxColor.WHITE;

	if (noteCache_useDebugPrint) {
		debugPrint('[Note Cacher] ' + message, color);
	}

	if (noteCache_useTrace) {
		trace('[Note Cacher] ' + message);
	}
}

/**
 * Debug helper that logs core information about a note.
 * @param note The note to inspect.
 */
function printNoteInfo(note:Dynamic) {
	if (note == null) {
		debug('Note is null!');
		return;
	}

	debug('Note Info:');
	debug('  Time: ' + note.strumTime + 'ms');
	debug('  Column: ' + note.noteData);
	debug('  Must Press: ' + note.mustPress);
	debug('  Type: ' + note.noteType);
	debug('  Is Sustain: ' + note.isSustainNote);
	debug('  Sustain Length: ' + note.sustainLength);
}

// ========================================
// CACHE INFO GETTERS
// ========================================

/**
 * Returns how many notes were cached when the song was generated.
 * @return Total note count.
 */
function getCachedNoteCount():Int {
	return cachedNotes.length;
}

/**
 * Returns the array of all cached notes.
 * @return Array of all cached notes
 */
function getAllCachedNotes():Array<Dynamic> {
	return cachedNotes;
}

/**
 * Returns the array of cached player notes.
 * @return Array of player notes
 */
function getAllPlayerNotes():Array<Dynamic> {
	return cachedPlayerNotes;
}

/**
 * Returns the array of cached opponent notes.
 * @return Array of opponent notes
 */
function getAllOpponentNotes():Array<Dynamic> {
	return cachedOpponentNotes;
}

/**
 * Returns the array of cached note data.
 * @return Array of note data objects
 */
function getNoteDataCache():Array<Dynamic> {
	return noteDataCache;
}

/**
 * Returns the replacement lookup array.
 * @return Array of replacement entries
 */
function getReplacementLookup():Array<Dynamic> {
	return replacementLookup;
}

// ========================================
// NOTE QUERY FUNCTIONS
// ========================================

/**
 * Returns the cached note at an exact strum time, optionally filtering by side.
 * @param time The strum time to match.
 * @param mustPress Optional filter: true for player notes, false for opponent, null for both.
 * @return The matching note, or null if not found.
 */
function getNoteAtTime(time:Float, ?mustPress:Bool = null):Dynamic {
	for (note in cachedNotes) {
		if (note.strumTime == time) {
			if (mustPress == null || note.mustPress == mustPress) {
				return note;
			}
		}
	}
	return null;
}

/**
 * Collects cached notes whose strum times fall within the provided window.
 * @param startTime The beginning of the time range.
 * @param endTime The end of the time range.
 * @param mustPress Optional filter: true for player notes, false for opponent, null for both.
 * @return Array of notes in the range.
 */
function getNotesInRange(startTime:Float, endTime:Float, ?mustPress:Bool = null):Array<Dynamic> {
	var notesInRange:Array<Dynamic> = [];

	for (note in cachedNotes) {
		if (note.strumTime >= startTime && note.strumTime <= endTime) {
			if (mustPress == null || note.mustPress == mustPress) {
				notesInRange.push(note);
			}
		}
	}

	return notesInRange;
}

/**
 * Retrieves cached notes for a single lane, optionally filtering by player/opponent.
 * @param column The note lane (0-3).
 * @param mustPress Optional filter: true for player notes, false for opponent, null for both.
 * @return Array of notes in that column.
 */
function getNotesByColumn(column:Int, ?mustPress:Bool = null):Array<Dynamic> {
	var columnNotes:Array<Dynamic> = [];

	for (note in cachedNotes) {
		if (note.noteData == column) {
			if (mustPress == null || note.mustPress == mustPress) {
				columnNotes.push(note);
			}
		}
	}

	return columnNotes;
}

/**
 * Returns all cached notes that were assigned the given note type.
 * @param noteType The note type string to filter by (e.g., 'Hurt Note').
 * @return Array of matching notes.
 */
function getNotesByType(noteType:String):Array<Dynamic> {
	var typedNotes:Array<Dynamic> = [];

	for (note in cachedNotes) {
		if (note.noteType == noteType) {
			typedNotes.push(note);
		}
	}

	return typedNotes;
}

/**
 * Returns the cached data blob for a note without recreating it.
 * @param index The index in noteDataCache.
 * @return The cached data, or null if out of bounds.
 */
function getCachedNoteData(index:Int):Dynamic {
	// Get cached note data without respawning
	if (index >= 0 && index < noteDataCache.length) {
		return noteDataCache[index];
	}
	return null;
}

/**
 * Finds every cached data blob that matches the provided time (and side).
 * @param time The strum time to match.
 * @param mustPress Optional filter: true for player notes, false for opponent, null for both.
 * @return Array of matching cached data blobs.
 */
function getNoteDataByTime(time:Float, ?mustPress:Bool = null):Array<Dynamic> {
	// Find cached note data at a specific time
	var foundData:Array<Dynamic> = [];

	for (data in noteDataCache) {
		if (data.strumTime == time) {
			if (mustPress == null || data.mustPress == mustPress) {
				foundData.push(data);
			}
		}
	}

	return foundData;
}

// ========================================
// NOTE MANIPULATION FUNCTIONS
// ========================================

/**
 * Removes live and queued notes in the provided window prior to respawning.
 * @param startTime The start of the time range.
 * @param endTime The end of the time range.
 */
function clearNotesInRange(startTime:Float, endTime:Float) {
	// Remove notes from game in a time range (useful before respawning)
	var notesToRemove = [];

	for (note in game.notes) {
		if (note.strumTime >= startTime && note.strumTime <= endTime) {
			notesToRemove.push(note);
		}
	}

	for (note in notesToRemove) {
		note.active = false;
		note.visible = false;
		note.ignoreNote = true;
		game.notes.remove(note, true);
	}

	// Also clear from unspawnNotes
	var unspawnToRemove = [];
	for (note in game.unspawnNotes) {
		if (note.strumTime >= startTime && note.strumTime <= endTime) {
			unspawnToRemove.push(note);
		}
	}

	for (note in unspawnToRemove) {
		game.unspawnNotes.remove(note);
	}

	if (notesToRemove.length > 0 || unspawnToRemove.length > 0) {
		debug('Cleared ' + (notesToRemove.length + unspawnToRemove.length) + ' notes in range ' + startTime + '-' + endTime + 'ms');
	}
}

// ========================================
// NOTE REBUILDER FUNCTIONS
// ========================================

/**
 * Caches all notes from the unspawn queue at song start.
 * Stores note objects and their data for later respawning.
 */
function cacheNotes() {
	if (game.unspawnNotes != null && game.unspawnNotes.length > 0) {
		for (note in game.unspawnNotes) {
			cachedNotes.push(note);

			var noteData = {
				strumTime: note.strumTime,
				noteData: note.noteData,
				mustPress: note.mustPress,
				noteType: note.noteType,
				isSustainNote: note.isSustainNote,
				sustainLength: note.sustainLength,
				prevNote: note.prevNote,
				parent: note.parent,
				hitByOpponent: note.hitByOpponent,
				ignoreNote: note.ignoreNote,
				hitHealth: note.hitHealth,
				missHealth: note.missHealth,
				rating: note.rating,
				ratingMod: note.ratingMod,
				texture: note.texture,
				noAnimation: note.noAnimation,
				noMissAnimation: note.noMissAnimation,
				hitCausesMiss: note.hitCausesMiss,
				distance: note.distance,
				hitsoundDisabled: note.hitsoundDisabled,
				gfNote: note.gfNote,
				earlyHitMult: note.earlyHitMult,
				lateHitMult: note.lateHitMult,
				lowPriority: note.lowPriority
			};

			noteDataCache.push(noteData);

			if (note.mustPress) {
				cachedPlayerNotes.push(note);
			} else {
				cachedOpponentNotes.push(note);
			}
		}
	}
}

/**
 * Retrieves the replacement entry for a cached note from a pseudo-map array.
 * @param original The original note object to look up.
 * @param source The array of replacement entries to search.
 * @return The replacement note, or null if not found.
 */
function findReplacement(original:Dynamic, source:Array<Dynamic>):Dynamic {
	if (source == null || original == null) {
		return null;
	}

	for (entry in source) {
		if (entry != null && entry.original == original) {
			return entry.replacement;
		}
	}

	return null;
}

/**
 * Updates or inserts a replacement entry inside the pseudo-map array.
 * @param source The array of replacement entries to modify.
 * @param original The original note being replaced.
 * @param replacement The new note replacing it.
 */
function setReplacement(source:Array<Dynamic>, original:Dynamic, replacement:Dynamic) {
	if (source == null || original == null || replacement == null) {
		return;
	}

	var updated:Bool = false;
	for (entry in source) {
		if (entry != null && entry.original == original) {
			entry.replacement = replacement;
			updated = true;
		}
	}

	if (!updated) {
		source.push({original: original, replacement: replacement});
	}

	// Update any entries whose replacement points to the old note
	for (entry in source) {
		if (entry != null && entry.replacement == original) {
			entry.replacement = replacement;
		}
	}
}

/**
 * Resolves a cached reference to its latest rebuilt note instance.
 * @param original The original note reference from cached data.
 * @param replacements Local pseudo-map of replaced notes for this respawn operation.
 * @return The most recent replacement, or the original if no replacement exists.
 */
function resolveNoteReference(original:Dynamic, replacements:Array<Dynamic>):Dynamic {
	if (original == null) {
		return null;
	}

	// Check local replacements first
	var localFound:Dynamic = findReplacement(original, replacements);
	if (localFound != null) {
		return localFound;
	}

	// Check global replacements second
	var globalFound:Dynamic = findReplacement(original, replacementLookup);
	if (globalFound != null) {
		return globalFound;
	}

	return original;
}

/**
 * Registers a rebuilt note so future lookups return the fresh instance.
 * @param original The original cached note.
 * @param replacement The newly created note replacing it.
 * @param replacements Local pseudo-map to update.
 */
function registerReplacement(original:Dynamic, replacement:Dynamic, replacements:Array<Dynamic>) {
	if (original == null || replacement == null) {
		return;
	}

	// Update local replacements map
	if (replacements != null) {
		setReplacement(replacements, original, replacement);
	}

	// Update global replacements map
	setReplacement(replacementLookup, original, replacement);
}

/**
 * Reattaches a sustain tail to its parent while clearing conflicting pieces.
 * @param newNote The sustain note to attach.
 * @param parentNote The parent (head) note of the sustain chain.
 * @param startTime Optional start of respawn window, used to filter stale tail entries.
 * @param endTime Optional end of respawn window, used to filter stale tail entries.
 */
function updateParentChain(newNote:Dynamic, parentNote:Dynamic, ?startTime:Float = null, ?endTime:Float = null) {
	if (newNote == null || parentNote == null) {
		return;
	}

	newNote.parent = parentNote;

	if (parentNote.tail == null) {
		parentNote.tail = [];
	}

	// Remove any stale or duplicate tail entries
	var i:Int = 0;
	while (i < parentNote.tail.length) {
		var tailNote:Dynamic = parentNote.tail[i];
		var remove:Bool = false;

		if (tailNote == null) {
			remove = true;
		} else {
			// Remove if it's in the respawn window (will be replaced)
			if (startTime != null && endTime != null && tailNote.strumTime >= startTime && tailNote.strumTime <= endTime) {
				remove = true;
			}

			// Remove if it's a duplicate timestamp
			if (!remove && tailNote.strumTime == newNote.strumTime) {
				remove = true;
			}
		}

		if (remove) {
			parentNote.tail.splice(i, 1);
		} else {
			i = i + 1;
		}
	}

	// Add the new note to the tail
	parentNote.tail.push(newNote);
}

/**
 * Rebuilds a cached note, wiring up sustain parents and updating arrays.
 * @param index The index in noteDataCache to rebuild.
 * @param startTime Start of the respawn window.
 * @param endTime End of the respawn window.
 * @param replacements Local pseudo-map of replaced notes.
 * @param lastNotePerColumn Array tracking the last note rebuilt in each column.
 * @param headPerColumn Array tracking the head note of each sustain chain.
 * @return The rebuilt note, or null if data is invalid.
 */
function rebuildNote(index:Int, startTime:Float, endTime:Float, replacements:Array<Dynamic>, ?lastNotePerColumn:Array<Dynamic> = null, ?headPerColumn:Array<Dynamic> = null):Dynamic {
	var data = noteDataCache[index];
	var originalNote = cachedNotes[index];

	if (data == null || originalNote == null) {
		return null;
	}

	// Calculate column key (0-3 for player, 4-7 for opponent)
	var columnKey:Int = data.noteData + (data.mustPress ? 0 : 4);

	// Ensure tracking arrays have enough slots
	if (lastNotePerColumn != null) {
		while (lastNotePerColumn.length <= columnKey) {
			lastNotePerColumn.push(null);
		}
	}

	if (headPerColumn != null) {
		while (headPerColumn.length <= columnKey) {
			headPerColumn.push(null);
		}
	}

	// Resolve the previous note in the chain
	var prevNote:Dynamic = resolveNoteReference(data.prevNote, replacements);
	if (prevNote == null && lastNotePerColumn != null && lastNotePerColumn[columnKey] != null) {
		prevNote = lastNotePerColumn[columnKey];
	}

	// Resolve the parent note (head of sustain chain)
	var parentNote:Dynamic = null;
	if (data.isSustainNote) {
		parentNote = resolveNoteReference(data.parent, replacements);
		if (parentNote == null && headPerColumn != null && headPerColumn[columnKey] != null) {
			parentNote = headPerColumn[columnKey];
		}
		if (parentNote == null && data.parent != null) {
			parentNote = data.parent;
		}
	}

	// Mark if this sustain needs wasGoodHit set (orphaned first piece)
	var needsGoodHitMark:Bool = false;
	if (data.isSustainNote) {
		needsGoodHitMark = (prevNote == null && parentNote == null);
	}

	// Construct a new note while preserving gameplay-critical setup done by noteType setters.
	var newNote = createNoteFromData(data, prevNote, needsGoodHitMark, parentNote);
	if (newNote == null) {
		return null;
	}

	insertNoteIntoGame(newNote);
	registerReplacement(originalNote, newNote, replacements);
	cachedNotes[index] = newNote;
	data.prevNote = newNote.prevNote;
	data.parent = newNote.parent;

	// Update tracking arrays
	if (lastNotePerColumn != null) {
		lastNotePerColumn[columnKey] = newNote;
	}

	if (headPerColumn != null) {
		if (!data.isSustainNote) {
			headPerColumn[columnKey] = newNote;
		} else if (parentNote != null && headPerColumn[columnKey] == null) {
			headPerColumn[columnKey] = parentNote;
		}
	}

	// Reattach sustain tails to parent
	if (newNote.parent != null) {
		updateParentChain(newNote, newNote.parent, startTime, endTime);
	}

	return newNote;
}

/**
 * Creates a fresh Note instance from cached data while restoring sustain flags.
 * @param data The cached note data.
 * @param prevNote The previous note in the chain (for sustains).
 * @param needsGoodHitMark If true, marks the note as already hit (for orphaned sustain pieces).
 * @param parentNote The parent (head) note for sustains.
 * @return The newly created note.
 */
function createNoteFromData(data:Dynamic, ?prevNote:Dynamic = null, ?needsGoodHitMark:Bool = false, ?parentNote:Dynamic = null):Dynamic {
	// Validate data before attempting to create note
	if (data == null) {
		debug('ERROR: Cannot create note - data is null');
		return null;
	}

	if (data.strumTime == null || data.noteData == null) {
		debug('ERROR: Cannot create note - missing required data (strumTime or noteData)');
		return null;
	}

	// Create a new note object from cached data
	// Note constructor: new(strumTime, noteData, ?prevNote, ?sustainNote, ?inEditor, ?createdFrom)
	try {
		var newNote = new Note(data.strumTime, data.noteData, prevNote, data.isSustainNote, false, null);

		if (newNote == null) {
			debug('ERROR: Note constructor returned null for time=' + data.strumTime);
			return null;
		}

		debug('Created note - isSustain: ' + data.isSustainNote + ', hitCausesMiss: ' + newNote.hitCausesMiss + ', noteType: ' + newNote.noteType
			+ ', hasPrevNote: ' + (prevNote != null) + ', needsGoodHitMark: ' + needsGoodHitMark);

		// Apply mustPress BEFORE noteType since noteType setter may depend on it
		newNote.mustPress = data.mustPress; // This is critical for player vs opponent placement!

		// Set noteType - this will trigger the setter which configures all gameplay properties
		// The setter handles hitCausesMiss, missHealth, hitHealth, ignoreNote, etc. based on noteType
		if (data.noteType != null && data.noteType != '') {
			debug('Setting noteType to: ' + data.noteType);
			newNote.noteType = data.noteType; // This triggers set_noteType() which sets up everything
			debug('After noteType set - hitCausesMiss: ' + newNote.hitCausesMiss + ', ignoreNote: ' + newNote.ignoreNote);
		}

		newNote.sustainLength = data.sustainLength;

		// Reset ONLY the state flags that track note status during gameplay
		// DO NOT reset ignoreNote - it's set by noteType (e.g., Hurt Notes use it)!
		newNote.canBeHit = false;
		newNote.tooLate = false;
		newNote.hitByOpponent = false;

		// Special handling: If this sustain piece is the first in the respawn range (no prevNote in range),
		// mark it as already hit so subsequent pieces in the chain can be hit successfully
		if (needsGoodHitMark && data.isSustainNote) {
			newNote.wasGoodHit = true;
			debug('Marked first sustain piece in range as wasGoodHit for sustain chain');
		} else {
			newNote.wasGoodHit = false;
		}

		// Debug: Check if sustain notes have incorrect properties
		if (data.isSustainNote) {
			debug('Sustain note final state - hitCausesMiss: ' + newNote.hitCausesMiss + ', hitHealth: ' + newNote.hitHealth + ', missHealth: '
				+ newNote.missHealth + ', wasGoodHit: ' + newNote.wasGoodHit);
		}

		// Only apply cosmetic/non-gameplay properties that aren't set by noteType
		// DO NOT copy: hitHealth, missHealth, hitCausesMiss, lowPriority, ignoreNote - noteType sets these!
		newNote.rating = data.rating;
		newNote.ratingMod = data.ratingMod;
		newNote.noAnimation = data.noAnimation;
		newNote.noMissAnimation = data.noMissAnimation;
		newNote.distance = data.distance;
		newNote.hitsoundDisabled = data.hitsoundDisabled;
		newNote.gfNote = data.gfNote;
		newNote.earlyHitMult = data.earlyHitMult;
		newNote.lateHitMult = data.lateHitMult;

		if (parentNote != null) {
			newNote.parent = parentNote;
		}

		// Texture should be set AFTER noteType to not override noteType colors
		if (data.texture != null && data.texture != '') {
			newNote.texture = data.texture;
		}

		return newNote;
	} catch (e:Dynamic) {
		debug('ERROR: Exception while creating note - ' + e);
		return null;
	}
}

// ========================================
// RESPAWN FUNCTIONS
// ========================================

/**
 * Respawns a specific cached note and reinserts it into the unspawn queue.
 * @param index The index in noteDataCache to respawn.
 * @return The rebuilt note, or null if invalid index.
 */
function respawnNote(index:Int):Dynamic {
	// Respawn a single note by its cache index
	if (index < 0 || index >= noteDataCache.length) {
		debug('Invalid note index ' + index);
		return null;
	}

	var data = noteDataCache[index];
	var replacements:Array<Dynamic> = [];
	var newNote = rebuildNote(index, data.strumTime, data.strumTime, replacements);

	if (newNote != null) {
		debug('Respawned note at ' + data.strumTime + 'ms');
	}

	return newNote;
}

/**
 * Respawns every cached note that matches the chosen strum time.
 * @param time The exact strum time to respawn.
 * @param mustPress Optional filter: true for player notes, false for opponent, null for both.
 * @return Array of respawned notes.
 */
function respawnNoteAtTime(time:Float, ?mustPress:Bool = null):Array<Dynamic> {
	// Respawn all notes at a specific time
	var respawnedNotes:Array<Dynamic> = [];
	var replacements:Array<Dynamic> = [];
	var lastNotePerColumn:Array<Dynamic> = [];
	var headPerColumn:Array<Dynamic> = [];

	for (i in 0...noteDataCache.length) {
		var data = noteDataCache[i];
		if (data.strumTime == time) {
			if (mustPress == null || data.mustPress == mustPress) {
				var newNote = rebuildNote(i, time, time, replacements, lastNotePerColumn, headPerColumn);
				if (newNote != null) {
					respawnedNotes.push(newNote);
				}
			}
		}
	}

	if (respawnedNotes.length > 0) {
		debug('Respawned ' + respawnedNotes.length + ' notes at ' + time + 'ms');
	}

	return respawnedNotes;
}

/**
 * Respawns all cached notes between two timestamps, rebuilding sustain chains.
 * @param startTime The start of the time range.
 * @param endTime The end of the time range.
 * @param mustPress Optional filter: true for player notes, false for opponent, null for both.
 * @return Array of respawned notes.
 */
function respawnNotesInRange(startTime:Float, endTime:Float, ?mustPress:Bool = null):Array<Dynamic> {
	// Respawn all notes within a time range (useful for rewind)
	var respawnedNotes:Array<Dynamic> = [];
	var replacements:Array<Dynamic> = [];
	var lastNotePerColumn:Array<Dynamic> = [];
	var headPerColumn:Array<Dynamic> = [];

	for (i in 0...noteDataCache.length) {
		var data = noteDataCache[i];
		if (data.strumTime >= startTime && data.strumTime <= endTime) {
			if (mustPress == null || data.mustPress == mustPress) {
				var newNote = rebuildNote(i, startTime, endTime, replacements, lastNotePerColumn, headPerColumn);
				if (newNote != null) {
					respawnedNotes.push(newNote);
				}
			}
		}
	}

	if (respawnedNotes.length > 0) {
		debug('Respawned ' + respawnedNotes.length + ' notes between ' + startTime + '-' + endTime + 'ms');
	}

	return respawnedNotes;
}

/**
 * Inserts a note back into the unspawn queue while keeping time ordering intact.
 * @param note The note to insert.
 */
function insertNoteIntoGame(note:Dynamic) {
	// Insert the note into the game's note system
	// Add to unspawnNotes in the correct position (sorted by strumTime)
	var inserted = false;

	for (i in 0...game.unspawnNotes.length) {
		if (note.strumTime < game.unspawnNotes[i].strumTime) {
			game.unspawnNotes.insert(i, note);
			inserted = true;
			break;
		}
	}

	// If not inserted, add to end
	if (!inserted) {
		game.unspawnNotes.push(note);
	}
}

// ========================================
// CALLBACK REGISTRATION
// ========================================

/**
 * Registers all note caching functions as global callbacks.
 * Makes these functions accessible from other scripts via setVar() and createGlobalCallback().
 */
function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		// Debug functions
		['noteCacher_printNoteInfo', printNoteInfo],
		// Cache info getters
		['noteCacher_getCachedNoteCount', getCachedNoteCount],
		['noteCacher_getAllCachedNotes', getAllCachedNotes],
		['noteCacher_getAllPlayerNotes', getAllPlayerNotes],
		['noteCacher_getAllOpponentNotes', getAllOpponentNotes],
		['noteCacher_getNoteDataCache', getNoteDataCache],
		['noteCacher_getReplacementLookup', getReplacementLookup],
		// Note query functions
		['noteCacher_getNoteAtTime', getNoteAtTime],
		['noteCacher_getNotesInRange', getNotesInRange],
		['noteCacher_getNotesByColumn', getNotesByColumn],
		['noteCacher_getNotesByType', getNotesByType],
		['noteCacher_getCachedNoteData', getCachedNoteData],
		['noteCacher_getNoteDataByTime', getNoteDataByTime],
		// Note manipulation functions
		['noteCacher_respawnNote', respawnNote],
		['noteCacher_respawnNoteAtTime', respawnNoteAtTime],
		['noteCacher_respawnNotesInRange', respawnNotesInRange],
		['noteCacher_clearNotesInRange', clearNotesInRange]
	];

	for (callback in callbacks) {
		setVar(callback[0], callback[1]);
		createGlobalCallback(callback[0], callback[1]);
	}

	debug('Registered ' + callbacks.length + ' callbacks');
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreatePost() {
	if (!noteCache_enabled)
		return;

	cacheNotes();

	if (cachedNotes.length > 0) {
		debug('Cached ' + cachedNotes.length + ' total notes');
		debug('' + cachedPlayerNotes.length + ' player notes');
		debug('' + cachedOpponentNotes.length + ' opponent notes');
	} else {
		debug('No notes found to cache!');
	}

	registerCallbacks();
}
