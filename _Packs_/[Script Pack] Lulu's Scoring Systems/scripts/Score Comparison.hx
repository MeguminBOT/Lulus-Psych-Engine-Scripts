/*
	>>> Score Comparison Display
		Shows all scoring systems (Psych, Wife3, osu!mania V1/V2, ITG, Ruthless, O2Jam, DJMAX, IIDX, Quaver) simultaneously
		so you can compare accuracy, score, and grades side by side during gameplay.

		Reads values directly from the Wife3, osu!mania, and ITG scoring scripts
		via their registered global callbacks, guaranteeing identical results.
		All scoring scripts always calculate regardless of which system is active.

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
 */
// ========================================
// CONFIGURATION & VARIABLES
// ========================================

var cmp_enabled = true;

// --- Hit Counters (universal timing buckets) ---
var cmp_hits16 = 0; // <=16ms  (IIDX PGreat, osu MAX, DJMAX MAX100%)
var cmp_hits22 = 0; // <=22ms  (Wife3 Marvelous, ITG Fantastic, Quaver Marvelous)
var cmp_hits33 = 0; // <=33ms  (IIDX Great, DJMAX MAX90%, O2Jam Cool)
var cmp_hits45 = 0; // <=45ms  (Wife3 Perfect, ITG Excellent, osu 300, Quaver Perfect)
var cmp_hits75 = 0; // <=75ms  (osu 200, Quaver Great, Ruthless Sloppy)
var cmp_hits90 = 0; // <=90ms  (Wife3 Great, ITG Great)
var cmp_hits100 = 0; // <=100ms (IIDX Good, O2Jam Bad, DJMAX Bad, Ruthless Barely)
var cmp_hits135 = 0; // <=135ms (Wife3 Good, ITG Decent, osu 100)
var cmp_hits180 = 0; // <=180ms (Wife3 Bad, ITG Way Off, IIDX Bad)
var cmp_hits180plus = 0; // >180ms
var cmp_misses = 0;

// --- Display ---
var cmp_bg:FlxSprite = null;
var cmp_text:FlxText = null;

// --- Callback references (populated in onCreatePost) ---
var cmp_wife3_getAccuracy = null;
var cmp_wife3_getScore = null;
var cmp_wife3_getGrade = null;
var cmp_wife3_getRatingFC = null;
var cmp_wife3_formatPercent = null;
var cmp_osu_getAccuracy = null;
var cmp_osu_getScore = null;
var cmp_osu_getGrade = null;
var cmp_osu_getRatingFC = null;
var cmp_osu_formatPercent = null;
var cmp_itg_getAccuracy = null;
var cmp_itg_getScore = null;
var cmp_itg_getGrade = null;
var cmp_itg_getRatingFC = null;
var cmp_itg_formatPercent = null;
var cmp_ruthless_getAccuracy = null;
var cmp_ruthless_getScore = null;
var cmp_ruthless_getGrade = null;
var cmp_ruthless_getRatingFC = null;
var cmp_ruthless_formatPercent = null;
var cmp_o2jam_getAccuracy = null;
var cmp_o2jam_getScore = null;
var cmp_o2jam_getGrade = null;
var cmp_o2jam_getRatingFC = null;
var cmp_o2jam_formatPercent = null;
var cmp_djmax_getAccuracy = null;
var cmp_djmax_getScore = null;
var cmp_djmax_getGrade = null;
var cmp_djmax_getRatingFC = null;
var cmp_djmax_formatPercent = null;
var cmp_iidx_getAccuracy = null;
var cmp_iidx_getScore = null;
var cmp_iidx_getGrade = null;
var cmp_iidx_getRatingFC = null;
var cmp_iidx_formatPercent = null;
var cmp_osuv2_getAccuracy = null;
var cmp_osuv2_getScore = null;
var cmp_osuv2_getGrade = null;
var cmp_osuv2_getRatingFC = null;
var cmp_osuv2_formatPercent = null;
var cmp_quaver_getAccuracy = null;
var cmp_quaver_getScore = null;
var cmp_quaver_getGrade = null;
var cmp_quaver_getRatingFC = null;
var cmp_quaver_formatPercent = null;

