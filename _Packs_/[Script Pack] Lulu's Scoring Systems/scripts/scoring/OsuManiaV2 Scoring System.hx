/*
	>>> osu!mania ScoreV2 Scoring System for Psych Engine
		HScript-based scoring system that implements osu!mania's ScoreV2 scoring.
		This replaces Psych Engine's default scoring system.
		Can be used with Custom HUDs in Lua/HScript by using the provided global callbacks.

		Features:
			- osu!mania ScoreV2 scoring normalized to 1,000,000.
			- Score = 700,000 × ComboRatio + 300,000 × Accuracy^10
			- ComboRatio = MaxComboAchieved / MaxCombo (total objects in chart)
			- Press and release judged separately (objects = taps + LN starts + LN releases)
			- OD (Overall Difficulty) 0-10 for customizable hit windows (shared with V1)
			- Hold note (sustain) tail judgements with 1.5x lenient timing windows
			- Playback rate modifier support
			- Settings.json support (when using "Lulu's Scoring Systems" pack)
				- Configure settings through the mod settings menu
				- Settings from settings.json will override the default values in the script

		ScoreV2 Formula:
			Score = 700,000 × ComboRatio + 300,000 × Accuracy^10
			ComboRatio = MaxComboAchieved / MaxCombo
			MaxCombo = total objects (taps + LN starts + LN releases)
			Accuracy = standard osu!mania accuracy (MAX/300=300, 200=200, 100=100, 50=50, Miss=0) / 300

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================
// --- General Settings ---
var osuv2_enabled = true;
var osuv2_isActiveSystem = false;
var osuv2_debug = false;
var osuv2_replaceScoreText = true;
var osuv2_kadeEngineStyle = false;

// --- Overall Difficulty (0-10, higher = stricter timing windows) ---
var osuv2_od = 8.0;

// --- Scoring State (Do Not Modify) ---
var osuv2_totalObjects = 0;
var osuv2_objectsProcessed = 0;
var osuv2_objectsCounted = false;

// --- Combo Tracking (Do Not Modify) ---
var osuv2_combo = 0;
var osuv2_maxComboAchieved = 0;

// --- Accuracy Tracking (Do Not Modify) ---
// Accuracy: (countMAX+count300)*300 + count200*200 + count100*100 + count50*50) / (total*300)
var osuv2_accuracyNum = 0.0;
var osuv2_accuracyDen = 0.0;

// --- Judgement Tracking (Do Not Modify) ---
var osuv2_maxHits = 0;
var osuv2_300Hits = 0;
var osuv2_200Hits = 0;
var osuv2_100Hits = 0;
var osuv2_50Hits = 0;
var osuv2_comboBreaks = 0; // Combo breaks from dropped sustains (tail misses)

// --- Sustain Tail Tracking (Do Not Modify) ---
var osuv2_tailLenience = 1.5;
// Active sustain tracking per column (noteData 0-3)
// Each entry: { parentNote, lastTailStrumTime, holdBroken, tailProcessed }
var osuv2_activeSustains:Array<Dynamic> = [null, null, null, null];

// ========================================
// SETTINGS LOADER
// ========================================

/**
 * Loads settings from settings.json using getModSetting if available.
 */
function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath)))
		return;

	var value:Dynamic;

	if ((value = getModSetting('scoring_system')) != null) {
		osuv2_isActiveSystem = (value == 'OsuManiaV2');
		osuv2_enabled = osuv2_isActiveSystem;
	}

	if (!osuv2_enabled) {
		var cmpEnabled:Dynamic = getModSetting('scoring_showComparison');
		var cmpShow:Dynamic = getModSetting('cmp_showOsuManiaV2');
		if (cmpEnabled == true && cmpShow == true)
			osuv2_enabled = true;
	}

	if (!osuv2_enabled)
		return;

	trace('[osu!maniaV2] settings.json found, loading settings...');

	if ((value = getModSetting('scoring_debug')) != null)
		osuv2_debug = value;

	if ((value = getModSetting('scoring_replaceScoreText')) != null)
		osuv2_replaceScoreText = value;

	if ((value = getModSetting('scoring_kadeEngineStyle')) != null)
		osuv2_kadeEngineStyle = value;

	// Share OD setting with V1
	if ((value = getModSetting('osu_od')) != null) {
		var od:Float = value;
		if (od >= 0.0 && od <= 10.0) {
			osuv2_od = od;
			debug('Loaded osu_od from settings: OD' + osuv2_od);
		}
	}
}

