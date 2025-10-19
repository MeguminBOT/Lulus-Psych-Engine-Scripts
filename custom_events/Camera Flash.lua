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

	return string.format("%02X%02X%02X", r, g, b)
end

-- Validates hex colour format
local function isValidHex(hex)
	return #hex == 6 and not hex:find("[^0-9A-Fa-f]")
end

-- Parses the camera and forced value from the input string
local function parseCameraValue(value)
	if not value or value == "" then
		return defaultCamera, defaultForced
	end

	local cleanValue = value:gsub(" ", "")
	local camera, forcedStr = string.match(cleanValue, "([^,]+),(%a+)")

	if camera and validCameras[camera] then
		return camera, forcedStr == "true"
	end

	return defaultCamera, defaultForced
end

-- Parses the colour and duration from the input string
local function parseFlashValue(value)
	if not value or value == "" then
		return defaultColour, defaultDuration
	end

	local cleanValue = value:gsub(" ", "")
	local parts = {}
	for part in string.gmatch(cleanValue, "[^,]+") do
		table.insert(parts, part)
	end

	if #parts < 2 then
		return defaultColour, defaultDuration
	end

	local duration = tonumber(parts[#parts]) or defaultDuration

	-- Handle 'random' colour
	if parts[1]:lower() == "random" then
		return rgbToHex(math.random(0, 255), math.random(0, 255), math.random(0, 255)), duration
	end

	-- Handle RGB (3 parts + duration)
	if #parts == 4 then
		local r, g, b = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
		if r and g and b then
			return rgbToHex(r, g, b), duration
		end
	end

	-- Handle HEX (1 part + duration)
	return parts[1], duration
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

			if not isValidHex(colour) then
				debugPrint("  WARNING: Invalid hex colour format (expected 6 hex characters)")
			end
		end
		cameraFlash(camera, colour, duration, isForced)
	end
end