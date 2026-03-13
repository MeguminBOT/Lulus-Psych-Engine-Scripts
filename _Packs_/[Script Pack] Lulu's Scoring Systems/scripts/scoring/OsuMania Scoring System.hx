/*
	>>> osu!mania Scoring System for Psych Engine
		HScript-based scoring system that implements osu!mania's ScoreV1 scoring.
		This replaces Psych Engine's default scoring system.
		Can be used with Custom HUDs in Lua/HScript by using the provided global callbacks.

		Features:
			- Full osu!mania ScoreV1 scoring with base score + bonus score system.
			- Max score of 1,000,000 per song (scaled by playback rate modifier).
			- OD (Overall Difficulty) 0-10 for customizable hit windows.
			- Hold note (sustain) tail judgements with 1.5x lenient timing windows.
			- Playback rate modifier support with OD and score adjustments just like osu! (e.g., HalfTime, DoubleTime).
			- Settings.json support (when using "Lulu's Feature Pack")
				- Configure settings through the mod settings menu
				- Settings from settings.json will override the default values in the script

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var osu_enabled = true;
var osu_isActiveSystem = false;
var osu_debug = false;
var osu_replaceScoreText = true;
var osu_kadeEngineStyle = false; // Whether to use Kade Engine style scoreText or Psych Engine style.
// --- Overall Difficulty (0-10, higher = stricter timing windows) ---
var osu_od = 8.0;

// --- Score Constants (Do Not Modify) ---
var osu_maxScore = 1000000;

// --- Mod Multipliers (calculated from playback rate, Do Not Modify) ---
var osu_modMultiplier = 1.0;
var osu_modDivider = 1.0;

// --- Scoring State (Do Not Modify) ---
var osu_totalNotes = 0;
var osu_notesProcessed = 0;
var osu_bonus = 100.0;
var osu_baseScoreAccum = 0.0;
var osu_bonusScoreAccum = 0.0;
var osu_currentScore = 0;
var osu_notesCounted = false;

// --- Accuracy Tracking (Do Not Modify) ---
// osu!mania V1 accuracy: (countMAX+count300)*300 + count200*200 + count100*100 + count50*50) / (total*300)
var osu_accuracyNum = 0.0;
var osu_accuracyDen = 0.0;

// --- Judgement Tracking (Do Not Modify) ---
var osu_maxHits = 0; // MAX (Rainbow 300) - <=16ms
var osu_300Hits = 0; // 300 - <=(64 - 3*OD)ms
var osu_200Hits = 0; // 200 - <=(97 - 3*OD)ms
var osu_100Hits = 0; // 100 - <=(127 - 3*OD)ms
var osu_50Hits = 0; // 50 - <=(151 - 3*OD)ms
// --- Sustain Tail Tracking (Do Not Modify) ---
var osu_tailLenience = 1.5; // osu!mania tail release window lenience multiplier
var osu_holdBreaks:Array<Dynamic> = []; // Tracks parent note indices with broken holds

// ========================================
// SETTINGS LOADER
// ========================================

/**
 * Loads settings from settings.json using getModSetting if available.
 * Settings from settings.json will override the default values above.
 */
function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath)))
		return;

	var value:Dynamic;

	if ((value = getModSetting('scoring_system')) != null) {
		osu_isActiveSystem = (value == 'OsuMania');
		osu_enabled = osu_isActiveSystem;
	}

	if (!osu_enabled) {
		var cmpEnabled:Dynamic = getModSetting('scoring_showComparison');
		var cmpShow:Dynamic = getModSetting('cmp_showOsuMania');
		if (cmpEnabled == true && cmpShow == true)
			osu_enabled = true;
	}

	if (!osu_enabled)
		return;

	trace('[osu!mania] settings.json found, loading settings...');

	if ((value = getModSetting('scoring_debug')) != null)
		osu_debug = value;

	if ((value = getModSetting('scoring_replaceScoreText')) != null)
		osu_replaceScoreText = value;

	if ((value = getModSetting('scoring_kadeEngineStyle')) != null)
		osu_kadeEngineStyle = value;

	if ((value = getModSetting('osu_od')) != null) {
		var od:Float = value;
		if (od >= 0.0 && od <= 10.0) {
			osu_od = od;
			debug('Loaded osu_od from settings: OD' + osu_od);
		} else {
			debug('Invalid OD value: ' + od + ', must be between 0.0 and 10.0');
		}
	}
}

