/*
	>>> Replay System Alpha
	Testing approach using Controls.pressed/justPressed/justReleased
	- Records actual control states every frame
	- No input blocking (for now)
*/

import tjson.TJSON;
import backend.MusicBeatState;
import states.LoadingState;
import flixel.group.FlxGroup.FlxTypedGroup;
import backend.Song;
import backend.Difficulty;
import backend.Mods;
import backend.StageData;
import backend.WeekData;
import Reflect;

// ========================================
// CONFIGURATION
// ========================================

var replay_autoRecord:Bool = true;
var replay_autoSaveReplays:Bool = true;
var replay_saveFolder:String = 'replays/';
var replay_viewerSongName:String = 'replay-viewer';
var replay_pendingDataFile:String = 'mods/replays/.pending-replay.json';
var replay_debug:Bool = true;

// ========================================
// RECORDING STATE
// ========================================

var isRecording:Bool = false;
var replayData:Dynamic = null;
var recordingStartTime:Float = 0;
var songCompleted:Bool = false; // Track if song was completed normally

// Frame-by-frame recording of control states
var frameRecordings:Array<Dynamic> = [];

// ========================================
// PLAYBACK STATE
// ========================================

var isPlayingReplay:Bool = false;
var currentReplay:Dynamic = null;
var playbackIndex:Int = 0;
var playbackStartTime:Float = 0;

// Current frame's control states to simulate
var simulatedControls:Dynamic = {
    note_left: false,
    note_down: false,
    note_up: false,
    note_right: false
};

// Previous frame states for detecting transitions
var prevControls:Dynamic = {
    note_left: false,
    note_down: false,
    note_up: false,
    note_right: false
};

// ========================================
// UI STATE
// ========================================

var replayTxt:FlxText = null;
var replaySine:Float = 0;
var replayMenu:FlxTypedGroup = null;
var replayMenuActive:Bool = false;
var replayMenuSelection:Int = 0;
var replayMenuItems:Array<String> = [];
var replayMenuTexts:Array<Dynamic> = [];
var replayMenuTitle:FlxText = null;
var replayMenuInstructions:FlxText = null;

// ========================================
// TEMP STATE FOR TRANSITIONS
// ========================================

var pendingReplayFilename:String = null;
var pendingReplayModDirectory:String = null;
var previousModDirectory:String = null;
var modDirectoryOverrideActive:Bool = false;

// ========================================
// DEBUG HELPERS
// ========================================

function debug(msg:String) {
    if (!replay_debug) return;
    trace('[Replay System v2] ' + msg);
}

// ========================================
// INITIALIZATION
// ========================================

function onCreate() {
    debug('Initializing...');
    debug('Mods.currentModDirectory at onCreate: ' + Mods.currentModDirectory);
    
    registerCallbacks();
    
    var pendingFromFile = loadPendingReplaySelection();
    if (pendingFromFile != null) {
        pendingReplayFilename = pendingFromFile.filename;
        pendingReplayModDirectory = pendingFromFile.modDirectory;
        clearPendingReplaySelection();
        debug('Loaded pending replay from file: ' + pendingReplayFilename);
        
        var replay = loadReplay(pendingReplayFilename);
        if (replay != null) {
            debug('Replay loaded: ' + pendingReplayFilename);
            
            // Apply mod directory BEFORE loading replay (so file paths resolve correctly)
            if (pendingReplayModDirectory != null && pendingReplayModDirectory.length > 0) {
                debug('Applying mod directory for replay: ' + pendingReplayModDirectory);
                if (previousModDirectory == null) {
                    previousModDirectory = Mods.currentModDirectory;
                }
                modDirectoryOverrideActive = true;
                Mods.currentModDirectory = pendingReplayModDirectory;
            }
            
            // Set flag to load after song creation
            setVar('loadReplayAfterCreate', replay);
            pendingReplayFilename = null;
            return;
        }
    }
    
    var currentSong = Paths.formatToSongPath(PlayState.SONG.song);
    if (currentSong == replay_viewerSongName) {
        debug('Detected replay viewer song, opening menu...');
        new FlxTimer().start(0.1, function(tmr:FlxTimer) {
            openReplayViewerSubstate();
        });
    }
}

