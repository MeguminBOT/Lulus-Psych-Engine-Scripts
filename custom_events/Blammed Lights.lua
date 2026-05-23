--[[
	>>> Blammed Lights for Psych Engine 1.0.4
		Place this script in 'mods/YourMod/custom_events/' or 'mods/custom_events/'.
	Script by AutisticLulu.
]]

-- ========================================
-- CONFIGURATION & VARIABLES
-- ========================================

-- CONFIGURABLE VARIABLES
local TWEEN_TYPE = "quadInOut"
local TWEEN_DURATION = 1
local LIGHT_COUNT = 5
local LIGHT_COLORS = {
    "31a2fd", -- 1 Blue
    "31fd8c", -- 2 Green
    "f794f7", -- 3 Pink
    "f96d63", -- 4 Red
    "fba633" -- 5 Orange
}

-- DO NOT MODIFY THESE UNLESS YOU KNOW WHAT YOU'RE DOING
local CHAR_TAGS = {"boyfriend", "gf", "dad"}
local curLightEvent = 0
local blammedLightsBlackTween = nil
local phillyEventTween = nil

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

local function phillyTag(i)
    return "phillyCityLightsEvent" .. i
end

local function charColorTweenTag(tag)
    return tag .. "ColorTween"
end

local function cancelIfActive(tweenTag)
    if tweenTag ~= nil then
        cancelTween(tweenTag)
    end
end

local function setAllPhillyLightsVisible(visible)
    for i = 0, LIGHT_COUNT - 1 do
        setProperty(phillyTag(i) .. ".visible", visible)
    end
end

local function tweenCharsToColor(hex)
    for _, tag in ipairs(CHAR_TAGS) do
        local ct = charColorTweenTag(tag)
        cancelTween(ct)
        doTweenColor(ct, tag, "#" .. hex, TWEEN_DURATION, TWEEN_TYPE)
    end
end

local function snapCharsToColor(hex)
    for _, tag in ipairs(CHAR_TAGS) do
        cancelTween(charColorTweenTag(tag))
        setProperty(tag .. ".color", getColorFromHex(hex))
    end
end

local function lightsOn(lightId)
    if lightId > 5 then
        lightId = getRandomInt(1, 5, tostring(curLightEvent))
    end

    local colorHex = LIGHT_COLORS[lightId] or "ffffff"
    curLightEvent = lightId

    if getProperty("blammedLightsBlack.alpha") == 0 then
        cancelIfActive(blammedLightsBlackTween)
        blammedLightsBlackTween = doTweenAlpha("blammedLightsBlackTween", "blammedLightsBlack", 1, TWEEN_DURATION, TWEEN_TYPE)
        tweenCharsToColor(colorHex)
    else
        cancelIfActive(blammedLightsBlackTween)
        blammedLightsBlackTween = nil
        setProperty("blammedLightsBlack.alpha", 1)
        snapCharsToColor(colorHex)
    end

    if curStage == "philly" then
        setAllPhillyLightsVisible(false)
        local active = phillyTag(lightId - 1)
        setProperty(active .. ".visible", true)
        setProperty(active .. ".alpha", 1)
    end
end

local function lightsOff()
    if getProperty("blammedLightsBlack.alpha") ~= 0 then
        cancelIfActive(blammedLightsBlackTween)
        blammedLightsBlackTween = doTweenAlpha("blammedLightsBlackTween", "blammedLightsBlack", 0, TWEEN_DURATION, TWEEN_TYPE)
    end

    tweenCharsToColor("ffffff")

    if curStage == "philly" then
        for i = 0, LIGHT_COUNT - 1 do
            setPropertyFromGroup("phillyCityLights", i, "visible", false)
        end

        setAllPhillyLightsVisible(false)

        if curLightEvent > 0 then
            local lastTag = phillyTag(curLightEvent - 1)
            setProperty(lastTag .. ".visible", true)
            setProperty(lastTag .. ".alpha", 1)
            cancelIfActive(phillyEventTween)
            phillyEventTween = doTweenAlpha("phillyEventTween", lastTag, 0, TWEEN_DURATION, TWEEN_TYPE)
        end
    end

    curLightEvent = 0
end

-- ========================================
-- PSYCH FUNCTIONS
-- ========================================

function onCreatePost()
    if curStage == "philly" then
        for i = 0, LIGHT_COUNT - 1 do
            local tag = phillyTag(i)
            makeLuaSprite(tag, nil, -10, 0)
            loadFrames(tag, "philly/win" .. i, "sparrow")
            addAnimationByPrefix(tag, "idle", "win" .. i, 24, false)
            playAnim(tag, "idle")
            setScrollFactor(tag, 0.3, 0.3)
            setGraphicSize(tag, getProperty(tag .. ".width") * 0.85)
            updateHitbox(tag)
            setProperty(tag .. ".visible", false)
        end
    end

    if not luaSpriteExists("blammedLightsBlack") then
        makeLuaSprite("blammedLightsBlack", nil, screenWidth * -0.5, screenHeight * -0.5)
        makeGraphic("blammedLightsBlack", screenWidth * 2, screenHeight * 2, "000000")
        setScrollFactor("blammedLightsBlack", 0, 0)

        local pos = getObjectOrder("gfGroup")
        local bfPos = getObjectOrder("boyfriendGroup")
        local dadPos = getObjectOrder("dadGroup")

        if bfPos < pos then
            pos = bfPos
        end

        if dadPos < pos then
            pos = dadPos
        end

        addLuaSprite("blammedLightsBlack", false)
        setObjectOrder("blammedLightsBlack", pos)
    end

    setProperty("blammedLightsBlack.alpha", 0)

    if curStage == "philly" then
        local blackPos = getObjectOrder("blammedLightsBlack")
        for i = 0, LIGHT_COUNT - 1 do
            local tag = phillyTag(i)
            addLuaSprite(tag, false)
            setObjectOrder(tag, blackPos + 1 + i)
        end
    end
end

function onEvent(name, value1, value2, strumTime)
    if name == "Blammed Lights" or name == "Blammed_Lights" then
        local lightId = tonumber(value1) or 0

        if lightId > 0 and curLightEvent ~= lightId then
            lightsOn(lightId)
        else
            lightsOff()
        end
    end
end
