--[[
	Script to temporarily disable anti-aliasing for a specific song.
	
	Supports: 
		* 0.6.x
		* 0.7.x
		* VS FNAF 3's modified 0.6.2 variant.

	Script by AutisticLulu.
]]

-- #####################################################################
-- [[ Variables ]]
-- #####################################################################

-- Enables the script
local scriptEnabled = false
local debugEnabled = false

-- Variables to save the user's original settings [DO NOT MODIFY THIS]
local originalGlobalAA = nil
local originalHudAA = nil

-- #####################################################################
-- [[ Custom Functions ]]
-- #####################################################################

-- Function to restore the user's original anti-alias settings
local function revertAntialiasing()
	if not scriptEnabled then return end
	if not originalGlobalAA then return end

	-- VS FNaF 3 Specific
	if stringStartsWith(version, '0.6.2 (Modified)') then
		setPropertyFromClass('ClientPrefs', 'globalAntialiasing', originalGlobalAA)
		setPropertyFromClass('ClientPrefs', 'hudAntialiasing', originalHudAA)

	-- Any Psych Engine 0.6 version
	elseif stringStartsWith(version, '0.6') then
		setPropertyFromClass('ClientPrefs', 'globalAntialiasing', originalGlobalAA)

	-- Any Psych Engine 0.7 version
	elseif stringStartsWith(version, '0.7') then
		setPropertyFromClass('backend.ClientPrefs', 'data.antialiasing', originalGlobalAA)
	end
	if debugEnabled then
		debugPrint('!! Reverting to saved user settings !!')
	end
end

-- Function to disable anti-aliasing temporarily
local function disableAntialiasing()
	if not scriptEnabled then return end

	-- VS FNaF 3 Specific
	if stringStartsWith(version, '0.6.2 (Modified)') then
		setPropertyFromClass('ClientPrefs', 'globalAntialiasing', false)
		setPropertyFromClass('ClientPrefs', 'hudAntialiasing', false)

	-- Any Psych Engine 0.6 version
	elseif stringStartsWith(version, '0.6') then
		setPropertyFromClass('ClientPrefs', 'globalAntialiasing', false)

	-- Any Psych Engine 0.7 version
	elseif stringStartsWith(version, '0.7') then
		setPropertyFromClass('backend.ClientPrefs', 'data.antialiasing', false)
	end

	if debugEnabled then
		debugPrint('!! Turning off anti-alias temporarily !!')
	end
end

-- Function to retrieve and save user's current settings
local function getAntialiasSettings()
	if not scriptEnabled then return end

	if stringStartsWith(version, '0.6.2 (Modified)') then
		originalGlobalAA = getPropertyFromClass('ClientPrefs', 'globalAntialiasing')
		originalHudAA = getPropertyFromClass('ClientPrefs', 'hudAntialiasing')
		if debugEnabled then
			debugPrint('!! Saved user settings !!', 'Sprite Anti-Aliasing: ' .. originalGlobalAA, 'HUD Anti-Aliasing: ' .. originalHudAA)
		end

	elseif stringStartsWith(version, '0.6') then
		originalGlobalAA = getPropertyFromClass('ClientPrefs', 'globalAntialiasing')
		if debugEnabled then
			debugPrint('!! Saved user settings !!', 'Anti-Aliasing: ' .. originalGlobalAA)
		end

	elseif stringStartsWith(version, '0.7') then
		originalGlobalAA = getPropertyFromClass('backend.ClientPrefs', 'data.antialiasing')
		if debugEnabled then
			debugPrint('!! Saved user settings !!', 'Anti-Aliasing: ' .. originalGlobalAA)
		end
	end
end

-- #####################################################################
-- [[ Bind our local functions to Psych Engine events ]]
-- #####################################################################

function onCreate()
	getAntialiasSettings()
end

-- Might be able to change this to onCreatePost() instead. 
-- onSongStart is however guaranteed to work.
function onSongStart() 
	disableAntialiasing()
end

-- Change this to onDestroy() if the settings doesnt revert as intended. (Usually if cutscenes are used after song)
function onSongEnd() 
	revertAntialiasing()
end
