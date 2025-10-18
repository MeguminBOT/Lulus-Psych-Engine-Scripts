// Example UI script for Wife3 Scoring System

// UI Toggle Settings
var showTimingDisplay:Bool = true; // Timing feedback display (enabled by default)
var showJudgeCounter:Bool = false; // Judge counter display
var showExtraInfo:Bool = false; // Detailed breakdown display

// UI Elements
var wife3ScoreText:FlxText = null;
var wife3DetailText:FlxText = null;
var timingText:FlxText = null;
var judgeCountText:FlxText = null;

// Animation tweens
var scoreTween:FlxTween = null;
var timingTween:FlxTween = null;

// Wife3 function references
var wife3_getAccuracy:Dynamic = null;
var wife3_getScore:Dynamic = null;
var wife3_getGrade:Dynamic = null;
var wife3_formatPercent:Dynamic = null;
var wife3_getJudgeScale:Dynamic = null;
var wife3_getJudgePreset:Dynamic = null;
var wife3_getMarvelousHits:Dynamic = null;
var wife3_getPerfectHits:Dynamic = null;
var wife3_getGreatHits:Dynamic = null;
var wife3_getGoodHits:Dynamic = null;
var wife3_getBadHits:Dynamic = null;
var wife3_getTimingWindow:Dynamic = null;

function onCreate() {
	trace('Wife3 Custom HScript UI initialized');
	createWife3UI();
}

function onCreatePost() {
	new FlxTimer().start(0.1, function(tmr:FlxTimer) {
		// Get references to Wife3 functions
		wife3_getAccuracy = getVar('wife3_getAccuracy');
		wife3_getScore = getVar('wife3_getScore');
		wife3_getGrade = getVar('wife3_getGrade');
		wife3_formatPercent = getVar('wife3_formatPercent');
		wife3_getJudgeScale = getVar('wife3_getJudgeScale');
		wife3_getJudgePreset = getVar('wife3_getJudgePreset');
		wife3_getMarvelousHits = getVar('wife3_getMarvelousHits');
		wife3_getPerfectHits = getVar('wife3_getPerfectHits');
		wife3_getGreatHits = getVar('wife3_getGreatHits');
		wife3_getGoodHits = getVar('wife3_getGoodHits');
		wife3_getBadHits = getVar('wife3_getBadHits');
		wife3_getTimingWindow = getVar('wife3_getTimingWindow');

		// Debug: Check if function references were obtained
		trace('UI Script - Function References:');
		trace('wife3_getMarvelousHits: ' + (wife3_getMarvelousHits != null ? 'OK' : 'NULL'));
		trace('wife3_getPerfectHits: ' + (wife3_getPerfectHits != null ? 'OK' : 'NULL'));
		trace('wife3_getGreatHits: ' + (wife3_getGreatHits != null ? 'OK' : 'NULL'));
		trace('wife3_getGoodHits: ' + (wife3_getGoodHits != null ? 'OK' : 'NULL'));
		trace('wife3_getBadHits: ' + (wife3_getBadHits != null ? 'OK' : 'NULL'));

		positionUIElements();
		updateAllDisplays();

		game.scoreTxt.visible = false; // Hide default score text
	});
}

function createWife3UI() {
	// Main Wife3 score display - styled like Psych Engine's scoreTxt
	wife3ScoreText = new FlxText(0, 0, FlxG.width, '');
	wife3ScoreText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
	wife3ScoreText.scrollFactor.set();
	wife3ScoreText.borderSize = 2;
	wife3ScoreText.cameras = [game.camHUD];

	// Detailed breakdown display - same style as main text (optional)
	if (showExtraInfo) {
		wife3DetailText = new FlxText(0, 0, FlxG.width, '');
		wife3DetailText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
		wife3DetailText.scrollFactor.set();
		wife3DetailText.borderSize = 2;
		wife3DetailText.cameras = [game.camHUD];
	}

	// Timing display (optional)
	if (showTimingDisplay) {
		timingText = new FlxText(0, 0, 200, '');
		timingText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, 'center', 'outline', FlxColor.BLACK);
		timingText.scrollFactor.set();
		timingText.borderSize = 1.5;
		timingText.cameras = [game.camHUD];
		timingText.alpha = 0;
	}

	// Judge count display (optional)
	if (showJudgeCounter) {
		judgeCountText = new FlxText(0, 0, 240, '');
		judgeCountText.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, 'left', 'outline', FlxColor.BLACK);
		judgeCountText.scrollFactor.set();
		judgeCountText.borderSize = 1;
		judgeCountText.cameras = [game.camHUD];
	}
}

