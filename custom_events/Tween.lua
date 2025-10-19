--[[

>>> "All-In-One" Tween Event for Psych Engine.
	Tween event that provides a unified interface for all Psych Engine tween functions.
	Additionally includes a custom Scale tween implementation.

	* Supports all parameters for the various Tween functions.
	* Supports different names or spelling of some tween types (e.g., "Colour" = "Color", "Rotate" = "Angle").

	Script by AutisticLulu.

	Usage:
		>>> Tween:
			Value 1:
				Tween Type, Tag, Object
				(Example: alpha, byeDad, dad)
				(Example: angle, rotateSprite, mySprite)
				(Example: x, moveLeft, boyfriend)

			Value 2:
				Value, Duration [Seconds], Ease Type [FlxTween]
				(Example: 0, 4, bounceIn)
				(Example: 360, 2.5, quintOut)

				For doTweenColor, the value needs to be a valid Hex Color code:
				(Example: 9DCFED, 4, quintIn)
				(Example: FF0000, 1, linear)

		All parameters in Value 1 are required.
		Ease Type in Value 2 is optional (defaults to "linear").

		Valid Tween Types:
			- Alpha / Opacity / Fade: Tweens object transparency (0-1)
			- Angle / Rotate: Tweens object rotation in degrees
			- X: Tweens object horizontal position
			- Y: Tweens object vertical position
			- Color / Colour / Tint: Tweens object color (hex values)
			- Zoom: Tweens camera zoom (object should be "game", "hud", or "other")
			- Scale / Size: Tweens object scale uniformly (custom implementation)

		Note: Scale is a custom tween that uses runTimer to simulate smooth scaling.
			It scales both X and Y uniformly. For independent axis scaling, use scaleX/scaleY separately.

		For more ease types, see: https://api.haxeflixel.com/flixel/tweens/FlxEase.html

]]

-- #####################################################################
-- [[ Tween Configuration Tables ]]
-- #####################################################################

local validTweenTypes = {"Alpha", "Angle", "X", "Y", "Color", "Zoom", "Scale"}
local tweenAltNames = {
	Rotate = "Angle",
	Opacity = "Alpha",
	Fade = "Alpha",
	Colour = "Color",
	Tint = "Color",
	Size = "Scale"
}
local colorTweenTypes = {Color = true, Colour = true, Tint = true}

local validTweens = {}
for _, tweenType in ipairs(validTweenTypes) do
	validTweens[tweenType] = true
end


-- #####################################################################
-- [[ Custom Tween Implementation: Scale ]]
-- #####################################################################

local activeTweens = {}
local tweenUpdateRate = 1 / 60 -- 60 FPS update rate

-- Custom implementation of scale tweening using runTimer
local function doTweenScale(tag, object, toValue, duration, easeType)
	-- Get current scale values
	local startScaleX = getProperty(object .. ".scale.x")
	local startScaleY = getProperty(object .. ".scale.y")

	if startScaleX == nil or startScaleY == nil then
		debugPrint('Tween Error: Object "' .. object .. '" does not exist or has no scale property')
		return false
	end

	-- Store tween data
	activeTweens[tag] = {
		object = object,
		startScaleX = startScaleX,
		startScaleY = startScaleY,
		targetScale = toValue,
		duration = duration,
		easeType = easeType,
		elapsed = 0,
		isActive = true
	}

	-- Start the update timer
	runTimer("tween_scale_" .. tag, tweenUpdateRate, 0)
	return true
end

-- Update function for scale tweens
local function updateScaleTween(tag, elapsed)
	local tween = activeTweens[tag]
	if not tween or not tween.isActive then
		return false
	end

	tween.elapsed = tween.elapsed + elapsed
	local progress = math.min(tween.elapsed / tween.duration, 1)
	local easedProgress = applyEasing(progress, tween.easeType)
	local currentScale = tween.startScaleX + (tween.targetScale - tween.startScaleX) * easedProgress

	setProperty(tween.object .. ".scale.x", currentScale)
	setProperty(tween.object .. ".scale.y", currentScale)

	if progress >= 1 then
		tween.isActive = false
		cancelTimer("tween_scale_" .. tag)

		if onTweenCompleted then
			onTweenCompleted(tag)
		end

		return false
	end

	return true