// ========================================
// DEBUG HELPER
// ========================================

/**
 * Helper function to print debug messages only when osu_debug is true
 * @param message Message to print
 * @param color Optional color for the debug text (FlxColor)
 */
function debug(message:String, ?color:FlxColor = null) {
	if (!osu_debug || !osu_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[osu!mania] ' + message, color);
}

// ========================================
// HIT WINDOW FUNCTIONS
// ========================================

/**
 * Gets the hit window (in ms) for a judgement at the current OD.
 *
 * Hit windows per osu! wiki:
 *   MAX:  ±16ms (fixed)
 *   300:  ±(64  - 3 * OD) ms
 *   200:  ±(97  - 3 * OD) ms
 *   100:  ±(127 - 3 * OD) ms
 *   50:   ±(151 - 3 * OD) ms
 *   Miss: ±(188 - 3 * OD) ms
 *
 * @param judgement Judgement name: 'max', '300', '200', '100', '50', 'miss'
 * @return Hit window in milliseconds
 */
function osu_getHitWindow(judgement:String):Float {
	switch (judgement.toLowerCase()) {
		case 'max':
			return 16.0;
		case '300':
			return 64.0 - 3.0 * osu_od;
		case '200':
			return 97.0 - 3.0 * osu_od;
		case '100':
			return 127.0 - 3.0 * osu_od;
		case '50':
			return 151.0 - 3.0 * osu_od;
		case 'miss':
			return 188.0 - 3.0 * osu_od;
		default:
			return 0.0;
	}
}

/**
 * Gets the tail release hit window (in ms) for a judgement at the current OD.
 * Tail windows are multiplied by osu_tailLenience (1.5x by default) for more forgiving release timing.
 *
 * @param judgement Judgement name: 'max', '300', '200', '100', '50', 'miss'
 * @return Tail hit window in milliseconds
 */
function osu_getTailHitWindow(judgement:String):Float {
	return osu_getHitWindow(judgement) * osu_tailLenience;
}

/**
 * Determines the osu!mania judgement for a sustain tail release timing.
 * Uses lenient tail windows (1.5x regular windows).
 * @param offsetMs Absolute timing offset in milliseconds
 * @return Judgement string: 'MAX', '300', '200', '100', '50'
 */
function osu_getTailJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= osu_getTailHitWindow('max'))
		return 'MAX';
	if (absMs <= osu_getTailHitWindow('300'))
		return '300';
	if (absMs <= osu_getTailHitWindow('200'))
		return '200';
	if (absMs <= osu_getTailHitWindow('100'))
		return '100';
	return '50';
}

/**
 * Determines the osu!mania judgement for a given timing offset.
 * @param offsetMs Absolute timing offset in milliseconds
 * @return Judgement string: 'MAX', '300', '200', '100', '50'
 */
function osu_getJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= osu_getHitWindow('max'))
		return 'MAX';
	if (absMs <= osu_getHitWindow('300'))
		return '300';
	if (absMs <= osu_getHitWindow('200'))
		return '200';
	if (absMs <= osu_getHitWindow('100'))
		return '100';
	return '50';
}

// ========================================
// SCORING ALGORITHM
// ========================================

/**
 * Calculates mod multiplier and divider from the current playback rate.
 *
 * Slower speeds (< 1.0x) apply a score multiplier penalty:
 *   rate 0.75x → ModMultiplier = 0.5 (like osu! HalfTime)
 *   rate 1.0x  → ModMultiplier = 1.0
 *   Linear interpolation between 0.75x and 1.0x
 *
 * Faster speeds (> 1.0x) reduce punishment from bad hits:
 *   rate 1.0x  → ModDivider = 1.0
 *   rate 1.5x  → ModDivider = 1.1 (like osu! DoubleTime)
 *   Capped at 1.1 for rates >= 1.5x
 */