// ========================================
// SETTINGS LOADER
// ========================================

function loadSettings() {
	var settingsPath:String = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath)))
		return;

	var value:Dynamic;

	if ((value = getModSetting('scoring_showComparison')) != null)
		cmp_enabled = value;
}

// ========================================
// FORMATTING HELPERS
// ========================================

function cmp_formatPercent(value:Float):String {
	return Std.string(Math.floor(value * 100) / 100);
}

function cmp_padR(s:String, len:Int):String {
	while (s.length < len)
		s = s + ' ';
	return s;
}

function cmp_padL(s:String, len:Int):String {
	while (s.length < len)
		s = ' ' + s;
	return s;
}

function cmp_formatRow(name:String, scoreStr:String, accStr:String, grade:String, fc:String):String {
	var accCol = accStr;
	if (accCol != '?')
		accCol = accCol + '%';
	var line = cmp_padR(name + ': ', 16) + cmp_padL(scoreStr, 8) + ' | ' + cmp_padL(accCol, 7) + ' | ' + grade;
	if (fc != null && fc != '')
		line = line + ' [' + fc + ']';
	return line;
}

// ========================================
// DISPLAY
// ========================================

function cmp_createDisplay() {
	cmp_bg = new FlxSprite(2, 50);
	cmp_bg.makeGraphic(580, 80, FlxColor.BLACK);
	cmp_bg.alpha = 0.5;
	cmp_bg.scrollFactor.set();
	cmp_bg.cameras = [game.camOther];
	game.add(cmp_bg);

	cmp_text = new FlxText(8, 54, 570, '');
	cmp_text.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, 'left', 'outline', FlxColor.BLACK);
	cmp_text.borderSize = 1.25;
	cmp_text.scrollFactor.set();
	cmp_text.cameras = [game.camOther];
	game.add(cmp_text);
}