function registerCallbacks() {
    setVar('replaySystem_getReplayList', getReplayList);
    setVar('replaySystem_loadReplay', loadReplay);
    setVar('replaySystem_saveReplay', saveReplay);
    setVar('replaySystem_startPlayback', startPlayback);
    setVar('replaySystem_stopPlayback', stopPlayback);
}

function onCreatePost() {
    var replayToLoad = getVar('loadReplayAfterCreate');
    if (replayToLoad != null) {
        setVar('loadReplayAfterCreate', null);
        debug('Starting replay playback...');
        new FlxTimer().start(0.1, function(tmr:FlxTimer) {
            startPlayback(replayToLoad);
        });
        return;
    }

    var currentSong = Paths.formatToSongPath(PlayState.SONG.song);
    if (currentSong == replay_viewerSongName) {
        debug('Replay viewer song - skipping auto-record');
        return;
    }

    if (replay_autoRecord && !isPlayingReplay) {
        debug('Auto-starting recording...');
        new FlxTimer().start(0.1, function(tmr:FlxTimer) {
            startRecording();
        });
    }
}

// ========================================
// RECORDING FUNCTIONS
// ========================================

function startRecording() {
    isRecording = true;
    recordingStartTime = Conductor.songPosition;
    frameRecordings = [];
    songCompleted = false;
    
    var diffName = game.storyDifficultyText;
    var timestamp = Std.int(FlxG.game.ticks / 1000);
    
    replayData = {
        version: 2,
        song: PlayState.SONG.song,
        diff: diffName,
        timestamp: timestamp,
        modDirectory: (Mods.currentModDirectory != null ? Mods.currentModDirectory : ''),
        frames: [],
        result: {}
    };
    
    debug('Recording started: ' + PlayState.SONG.song + ' (' + diffName + ')');
}

function stopRecording() {
    if (!isRecording) return;
    
    isRecording = false;
    replayData.frames = frameRecordings;
    
    replayData.result = {
        score: game.songScore,
        misses: game.songMisses,
        hits: game.songHits,
        acc: game.ratingPercent * 100,
        rating: game.ratingName
    };
    
    debug('Recording stopped. Frames: ' + frameRecordings.length);
    debug('Score: ' + replayData.result.score + ' | Acc: ' + replayData.result.acc + '%');
    
    if (replay_autoSaveReplays && isValidScore()) {
        saveReplay(replayData);
    } else if (!isValidScore()) {
        debug('Score not valid (practice/botplay/charting mode) - replay not saved');
    }
}

function recordFrame() {
    if (!isRecording || game == null) return;
    
    var currentTime = Conductor.songPosition;
    
    // Record control states
    var controls = game.controls;
    if (controls == null) return;
    
    var time = Math.floor(currentTime);
    
    var frame = {
        t: time,
        l: controls.NOTE_LEFT,
        d: controls.NOTE_DOWN,
        u: controls.NOTE_UP,
        r: controls.NOTE_RIGHT
    };
    
    frameRecordings.push(frame);
}

// ========================================
// PLAYBACK FUNCTIONS
// ========================================

function startPlayback(replay:Dynamic) {
    if (replay == null || replay.frames == null) {
        debug('Invalid replay data');
        return;
    }
    
    currentReplay = replay;
    isPlayingReplay = true;
    playbackIndex = 0;
    playbackStartTime = Conductor.songPosition;
    replaySine = 0;
    
    // Reset control states
    simulatedControls = {
        note_left: false,
        note_down: false,
        note_up: false,
        note_right: false
    };
    prevControls = {
        note_left: false,
        note_down: false,
        note_up: false,
        note_right: false
    };
    
    // Create replay indicator (same position as botplay text)
    var healthBar = game.healthBar;
    var yPos = ClientPrefs.data.downScroll ? healthBar.y + 70 : healthBar.y - 90;
    
    replayTxt = new FlxText(400, yPos, FlxG.width - 800, 'REPLAY', 32);
    replayTxt.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
    replayTxt.borderSize = 1.25;
    replayTxt.scrollFactor.set();
    replayTxt.cameras = [game.camHUD];
    game.add(replayTxt);
    
    debug('Playback started with ' + currentReplay.frames.length + ' frames');
}

function stopPlayback() {
    isPlayingReplay = false;
    currentReplay = null;
    playbackIndex = 0;
    
    if (replayTxt != null) {
        game.remove(replayTxt);
        replayTxt.destroy();
        replayTxt = null;
    }
    
    modDirectoryOverrideActive = false;
    pendingReplayModDirectory = null;
    debug('Playback stopped');
}

