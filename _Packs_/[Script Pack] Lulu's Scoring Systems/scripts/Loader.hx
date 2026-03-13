/*
	>>> Dynamic Script Loader for Lulu's Scoring Systems
		Instead of loading all 10+ scoring system scripts every song,
		this loader reads settings and only loads what's needed:
		- The active scoring system
		- Any systems enabled in Score Comparison (if comparison is on)
		- Rating Popups, Timing Display, Judgement Counter, Score Comparison (if enabled)

		All scoring system scripts live in scripts/scoring/ to prevent
		Psych Engine from auto-loading them. Extra feature scripts
		(Rating Popups, Timing Display, Judgement Counter, Score Comparison)
		live in scripts/extras/. This loader is the only HScript in
		scripts/ and handles dynamic loading via game.initHScript()
		and FunkinLua (for Lua scripts).

	Script by AutisticLulu.
*/

// Maps scoring system name -> script filename (in scripts/scoring/)
var loader_scriptMap = null;

// Maps scoring system name -> comparison toggle setting name
var loader_cmpToggleMap = null;

function onCreate() {
	// Build lookup maps
	loader_scriptMap = new haxe.ds.StringMap();
	loader_scriptMap.set('Wife3', 'Wife3 Scoring System.hx');
	loader_scriptMap.set('OsuMania', 'OsuMania Scoring System.hx');
	loader_scriptMap.set('OsuManiaV2', 'OsuManiaV2 Scoring System.hx');
	loader_scriptMap.set('ITG', 'ITG Scoring System.hx');
	loader_scriptMap.set('Ruthless', 'Ruthless Scoring System.hx');
	loader_scriptMap.set('O2Jam', 'O2Jam Scoring System.hx');
	loader_scriptMap.set('DJMAX', 'DJMAX Scoring System.hx');
	loader_scriptMap.set('IIDX', 'IIDX Scoring System.hx');
	loader_scriptMap.set('Quaver', 'Quaver Scoring System.hx');

	loader_cmpToggleMap = new haxe.ds.StringMap();
	loader_cmpToggleMap.set('Wife3', 'cmp_showWife3');
	loader_cmpToggleMap.set('OsuMania', 'cmp_showOsuMania');
	loader_cmpToggleMap.set('OsuManiaV2', 'cmp_showOsuManiaV2');
	loader_cmpToggleMap.set('ITG', 'cmp_showITG');
	loader_cmpToggleMap.set('Ruthless', 'cmp_showRuthless');
	loader_cmpToggleMap.set('O2Jam', 'cmp_showO2Jam');
	loader_cmpToggleMap.set('DJMAX', 'cmp_showDJMAX');
	loader_cmpToggleMap.set('IIDX', 'cmp_showIIDX');
	loader_cmpToggleMap.set('Quaver', 'cmp_showQuaver');

	// Read settings
	var settingsPath = 'data/settings.json';
	if (!FileSystem.exists(Paths.modFolders(settingsPath)))
		return;

	var activeSystem = getModSetting('scoring_system');
	if (activeSystem == null)
		activeSystem = 'Psych';

	var showComparison = getModSetting('scoring_showComparison');
	if (showComparison == null)
		showComparison = false;

	var showRatingPopups = getModSetting('scoring_ratingPopups');
	if (showRatingPopups == null)
		showRatingPopups = false;

	var showTimingDisplay = getModSetting('scoring_showTimingDisplay');
	if (showTimingDisplay == null)
		showTimingDisplay = true;

	var showJudgementCounter = getModSetting('scoring_showJudgementCounter');
	if (showJudgementCounter == null)
		showJudgementCounter = true;

	// Track which systems to load (avoid duplicates)
	var systemsToLoad = new haxe.ds.StringMap();

	// Always load the active scoring system (Psych has no script)
	if (activeSystem != 'Psych' && loader_scriptMap.exists(activeSystem))
		systemsToLoad.set(activeSystem, true);

	// If Score Comparison is enabled, also load any systems toggled on
	if (showComparison) {
		var allSystems = [
			'Wife3',
			'OsuMania',
			'OsuManiaV2',
			'ITG',
			'Ruthless',
			'O2Jam',
			'DJMAX',
			'IIDX',
			'Quaver'
		];
		for (sys in allSystems) {
			var toggleName = loader_cmpToggleMap.get(sys);
			var toggleValue = getModSetting(toggleName);
			if (toggleValue == true && loader_scriptMap.exists(sys))
				systemsToLoad.set(sys, true);
		}
	}

	// Load scoring system scripts
	for (sys in systemsToLoad.keys()) {
		var scriptFile = loader_scriptMap.get(sys);
		loadScoringSystem(scriptFile);
	}

	// Load extra feature scripts
	if (showComparison)
		loadExtra('Score Comparison.hx');

	if (showRatingPopups && activeSystem != 'Psych')
		loadExtra('Rating Popups.hx');

	if (showTimingDisplay)
		loadExtra('Timing Display.hx');

	if (showJudgementCounter)
		loadExtraLua('Judgement Counter.lua');

	trace('[Loader] Finished loading scripts for system: ' + activeSystem + (showComparison ? ' (with comparison)' : ''));
}

function loadScoringSystem(filename:String) {
	var path = Paths.modFolders('scripts/scoring/' + filename);
	if (FileSystem.exists(path)) {
		game.initHScript(path);
		trace('[Loader] Loaded: ' + filename);
	} else {
		trace('[Loader] WARNING: Script not found: ' + path);
	}
}

function loadExtra(filename:String) {
	var path = Paths.modFolders('scripts/extras/' + filename);
	if (FileSystem.exists(path)) {
		game.initHScript(path);
		trace('[Loader] Loaded extra: ' + filename);
	} else {
		trace('[Loader] WARNING: Extra script not found: ' + path);
	}
}

function loadExtraLua(filename:String) {
	var path = Paths.modFolders('scripts/extras/' + filename);
	if (FileSystem.exists(path)) {
		addHaxeLibrary('FunkinLua', 'psychlua');
		new FunkinLua(path);
		trace('[Loader] Loaded extra (Lua): ' + filename);
	} else {
		trace('[Loader] WARNING: Extra Lua script not found: ' + path);
	}
}
