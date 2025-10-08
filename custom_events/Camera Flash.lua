--[[

>>> Camera Flash Event for Psych Engine.
	Flashes the screen with a specified colour and duration on a chosen camera object

	Compatible with Psych Engine 0.5.x, 0.6.x, 0.7.X, 1.0.x

	* Supports all parameters for the built-in cameraFlash function.
	* Supports RGB and HEX as colour input or 'random' for random colour.
	* Only triggers if Flashing Lights are enabled.
	* Includes basic debugging output.

	Script by AutisticLulu.

	Usage:
		Value 1:
			Camera [camGame/camHUD/camOther], forced? [true/false] 
			(Example: camHUD, true)

		Value 2:
			Colour [HEX], Duration [Seconds] 
			(Example: 9DCFED, 4)

			Colour [RGB], Duration [Seconds] 
			(Example: 157, 207, 237, 4)

	If no camera is specified, it defaults to "defaultCamera"
	If no bool is specified, it defaults to "defaultForced"
	If no colour is specified, it defaults to "defaultColour"
	If no duration is specified, it defaults to "defaultDuration"

]]
-- #####################################################################
-- [[ Setting Variables ]]
-- Users can modify these variables freely.
-- #####################################################################

local enableDebug = false

local validCameras = {
	camGame = true,
	camHUD = true,
	camOther = true
}

local defaultCamera = "camGame"
local defaultForced = false
local defaultColour = "FFFFFF"
local defaultDuration = 1


-- #####################################################################
-- [[ Custom Functions ]]
-- #####################################################################

-- Converts each RGB value to hexadecimal
local function rgbToHex(r, g, b)
	r = math.max(0, math.min(255, r))
	g = math.max(0, math.min(255, g))
	b = math.max(0, math.min(255, b))

	local hexR = string.format("%02X", r)
	local hexG = string.format("%02X", g)
	local hexB = string.format("%02X", b)
	return hexR .. hexG .. hexB
end

-- Parses the camera and forced value from the input string.
local function parseCameraValue(value)
	if not value or value == "" then
		return defaultCamera, defaultForced
	end

	local camera, isForced = string.match(value:gsub(" ", ""), "(.*),(%a+)")

	if validCameras[camera] and isForced == "true" then
		return camera, true
	elseif validCameras[camera] then
		return camera, false
	end

	return defaultCamera, defaultForced
end

-- Parses the colour and duration from the input string.
local function parseFlashValue(value)
	if not value or value == "" then
		return defaultColour, defaultDuration
	end

	local colour, duration = string.match(value:gsub(" ", ""), "(.*),(.*)")

	if not colour or not duration then
		return defaultColour, defaultDuration
	end

	if colour:lower() == "random" then
		local r = math.random(0, 255)
		local g = math.random(0, 255)
		local b = math.random(0, 255)
		colour = rgbToHex(r, g, b)
		return colour, tonumber(duration) or defaultDuration
	else
		local r, g, b = string.match(colour:gsub(" ", ""), "(%d+),(%d+),(%d+)")
		if r and g and b then
			colour = rgbToHex(tonumber(r), tonumber(g), tonumber(b))
			return colour, tonumber(duration) or defaultDuration
		else
			return colour, tonumber(duration) or defaultDuration
		end
	end
end

-- #####################################################################
-- [[ Bind our local functions to Psych Engine events ]]
-- #####################################################################

function onEvent(name, value1, value2)
	if (name == "Camera Flash" or name == "Camera_Flash") and flashingLights then
		local camera, isForced = parseCameraValue(value1)
		local colour, duration = parseFlashValue(value2)

		-- Debug output if enabled
		if enableDebug then
			debugPrint("Camera Flash Event Triggered:")
			debugPrint("  Camera: " .. camera .. " | Forced: " .. tostring(isForced))
			debugPrint("  Colour: " .. colour .. " | Duration: " .. duration)

			-- Validate hex colour format
			local charIndex = string.find(colour, "[^0-9A-Fa-f]")
			if colour:len() == 6 and charIndex then
				debugPrint("  WARNING: Hex colour contains invalid character at index " .. charIndex)
			elseif colour:len() ~= 6 then
				debugPrint("  WARNING: Hex colour length is " .. colour:len() .. ", expected 6")
			end
		end

		cameraFlash(camera, colour, duration, isForced)
	end
end