// ========================================
// DEBUG HELPER
// ========================================

function debug(message:String, ?color:FlxColor = null) {
	if (!osuv2_debug || !osuv2_enabled)
		return;

	if (color == null)
		color = FlxColor.WHITE;
	debugPrint('[osu!maniaV2] ' + message, color);
}

// ========================================
// HIT WINDOW FUNCTIONS
// ========================================

/**
 * Gets the hit window (in ms) for a judgement at the current OD.
 * Same windows as ScoreV1.
 *
 * @param judgement Judgement name: 'max', '300', '200', '100', '50', 'miss'
 * @return Hit window in milliseconds
 */
function osuv2_getHitWindow(judgement:String):Float {
	switch (judgement.toLowerCase()) {
		case 'max':
			return 16.0;
		case '300':
			return 64.0 - 3.0 * osuv2_od;
		case '200':
			return 97.0 - 3.0 * osuv2_od;
		case '100':
			return 127.0 - 3.0 * osuv2_od;
		case '50':
			return 151.0 - 3.0 * osuv2_od;
		case 'miss':
			return 188.0 - 3.0 * osuv2_od;
		default:
			return 188.0 - 3.0 * osuv2_od;
	}
}

/**
 * Gets the tail release hit window with 1.5x lenience.
 */
function osuv2_getTailHitWindow(judgement:String):Float {
	return osuv2_getHitWindow(judgement) * osuv2_tailLenience;
}

/**
 * Determines the judgement for a sustain tail release.
 */
function osuv2_getTailJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= osuv2_getTailHitWindow('max'))
		return 'MAX';
	if (absMs <= osuv2_getTailHitWindow('300'))
		return '300';
	if (absMs <= osuv2_getTailHitWindow('200'))
		return '200';
	if (absMs <= osuv2_getTailHitWindow('100'))
		return '100';
	return '50';
}

/**
 * Determines the osu!mania judgement for a given timing offset.
 */
function osuv2_getJudgement(offsetMs:Float):String {
	var absMs = Math.abs(offsetMs);

	if (absMs <= osuv2_getHitWindow('max'))
		return 'MAX';
	if (absMs <= osuv2_getHitWindow('300'))
		return '300';
	if (absMs <= osuv2_getHitWindow('200'))
		return '200';
	if (absMs <= osuv2_getHitWindow('100'))
		return '100';
	return '50';
}

// ========================================
// SCORING ALGORITHM
// ========================================

/**
 * Counts total objects (taps + LN starts + LN releases).
 * Press and release are judged separately.
 */
function countTotalObjects() {
	osuv2_totalObjects = osuv2_objectsProcessed;

	if (game.unspawnNotes != null) {
		for (note in game.unspawnNotes) {
			if (note != null && note.mustPress) {
				if (!note.isSustainNote) {
					osuv2_totalObjects = osuv2_totalObjects + 1;
					// LN release = additional object
					if (note.tail != null && note.tail.length > 0)
						osuv2_totalObjects = osuv2_totalObjects + 1;
				}
			}
		}
	}

	if (game.notes != null && game.notes.members != null) {
		for (note in game.notes.members) {
			if (note != null && note.mustPress && note.alive) {
				if (!note.isSustainNote) {
					osuv2_totalObjects = osuv2_totalObjects + 1;
					if (note.tail != null && note.tail.length > 0)
						osuv2_totalObjects = osuv2_totalObjects + 1;
				}
			}
		}
	}

	if (osuv2_totalObjects <= 0)
		osuv2_totalObjects = 1;

	debug('Total objects counted (taps + LN starts + LN releases): ' + osuv2_totalObjects);
}

