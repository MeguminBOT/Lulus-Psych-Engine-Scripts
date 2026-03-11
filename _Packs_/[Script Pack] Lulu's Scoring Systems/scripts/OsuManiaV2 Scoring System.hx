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

// --- Sustain Tail Tracking (Do Not Modify) ---
var osuv2_tailLenience = 1.5;

// ========================================
// SETTINGS LOADER
// ========================================

/**
 * Loads settings from settings.json using getModSetting if available.
 */
function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath))) {
		trace('[osu!maniaV2] settings.json not found, using default values from script');
		return;
	}
	trace('[osu!maniaV2] settings.json found, loading settings...');

	var value:Dynamic;

	if ((value = getModSetting('scoring_system')) != null)
		osuv2_enabled = (value == 'OsuManiaV2');

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
			return 0.0;
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

	// Track max combo achieved
	if (osuv2_combo > osuv2_maxComboAchieved)
		osuv2_maxComboAchieved = osuv2_combo;

	// Update accuracy tracking
	osuv2_accuracyNum = osuv2_accuracyNum + accuracyWeight;
	osuv2_accuracyDen = osuv2_accuracyDen + 300.0;

	osuv2_objectsProcessed = osuv2_objectsProcessed + 1;
}

/**
 * Processes a sustain tail hit with lenient windows.
 */
function processTailHit(note:Dynamic) {
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;

	// Check if hold was broken
	var holdBroken = false;
	if (note.parent != null) {
		if (!note.parent.wasGoodHit)
			holdBroken = true;

		if (!holdBroken && note.parent.tail != null) {
			for (child in note.parent.tail) {
				if (child == note)
					break;
				if (child.missed || child.tooLate) {
					holdBroken = true;
					break;
				}
			}
		}
	}

	var judgement = osuv2_getTailJudgement(noteDiff);

	if (holdBroken) {
		judgement = '50';
		debug('Tail hit with broken hold - capped to 50');
	}

	processJudgement(judgement);

	debug('Tail Hit: '
		+ judgement
		+ ' ('
		+ Math.round(noteDiff * 100) / 100
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
	debug('Tail Miss! Combo broken | Score: ' + osuv2_getScore());
}

/**
 * Processes a miss. Breaks combo and adds 0 to accuracy.
 */
function processMiss() {
	osuv2_combo = 0;
	osuv2_accuracyDen = osuv2_accuracyDen + 300.0;
	osuv2_objectsProcessed = osuv2_objectsProcessed + 1;
	debug('Miss! Combo broken | Score: ' + osuv2_getScore());
}

// ========================================
// HELPER FUNCTIONS
// ========================================

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

	if (misses > 0) {
		if (misses < 10)
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
	osuv2_objectsCounted = false;
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
	var hasHitNotes = (osuv2_accuracyDen > 0);

	var scoreText = '';

	if (hasHitNotes) {
		var accuracy = osuv2_getAccuracy();
		var formattedPercent = osuv2_formatPercent(accuracy);
		var grade = osuv2_getGrade(accuracy);
		var ratingFC = osuv2_getRatingFC();

		scoreText = osuv2_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ' + formattedPercent + ' % | (' + ratingFC
			+ ') ' + grade : 'Score: '
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
		scoreText = osuv2_kadeEngineStyle ? 'Score: ' + score + ' | Combo Breaks: ' + misses + ' | Accuracy: ?' : 'Score: '
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
}

function preUpdateScore(miss:Bool) {
	if (osuv2_enabled && osuv2_replaceScoreText) {
		if (!miss)
			game.doScoreBop();
		return Function_Stop;
	}
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	if (osuv2_enabled && osuv2_replaceScoreText)
		osuv2_updateScoreText();
}

function goodNoteHit(note:Note) {
	if (!note.mustPress)
		return;

	// Handle sustain tail (last piece only)
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

		ensureObjectsCounted();
		processTailHit(note);

		if (osuv2_replaceScoreText)
			osuv2_updateScoreText();
		return;
	}

	// Regular note hit
	ensureObjectsCounted();

	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;

	processHit(noteDiff);

	if (osuv2_replaceScoreText)
		osuv2_updateScoreText();
}

function noteMiss(note:Note) {
	if (!note.mustPress)
		return;

	// Handle sustain tail miss (last piece only)
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

		ensureObjectsCounted();
		processTailMiss();

		if (osuv2_replaceScoreText)
			osuv2_updateScoreText();
		return;
	}

	// Regular note miss
	ensureObjectsCounted();
	processMiss();

	if (osuv2_replaceScoreText)
		osuv2_updateScoreText();
}

function onDestroy() {
	// Cleanup handled by other scripts
}