function positionUIElements() {
	// Position Wife3 score exactly like Psych Engine's scoreTxt
	wife3ScoreText.y = game.healthBar.y + 40;
	if (showExtraInfo && wife3DetailText != null) {
		wife3DetailText.y = wife3ScoreText.y + 25;
	}

	// Position timing display in the middle of the playfield (only if enabled)
	if (showTimingDisplay && timingText != null && game.playerStrums != null && game.playerStrums.members.length >= 4) {
		var firstStrumX = game.playerStrums.members[0].x;
		var lastStrumX = game.playerStrums.members[3].x;
		var strumWidth = game.playerStrums.members[0].width;
		var totalWidth = (lastStrumX + strumWidth) - firstStrumX;

		// Center the timing text in the middle of the playfield
		timingText.x = firstStrumX + (totalWidth / 2) - (timingText.width / 2);
		timingText.y = FlxG.height / 2; // Always use screen center for Y position
	}

	// Position judge counter to the left of player playfield (only if enabled)
	if (showJudgeCounter && judgeCountText != null && game.playerStrums != null && game.playerStrums.members.length >= 4) {
		var firstStrumX = game.playerStrums.members[0].x;
		var firstStrumY = game.playerStrums.members[0].y;

		judgeCountText.x = firstStrumX - 133; // offset from playfield
		judgeCountText.y = firstStrumY;
	}

	// Add all UI elements to the scene in front of healthbar
	game.add(wife3ScoreText);
	if (showExtraInfo && wife3DetailText != null) {
		game.add(wife3DetailText);
	}
	if (showTimingDisplay && timingText != null) {
		game.add(timingText);
	}
	if (showJudgeCounter && judgeCountText != null) {
		game.add(judgeCountText);
	}
}

function updateAllDisplays() {
	updateMainScore();
	if (showExtraInfo) {
		updateDetailedBreakdown();
	}
	if (showJudgeCounter) {
		updateJudgeCount();
	}
}

function updateMainScore() {
	// Wife3 system provides all the necessary functions, just call them directly
	if (wife3_getAccuracy == null || wife3_getScore == null || wife3_getGrade == null || wife3_formatPercent == null) {
		return;
	}

	var accuracy = wife3_getAccuracy();
	var score = wife3_getScore();
	var grade = wife3_getGrade(accuracy);
	var formattedAcc = wife3_formatPercent(accuracy);

	// Match Psych Engine's score format exactly
	var mainText = 'Score: ' + score + ' | Misses: ' + game.songMisses + ' | Rating: ' + formattedAcc + '% (' + grade + ')';
	wife3ScoreText.text = mainText;
}

function updateDetailedBreakdown() {
	// Only update if detailed info is enabled and text exists
	if (!showExtraInfo)
		return;

	// Get judge preset directly from Wife3 system
	var judgePreset = 'J4'; // Default fallback
	if (wife3_getJudgePreset != null) {
		var judgeValue = wife3_getJudgePreset();

		// Check if this is an exact preset value (whole number)
		var wholeJudge = Math.round(judgeValue);
		var isExactPreset = Math.abs(judgeValue - wholeJudge) < 0.001;

		if (isExactPreset) {
			// Exact preset - show as whole number
			judgePreset = (wholeJudge == 9) ? 'J9 (JUSTICE)' : 'J' + wholeJudge;
		} else {
			// Extrapolated value - show with decimal places
			var formattedValue = Math.round(judgeValue * 100) / 100; // 2 decimal places
			judgePreset = 'J' + formattedValue;
		}
	}

	// Match Psych Engine's detail format
	var detailText = judgePreset + ' | Hits: ' + game.songHits;
	wife3DetailText.text = detailText;
}