function ensureObjectsCounted() {
	if (!osuv2_objectsCounted) {
		osuv2_objectsCounted = true;
		countTotalObjects();
	}
}

/**
 * Processes a note hit. Updates combo, accuracy, and judgement counts.
 *
 * @param offsetMs Timing offset in milliseconds
 */
function processHit(offsetMs:Float) {
	var judgement = osuv2_getJudgement(offsetMs);
	processJudgement(judgement);

	debug('Hit: '
		+ judgement
		+ ' ('
		+ Math.round(offsetMs * 100) / 100
		+ 'ms) | Combo: '
		+ osuv2_combo
		+ ' | Score: '
		+ osuv2_getScore());
}

/**
 * Processes a judgement result, updating combo, accuracy, and hit counters.
 */
function processJudgement(judgement:String) {
	var accuracyWeight = 0.0;

	if (judgement == 'MAX') {
		accuracyWeight = 300.0;
		osuv2_combo = osuv2_combo + 1;
		osuv2_maxHits = osuv2_maxHits + 1;
		setVar('osuv2_maxHits', osuv2_maxHits);
	} else if (judgement == '300') {
		accuracyWeight = 300.0;
		osuv2_combo = osuv2_combo + 1;
		osuv2_300Hits = osuv2_300Hits + 1;
		setVar('osuv2_300Hits', osuv2_300Hits);
	} else if (judgement == '200') {
		accuracyWeight = 200.0;
		osuv2_combo = osuv2_combo + 1;
		osuv2_200Hits = osuv2_200Hits + 1;
		setVar('osuv2_200Hits', osuv2_200Hits);
	} else if (judgement == '100') {
		accuracyWeight = 100.0;
		osuv2_combo = osuv2_combo + 1;
		osuv2_100Hits = osuv2_100Hits + 1;
		setVar('osuv2_100Hits', osuv2_100Hits);
	} else {
		// 50
		accuracyWeight = 50.0;
		osuv2_combo = osuv2_combo + 1;
		osuv2_50Hits = osuv2_50Hits + 1;
		setVar('osuv2_50Hits', osuv2_50Hits);
	}

	if (osuv2_combo > osuv2_maxComboAchieved)
		osuv2_maxComboAchieved = osuv2_combo;

	osuv2_accuracyNum = osuv2_accuracyNum + accuracyWeight;
	osuv2_accuracyDen = osuv2_accuracyDen + 300.0;

	osuv2_objectsProcessed = osuv2_objectsProcessed + 1;
}

/**
 * Processes a sustain tail judgement based on release timing.
 * Uses 1.5x lenient timing windows. If hold was broken, caps judgement to 50.
 *
 * @param releaseOffsetMs Release timing offset in milliseconds (tail strumTime - release time, adjusted for playback rate)
 * @param holdBroken Whether the hold was broken (early release + re-press, or missed pieces)
 */
function processTailHit(releaseOffsetMs:Float, holdBroken:Bool) {
	var judgement = osuv2_getTailJudgement(releaseOffsetMs);

	if (holdBroken) {
		judgement = '50';
		debug('Tail release with broken hold - capped to 50');
	}

	processJudgement(judgement);

	// Trigger release visual feedback (if extras scripts are loaded)
	var releaseFeedbackFn = getVar('showTimingFeedback');
	if (releaseFeedbackFn != null)
		releaseFeedbackFn(releaseOffsetMs);

	var releasePopupFn = getVar('ratingPopups_spawnPopup');
	if (releasePopupFn != null)
		releasePopupFn(judgement);

	debug('Tail Release: '
		+ judgement
		+ ' ('
		+ Math.round(releaseOffsetMs * 100) / 100
		+ 'ms)'
		+ (holdBroken ? ' [HOLD BROKEN]' : '')
		+ ' | Score: '
		+ osuv2_getScore());
}

