--[[
	Half Life 2 style loading screen in lua.
	This is not a real loading screen, it's just for visuals.

	Compatible with Psych Engine 0.6.x and 0.7.x

	Script by AutisticLulu.
]]

-- #####################################################################
-- [[ Setting Variables ]]
-- Users can modify these variables freely.
-- #####################################################################

-- Enables the script
local scriptEnabled = false

-- Sprite stuff
local loadingBG = 'luluScripts/loadingHL2/loadingBG' -- Must be a 1280x720 resolution image
local loadingAnim = 'luluScripts/loadingHL2/loadingAnim' -- Half Life 2 style loading bar
local loadingPrefixXML = 'loadingAnim' -- XML Prefix for loading animation

-- #####################################################################
-- [[ Script Variables ]]
-- Do NOT touch unless you know what you're doing.
-- #####################################################################

local onLoadingScreen = false
local allowCountdown = false

-- #####################################################################
-- [[ Custom Functions ]]
-- #####################################################################

local function makeFakeLoading(name, image, x, y, camera, animPrefix, xmlPrefix, scale)
	precacheImage(image)

	if animPrefix then
		makeAnimatedLuaSprite(name, image, x, y)
		addAnimationByPrefix(name, animPrefix, xmlPrefix, 24, false)
	else
		makeLuaSprite(name, image, x, y)
	end

	if scale then 
		scaleObject(name, scale, scale) 
	end

	setObjectCamera(name, camera)
	screenCenter(name, 'xy')
	addLuaSprite(name, true)
end

local function fadeOut(sprite)
	doTweenAlpha(sprite .. "Fade", sprite, 0, 0.75, "linear")
end

-- #####################################################################
-- [[ Bind our local functions to Psych Engine events ]]
-- #####################################################################

function onCreate()
	if not scriptEnabled then return end
	makeFakeLoading('loadingBG', loadingBG, 0, 0, 'camOther') -- Replace with any 1280x720 image if desired
	makeFakeLoading('loadingAnim', loadingAnim, 0, 0, 'camOther', 'anim', 'loadingAnim', 0.5)
end

function onStartCountdown()
	if not allowCountdown and scriptEnabled then
		runTimer('fadeLoadingScreen', 5)
		runTimer('loadingComplete', 6)
		onLoadingScreen = true
		allowCountdown = true
		return Function_Stop
	end
	return Function_Continue
end

function onTimerCompleted(tag)
	if tag == 'fadeLoadingScreen' and scriptEnabled then
		fadeOut("loadingAnim")
		fadeOut("loadingBG")

	elseif tag == 'loadingComplete' and scriptEnabled then
		onLoadingScreen = false
		startCountdown()
		removeLuaSprite("loadingAnim", true)
		removeLuaSprite("loadingBG", true)
	end
end