function updateJudgeCount() {
	// Only update if judge counter is enabled and text exists
	if (!showJudgeCounter)
		return;

	// Get values directly from Wife3 functions (no need for local variables)
	var judgeText = 'Judgments:\n';
	judgeText += 'Marvelous: ' + (wife3_getMarvelousHits != null ? wife3_getMarvelousHits() : 0) + '\n';
	judgeText += 'Perfect: ' + (wife3_getPerfectHits != null ? wife3_getPerfectHits() : 0) + '\n';
	judgeText += 'Great: ' + (wife3_getGreatHits != null ? wife3_getGreatHits() : 0) + '\n';
	judgeText += 'Good: ' + (wife3_getGoodHits != null ? wife3_getGoodHits() : 0) + '\n';
	judgeText += 'Bad: ' + (wife3_getBadHits != null ? wife3_getBadHits() : 0) + '\n';
	judgeText += 'Miss: ' + game.songMisses;

	judgeCountText.text = judgeText;
}

function showTimingFeedback(offset:Float) {
	// Only show timing feedback if timing display is enabled and text exists
	if (!showTimingDisplay || timingText == null)
		return;

	var absOffset = Math.abs(offset);
	var prefix = offset > 0 ? '+' : '';
	var roundedOffset = Math.round(offset * 10) / 10;
	var timingStr = prefix + roundedOffset + 'ms';

	// Determine color based on timing windows
	var color = FlxColor.WHITE; // Default/Marvelous

	// Check if Wife3 timing window function is available
	if (wife3_getTimingWindow != null) {
		if (absOffset > wife3_getTimingWindow('marvelous'))
			color = FlxColor.YELLOW; // Perfect
		if (absOffset > wife3_getTimingWindow('perfect'))
			color = FlxColor.GREEN; // Great
		if (absOffset > wife3_getTimingWindow('great'))
			color = FlxColor.CYAN; // Good
		if (absOffset > wife3_getTimingWindow('good'))
			color = FlxColor.MAGENTA; // Bad
		if (absOffset > wife3_getTimingWindow('bad'))
			color = FlxColor.RED; // Way off
	}

	timingText.text = timingStr;
	timingText.color = color;

	// Cancel existing tween
	if (timingTween != null) {
		timingTween.cancel();
	}

	// Animate in
	timingText.alpha = 0;
	// Always start from screen center
	timingText.y = FlxG.height / 2;
	timingText.scale.set(1.05, 1.05);

	timingTween = FlxTween.tween(timingText, {
		alpha: 1,
		y: (FlxG.height / 2) - 15,
		'scale.x': 1,
		'scale.y': 1
	}, 0.1, {
		onComplete: function(twn:FlxTween) {
			// Fade out
			timingTween = FlxTween.tween(timingText, {
				alpha: 0,
				y: (FlxG.height / 2) - 25
			}, 0.3, {
				startDelay: 0.3,
				onComplete: function(twn:FlxTween) {
					// Reset to screen center when animation completes
					timingText.y = FlxG.height / 2;
					timingTween = null;
				}
			});
		}
	});
}

function performScoreBop() {
	if (scoreTween != null) {
		scoreTween.cancel();
	}

	wife3ScoreText.scale.set(1.05, 1.05);
	scoreTween = FlxTween.tween(wife3ScoreText.scale, {x: 1, y: 1}, 0.2, {
		ease: FlxEase.elasticOut,
		onComplete: function(twn:FlxTween) {
			scoreTween = null;
		}
	});
}

function goodNoteHit(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;

	// Calculate timing offset for display only
	var noteDiff = note.strumTime - Conductor.songPosition;
	var playbackRate = game.playbackRate != null ? game.playbackRate : 1.0;
	noteDiff = noteDiff / playbackRate;

	// Show timing feedback only if enabled
	if (showTimingDisplay) {
		showTimingFeedback(noteDiff);
	}

	// Update displays (Wife3 system already handles scoring)
	updateAllDisplays();
	performScoreBop();
}

function noteMiss(note:Note) {
	if (note.isSustainNote || !note.mustPress)
		return;

	// Wife3 system already handles miss scoring, just update displays
	updateAllDisplays();
}

function onRecalculateRating() {
	updateAllDisplays();
}

function onDestroy() {
	// Clean up tweens
	if (scoreTween != null)
		scoreTween.cancel();
	if (timingTween != null)
		timingTween.cancel();
}
