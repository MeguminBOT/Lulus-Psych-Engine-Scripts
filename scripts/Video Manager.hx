
/*
	>>> Video Manager Script for Psych Engine
		HScript-based video management system that provides direct access to the
		VideoSprite class, bypassing PlayState's built-in startVideo function.

		Unlike PlayState's startVideo function which only supports a single video at a time, 
		this enables multiple videos to coexist simultaneously, with individual control
		over each video's playback state, camera assignment, and lifecycle.

		* Direct access to VideoSprite class methods and properties.
		* Supports creation of multiple independent video sprites simultaneously.
		* Full playback control (play, pause, resume) without interrupting other videos
		* Supports camera and layer settings, allowing videos to be played behind the HUD.
		* Tag-based video sprite identification for easy management just like regular sprites.

		Functions:
			makeVideoSprite: Creates and initializes a video sprite without playing it
			playVideoSprite: Adds the video to the scene and begins playback
			pauseVideoSprite: Pauses video playback
			resumeVideoSprite: Resumes paused video playback
			removeVideoSprite: Removes and destroys a video sprite
			videoSpriteExists: Checks if a video sprite with a given tag exists

		Parameters:
			tag: String - Unique identifier for the video sprite
			path: String - Name of the video file (without extension)
			canSkip: Bool - Whether the video can be skipped (default: true)
			shouldLoop: Bool - Whether the video should loop (default: false)
			camera: String - Camera to attach to: 'camGame', 'camHUD', 'camOther' (default: 'camOther')

		Script by AutisticLulu.

		Usage Example in Lua:
			function onCreate()
				makeVideoSprite('IntroCutscene', 'EntranceCutscene', true, false, 'camOther')
			end

			function onStepHit()
				if curStep == 1 then
					playVideoSprite('IntroCutscene')
				end
			end
*/

import objects.VideoSprite;
import psychlua.LuaUtils;
import haxe.ds.StringMap;

var videoSprites:StringMap<VideoSprite> = new StringMap();

function makeVideoSprite(tag:String, path:String, ?canSkip:Bool = true, ?shouldLoop:Bool = false, ?camera:String = 'other'):Void {
	if (videoSprites.exists(tag)) {
		var oldVideo:VideoSprite = videoSprites.get(tag);
		game.remove(oldVideo);
		oldVideo.destroy();
		videoSprites.remove(tag);
	}
	
	var fileName:String = Paths.video(path);
	var videoSprite:VideoSprite = new VideoSprite(fileName, true, canSkip, shouldLoop);
	
	var cam:FlxCamera = game.camOther;
	if (camera == 'game' || camera == 'camGame') cam = game.camGame;
	else if (camera == 'hud' || camera == 'camHUD') cam = game.camHUD;
	
	videoSprite.cameras = [cam];
	videoSprites.set(tag, videoSprite);
}

function removeVideoSprite(tag:String):Void {
	if (!videoSprites.exists(tag)) return;
	
	var videoSprite:VideoSprite = videoSprites.get(tag);
	videoSprite.pause();
	game.remove(videoSprite);
	videoSprite.destroy();
	videoSprites.remove(tag);
}

function playVideoSprite(tag:String):Void {
	if (!videoSprites.exists(tag)) return;

	var videoSprite:VideoSprite = videoSprites.get(tag);

	if (!game.members.contains(videoSprite)) {
		game.add(videoSprite);
	}

	videoSprite.play();
}

function pauseVideoSprite(tag:String):Void {
	if (!videoSprites.exists(tag)) return;
	videoSprites.get(tag).pause();
}

function resumeVideoSprite(tag:String):Void {
	if (!videoSprites.exists(tag)) return;
	videoSprites.get(tag).resume();
}

function videoSpriteExists(tag:String):Bool {
	return videoSprites.exists(tag);
}

// Add callbacks so they can be called from Lua or HScripts
function onCreate():Void {
	createGlobalCallback('makeVideoSprite', makeVideoSprite);
	createGlobalCallback('playVideoSprite', playVideoSprite);
	createGlobalCallback('removeVideoSprite', removeVideoSprite);
	createGlobalCallback('pauseVideoSprite', pauseVideoSprite);
	createGlobalCallback('resumeVideoSprite', resumeVideoSprite);
	createGlobalCallback('videoSpriteExists', videoSpriteExists);
}

function onPause():Void {
	for (tag in videoSprites.keys()) {
		pauseVideoSprite(tag);
	}
}

function onResume():Void {
	for (tag in videoSprites.keys()) {
		resumeVideoSprite(tag);
	}
}

function onDestroy():Void {
	for (tag in videoSprites.keys()) {
		removeVideoSprite(tag);
	}
	videoSprites.clear();
}