function calculateModifiers() {
	var rate = game.playbackRate;
	if (rate == null)
		rate = 1.0;

	// Score multiplier penalty for slower speeds
	if (rate < 1.0) {
		if (rate <= 0.75) {
			osu_modMultiplier = 0.5;
		} else {
			// Linear interpolation: 0.75 → 0.5, 1.0 → 1.0
			var t = (rate - 0.75) / 0.25;
			osu_modMultiplier = 0.5 + (t * 0.5);
		}
	} else {
		osu_modMultiplier = 1.0;
	}

	// Punishment divider for faster speeds
	if (rate > 1.0) {
		var t = (rate - 1.0) / 0.5;
		if (t > 1.0)
			t = 1.0;
		osu_modDivider = 1.0 + (t * 0.1);
	} else {
		osu_modDivider = 1.0;
	}

	debug('Modifiers calculated - Rate: ' + rate + ', Multiplier: ' + osu_modMultiplier + ', Divider: ' + osu_modDivider);
}

/**
 * Counts total non-sustain player notes from the game's note arrays.
 * Should be called after all chart modifications (e.g., double chart) are complete.
 */
function countTotalNotes() {
	osu_totalNotes = osu_notesProcessed;

	if (game.unspawnNotes != null) {
		for (note in game.unspawnNotes) {
			if (note != null && note.mustPress) {
				if (!note.isSustainNote) {
					osu_totalNotes = osu_totalNotes + 1;
					// Count tail as an additional judgement if this note has sustain pieces
					if (note.tail != null && note.tail.length > 0)
						osu_totalNotes = osu_totalNotes + 1;
				}
			}
		}
	}

	if (game.notes != null && game.notes.members != null) {
		for (note in game.notes.members) {
			if (note != null && note.mustPress && note.alive) {
				if (!note.isSustainNote) {
					osu_totalNotes = osu_totalNotes + 1;
					// Count tail as an additional judgement if this note has sustain pieces
					if (note.tail != null && note.tail.length > 0)
						osu_totalNotes = osu_totalNotes + 1;
				}
			}
		}
	}

	if (osu_totalNotes <= 0)
		osu_totalNotes = 1;

	debug('Total notes counted (including tails): ' + osu_totalNotes);
}

/**
 * Ensures note count is accurate by recounting on first note interaction.
 * This catches chart modifications made by other scripts (e.g., Play Both Charts).
 */
function ensureNotesCounted() {
	if (!osu_notesCounted) {
		osu_notesCounted = true;
		countTotalNotes();
	}
}

/**
 * Processes a note hit and updates score, bonus, accuracy, and judgement counts.
 *
 * osu!mania ScoreV1 formula:
 *   Score = BaseScore + BonusScore
 *   BaseScore  = (MaxScore * ModMultiplier * 0.5 / TotalNotes) * (HitValue / 320)
 *   BonusScore = (MaxScore * ModMultiplier * 0.5 / TotalNotes) * (HitBonusValue * sqrt(Bonus) / 320)
 *
 * Bonus is updated BEFORE calculating BonusScore:
 *   Bonus = clamp(Bonus + HitBonus - HitPunishment / ModDivider, 0, 100)
 *
 * @param offsetMs Timing offset in milliseconds (absolute value used for judgement)
 */