function cmp_updateDisplay() {
	if (cmp_text == null)
		return;

	// Psych Engine values (always calculated by the engine)
	var psychScore = game.songScore;
	var psychHasData = (game.totalPlayed > 0);
	var psychAcc = psychHasData ? cmp_formatPercent(game.ratingPercent * 100) : '?';
	var psychGrade = psychHasData ? game.ratingName : '?';
	var psychFC = game.ratingFC;

	// Wife3 values (read directly from Wife3 Scoring System.hx)
	var w3Acc = cmp_wife3_getAccuracy();
	var w3HasData = (w3Acc > 0 || game.totalPlayed > 0);
	var w3AccStr = w3HasData ? cmp_wife3_formatPercent(w3Acc) : '?';
	var w3Grade = w3HasData ? cmp_wife3_getGrade(w3Acc) : '?';
	var w3Score = cmp_wife3_getScore();
	var w3FC = w3HasData ? cmp_wife3_getRatingFC() : '';

	// osu!mania values (read directly from OsuMania Scoring System.hx)
	var osuAcc = cmp_osu_getAccuracy();
	var osuHasData = (osuAcc > 0 || game.totalPlayed > 0);
	var osuAccStr = osuHasData ? cmp_osu_formatPercent(osuAcc) : '?';
	var osuGrade = osuHasData ? cmp_osu_getGrade(osuAcc) : '?';
	var osuScore = cmp_osu_getScore();
	var osuFC = osuHasData ? cmp_osu_getRatingFC() : '';

	// Ruthless values (read directly from Ruthless Scoring System.hx)
	var ruthlessAcc = cmp_ruthless_getAccuracy();
	var ruthlessHasData = (ruthlessAcc > 0 || game.totalPlayed > 0);
	var ruthlessAccStr = ruthlessHasData ? cmp_ruthless_formatPercent(ruthlessAcc) : '?';
	var ruthlessGrade = ruthlessHasData ? cmp_ruthless_getGrade(ruthlessAcc) : '?';
	var ruthlessScore = cmp_ruthless_getScore();
	var ruthlessFC = ruthlessHasData ? cmp_ruthless_getRatingFC() : '';

	// osu!mania V2 values (read directly from OsuManiaV2 Scoring System.hx)
	var osuv2Acc = cmp_osuv2_getAccuracy();
	var osuv2HasData = (osuv2Acc > 0 || game.totalPlayed > 0);
	var osuv2AccStr = osuv2HasData ? cmp_osuv2_formatPercent(osuv2Acc) : '?';
	var osuv2Grade = osuv2HasData ? cmp_osuv2_getGrade(osuv2Acc) : '?';
	var osuv2Score = cmp_osuv2_getScore();
	var osuv2FC = osuv2HasData ? cmp_osuv2_getRatingFC() : '';

	// Quaver values (read directly from Quaver Scoring System.hx)
	var quaverAcc = cmp_quaver_getAccuracy();
	var quaverHasData = (quaverAcc > 0 || game.totalPlayed > 0);
	var quaverAccStr = quaverHasData ? cmp_quaver_formatPercent(quaverAcc) : '?';
	var quaverGrade = quaverHasData ? cmp_quaver_getGrade(quaverAcc) : '?';
	var quaverScore = cmp_quaver_getScore();
	var quaverFC = quaverHasData ? cmp_quaver_getRatingFC() : '';

	// DJMAX values (read directly from DJMAX Scoring System.hx)
	var djmaxAcc = cmp_djmax_getAccuracy();
	var djmaxHasData = (djmaxAcc > 0 || game.totalPlayed > 0);
	var djmaxAccStr = djmaxHasData ? cmp_djmax_formatPercent(djmaxAcc) : '?';
	var djmaxGrade = djmaxHasData ? cmp_djmax_getGrade(djmaxAcc) : '?';
	var djmaxScore = cmp_djmax_getScore();
	var djmaxFC = djmaxHasData ? cmp_djmax_getRatingFC() : '';

	// ITG values (read directly from ITG Scoring System.hx)
	var itgAcc = cmp_itg_getAccuracy();
	var itgHasData = (itgAcc > 0 || game.totalPlayed > 0);
	var itgAccStr = itgHasData ? cmp_itg_formatPercent(itgAcc) : '?';
	var itgGrade = itgHasData ? cmp_itg_getGrade(itgAcc) : '?';
	var itgScore = cmp_itg_getScore();
	var itgFC = itgHasData ? cmp_itg_getRatingFC() : '';

	// O2Jam values (read directly from O2Jam Scoring System.hx)
	var o2jamAcc = cmp_o2jam_getAccuracy();
	var o2jamHasData = (o2jamAcc > 0 || game.totalPlayed > 0);
	var o2jamAccStr = o2jamHasData ? cmp_o2jam_formatPercent(o2jamAcc) : '?';
	var o2jamGrade = o2jamHasData ? cmp_o2jam_getGrade(o2jamAcc) : '?';
	var o2jamScore = cmp_o2jam_getScore();
	var o2jamFC = o2jamHasData ? cmp_o2jam_getRatingFC() : '';

	// IIDX values (read directly from IIDX Scoring System.hx)
	var iidxAcc = cmp_iidx_getAccuracy();
	var iidxHasData = (iidxAcc > 0 || game.totalPlayed > 0);
	var iidxAccStr = iidxHasData ? cmp_iidx_formatPercent(iidxAcc) : '?';
	var iidxGrade = iidxHasData ? cmp_iidx_getGrade(iidxAcc) : '?';
	var iidxScore = cmp_iidx_getScore();
	var iidxFC = iidxHasData ? cmp_iidx_getRatingFC() : '';

	// Build display text (aligned columns)
	var lines = '--- Score Comparison ---\n';
	lines = lines + cmp_formatRow('Psych Engine', '' + psychScore, psychAcc, psychGrade, psychFC) + '\n';
	lines = lines + cmp_formatRow('Wife3', '' + w3Score, w3AccStr, w3Grade, w3FC) + '\n';
	lines = lines + cmp_formatRow('Lulus Ruthless', '' + ruthlessScore, ruthlessAccStr, ruthlessGrade, ruthlessFC) + '\n';
	lines = lines + cmp_formatRow('osu!mania', '' + osuScore, osuAccStr, osuGrade, osuFC) + '\n';
	lines = lines + cmp_formatRow('osu!mania V2', '' + osuv2Score, osuv2AccStr, osuv2Grade, osuv2FC) + '\n';
	lines = lines + cmp_formatRow('Quaver', '' + quaverScore, quaverAccStr, quaverGrade, quaverFC) + '\n';
	lines = lines + cmp_formatRow('DJMAX', '' + djmaxScore, djmaxAccStr, djmaxGrade, djmaxFC) + '\n';
	lines = lines + cmp_formatRow('O2Jam', '' + o2jamScore, o2jamAccStr, o2jamGrade, o2jamFC) + '\n';
	lines = lines + cmp_formatRow('StepMania ITG', '' + itgScore, itgAccStr, itgGrade, itgFC) + '\n';
	lines = lines + cmp_formatRow('BeatMania IIDX', 'EX ' + iidxScore, iidxAccStr, iidxGrade, iidxFC) + '\n';

	// Universal timing hit breakdown

	lines = lines + '\n';
	lines = lines + '--- Hit Breakdown ---\n';
	lines = lines + '<=16ms:  ' + cmp_hits16 + '\n';
	lines = lines + '<=22ms:  ' + cmp_hits22 + '\n';
	lines = lines + '<=33ms:  ' + cmp_hits33 + '\n';
	lines = lines + '<=45ms:  ' + cmp_hits45 + '\n';
	lines = lines + '<=75ms:  ' + cmp_hits75 + '\n';
	lines = lines + '<=90ms:  ' + cmp_hits90 + '\n';
	lines = lines + '<=100ms: ' + cmp_hits100 + '\n';
	lines = lines + '<=135ms: ' + cmp_hits135 + '\n';
	lines = lines + '<=180ms: ' + cmp_hits180 + '\n';
	lines = lines + '>180ms:  ' + cmp_hits180plus + '\n';
	lines = lines + 'Misses:  ' + cmp_misses;

	cmp_text.text = lines;

	// Resize background to fit text
	var textHeight = cmp_text.height;
	if (textHeight < 80)
		textHeight = 80;
	cmp_bg.makeGraphic(580, Math.round(textHeight + 8), FlxColor.BLACK);
}