end

-- Custom implementation of easing functions for the custom scale tween
-- Mimics easing functions found in FlxEase
local easingFunctions = {}

-- Linear
easingFunctions.linear = function(t)
	return t
end

-- Quad easing
easingFunctions.quadin = function(t)
	return t * t
end
easingFunctions.quadout = function(t)
	return t * (2 - t)
end
easingFunctions.quadinout = function(t)
	return t < 0.5 and 2 * t * t or 1 - 2 * (1 - t) * (1 - t)
end

-- Cubic easing
easingFunctions.cubicin = function(t)
	return t * t * t
end
easingFunctions.cubicout = function(t)
	local t1 = t - 1
	return t1 * t1 * t1 + 1
end
easingFunctions.cubicinout = function(t)
	if t < 0.5 then
		return 4 * t * t * t
	else
		local t2 = 2 * t - 2
		return 1 + t2 * t2 * t2 * 0.5
	end
end

-- Sine easing (cached pi values)
local PI_HALF = math.pi * 0.5
local PI = math.pi
easingFunctions.sinein = function(t)
	return 1 - math.cos(t * PI_HALF)
end
easingFunctions.sineout = function(t)
	return math.sin(t * PI_HALF)
end
easingFunctions.sineinout = function(t)
	return -(math.cos(PI * t) - 1) * 0.5
end

-- Expo easing
easingFunctions.expoin = function(t)
	return t == 0 and 0 or math.pow(2, 10 * (t - 1))
end
easingFunctions.expoout = function(t)
	return t == 1 and 1 or 1 - math.pow(2, -10 * t)
end
easingFunctions.expoinout = function(t)
	if t == 0 or t == 1 then
		return t
	end
	if t < 0.5 then
		return math.pow(2, 20 * t - 10) * 0.5
	else
		return (2 - math.pow(2, -20 * t + 10)) * 0.5
	end
end

-- Elastic easing (cached constants)
local ELASTIC_CONST1 = 5 * PI
local ELASTIC_CONST2 = 1.1
local ELASTIC_CONST3 = 0.1
easingFunctions.elasticin = function(t)
	if t == 0 or t == 1 then
		return t
	end
	return -math.pow(2, 10 * (t - 1)) * math.sin((t - ELASTIC_CONST2) * ELASTIC_CONST1)
end
easingFunctions.elasticout = function(t)
	if t == 0 or t == 1 then
		return t
	end
	return math.pow(2, -10 * t) * math.sin((t - ELASTIC_CONST3) * ELASTIC_CONST1) + 1
end
easingFunctions.elasticinout = function(t)
	if t == 0 or t == 1 then
		return t
	end
	t = t * 2
	if t < 1 then
		return -0.5 * math.pow(2, 10 * (t - 1)) * math.sin((t - ELASTIC_CONST2) * ELASTIC_CONST1)
	else
		return 0.5 * math.pow(2, -10 * (t - 1)) * math.sin((t - ELASTIC_CONST2) * ELASTIC_CONST1) + 1
	end
end

-- Back easing (cached constant)
local BACK_CONST = 1.70158
local BACK_CONST_INOUT = BACK_CONST * 1.525
easingFunctions.backin = function(t)
	return t * t * ((BACK_CONST + 1) * t - BACK_CONST)
end
easingFunctions.backout = function(t)
	t = t - 1
	return t * t * ((BACK_CONST + 1) * t + BACK_CONST) + 1
end
easingFunctions.backinout = function(t)
	t = t * 2
	if t < 1 then
		return 0.5 * (t * t * ((BACK_CONST_INOUT + 1) * t - BACK_CONST_INOUT))
	else
		t = t - 2
		return 0.5 * (t * t * ((BACK_CONST_INOUT + 1) * t + BACK_CONST_INOUT) + 2)
	end
end

-- Bounce easing (cached constants)
local BOUNCE_CONST1 = 7.5625
local BOUNCE_DIV1 = 1 / 2.75
local BOUNCE_DIV2 = 2 / 2.75
local BOUNCE_DIV3 = 2.5 / 2.75
easingFunctions.bounceout = function(t)
	if t < BOUNCE_DIV1 then
		return BOUNCE_CONST1 * t * t
	elseif t < BOUNCE_DIV2 then
		t = t - 1.5 / 2.75
		return BOUNCE_CONST1 * t * t + 0.75
	elseif t < BOUNCE_DIV3 then
		t = t - 2.25 / 2.75
		return BOUNCE_CONST1 * t * t + 0.9375
	else
		t = t - 2.625 / 2.75
		return BOUNCE_CONST1 * t * t + 0.984375
	end