function updatePlayback() {
    if (!isPlayingReplay || currentReplay == null || game == null) return;
    
    var currentTime = Conductor.songPosition;
    var frames = currentReplay.frames;
    
    // Process frames up to current time
    while (playbackIndex < frames.length) {
        var frame = frames[playbackIndex];
        var frameTime = Std.parseFloat(Std.string(frame.t));
        
        if (frameTime > currentTime) break;
        
        // Update simulated control states
        prevControls.note_left = simulatedControls.note_left;
        prevControls.note_down = simulatedControls.note_down;
        prevControls.note_up = simulatedControls.note_up;
        prevControls.note_right = simulatedControls.note_right;
        
        simulatedControls.note_left = frame.l == true;
        simulatedControls.note_down = frame.d == true;
        simulatedControls.note_up = frame.u == true;
        simulatedControls.note_right = frame.r == true;
        
        // Trigger actions based on state changes
        checkAndTriggerActions();
        
        playbackIndex = playbackIndex + 1;
    }
    
    // Check for sustain notes while keys are held
    var anyHeld = simulatedControls.note_left || simulatedControls.note_down || 
                   simulatedControls.note_up || simulatedControls.note_right;
    
    if (anyHeld) {
        checkSustainNotes();
    }
}

function checkAndTriggerActions() {
    // Check for press events (false -> true)
    if (!prevControls.note_left && simulatedControls.note_left) triggerPress(0);
    if (!prevControls.note_down && simulatedControls.note_down) triggerPress(1);
    if (!prevControls.note_up && simulatedControls.note_up) triggerPress(2);
    if (!prevControls.note_right && simulatedControls.note_right) triggerPress(3);
    
    // Check for release events (true -> false)
    if (prevControls.note_left && !simulatedControls.note_left) triggerRelease(0);
    if (prevControls.note_down && !simulatedControls.note_down) triggerRelease(1);
    if (prevControls.note_up && !simulatedControls.note_up) triggerRelease(2);
    if (prevControls.note_right && !simulatedControls.note_right) triggerRelease(3);
}

function checkSustainNotes() {
    if (game == null || game.notes == null) return;
    
    var members = game.notes.members;
    if (members == null) return;
    
    var currentTime = Conductor.songPosition;
    
    // Check each lane if key is held
    for (lane in 0...4) {
        var isHeld = getControlStateForLane(lane);
        if (!isHeld) continue;
        
        var sustainCount = 0;
        var hitCount = 0;
        
        // Find sustain notes that can be hit in this lane
        for (note in members) {
            if (note == null) continue;
            if (!note.mustPress) continue;
            if (note.noteData != lane) continue;
            if (!note.isSustainNote) continue;
            
            sustainCount = sustainCount + 1;
            
            if (note.wasGoodHit) continue;
            if (note.tooLate) continue;
            if (!note.canBeHit) continue;
            if (note.blockHit) continue;
            
            // Check guitar hero sustains mode
            if (game.guitarHeroSustains) {
                if (note.parent == null) continue;
                if (!note.parent.wasGoodHit) continue;
            }
            
            // Hit the sustain note
            game.goodNoteHit(note);
            hitCount = hitCount + 1;
        }
    }
}

function getControlStateForLane(lane:Int):Bool {
    switch (lane) {
        case 0: return simulatedControls.note_left;
        case 1: return simulatedControls.note_down;
        case 2: return simulatedControls.note_up;
        case 3: return simulatedControls.note_right;
    }
    return false;
}

function triggerPress(lane:Int) {
    if (game == null) return;
    
    // Animate strum
    if (game.playerStrums != null && game.playerStrums.members != null) {
        var strums = game.playerStrums.members;
        if (lane >= 0 && lane < strums.length) {
            var strum = strums[lane];
            if (strum != null) {
                strum.playAnim('confirm', true);
                strum.resetAnim = 0;
            }
        }
    }
    
    // Find and hit note
    var note = findNoteForLane(lane);
    if (note != null) {
        game.goodNoteHit(note);
    }
}

function triggerRelease(lane:Int) {
    if (game == null) return;
    
    // Animate strum
    if (game.playerStrums != null && game.playerStrums.members != null) {
        var strums = game.playerStrums.members;
        if (lane >= 0 && lane < strums.length) {
            var strum = strums[lane];
            if (strum != null) {
                strum.playAnim('static', true);
                strum.resetAnim = 0;
            }
        }
    }
}

