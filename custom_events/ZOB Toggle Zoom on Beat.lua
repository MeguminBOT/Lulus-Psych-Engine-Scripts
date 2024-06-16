--[[ 	
    Alternative "Toggle Zoom on Beat" for those who can't use my other version due to various reasons.
    This version is more configurable and allows you to set the zoom speed and easing for both zooming in and out.
    It's parameter input works exactly the same as my other version.

    Compatible with Psych Engine 0.6.x and 0.7.x

    Credit if you take any code from this script.
    Script by AutisticLulu.

    * ZOB Toggle Zoom on Beat
        Zooms on every beat or optionally between a set amount of beats.

        Value 1:
            Parameters: "Stage Zoom, Hud Zoom, Number of beats *OPTIONAL*"
            (Example: 0.015, 0.03)
            (Example: 0.015, 0.03, 2)

        Value 2:
            Parameters: [On/Off]
            (Example: On)

    * ZOB Update Zoom
        Updates the variable used to go back to normal zoom level.
        No values or parameters are required.

    * ZOB Return to Default
        Completely resets the zoom back to what it was when the song started.
        No values or parameters are required.
]]

-- #####################################################################
-- [[ Setting Variables ]]
-- Users can modify these variables freely. EaseType list: https://api.haxeflixel.com/flixel/tweens/FlxEase.html
-- #####################################################################

local zoomInSpeed = 0.05
local zoomOutSpeed = 0.025
local zoomInEase = 'sineIn'
local zoomOutEase = 'sineOut'

-- #####################################################################
-- [[ Script Variables ]]
-- Do NOT touch unless you know what you're doing.
-- #####################################################################

local isActive = false
local beatTrigger = 1
local beatCount = 0
local defaultGameZoom, defaultHudZoom, curGameZoom, curHudZoom

-- #####################################################################
-- [[ Custom Functions ]]
-- #####################################################################

-- Saves the default zoom values when the song starts.
local function saveZoom()
    defaultGameZoom = getProperty('camGame.zoom')
    defaultHudZoom = getProperty('camHUD.zoom')
    curGameZoom = defaultGameZoom
    curHudZoom = defaultHudZoom
end

-- Updates the variable used to go back to normal zoom level.
local function updateZoom()
    curGameZoom = getProperty('camGame.zoom')
    curHudZoom = getProperty('camHUD.zoom')
end

-- Sets the zoom back to what it was when the song started.
local function revertZoom()
    curGameZoom = defaultGameZoom
    curHudZoom = defaultHudZoom
end

-- Helper function: Parses the gameZoom, hudZoom, and numBeats.
local function parseZoomValues(value)
    local gameZoom, hudZoom, numBeats = value:match('([^,]+),%s*([^,]+),?%s*([^,]*)')
    return tonumber(gameZoom), tonumber(hudZoom), tonumber(numBeats)
end

-- #####################################################################
-- [[ Bind our local functions to Psych Engine events ]]
-- #####################################################################

function onSongStart()
    saveZoom()
end

function onEvent(name, value1, value2)
    if (name == 'ZOB Toggle Zoom on Beat' or name == 'ZOB_Toggle_Zoom_on_Beat') then
        gameZoom, hudZoom, numBeats = parseZoomValues(value1)
        beatTrigger = numBeats or 1 -- Defaults to 1 if not specified or invalid
        isActive = (value2 == 'On')

    elseif (name == 'ZOB Update Zoom' or name == 'ZOB_Update_Zoom') then
        updateZoom()

    elseif (name == 'ZOB Revert Zoom' or name == 'ZOB_Revert_Zoom') then
        revertZoom()
    end
end

function onBeatHit()
    beatCount = beatCount + 1
    if isActive and beatCount % beatTrigger == 0 and gameZoom and hudZoom then
        doTweenZoom('gameZoomBeat', 'camGame', curGameZoom + gameZoom, zoomInSpeed, zoomInEase)
        doTweenZoom('hudZoomBeat', 'camHUD', curHudZoom + hudZoom, zoomInSpeed, zoomInEase)
    end
end

function onTweenCompleted(tag)
    if tag == 'gameZoomBeat' then
        doTweenZoom('gameZoomBeat', 'camGame', curGameZoom - gameZoom, zoomOutSpeed, zoomOutEase)
    elseif tag == 'hudZoomBeat' then
        doTweenZoom('hudZoomBeat', 'camHUD', curHudZoom - hudZoom, zoomOutSpeed, zoomOutEase)
    end
end