// ========================================
// PSYCH ENGINE CALLBACKS
// ========================================

function onCreate() {
	loadSettings();
}

function onCreatePost() {
	if (!cmp_enabled)
		return;

	// Grab function references from the original scoring scripts (registered via createGlobalCallback/setVar)
	cmp_wife3_getAccuracy = getVar('wife3_getAccuracy');
	cmp_wife3_getScore = getVar('wife3_getScore');
	cmp_wife3_getGrade = getVar('wife3_getGrade');
	cmp_wife3_getRatingFC = getVar('wife3_getRatingFC');
	cmp_wife3_formatPercent = getVar('wife3_formatPercent');

	cmp_osu_getAccuracy = getVar('osu_getAccuracy');
	cmp_osu_getScore = getVar('osu_getScore');
	cmp_osu_getGrade = getVar('osu_getGrade');
	cmp_osu_getRatingFC = getVar('osu_getRatingFC');
	cmp_osu_formatPercent = getVar('osu_formatPercent');

	cmp_itg_getAccuracy = getVar('itg_getAccuracy');
	cmp_itg_getScore = getVar('itg_getScore');
	cmp_itg_getGrade = getVar('itg_getGrade');
	cmp_itg_getRatingFC = getVar('itg_getRatingFC');
	cmp_itg_formatPercent = getVar('itg_formatPercent');

	cmp_ruthless_getAccuracy = getVar('ruthless_getAccuracy');
	cmp_ruthless_getScore = getVar('ruthless_getScore');
	cmp_ruthless_getGrade = getVar('ruthless_getGrade');
	cmp_ruthless_getRatingFC = getVar('ruthless_getRatingFC');
	cmp_ruthless_formatPercent = getVar('ruthless_formatPercent');

	cmp_o2jam_getAccuracy = getVar('o2jam_getAccuracy');
	cmp_o2jam_getScore = getVar('o2jam_getScore');
	cmp_o2jam_getGrade = getVar('o2jam_getGrade');
	cmp_o2jam_getRatingFC = getVar('o2jam_getRatingFC');
	cmp_o2jam_formatPercent = getVar('o2jam_formatPercent');

	cmp_djmax_getAccuracy = getVar('djmax_getAccuracy');
	cmp_djmax_getScore = getVar('djmax_getScore');
	cmp_djmax_getGrade = getVar('djmax_getGrade');
	cmp_djmax_getRatingFC = getVar('djmax_getRatingFC');
	cmp_djmax_formatPercent = getVar('djmax_formatPercent');

	cmp_iidx_getAccuracy = getVar('iidx_getAccuracy');
	cmp_iidx_getScore = getVar('iidx_getScore');
	cmp_iidx_getGrade = getVar('iidx_getGrade');
	cmp_iidx_getRatingFC = getVar('iidx_getRatingFC');
	cmp_iidx_formatPercent = getVar('iidx_formatPercent');

	cmp_osuv2_getAccuracy = getVar('osuv2_getAccuracy');
	cmp_osuv2_getScore = getVar('osuv2_getScore');
	cmp_osuv2_getGrade = getVar('osuv2_getGrade');
	cmp_osuv2_getRatingFC = getVar('osuv2_getRatingFC');
	cmp_osuv2_formatPercent = getVar('osuv2_formatPercent');

	cmp_quaver_getAccuracy = getVar('quaver_getAccuracy');
	cmp_quaver_getScore = getVar('quaver_getScore');
	cmp_quaver_getGrade = getVar('quaver_getGrade');
	cmp_quaver_getRatingFC = getVar('quaver_getRatingFC');
	cmp_quaver_formatPercent = getVar('quaver_formatPercent');

	// Verify callbacks are available
	if (cmp_wife3_getAccuracy == null || cmp_osu_getAccuracy == null || cmp_itg_getAccuracy == null || cmp_ruthless_getAccuracy == null
		|| cmp_o2jam_getAccuracy == null || cmp_djmax_getAccuracy == null || cmp_iidx_getAccuracy == null || cmp_osuv2_getAccuracy == null
		|| cmp_quaver_getAccuracy == null) {
		trace('[ScoreComparison] WARNING: Could not find scoring script callbacks. Make sure Wife3, osu!mania V1/V2, ITG, Ruthless, O2Jam, DJMAX, IIDX, and Quaver scripts are loaded.');
		cmp_enabled = false;
		return;
	}

	cmp_createDisplay();
	cmp_updateDisplay();
}

