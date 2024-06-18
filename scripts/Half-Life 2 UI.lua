--[[
    Half Life 2 Style UI in lua.

    Compatible with Psych Engine 0.6.x and 0.7.x

    Credit if you take any code from this script.
    Script by AutisticLulu.
]]

-- #####################################################################
-- [[ Variables ]]
-- #####################################################################

-- Enables the script
local scriptEnabled = false

-- Positions and sizes
local scrollOffset = 0
local centerOffset = 128
local bgWidth = 169

-- Fonts
local valueFontHL2 = 'luluScripts/halflife2.ttf'
local textFontHL2 = 'luluScripts/dejavusans.ttf'

-- #####################################################################
-- [[ Custom Functions ]]
-- #####################################################################

local function hideOriginalUI()
    if not scriptEnabled then return end

    setProperty('timeBar.visible', false)
    setProperty('timeBarBG.visible', false)
    setProperty('timeTxt.visible', false)
    setProperty('healthBar.visible', false)
    setProperty('healthBarBG.visible', false)
    setProperty('iconP1.visible', false)
    setProperty('iconP2.visible', false)
    setProperty('scoreTxt.visible', false)
    setProperty('showCombo', false)
    setProperty('showComboNum', false)
    setProperty('showRating', true)
end

local function hexToRGB(hex)
    if not scriptEnabled then return end

    return tonumber("0x" .. hex:sub(1,2)), tonumber("0x" .. hex:sub(3,4)), tonumber("0x" .. hex:sub(5,6))
end

local function rgbToHex(r, g, b)
    if not scriptEnabled then return end

    return string.format("%02X%02X%02X", r, g, b)
end

local function interpolateColor(color1, color2, factor)
    if not scriptEnabled then return end

    local r1, g1, b1 = hexToRGB(color1)
    local r2, g2, b2 = hexToRGB(color2)
    
    local r = r1 + (r2 - r1) * factor
    local g = g1 + (g2 - g1) * factor
    local b = b1 + (b2 - b1) * factor
    
    return rgbToHex(math.floor(r), math.floor(g), math.floor(b))
end

local function createTextElement(name, text, size, font, x, y)
    if not scriptEnabled then return end

    makeLuaText(name, text, 0, x, y)
    setTextSize(name, size)
    setTextFont(name, font)
    setTextColor(name, 'FFDC00')
    setTextBorder(name, 0, 'FFDC00')
    setObjectCamera(name, 'camHUD')
    setProperty(name .. '.antialiasing', true)
    addLuaText(name)
end

local function createBackgroundElement(name, x, y, width)
    if not scriptEnabled then return end

    makeLuaSprite(name, nil, x, y)
    makeGraphic(name, width, 48, '000000')
    setObjectCamera(name, 'camHUD')
    setProperty(name .. '.alpha', 0.2)
    setProperty(name .. '.antialiasing', true)
    addLuaSprite(name, false)
end

local function checkScrollDirection()
    if not scriptEnabled then return end

    scrollOffset = downscroll and 660 or 0
end

local function makeHalfLifeHUD()
    if not scriptEnabled then return end

    createTextElement('healthHL2', '100', 48, valueFontHL2, 100 + centerOffset, 662 - scrollOffset)
    createTextElement('healthTextHL2', 'HEALTH', 14, textFontHL2, 28 + centerOffset, 694 - scrollOffset)
    local hpWidth = getTextWidth('healthHL2')
    local hpTextWidth = getTextWidth('healthTextHL2')
    local totalWidth = math.floor(hpWidth - hpTextWidth)
    createBackgroundElement('healthBackgroundHL2', 19 + centerOffset, 670 - scrollOffset, bgWidth)

    createTextElement('ratingHL2', '100', 48, valueFontHL2, 300 + centerOffset, 662 - scrollOffset)
    createTextElement('ratingTextHL2', 'RATING', 14, textFontHL2, 228 + centerOffset, 694 - scrollOffset)
    createBackgroundElement('ratingBackgroundHL2', 219 + centerOffset, 670 - scrollOffset, bgWidth)

    createTextElement('comboHL2', '100', 24, valueFontHL2, 500 + centerOffset, 684 - scrollOffset)
    createTextElement('comboTextHL2', 'COMBO', 14, textFontHL2, 428 + centerOffset, 694 - scrollOffset)
    createBackgroundElement('comboBackgroundHL2', 419 + centerOffset, 670 - scrollOffset, bgWidth)

    createTextElement('scoreHL2', '100', 24, valueFontHL2, 700 + centerOffset, 684 - scrollOffset)
    createTextElement('scoreTextHL2', 'SCORE', 14, textFontHL2, 628 + centerOffset, 694 - scrollOffset)
    createBackgroundElement('scoreBackgroundHL2', 619 + centerOffset, 670 - scrollOffset, bgWidth)

    createTextElement('missesHL2', '100', 48, valueFontHL2, 900 + centerOffset, 662 - scrollOffset)
    createTextElement('missesTextHL2', 'MISSES', 14, textFontHL2, 828 + centerOffset, 694 - scrollOffset)
    createBackgroundElement('missesBackgroundHL2', 819 + centerOffset, 670 - scrollOffset, bgWidth)
end

local function healthUpdate()
    if not scriptEnabled then return end

    local curHealth = getHealth()
    local percentageHealth = math.floor((curHealth / 2) * 100)
    setTextString('healthHL2', tostring(percentageHealth))

    local color1 = 'FFDC00'
    local color2 = 'FF3000'
    local factor

    if percentageHealth >= 50 then
        factor = 0
    elseif percentageHealth <= 25 then
        factor = 1
    else
        factor = (50 - percentageHealth) / 25
    end

    local interpolatedColor = interpolateColor(color1, color2, factor)
    setTextColor('healthHL2', interpolatedColor)
    setTextBorder('healthHL2', 0, interpolatedColor)
    setTextColor('healthTextHL2', interpolatedColor)
    setTextBorder('healthTextHL2', 0, interpolatedColor)
end

local function accuracyUpdate()
    if not scriptEnabled then return end

    local curAccuracy = getProperty('ratingPercent')
    local percentageAccuracy = math.floor(curAccuracy * 100)
    setTextString('ratingHL2', percentageAccuracy)
end

local function scoreUpdate()
    if not scriptEnabled then return end

    local curScore = getScore()
    setTextString('scoreHL2', tostring(curScore))
end

local function missesUpdate()
    if not scriptEnabled then return end

    local curMisses = getMisses()
    setTextString('missesHL2', tostring(curMisses))
end

local function comboUpdate()
    if not scriptEnabled then return end

    local curCombo = getProperty('combo')
    setTextString('comboHL2', tostring(curCombo))
end

-- #####################################################################
-- [[ Bind our local functions to Psych Engine events ]]
-- #####################################################################
function onCreate()
    checkScrollDirection()
    makeHalfLifeHUD()
end

function onCreatePost()
    hideOriginalUI()
end

function opponentNoteHit(membersIndex, noteData, noteType, isSustainNote)
    healthUpdate()
end

function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
    healthUpdate()
    accuracyUpdate()
    scoreUpdate()
    comboUpdate()
end

function onUpdateScore(miss)
    healthUpdate()
    accuracyUpdate()
    scoreUpdate()
    missesUpdate()
    comboUpdate()
end