function processHit(offsetMs:Float) {
	var judgement = osu_getJudgement(offsetMs);

	var hitValue = 0;
	var hitBonusValue = 0;
	var hitBonus = 0.0;
	var hitPunishment = 0.0;
	var accuracyWeight = 0.0;

	if (judgement == 'MAX') {
		hitValue = 320;
		hitBonusValue = 32;
		hitBonus = 2.0;
		accuracyWeight = 300.0; // MAX counts as 300 for V1 accuracy
		osu_maxHits = osu_maxHits + 1;
		setVar('osu_maxHits', osu_maxHits);
	} else if (judgement == '300') {
		hitValue = 300;
		hitBonusValue = 32;
		hitBonus = 1.0;
		accuracyWeight = 300.0;
		osu_300Hits = osu_300Hits + 1;
		setVar('osu_300Hits', osu_300Hits);
	} else if (judgement == '200') {
		hitValue = 200;
		hitBonusValue = 16;
		hitPunishment = 8.0;
		accuracyWeight = 200.0;
		osu_200Hits = osu_200Hits + 1;
		setVar('osu_200Hits', osu_200Hits);
	} else if (judgement == '100') {
		hitValue = 100;
		hitBonusValue = 8;
		hitPunishment = 24.0;
		accuracyWeight = 100.0;
		osu_100Hits = osu_100Hits + 1;
		setVar('osu_100Hits', osu_100Hits);
	} else {
		// 50 (Meh) - also used as minimum for any hit detected by Psych Engine
		hitValue = 50;
		hitBonusValue = 4;
		hitPunishment = 44.0;
		accuracyWeight = 50.0;
		osu_50Hits = osu_50Hits + 1;
		setVar('osu_50Hits', osu_50Hits);
	}

	// Update bonus BEFORE calculating bonus score
	osu_bonus = osu_bonus + hitBonus - hitPunishment / osu_modDivider;
	if (osu_bonus < 0)
		osu_bonus = 0;
	if (osu_bonus > 100)
		osu_bonus = 100;

	// Calculate score components
	var factor = (osu_maxScore * osu_modMultiplier * 0.5) / osu_totalNotes;
	var baseScore = factor * (hitValue / 320.0);
	var bonusScore = factor * (hitBonusValue * Math.sqrt(osu_bonus) / 320.0);

	osu_baseScoreAccum = osu_baseScoreAccum + baseScore;
	osu_bonusScoreAccum = osu_bonusScoreAccum + bonusScore;
	osu_currentScore = Math.round(osu_baseScoreAccum + osu_bonusScoreAccum);

	// Update accuracy tracking
	osu_accuracyNum = osu_accuracyNum + accuracyWeight;
	osu_accuracyDen = osu_accuracyDen + 300.0;

	osu_notesProcessed = osu_notesProcessed + 1;

	debug('Hit: ' + judgement + ' (' + Math.round(offsetMs * 100) / 100 + 'ms) | Score: ' + osu_currentScore + ' | Bonus: ' +
		Math.round(osu_bonus * 100) / 100);
}

/**
 * Processes a hit on a sustain tail (last piece of a hold note).
 * Uses 1.5x lenient timing windows. If hold was broken (early release), caps judgement to 50.
 *
 * @param note The sustain tail note
 */