function goodNoteHit(note:Note) {
	if (!cmp_enabled || note.isSustainNote || !note.mustPress)
		return;

	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;
	var absMs = Math.abs(noteDiff);

	if (absMs <= 16.0)
		cmp_hits16 = cmp_hits16 + 1;
	else if (absMs <= 22.0)
		cmp_hits22 = cmp_hits22 + 1;
	else if (absMs <= 33.0)
		cmp_hits33 = cmp_hits33 + 1;
	else if (absMs <= 45.0)
		cmp_hits45 = cmp_hits45 + 1;
	else if (absMs <= 75.0)
		cmp_hits75 = cmp_hits75 + 1;
	else if (absMs <= 90.0)
		cmp_hits90 = cmp_hits90 + 1;
	else if (absMs <= 100.0)
		cmp_hits100 = cmp_hits100 + 1;
	else if (absMs <= 135.0)
		cmp_hits135 = cmp_hits135 + 1;
	else if (absMs <= 180.0)
		cmp_hits180 = cmp_hits180 + 1;
	else
		cmp_hits180plus = cmp_hits180plus + 1;

	cmp_updateDisplay();
}

function noteMiss(note:Note) {
	if (!cmp_enabled || note.isSustainNote || !note.mustPress)
		return;

	cmp_misses = cmp_misses + 1;
	cmp_updateDisplay();
}

function onUpdateScore(miss:Bool) {
	if (!cmp_enabled)
		return;
	cmp_updateDisplay();
}
