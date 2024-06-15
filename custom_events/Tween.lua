--[[

>>> "All-In-One" Tween Event for Psych Engine. // AutisticLulu
* Supports all parameters for the various Tween functions.
* Supports different names or spelling of some tween types.

Value 1:
	Parameters: "Tween Type, Tag, Object"

	(Example: alpha, byeDad, dad)
	(Example: alpha, hiDad, dad)

	All parameters must be set for value1.

Value 2:
	Parameters: "Value, Duration [Seconds], Ease Type [FlxTween]"
	(Example: 0, 4, bounceIn)

	Same thing applies for doTweenColor but here the value needs to be a valid Hex Colour code:
	(Example: 9DCFED, 4, quintIn) 

	Ease Type is optional. Otherwise, see: "https://api.haxeflixel.com/flixel/tweens/FlxEase.html"

]]

-- Initialize Tables.
local validTweens = {}
local validTweenTypes = {"Alpha", "Angle", "X", "Y", "Color", "Zoom"}
local tweenAltNames = {Rotate = "Angle", Opacity = "Alpha", Fade = "Alpha", Colour = "Color", Tint = "Color"}

-- Loop through each valid tween type and add them to the validTweens table.
for _, tweenType in ipairs(validTweenTypes) do
	validTweens[tweenType] = true
end

-- Dumb loop.. send help please.
for funcName, funcValue in pairs(_G) do
	if type(funcValue) == "function" and string.match(funcName, "^doTween") then
		local tweenName = string.sub(funcName, 9)
		if validTweens["doTween" .. tweenName] == nil then
			validTweens["doTween" .. tweenName] = true
		end
	end
end

-- Helper function: Parses the tween type, tag, and object from the input string.
local function parseTweenNames(value)
	-- Extract parameters from the input string.
	local tweenType, tag, object = string.match(value:gsub(' ', ''), '(%a+),(.*),(.*)')

	-- Capitalize the first letter of the tweenType input.
	tweenType = string.gsub(tweenType, "^%l", string.upper)

	-- Check if an alternative name was used for the tween type.
	tweenType = tweenAltNames[tweenType] or tweenType

	return tweenType, tag, object
end

-- Helper function: Parses the toValue, duration, and easeType from the input string.
local function parseTweenValues(tweenType, value)
	-- Extract parameters from the input string.
	local toValue, duration, easeType = string.match(value:gsub(' ', ''), '([^,]*),([^,]*),?(.*)')

	-- If easeType is not provided, use "linear".
	easeType = (easeType == "" or easeType == nil) and "linear" or easeType

	-- Define a table for color-related tweenTypes. (Directly using if + or statements didnt work?!)
	local colorTweenTypes = {Color = true, Colour = true, Tint = true}

	-- If tweenType is not colour-based, convert to number.
	if not colorTweenTypes[tweenType] then
		toValue = tonumber(toValue)
	end

	return toValue, tonumber(duration), easeType
end

-- Helper function: Do the tween.
local function tweenObject(tweenType, tag, object, toValue, duration, easeType)
	local tweenFunctionName = "doTween" .. tweenType
	local tweenFunction = _G[tweenFunctionName]
	tweenFunction(tag, object, toValue, duration, easeType)
end
  
-- This function is called when an event occurs.
function onEvent(name, value1, value2)
	if name == 'Tween' then
		-- Parse the input fields for value1 and value2.
		local tweenType, tag, object = parseTweenNames(value1)
		local toValue, duration, easeType = parseTweenValues(tweenType, value2)

		if validTweens[tweenType] then
			tweenObject(tweenType, tag, object, toValue, duration, easeType)
		else
			debugPrint("Invalid tween function: " .. tweenType)
		end
	end
end	