/**
 * Processes a sustain tail miss. Breaks combo and adds miss to accuracy.
 */
function processTailMiss() {
	osuv2_combo = 0;
	osuv2_accuracyDen = osuv2_accuracyDen + 300.0;
	osuv2_objectsProcessed = osuv2_objectsProcessed + 1;
	osuv2_comboBreaks = osuv2_comboBreaks + 1;
	setVar('osuv2_comboBreaks', osuv2_comboBreaks);

	// Trigger release miss popup (if extras scripts are loaded)
	var releasePopupFn = getVar('ratingPopups_spawnPopup');
	if (releasePopupFn != null)
		releasePopupFn('miss');

	debug('Tail Miss! Combo broken | Score: ' + osuv2_getScore());
}

// ========================================
// HELPER FUNCTIONS
// ========================================

/**
 * Overrides Conductor.safeZoneOffset to match osu!mania V2's miss window.
 * Uses the formula: (188 - 3 * OD) * playbackRate
 */
function osuv2_applySafeZone() {
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	var outerWindow = 188.0 - 3.0 * osuv2_od;
	Conductor.safeZoneOffset = outerWindow * playbackRate;
	debug('Overrode safeZoneOffset to ' + Conductor.safeZoneOffset + 'ms (missWindow=' + outerWindow + 'ms)');
}

function osuv2_setEnabled(enabled:Bool) {
	osuv2_enabled = enabled;
	setVar('osuv2_enabled', osuv2_enabled);
	debug('osu!mania V2 scoring ' + (enabled ? 'enabled' : 'disabled'));
}

function osuv2_setOD(od:Float) {
	osuv2_od = Math.max(0.0, Math.min(10.0, od));
	debug('OD set to: ' + osuv2_od);
}

function osuv2_getOD():Float {
	return osuv2_od;
}

/**
 * Returns the current osu!mania accuracy as a percentage.
 * Same formula as V1: (MAX/300 count as 300) / 300.
 * @return Accuracy percentage (0-100)
 */
function osuv2_getAccuracy():Float {
	if (osuv2_accuracyDen <= 0)
		return 0.0;
	var percent = (osuv2_accuracyNum / osuv2_accuracyDen) * 100.0;
	return Math.max(0, Math.min(100, percent));
}

/**
 * Returns the current ScoreV2 score.
 *
 * Score = 700,000 × ComboRatio + 300,000 × Accuracy^10
 * ComboRatio = MaxComboAchieved / MaxCombo (total objects)
 * Accuracy = 0 to 1 (decimal)
 *
 * @return Score (0 to 1,000,000)
 */
function osuv2_getScore():Int {
	if (osuv2_totalObjects <= 0)
		return 0;

	var comboRatio = osuv2_maxComboAchieved / osuv2_totalObjects;
	if (comboRatio > 1.0)
		comboRatio = 1.0;

	var accuracy = 0.0;
	if (osuv2_accuracyDen > 0)
		accuracy = osuv2_accuracyNum / osuv2_accuracyDen; // 0 to 1

	var accuracyPow = Math.pow(accuracy, 10);

	var score = 700000.0 * comboRatio + 300000.0 * accuracyPow;
	return Math.round(score);
}

function osuv2_getCombo():Int {
	return osuv2_combo;
}

function osuv2_getMaxComboAchieved():Int {
	return osuv2_maxComboAchieved;
}

/**
 * Gets the letter grade for a given accuracy percentage.
 * Same thresholds as V1.
 */