function processTailHit(note:Dynamic) {
	// Calculate timing offset for the tail
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;

	// Check if the hold was broken (parent missed or hold break occurred)
	var holdBroken = false;
	if (note.parent != null) {
		// Hold is broken if the parent head was missed
		if (!note.parent.wasGoodHit)
			holdBroken = true;

		// Check if any earlier tail pieces were missed (hold break)
		if (!holdBroken && note.parent.tail != null) {
			for (child in note.parent.tail) {
				if (child == note)
					break; // Only check pieces before this one
				if (child.missed || child.tooLate) {
					holdBroken = true;
					break;
				}
			}
		}
	}

	// Get tail judgement with lenient windows
	var judgement = osu_getTailJudgement(noteDiff);

	// If hold was broken, cap judgement to 50 (Meh)
	if (holdBroken) {
		judgement = '50';
		debug('Tail hit with broken hold - capped to 50');
	}

	// Process using the same scoring values as regular hits
	var hitValue = 0;
	var hitBonusValue = 0;
	var hitBonus = 0.0;
	var hitPunishment = 0.0;
	var accuracyWeight = 0.0;

	if (judgement == 'MAX') {
		hitValue = 320;
		hitBonusValue = 32;
		hitBonus = 2.0;
		accuracyWeight = 300.0;
		osu_maxHits = osu_maxHits + 1;
		setVar('osu_maxHits', osu_maxHits);
	} else if (judgement == '300') {
		hitValue = 300;
		hitBonusValue = 32;
		hitBonus = 1.0;
		accuracyWeight = 300.0;
		osu_300Hits = osu_300Hits + 1;
		setVar('osu_300Hits', osu_300Hits);
	} else if (judgement == '200') {
		hitValue = 200;
		hitBonusValue = 16;
		hitPunishment = 8.0;
		accuracyWeight = 200.0;
		osu_200Hits = osu_200Hits + 1;
		setVar('osu_200Hits', osu_200Hits);
	} else if (judgement == '100') {
		hitValue = 100;
		hitBonusValue = 8;
		hitPunishment = 24.0;
		accuracyWeight = 100.0;
		osu_100Hits = osu_100Hits + 1;
		setVar('osu_100Hits', osu_100Hits);
	} else {
		hitValue = 50;
		hitBonusValue = 4;
		hitPunishment = 44.0;
		accuracyWeight = 50.0;
		osu_50Hits = osu_50Hits + 1;
		setVar('osu_50Hits', osu_50Hits);
	}

	// Update bonus
	osu_bonus = osu_bonus + hitBonus - hitPunishment / osu_modDivider;
	if (osu_bonus < 0)
		osu_bonus = 0;
	if (osu_bonus > 100)
		osu_bonus = 100;

	// Calculate score components
	var factor = (osu_maxScore * osu_modMultiplier * 0.5) / osu_totalNotes;
	var baseScore = factor * (hitValue / 320.0);
	var bonusScore = factor * (hitBonusValue * Math.sqrt(osu_bonus) / 320.0);

	osu_baseScoreAccum = osu_baseScoreAccum + baseScore;
	osu_bonusScoreAccum = osu_bonusScoreAccum + bonusScore;
	osu_currentScore = Math.round(osu_baseScoreAccum + osu_bonusScoreAccum);

	// Update accuracy tracking
	osu_accuracyNum = osu_accuracyNum + accuracyWeight;
	osu_accuracyDen = osu_accuracyDen + 300.0;

	osu_notesProcessed = osu_notesProcessed + 1;

	debug('Tail Hit: '
		+ judgement
		+ ' ('
		+ Math.round(noteDiff * 100) / 100
		+ 'ms)'
		+ (holdBroken ? ' [HOLD BROKEN]' : '')
		+ ' | Score: '
		+ osu_currentScore);
}

/**
 * Processes a sustain tail miss. Resets bonus and updates accuracy.
 */
function processTailMiss() {
	osu_bonus = 0;
	osu_accuracyDen = osu_accuracyDen + 300.0;
	osu_notesProcessed = osu_notesProcessed + 1;
	debug('Tail Miss! Bonus reset to 0 | Score: ' + osu_currentScore);
}

/**
 * Processes a miss, resetting the bonus multiplier and updating accuracy.
 * Miss: HitValue=0, HitBonusValue=0, Bonus resets to 0.
 */
