/*
	>>> Dynamic Script Loader for Lulu's Scoring Systems
		Instead of loading all 10+ scoring system scripts every song,
		this loader reads settings and only loads what's needed:
		- The active scoring system
		- Any systems enabled in Score Comparison (if comparison is on)
		- Rating Popups, Timing Display, Score Comparison (if enabled)
		- Judgement Counter is a Lua script and loads normally from scripts/

		All scoring/feature scripts live in scripts/scoring/ to prevent
		Psych Engine from auto-loading them. This loader is the only
		HScript in scripts/ and handles dynamic loading via game.initHScript().

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

	// Track which systems to load (avoid duplicates)
	var systemsToLoad = new haxe.ds.StringMap();

	// Always load the active scoring system (Psych has no script)
	if (activeSystem != 'Psych' && loader_scriptMap.exists(activeSystem))
		systemsToLoad.set(activeSystem, true);

	// If Score Comparison is enabled, also load any systems toggled on
	if (showComparison) {
		var allSystems = ['Wife3', 'OsuMania', 'OsuManiaV2', 'ITG', 'Ruthless', 'O2Jam', 'DJMAX', 'IIDX', 'Quaver'];
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
		loadScript(scriptFile);
	}

	// Load feature scripts
	if (showComparison)
		loadScript('Score Comparison.hx');

	if (showRatingPopups && activeSystem != 'Psych')
		loadScript('Rating Popups.hx');

	if (showTimingDisplay)
		loadScript('Timing Display.hx');

	trace('[Loader] Finished loading scripts for system: ' + activeSystem + (showComparison ? ' (with comparison)' : ''));
}

function loadScript(filename:String) {
	var path = Paths.modFolders('scripts/scoring/' + filename);
	if (FileSystem.exists(path)) {
		game.initHScript(path);
		trace('[Loader] Loaded: ' + filename);
	} else {
		trace('[Loader] WARNING: Script not found: ' + path);
	}
}