end
easingFunctions.bouncein = function(t)
	return 1 - easingFunctions.bounceout(1 - t)
end
easingFunctions.bounceinout = function(t)
	if t < 0.5 then
		return easingFunctions.bouncein(t * 2) * 0.5
	else
		return easingFunctions.bounceout(t * 2 - 1) * 0.5 + 0.5
	end
end

local function applyEasing(t, easeType)
	local easingFunc = easingFunctions[easeType:lower()]
	return easingFunc and easingFunc(t) or t
end


-- #####################################################################
-- [[ Event Functions ]]
-- #####################################################################

-- Parses the tween type, tag, and object from the input string.
local function parseTweenNames(value)
	local cleanValue = value:gsub(" ", "")
	local tweenType, tag, object = cleanValue:match("(%a+),([^,]+),(.+)")

	if not tweenType or not tag or not object then
		return nil, nil, nil
	end

	-- Capitalize the first letter of the tweenType input
	tweenType = tweenType:sub(1, 1):upper() .. tweenType:sub(2):lower()

	-- Check if an alternative name was used for the tween type
	tweenType = tweenAltNames[tweenType] or tweenType

	return tweenType, tag, object
end

-- Parses the toValue, duration, and easeType from the input string.
local function parseTweenValues(tweenType, value)
	local cleanValue = value:gsub(" ", "")
	local toValue, duration, easeType = cleanValue:match("([^,]+),([^,]+),?(.*)")

	if not toValue or not duration then
		return nil, nil, nil
	end

	easeType = (easeType == "" or easeType == nil) and "linear" or easeType

	-- If tweenType is not color-based, convert toValue to number
	-- Color tweens expect hex strings, so we keep them as strings
	if not colorTweenTypes[tweenType] then
		toValue = tonumber(toValue)
		if not toValue then
			return nil, nil, nil
		end
	end

	duration = tonumber(duration)
	if not duration then
		return nil, nil, nil
	end

	return toValue, duration, easeType
end

-- Executes the tween using the appropriate Psych Engine doTween function.
local function tweenObject(tweenType, tag, object, toValue, duration, easeType)
	-- Handle custom implementation for Scale tween
	if tweenType == "Scale" then
		return doTweenScale(tag, object, toValue, duration, easeType)
	end

	-- For other tween types, use built-in Psych Engine functions
	local tweenFunctionName = "doTween" .. tweenType
	local tweenFunction = _G[tweenFunctionName]

	if tweenFunction and type(tweenFunction) == "function" then
		tweenFunction(tag, object, toValue, duration, easeType)
		return true
	end

	return false
end


-- #####################################################################
-- [[ Bind our local functions to Psych Engine events ]]
-- #####################################################################

function onEvent(name, value1, value2)
	if name == "Tween" then
		local tweenType, tag, object = parseTweenNames(value1)

		if not tweenType then
			debugPrint('Tween Error: Invalid Value 1 format. Expected: "type, tag, object"')
			return
		end

		local toValue, duration, easeType = parseTweenValues(tweenType, value2)

		if not toValue or not duration then
			debugPrint(
				'Tween Error: Invalid Value 2 format. Expected: "value, duration, [easeType]"')
			return
		end

		if not validTweens[tweenType] then
			debugPrint(
				'Tween Error: Invalid tween type "' .. tweenType .. '". Valid types: Alpha, Angle, X, Y, Color, Zoom, Scale')
			return
		end

		if not tweenObject(tweenType, tag, object, toValue, duration, easeType) then
			debugPrint('Tween Error: Function "doTween' .. tweenType .. '" not found in Psych Engine')
		end
	end
end

function onTimerCompleted(tag)
	-- Handle scale tween updates
	if tag:sub(1, 12) == "tween_scale_" then
		local tweenTag = tag:sub(13)
		updateScaleTween(tweenTag, tweenUpdateRate)
	end
end