function processMiss() {
	// Bonus resets to 0 on miss (infinite punishment)
	osu_bonus = 0;

	// No score added (HitValue=0, HitBonusValue=0)

	// Update accuracy tracking (miss = 0 weight out of 300 max)
	osu_accuracyDen = osu_accuracyDen + 300.0;

	osu_notesProcessed = osu_notesProcessed + 1;

	debug('Miss! Bonus reset to 0 | Score: ' + osu_currentScore);
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Enables or disables the osu!mania scoring system
 * @param enabled Whether to enable osu!mania scoring
 */
function osu_setEnabled(enabled:Bool) {
	osu_enabled = enabled;
	setVar('osu_enabled', osu_enabled);
	debug('osu!mania scoring ' + (enabled ? 'enabled' : 'disabled'));
}

/**
 * Sets the Overall Difficulty (OD) for timing windows.
 * @param od OD value (clamped between 0.0 and 10.0)
 */
function osu_setOD(od:Float) {
	osu_od = Math.max(0.0, Math.min(10.0, od));
	debug('OD set to: ' + osu_od + ' (300 window: +/-' + osu_getHitWindow('300') + 'ms)');
}

/**
 * Returns the current OD value.
 * @return OD value (0.0 to 10.0)
 */
function osu_getOD():Float {
	return osu_od;
}

/**
 * Returns the current osu!mania accuracy as a percentage.
 * Uses ScoreV1 formula where both MAX and 300 count as 300 for accuracy.
 * @return Accuracy percentage (0-100)
 */
function osu_getAccuracy():Float {
	if (osu_accuracyDen <= 0)
		return 0.0;
	var percent = (osu_accuracyNum / osu_accuracyDen) * 100.0;
	return Math.max(0, Math.min(100, percent));
}

/**
 * Returns the current score.
 * @return Current osu!mania score (0 to ~1,000,000)
 */
function osu_getScore():Int {
	return osu_currentScore;
}

/**
 * Returns the maximum achievable score based on current modifiers.
 * @return Maximum possible score
 */
function osu_getMaxPossibleScore():Int {
	return Math.round(osu_maxScore * osu_modMultiplier);
}

/**
 * Gets the letter grade for a given accuracy percentage.
 * osu!mania grade thresholds:
 *   SS  = 100%
 *   S   = >95%
 *   A   = >90%
 *   B   = >80%
 *   C   = >70%
 *   D   = anything else
 *
 * @param percent Accuracy percentage (0-100)
 * @return Grade string
 */
function osu_getGrade(percent:Float):String {
	if (percent >= 100.0)
		return 'SS';
	if (percent > 95.0)
		return 'S';
	if (percent > 90.0)
		return 'A';
	if (percent > 80.0)
		return 'B';
	if (percent > 70.0)
		return 'C';
	return 'D';
}

/**
 * Gets the FC (Full Combo) tier based on judgement counts and misses.
 *   PFC  = All MAX (Perfect Full Combo)
 *   FC   = No misses
 *   SDCB = < 10 misses (Single Digit Combo Break)
 *   Clear = 10+ misses
 *
 * @return FC tier string
 */
function osu_getRatingFC():String {
	var misses = game.songMisses;

	if (misses > 0) {
		if (misses < 10)
			return 'SDCB';
		return 'Clear';
	}

	if (osu_300Hits == 0 && osu_200Hits == 0 && osu_100Hits == 0 && osu_50Hits == 0)
		return 'PFC';

	return 'FC';
}

/**
 * Returns the total number of MAX judgements.
 * @return Count of MAX hits (<=16ms)
 */
function osu_getMaxHits():Int {
	return osu_maxHits;
}

/**
 * Returns the total number of 300 judgements.
 * @return Count of 300 hits
 */
function osu_get300Hits():Int {
	return osu_300Hits;
}

/**
 * Returns the total number of 200 judgements.
 * @return Count of 200 hits
 */
function osu_get200Hits():Int {
	return osu_200Hits;
}

/**
 * Returns the total number of 100 judgements.
 * @return Count of 100 hits
 */
function osu_get100Hits():Int {
	return osu_100Hits;
}

/**
 * Returns the total number of 50 judgements.
 * @return Count of 50 hits
 */
function osu_get50Hits():Int {
	return osu_50Hits;
}

/**
 * Returns the current bonus multiplier value.
 * @return Bonus value (0 to 100)
 */
function osu_getBonus():Float {
	return osu_bonus;
}

/**
 * Returns the current mod multiplier (from playback rate).
 * @return Mod multiplier value
 */
function osu_getModMultiplier():Float {
	return osu_modMultiplier;
}

/**
 * Returns the current mod divider (from playback rate).
 * @return Mod divider value
 */
function osu_getModDivider():Float {
	return osu_modDivider;
}

/**
 * Returns the total number of notes in the chart.
 * @return Total note count
 */
function osu_getTotalNotes():Int {
	return osu_totalNotes;
}

/**
 * Formats percentage to 2 decimal places.
 * @param value Percentage value
 * @return Formatted string
 */
function osu_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

/**
 * Resets all scoring state to initial values.
 */
function osu_resetScoring() {
	osu_bonus = 100.0;
	osu_baseScoreAccum = 0.0;
	osu_bonusScoreAccum = 0.0;
	osu_currentScore = 0;
	osu_notesProcessed = 0;
	osu_accuracyNum = 0.0;
	osu_accuracyDen = 0.0;
	osu_maxHits = 0;
	osu_300Hits = 0;
	osu_200Hits = 0;
	osu_100Hits = 0;
	osu_50Hits = 0;
	osu_notesCounted = false;
	osu_holdBreaks = [];
	debug('osu!mania scoring reset');

	if (osu_replaceScoreText)
		osu_updateScoreText();
}

/**
 * Recounts total notes. Call this after chart modifications (e.g., double chart).
 */
function osu_recountNotes() {
	osu_notesCounted = false;
	ensureNotesCounted();
}

/**
 * Enables or disables score text replacement.
 * @param replace Whether to replace Psych Engine's default score text
 */
function osu_setReplaceScoreText(replace:Bool) {
	osu_replaceScoreText = replace;
	setVar('osu_replaceScoreText', osu_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

/**
 * Returns whether score text replacement is enabled.
 * @return Current state of score text replacement
 */
function osu_getReplaceScoreText():Bool {
	return osu_replaceScoreText;
}

// ========================================
// SCORE TEXT
// ========================================

/**
 * Updates the score text with osu!mania scoring information.
 * Format: Score: X | Misses: Y | Rating: GRADE (ACC%) - FC
 */
function osu_updateScoreText() {
	if (!osu_enabled || !osu_replaceScoreText)
		return;

	var score = osu_getScore();
	var misses = game.songMisses;
	var hasHitNotes = (osu_accuracyDen > 0);

	var scoreText = '';

	if (hasHitNotes) {
		var accuracy = osu_getAccuracy();
		var formattedPercent = osu_formatPercent(accuracy);
		var grade = osu_getGrade(accuracy);
		var ratingFC = osu_getRatingFC();

		scoreText = osu_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ' + formattedPercent + ' % | (' + ratingFC + ') '
			+ grade : 'Score: '
			+ score
			+ ' | Misses: '
			+ misses
			+ ' | Rating: '
			+ grade
			+ ' ('
			+ formattedPercent
			+ '%) - '
			+ ratingFC;
	} else {
		scoreText = osu_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ?' : 'Score: '
			+ score
			+ ' | Misses: '
			+ misses
			+ ' | Rating: ?';
	}

	game.scoreTxt.text = scoreText;
}

// ========================================
// CALLBACK REGISTRATION
// ========================================

/**
 * Registers all osu!mania scoring functions as global callbacks.
 * Makes these functions accessible from other scripts via setVar() and createGlobalCallback().
 */
function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['osu_getAccuracy', osu_getAccuracy],
		['osu_getScore', osu_getScore],
		['osu_getGrade', osu_getGrade],
		['osu_getOD', osu_getOD],
		['osu_setOD', osu_setOD],
		['osu_getMaxHits', osu_getMaxHits],
		['osu_get300Hits', osu_get300Hits],
		['osu_get200Hits', osu_get200Hits],
		['osu_get100Hits', osu_get100Hits],
		['osu_get50Hits', osu_get50Hits],
		['osu_getBonus', osu_getBonus],
		['osu_getModMultiplier', osu_getModMultiplier],
		['osu_getModDivider', osu_getModDivider],
		['osu_getTotalNotes', osu_getTotalNotes],
		['osu_getMaxPossibleScore', osu_getMaxPossibleScore],
		['osu_formatPercent', osu_formatPercent],
		['osu_getRatingFC', osu_getRatingFC],
		['osu_getHitWindow', osu_getHitWindow],
		['osu_getJudgement', osu_getJudgement],
		['osu_setEnabled', osu_setEnabled],
		['osu_resetScoring', osu_resetScoring],
		['osu_recountNotes', osu_recountNotes],
		['osu_setReplaceScoreText', osu_setReplaceScoreText],
		['osu_getReplaceScoreText', osu_getReplaceScoreText],
		['osu_updateScoreText', osu_updateScoreText],
		['osu_getTailHitWindow', osu_getTailHitWindow],
		['osu_getTailJudgement', osu_getTailJudgement]
	];

	for (callback in callbacks) {
		createGlobalCallback(callback[0], callback[1]);
		setVar(callback[0], callback[1]);
	}
}

// ========================================
// PSYCH FUNCTIONS
// ========================================

function onCreate() {
	// Load settings from settings.json if available
	loadSettings();
	registerCallbacks();

	debug('osu!mania functions registered - accessible from other scripts');
	debug('osu!mania Scoring System Initialized (OD' + osu_od + ')');
}

function onCreatePost() {
	calculateModifiers();
	countTotalNotes();
	osu_resetScoring();

	debug('Total notes: ' + osu_totalNotes + ' | Max possible score: ' + osu_getMaxPossibleScore());

	if (osu_isActiveSystem) {
		var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
		var outerWindow = 188.0 - 3.0 * osu_od;
		Conductor.safeZoneOffset = outerWindow * playbackRate;
		debug('Overrode safeZoneOffset to ' + Conductor.safeZoneOffset + 'ms (missWindow=' + outerWindow + 'ms)');
	}
}

function preUpdateScore(miss:Bool) {
	if (osu_isActiveSystem && osu_replaceScoreText) {
		if (!miss)
			game.doScoreBop();
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (osu_isActiveSystem && osu_replaceScoreText)
		osu_updateScoreText();
}

function goodNoteHit(note:Note) {
	if (!note.mustPress)
		return;
	if (!osu_enabled)
		return;

	// Handle sustain notes - only process the LAST tail piece as a tail judgement
	if (note.isSustainNote) {
		if (note.parent == null)
			return;

		// Check if this is the last tail piece of the sustain
		var isLastTail = false;
		var parentTail = note.parent.tail;
		if (parentTail != null && parentTail.length > 0) {
			var lastNote = parentTail[parentTail.length - 1];
			if (lastNote == note)
				isLastTail = true;
		}

		if (!isLastTail)
			return;

		// Ensure accurate note count
		ensureNotesCounted();

		// Process as tail hit
		processTailHit(note);

		if (osu_replaceScoreText)
			osu_updateScoreText();
		return;
	}

	// Regular (non-sustain) note hit
	// Ensure accurate note count (catches double chart modifications)
	ensureNotesCounted();

	// Calculate timing offset
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;

	// Process the hit using absolute offset
	processHit(noteDiff);

	if (osu_replaceScoreText)
		osu_updateScoreText();
}

function noteMiss(note:Note) {
	if (!note.mustPress)
		return;
	if (!osu_enabled)
		return;

	// Handle sustain note misses - only process the last tail piece
	if (note.isSustainNote) {
		if (note.parent == null)
			return;

		// Check if this is the last tail piece of the sustain
		var isLastTail = false;
		var parentTail = note.parent.tail;
		if (parentTail != null && parentTail.length > 0) {
			var lastNote = parentTail[parentTail.length - 1];
			if (lastNote == note)
				isLastTail = true;
		}

		if (!isLastTail)
			return;

		// Ensure accurate note count
		ensureNotesCounted();

		processTailMiss();

		if (osu_replaceScoreText)
			osu_updateScoreText();
		return;
	}

	// Regular (non-sustain) note miss
	// Ensure accurate note count
	ensureNotesCounted();

	// If this head note had a sustain, the tail miss will be handled
	// separately when the last tail piece is missed
	processMiss();

	if (osu_replaceScoreText)
		osu_updateScoreText();
}