function findNoteForLane(lane:Int):Dynamic {
    if (game == null || game.notes == null) return null;
    
    var members = game.notes.members;
    if (members == null) return null;
    
    var currentTime = Conductor.songPosition;
    var bestNote:Dynamic = null;
    var bestTimeDiff:Float = 999999;
    
    // First pass: Look for non-sustain notes (parent/head notes)
    for (note in members) {
        if (note == null) continue;
        if (!note.mustPress) continue;
        if (note.noteData != lane) continue;
        if (note.wasGoodHit) continue;
        if (note.tooLate) continue;
        if (note.isSustainNote) continue; // Skip sustains in first pass
        
        var timeDiff = Math.abs(note.strumTime - currentTime);
        if (timeDiff < 150 && timeDiff < bestTimeDiff) {
            bestNote = note;
            bestTimeDiff = timeDiff;
        }
    }
    
    // If we found a parent note, return it
    if (bestNote != null) return bestNote;
    
    // Second pass: If no parent found, look for sustain notes
    bestTimeDiff = 999999;
    for (note in members) {
        if (note == null) continue;
        if (!note.mustPress) continue;
        if (note.noteData != lane) continue;
        if (note.wasGoodHit) continue;
        if (note.tooLate) continue;
        if (!note.isSustainNote) continue; // Only sustains in second pass
        
        var timeDiff = Math.abs(note.strumTime - currentTime);
        if (timeDiff < 150 && timeDiff < bestTimeDiff) {
            bestNote = note;
            bestTimeDiff = timeDiff;
        }
    }
    
    return bestNote;
}

// ========================================
// UPDATE LOOP
// ========================================

function onUpdate(elapsed:Float) {
    // Recording
    if (isRecording) {
        recordFrame();
    }
    
    // Playback
    if (isPlayingReplay) {
        updatePlayback();
        
        // Update replay text fade (same as botplay)
        if (replayTxt != null && replayTxt.visible) {
            replaySine = replaySine + (180 * elapsed);
            replayTxt.alpha = 1 - Math.sin((Math.PI * replaySine) / 180);
        }
    }
}

// ========================================
// FILE I/O
// ========================================

function saveReplay(replay:Dynamic):String {
    var folderPath = Paths.mods(replay_saveFolder);
    if (!FileSystem.exists(folderPath)) {
        FileSystem.createDirectory(folderPath);
    }
    
    var filename = replay.song + '-' + replay.diff + '-' + replay.timestamp + '.json';
    var fullPath = folderPath + filename;
    
    try {
        File.saveContent(fullPath, TJSON.encode(replay, 'fancy'));
        debug('Replay saved: ' + fullPath);
        return filename;
    } catch (e:Dynamic) {
        debug('Failed to save replay: ' + e);
        return null;
    }
}

function loadReplay(filename:String):Dynamic {
    var fullPath = Paths.mods(replay_saveFolder + filename);
    
    if (!FileSystem.exists(fullPath)) {
        debug('Replay not found: ' + fullPath);
        return null;
    }
    
    try {
        var content = File.getContent(fullPath);
        var replay = TJSON.parse(content);
        debug('Replay loaded: ' + filename);
        return replay;
    } catch (e:Dynamic) {
        debug('Failed to load replay: ' + e);
        return null;
    }
}

function getReplayList():Array<String> {
    var folderPath = Paths.mods(replay_saveFolder);
    
    if (!FileSystem.exists(folderPath)) {
        return [];
    }
    
    var files = FileSystem.readDirectory(folderPath);
    var replays = [];
    for (f in files) {
        if (StringTools.endsWith(f, '.json') && !StringTools.startsWith(f, '.')) {
            replays.push(f);
        }
    }
    
    debug('Found ' + replays.length + ' replays');
    return replays;
}

function loadPendingReplaySelection():Dynamic {
    var path = replay_pendingDataFile;
    if (!FileSystem.exists(path)) return null;
    
    try {
        var content = File.getContent(path);
        if (content == null || StringTools.trim(content).length == 0) return null;
        return TJSON.parse(content);
    } catch (e:Dynamic) {
        return null;
    }
}

