--[[
	>>> Video late start fix for Psych Engine 1.0.4
		Drop-and-forget. Does ONE thing: pre-warms the VLC decoder pipeline at create
		with a tiny dummy video, so the first real game.startVideo has no startup hitch.

		How to use:
			Add the script to mods/scripts/ or your mods/yourMod/scripts/.
			Add _VideoDummy.mp4 (a tiny blank video) to mods/videos/ or mods/yourMod/videos/.

		Warning:
			This script runs onCreate, it won't work if your mod runs a video onCreate.
			Use onCreatePost instead for your real video.
]]

function onCreate()
    runHaxeCode([[
        import objects.VideoSprite;
        import sys.FileSystem;

        var dummyPath:String = Paths.video('_VideoDummy');
        if (!FileSystem.exists(dummyPath)) {
            trace('VideoWarmUp: dummy video missing (' + dummyPath + '), skipping warm-up');
            return;
        }
        var dummyVideo:VideoSprite = new VideoSprite(dummyPath, true, false, false);
        if (dummyVideo.videoSprite != null) {
            dummyVideo.videoSprite.visible = false;
            if (dummyVideo.videoSprite.bitmap != null)
                dummyVideo.videoSprite.bitmap.visible = false;
        }
        game.add(dummyVideo);
        dummyVideo.play();
        trace('VideoWarmUp: primed VLC decoder pipeline (self-destroys on end)');
    ]])
end