function osuv2_getGrade(percent:Float):String {
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
 * Gets the FC tier.
 *   PFC  = All MAX (Perfect Full Combo)
 *   FC   = No misses
 *   SDCB = < 10 misses
 *   Clear = 10+ misses
 */
function osuv2_getRatingFC():String {
	var misses = game.songMisses;
	var totalBreaks = misses + osuv2_comboBreaks;

	if (totalBreaks > 0) {
		if (totalBreaks < 10)
			return 'SDCB';
		return 'Clear';
	}

	if (osuv2_300Hits == 0 && osuv2_200Hits == 0 && osuv2_100Hits == 0 && osuv2_50Hits == 0)
		return 'PFC';

	return 'FC';
}

function osuv2_getMaxHits():Int {
	return osuv2_maxHits;
}

function osuv2_get300Hits():Int {
	return osuv2_300Hits;
}

function osuv2_get200Hits():Int {
	return osuv2_200Hits;
}

function osuv2_get100Hits():Int {
	return osuv2_100Hits;
}

function osuv2_get50Hits():Int {
	return osuv2_50Hits;
}

function osuv2_getTotalObjects():Int {
	return osuv2_totalObjects;
}

function osuv2_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

function osuv2_resetScoring() {
	osuv2_combo = 0;
	osuv2_maxComboAchieved = 0;
	osuv2_accuracyNum = 0.0;
	osuv2_accuracyDen = 0.0;
	osuv2_objectsProcessed = 0;
	osuv2_maxHits = 0;
	osuv2_300Hits = 0;
	osuv2_200Hits = 0;
	osuv2_100Hits = 0;
	osuv2_50Hits = 0;
	osuv2_comboBreaks = 0;
	osuv2_objectsCounted = false;
	osuv2_activeSustains = [null, null, null, null];
	debug('osu!mania V2 scoring reset');

	if (osuv2_replaceScoreText)
		osuv2_updateScoreText();
}

function osuv2_recountObjects() {
	osuv2_objectsCounted = false;
	ensureObjectsCounted();
}

function osuv2_setReplaceScoreText(replace:Bool) {
	osuv2_replaceScoreText = replace;
	setVar('osuv2_replaceScoreText', osuv2_replaceScoreText);
	debug('Replace Psych Engine score text: ' + (replace ? 'enabled' : 'disabled'));
}

function osuv2_getReplaceScoreText():Bool {
	return osuv2_replaceScoreText;
}

function osuv2_setKadeEngineStyle(kadeStyle:Bool) {
	osuv2_kadeEngineStyle = kadeStyle;
	setVar('osuv2_kadeEngineStyle', osuv2_kadeEngineStyle);
	debug('Kade Engine style score text ' + (kadeStyle ? 'enabled' : 'disabled'));
}

function osuv2_getKadeEngineStyle():Bool {
	return osuv2_kadeEngineStyle;
}

function processMiss() {
	osuv2_combo = 0;
	osuv2_accuracyDen = osuv2_accuracyDen + 300.0;
	osuv2_objectsProcessed = osuv2_objectsProcessed + 1;
}

function processNote(note:Note) {
	// Handle sustain pieces - track active sustains for release timing
	if (note.isSustainNote) {
		if (note.parent == null)
			return;

		var isLastTail = false;
		var parentTail = note.parent.tail;
		if (parentTail != null && parentTail.length > 0) {
			var lastNote = parentTail[parentTail.length - 1];
			if (lastNote == note)
				isLastTail = true;
		}

		if (!isLastTail)
			return;

		// Last tail piece hit while still holding = held to completion
		var active = osuv2_activeSustains[note.noteData];
		if (active != null && !active.tailProcessed) {
			active.tailProcessed = true;
			ensureObjectsCounted();

			var noteDiff = note.strumTime - Conductor.songPosition;
			var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
			processTailHit(noteDiff / playbackRate, active.holdBroken);

			osuv2_activeSustains[note.noteData] = null;
			debug('Tail completed (held to end) on column ' + note.noteData);

			if (osuv2_replaceScoreText)
				osuv2_updateScoreText();
		}
		return;
	}

	ensureObjectsCounted();

	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	processHit(noteDiff / playbackRate);

	// If this head note has sustain pieces, start tracking for release timing
	if (note.tail != null && note.tail.length > 0) {
		var lastTail = note.tail[note.tail.length - 1];
		osuv2_activeSustains[note.noteData] = {
			parentNote: note,
			lastTailStrumTime: lastTail.strumTime,
			holdBroken: false,
			tailProcessed: false
		};
		debug('Tracking sustain on column ' + note.noteData + ' (tail end: ' + lastTail.strumTime + 'ms)');
	}

	if (osuv2_replaceScoreText)
		osuv2_updateScoreText();
}

function processNoteMiss(note:Note) {
	if (note.isSustainNote) {
		// Undo engine's songMisses++ for sustain pieces (combo break, not a miss)
		game.songMisses = game.songMisses - 1;

		if (note.parent == null)
			return;

		var isLastTail = false;
		var parentTail = note.parent.tail;
		if (parentTail != null && parentTail.length > 0) {
			var lastNote = parentTail[parentTail.length - 1];
			if (lastNote == note)
				isLastTail = true;
		}

		// Track hold break if an intermediate piece was missed while sustain is active
		if (!isLastTail) {
			var active = osuv2_activeSustains[note.noteData];
			if (active != null && !active.tailProcessed) {
				active.holdBroken = true;
				osuv2_combo = 0;
			}
			return;
		}

		// Last tail piece missed - check if already processed via onKeyRelease
		var active = osuv2_activeSustains[note.noteData];
		if (active != null && active.tailProcessed) {
			osuv2_activeSustains[note.noteData] = null;
			return; // Already scored via release timing
		}

		// Tail was never processed (head was missed, or never tracked)
		ensureObjectsCounted();
		processTailMiss();

		if (active != null)
			osuv2_activeSustains[note.noteData] = null;

		if (osuv2_replaceScoreText)
			osuv2_updateScoreText();
		return;
	}

	ensureObjectsCounted();
	processMiss();

	debug('Miss! Combo broken | Score: ' + osuv2_getScore());

	if (osuv2_replaceScoreText)
		osuv2_updateScoreText();
}

/**
 * Processes a key release for sustain tail timing.
 * Calculates release offset vs tail end, scores or marks hold as broken.
 * @param key Column index (0-3: left, down, up, right)
 */
function processKeyRelease(key:Int) {
	var active = osuv2_activeSustains[key];
	if (active == null || active.tailProcessed)
		return;

	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	var releaseOffset = active.lastTailStrumTime - Conductor.songPosition;
	releaseOffset = releaseOffset / playbackRate;

	var absOffset = Math.abs(releaseOffset);
	var missWindow = osuv2_getTailHitWindow('miss');

	if (absOffset > missWindow) {
		active.holdBroken = true;
		debug('Hold broken (released early: ' + Math.round(releaseOffset * 100) / 100 + 'ms) on column ' + key);
		return;
	}

	active.tailProcessed = true;
	ensureObjectsCounted();
	processTailHit(releaseOffset, active.holdBroken);
	debug('Tail release on column ' + key + ' at offset ' + Math.round(releaseOffset * 100) / 100 + 'ms');

	if (active.parentNote != null && active.parentNote.tail != null) {
		for (child in active.parentNote.tail) {
			if (child != null && !child.wasGoodHit) {
				child.wasGoodHit = true;
				child.ignoreNote = true;
			}
		}
	}

	osuv2_activeSustains[key] = null;

	if (osuv2_replaceScoreText)
		osuv2_updateScoreText();
}

// ========================================
// SCORE TEXT
// ========================================

/**
 * Updates the score text with osu!mania V2 scoring information.
 */
function osuv2_updateScoreText() {
	if (!osuv2_enabled || !osuv2_replaceScoreText)
		return;

	var score = osuv2_getScore();
	var misses = game.songMisses;
	var cbs = osuv2_comboBreaks;
	var prefix = 'Score: ' + score + ' | Combo Breaks: ' + cbs + ' | Misses: ' + misses;

	if (osuv2_accuracyDen <= 0) {
		game.scoreTxt.text = prefix + (osuv2_kadeEngineStyle ? ' | Accuracy: ?' : ' | Rating: ?');
		return;
	}

	var accuracy = osuv2_getAccuracy();
	var formattedPercent = osuv2_formatPercent(accuracy);
	var grade = osuv2_getGrade(accuracy);
	var ratingFC = osuv2_getRatingFC();

	game.scoreTxt.text = osuv2_kadeEngineStyle ? prefix + ' | Accuracy: ' + formattedPercent + ' % | (' + ratingFC + ') ' + grade : prefix
		+ ' | Rating: '
		+ grade
		+ ' ('
		+ formattedPercent
		+ '%) - '
		+ ratingFC;
}

// ========================================
// CALLBACK REGISTRATION
// ========================================

function registerCallbacks() {
	var callbacks:Array<Dynamic> = [
		['osuv2_getAccuracy', osuv2_getAccuracy],
		['osuv2_getScore', osuv2_getScore],
		['osuv2_getGrade', osuv2_getGrade],
		['osuv2_getOD', osuv2_getOD],
		['osuv2_setOD', osuv2_setOD],
		['osuv2_getMaxHits', osuv2_getMaxHits],
		['osuv2_get300Hits', osuv2_get300Hits],
		['osuv2_get200Hits', osuv2_get200Hits],
		['osuv2_get100Hits', osuv2_get100Hits],
		['osuv2_get50Hits', osuv2_get50Hits],
		['osuv2_getCombo', osuv2_getCombo],
		['osuv2_getMaxComboAchieved', osuv2_getMaxComboAchieved],
		['osuv2_getTotalObjects', osuv2_getTotalObjects],
		['osuv2_formatPercent', osuv2_formatPercent],
		['osuv2_getRatingFC', osuv2_getRatingFC],
		['osuv2_getHitWindow', osuv2_getHitWindow],
		['osuv2_getJudgement', osuv2_getJudgement],
		['osuv2_setEnabled', osuv2_setEnabled],
		['osuv2_resetScoring', osuv2_resetScoring],
		['osuv2_recountObjects', osuv2_recountObjects],
		['osuv2_setReplaceScoreText', osuv2_setReplaceScoreText],
		['osuv2_getReplaceScoreText', osuv2_getReplaceScoreText],
		['osuv2_updateScoreText', osuv2_updateScoreText],
		['osuv2_setKadeEngineStyle', osuv2_setKadeEngineStyle],
		['osuv2_getKadeEngineStyle', osuv2_getKadeEngineStyle],
		['osuv2_getTailHitWindow', osuv2_getTailHitWindow],
		['osuv2_getTailJudgement', osuv2_getTailJudgement]
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
	loadSettings();
	registerCallbacks();

	debug('osu!mania V2 functions registered - accessible from other scripts');
	debug('osu!mania ScoreV2 System Initialized (OD' + osuv2_od + ')');
}

function onCreatePost() {
	countTotalObjects();
	osuv2_resetScoring();

	debug('Total objects: ' + osuv2_totalObjects);

	if (osuv2_isActiveSystem)
		osuv2_applySafeZone();
}

function preUpdateScore(miss:Bool) {
	if (osuv2_isActiveSystem && osuv2_replaceScoreText) {
		if (!miss)
			game.doScoreBop();
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (osuv2_isActiveSystem && osuv2_replaceScoreText)
		osuv2_updateScoreText();
}

function goodNoteHit(note:Note) {
	if (!note.mustPress || !osuv2_enabled)
		return;

	processNote(note);
}

/**
 * Handles key release for sustain tail release timing.
 * When the player releases a key, checks if there's an active sustain on that column
 * and processes the tail judgement based on how close the release was to the tail end.
 *
 * @param key Column index (0-3: left, down, up, right)
 */
function onKeyRelease(key:Int) {
	if (!osuv2_enabled)
		return;
	if (key < 0 || key > 3)
		return;

	processKeyRelease(key);
}

function noteMiss(note:Note) {
	if (!note.mustPress || !osuv2_enabled)
		return;

	processNoteMiss(note);
}

function onDestroy() {}