function storePendingReplaySelection(filename:String, modDirectory:String) {
    var folderPath = 'mods/' + replay_saveFolder;
    if (!FileSystem.exists(folderPath)) {
        FileSystem.createDirectory(folderPath);
    }
    
    var path = replay_pendingDataFile;
    var data = {
        filename: filename,
        modDirectory: modDirectory
    };
    
    try {
        File.saveContent(path, TJSON.encode(data));
        debug('Stored pending replay handoff');
    } catch (e:Dynamic) {
        debug('Failed to store pending replay: ' + e);
    }
}

function clearPendingReplaySelection() {
    var path = replay_pendingDataFile;
    if (FileSystem.exists(path)) {
        try {
            FileSystem.deleteFile(path);
        } catch (e:Dynamic) {}
    }
}

// ========================================
// REPLAY VIEWER MENU
// ========================================

function openReplayViewerSubstate() {
    debug('Opening replay viewer as CustomSubstate');
    CustomSubstate.openCustomSubstate('ReplayViewer', true);
}

function onCustomSubstateCreate(name:String) {
    trace('[Replay] onCustomSubstateCreate called with name: ' + name);
    if (name != 'ReplayViewer') return;
    
    trace('[Replay] Creating replay viewer substate');
    debug('Creating replay viewer substate');
    
    if (game.vocals != null) game.vocals.pause();
    if (game.inst != null) game.inst.pause();
    if (FlxG.sound.music != null) FlxG.sound.music.pause();
    
    game.camHUD.visible = false;
    if (game.boyfriend != null) game.boyfriend.visible = false;
    if (game.dad != null) game.dad.visible = false;
    if (game.gf != null) game.gf.visible = false;
    
    replayMenuItems = getReplayList();
    trace('[Replay] Found ' + replayMenuItems.length + ' replays');
    
    if (replayMenuItems.length == 0) {
        showNoReplaysMessage();
        return;
    }
    
    createReplayViewerMenu();
}

function createReplayViewerMenu() {
    replayMenu = new FlxTypedGroup();
    customSubstate.add(replayMenu);
    
    replayMenuTitle = new FlxText(0, 50, FlxG.width, '=== REPLAY VIEWER (v2) ===', 32);
    replayMenuTitle.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
    replayMenuTitle.borderSize = 2;
    replayMenuTitle.scrollFactor.set();
    customSubstate.add(replayMenuTitle);
    
    replayMenuInstructions = new FlxText(0, FlxG.height - 100, FlxG.width, '[UP/DOWN] Navigate | [ENTER] Play | [ESC] Exit', 20);
    replayMenuInstructions.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
    replayMenuInstructions.borderSize = 2;
    replayMenuInstructions.scrollFactor.set();
    customSubstate.add(replayMenuInstructions);
    
    var startY = 150;
    var itemHeight = 80;
    
    for (i in 0...replayMenuItems.length) {
        var itemName = replayMenuItems[i];
        var replayInfo = getReplayInfo(loadReplay(itemName));
        
        var itemText = new FlxText(100, startY + (i * itemHeight), FlxG.width - 200, itemName, 20);
        itemText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, 'left', 'outline', FlxColor.BLACK);
        itemText.borderSize = 2;
        itemText.scrollFactor.set();
        customSubstate.add(itemText);
        replayMenuTexts.push(itemText);
        
        var infoText = new FlxText(100, startY + (i * itemHeight) + 30, FlxG.width - 200, replayInfo, 16);
        infoText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.GRAY, 'left', 'outline', FlxColor.BLACK);
        infoText.borderSize = 1;
        infoText.scrollFactor.set();
        customSubstate.add(infoText);
        replayMenuTexts.push(infoText);
    }
    
    replayMenuActive = true;
    replayMenuSelection = 0;
    updateMenuSelection();
    
    debug('Replay menu created in substate');
}

function showNoReplaysMessage() {
    var noReplaysText = new FlxText(0, FlxG.height / 2 - 50, FlxG.width, 'No replays found!\n\nPlay songs to create replays.\n\nPress [ESC] to exit.', 24);
    noReplaysText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
    noReplaysText.borderSize = 2;
    noReplaysText.scrollFactor.set();
    customSubstate.add(noReplaysText);
    
    replayMenuActive = true;
}

function onCustomSubstateUpdate(name:String, elapsed:Float) {
    if (name != 'ReplayViewer') return;

    var controls = game.controls;
    if (controls.UI_UP_P) {
        trace('[Replay] UP pressed');
        replayMenuSelection = replayMenuSelection - 1;
        if (replayMenuSelection < 0) replayMenuSelection = replayMenuItems.length - 1;
        updateMenuSelection();
    }
    if (controls.UI_DOWN_P) {
        trace('[Replay] DOWN pressed');
        replayMenuSelection = replayMenuSelection + 1;
        if (replayMenuSelection >= replayMenuItems.length) replayMenuSelection = 0;
        updateMenuSelection();
    }
    if (controls.ACCEPT) {
        trace('[Replay] ACCEPT pressed');
        selectReplay();
    }
    if (controls.BACK) {
        trace('[Replay] BACK pressed');
        exitReplayMenu();
    }
}

function updateMenuSelection() {
    if (replayMenuTexts.length == 0) return;
    
    for (i in 0...Std.int(replayMenuTexts.length / 2)) {
        var idx = i * 2;
        if (i == replayMenuSelection) {
            replayMenuTexts[idx].color = FlxColor.YELLOW;
        } else {
            replayMenuTexts[idx].color = FlxColor.WHITE;
        }
    }
    
    FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
}

function selectReplay() {
    if (replayMenuSelection < 0 || replayMenuSelection >= replayMenuItems.length) return;
    
    var filename = replayMenuItems[replayMenuSelection];
    var replay = loadReplay(filename);
    
    if (replay == null) {
        debug('Failed to load selected replay');
        return;
    }
    
    debug('Selected replay: ' + filename);
    FlxG.sound.play(Paths.sound('confirmMenu'));
    
    pendingReplayFilename = filename;
    
    var songPath = Paths.formatToSongPath(replay.song);
    var diffName = replay.diff;
    var chartId = getChartIdForReplay(songPath, diffName);
    var difficultyIndex = getDifficultyFromString(diffName);
    
    var targetMod = getReplayModDirectory(replay, songPath, chartId);
    if (previousModDirectory == null) {
        previousModDirectory = Mods.currentModDirectory;
    }
    pendingReplayModDirectory = targetMod;
    modDirectoryOverrideActive = true;
    storePendingReplaySelection(filename, targetMod);
    
    debug('Target mod directory: ' + targetMod);
    debug('Previous mod directory: ' + previousModDirectory);
    
    // Set mod directory (even if null/empty, like FreeplayState does)
    Mods.currentModDirectory = (targetMod != null && targetMod.length > 0) ? targetMod : '';
    debug('Set Mods.currentModDirectory to: "' + Mods.currentModDirectory + '"');
    
    PlayState.SONG = Song.loadFromJson(chartId, songPath);
    PlayState.isStoryMode = false;
    PlayState.storyWeek = 0;
    PlayState.storyPlaylist = [];
    PlayState.storyDifficulty = difficultyIndex;
    
    // Set StageData.forceNextDirectory to the mod directory
    // This is what LoadingState.loadNextDirectory() will/should use
    StageData.forceNextDirectory = Mods.currentModDirectory;
    debug('StageData.forceNextDirectory set to: "' + StageData.forceNextDirectory + '"');
    
    debug('About to switch to PlayState via LoadingState');
    debug('Current Mods.currentModDirectory: "' + Mods.currentModDirectory + '"');
    
    LoadingState.loadAndSwitchState(new PlayState());
}

function exitReplayMenu() {
    FlxG.sound.play(Paths.sound('cancelMenu'));
    
    replayMenuActive = false;
    
    // Close the CustomSubstate
    CustomSubstate.closeCustomSubstate();
    
    // Clean up arrays
    replayMenuTexts = [];
    replayMenuItems = [];
    
    game.camHUD.visible = true;
    if (game.boyfriend != null) game.boyfriend.visible = true;
    if (game.dad != null) game.dad.visible = true;
    if (game.gf != null) game.gf.visible = true;

}

function onCustomSubstateDestroy(name:String) {
    if (name != 'ReplayViewer') return;
    
    debug('Replay viewer substate destroyed');

    replayMenu = null;
    replayMenuTitle = null;
    replayMenuInstructions = null;
    replayMenuTexts = [];
    replayMenuActive = false;
}

// ========================================
// HELPER FUNCTIONS
// ========================================

function isValidScore():Bool {
    // Check if this is a valid score (not practice, botplay, or charting mode)
    // Matches PlayState's validation for week completion saving
    
    if (!songCompleted) {
        debug('Song not completed - score not valid');
        return false;
    }
    
    var practiceMode = ClientPrefs.getGameplaySetting('practice');
    var botplay = ClientPrefs.getGameplaySetting('botplay');
    var chartingMode = PlayState.chartingMode;
    
    if (practiceMode || botplay || chartingMode) {
        debug('Score not valid (practice: ' + practiceMode + ', botplay: ' + botplay + ', charting: ' + chartingMode + ')');
        return false;
    }
    
    return true;
}

function getReplayInfo(replay:Dynamic):String {
    if (replay == null) return 'Invalid replay';
    var result = replay.result;
    if (result == null) return 'No result data';
    return 'Score: ' + result.score + ' | Acc: ' + Std.int(result.acc) + '% | Rating: ' + result.rating;
}

function getDifficultyFromString(diff:String):Int {
    var formatted = Paths.formatToSongPath(diff);
    var diffList = Difficulty.list;
    
    for (i in 0...diffList.length) {
        if (Paths.formatToSongPath(diffList[i]) == formatted) {
            return i;
        }
    }
    
    return 1;
}

function getChartIdForReplay(songPath:String, diffName:String):String {
    return songPath + getDifficultySuffix(diffName);
}

function getDifficultySuffix(diff:String):String {
    var formatted = Paths.formatToSongPath(diff);
    return (formatted != 'normal') ? '-' + formatted : '';
}

function getReplayModDirectory(replay:Dynamic, songPath:String, chartId:String):String {
    if (Reflect.hasField(replay, 'modDirectory') && replay.modDirectory != null) {
        var modDir:String = Std.string(replay.modDirectory);
        if (modDir.length > 0 && chartExistsInMod(modDir, songPath, chartId)) {
            return modDir;
        }
    }
    
    return detectModDirectory(songPath, chartId);
}

function chartExistsInMod(modName:String, songPath:String, chartId:String):Bool {
    var path = 'mods/' + modName + '/data/' + songPath + '/' + chartId + '.json';
    return FileSystem.exists(path);
}

function detectModDirectory(songPath:String, chartId:String):String {
    // Check current mod directory first
    if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 && chartExistsInMod(Mods.currentModDirectory, songPath, chartId)) {
        return Mods.currentModDirectory;
    }
    
    // Check global mods
    var globalMods = Mods.getGlobalMods();
    for (mod in globalMods) {
        if (chartExistsInMod(mod, songPath, chartId)) {
            return mod;
        }
    }
    
    // Check enabled mods
    var modList = Mods.parseList().enabled;
    for (mod in modList) {
        if (chartExistsInMod(mod, songPath, chartId)) {
            return mod;
        }
    }
    
    // Check shared mods folder
    var sharedPath = Paths.mods('data/' + songPath + '/' + chartId + '.json');
    if (FileSystem.exists(sharedPath)) {
        return '';
    }
    
    debug('detectModDirectory - No mod directory found for ' + songPath + '/' + chartId);
    return null;
}

// ========================================
// LIFECYCLE HOOKS
// ========================================

function onStartCountdown() {
    if (replayMenuActive) return Function_Stop;
    if (isPlayingReplay) return Function_Stop;
    return Function_Continue;
}

function onEndSong() {
    if (replayMenuActive) {
        return Function_Stop;
    }
    
    if (isRecording) {
        songCompleted = true; // Mark song as completed
        stopRecording();
    }
    return Function_Continue;
}

function onPause() {
    if (replayMenuActive) {
        return Function_Stop;
    }
    return Function_Continue;
}

function onResume() {
    if (replayMenuActive) {
        return Function_Stop;
    }
    return Function_Continue;
}

function onDestroy() {
    if (isRecording) {
        debug('Song exited early - stopping recording without saving');
        isRecording = false;
    }
    
    if (isPlayingReplay) {
        stopPlayback();
    }
    
    if (replayTxt != null) {
        replayTxt.destroy();
        replayTxt = null;
    }
    
    // Restore previous mod directory if it was changed
    if (modDirectoryOverrideActive) {
        debug('Mod directory override still active; deferring restore');
    } else if (previousModDirectory != null) {
        debug('Restoring mod directory to: "' + previousModDirectory + '"');
        Mods.currentModDirectory = previousModDirectory;
        previousModDirectory = null;
    }
    
    debug('Cleanup complete');
}
