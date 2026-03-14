--[[
	>>> Judgement Counter for Psych Engine
		Lua script that displays a judgment counter showing hit accuracy statistics.
		Automatically detects the active scoring system (Wife3, osu!mania, ITG, IIDX, DJMAX, Quaver, or Psych)
		and displays the appropriate judgment labels and colors.

		Features:
			- Real-time judgment counter display
			- Transparent background for better visibility
			- Customizable position and styling
			- Automatic scoring system detection
			- Wife3: Marvelous, Perfect, Great, Good, Bad, Miss
			- osu!mania: MAX, 300, 200, 100, 50, Miss
			- ITG: Fantastic, Excellent, Great, Decent, Way Off, Miss
			- IIDX: PGreat, Great, Good, Bad, Awful, Miss
			- DJMAX: MAX 100%, MAX 90%, Good, Bad, Miss
			- Quaver: Marvelous, Perfect, Great, Good, Okay, Miss
			- Psych: Sick, Good, Bad, Shit, Miss (fallback)

		Place this script in 'mods/YourMod/scripts/' or 'mods/scripts/'.

	Script by AutisticLulu.
--]]

-- ========================================
-- CONFIGURATION
-- ========================================

-- Position settings
local counterX = 50       -- X position of the judgment counter
local counterY = 250      -- Y position of the judgment counter
local counterWidth = 180  -- Width of the background
local counterHeight = 160 -- Height of the background

-- Style settings
local fontSize = 16        -- Font size for judgment text
local fontName = 'vcr.ttf' -- Font file name
local textColor = 'FFFFFF' -- Text color (hex)
local bgAlpha = 0.6        -- Background transparency (0.0 = invisible, 1.0 = opaque)
local bgColor = '000000'   -- Background color (hex)
local borderSize = 1.5     -- Text border/outline size

-- Spacing settings
local lineSpacing = 20 -- Spacing between judgment lines
local textPadding = 10 -- Padding from background edges

-- ========================================
-- VARIABLES
-- ========================================

-- Judgment counters (local tracking for all systems)
local tier1Count = 0
local tier2Count = 0
local tier3Count = 0
local tier4Count = 0
local tier5Count = 0
local tier6Count = 0
local tier7Count = 0
local missCount = 0

-- UI elements
local judgementBg = nil
local judgementTexts = {}

-- Toggle
local counterEnabled = true

-- Scoring system detection
local scoringSystem = 'Psych' -- 'Psych', 'Wife3', 'OsuMania', 'OsuManiaV2', 'ITG', 'Ruthless', 'IIDX', 'DJMAX', 'Quaver'
local wife3Available = false
local osuAvailable = false
local osuv2Available = false
local itgAvailable = false
local ruthlessAvailable = false
local iidxAvailable = false
local djmaxAvailable = false
local quaverAvailable = false

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Check if Wife3 scoring system is available
local function checkWife3Availability()
    wife3Available = (getVar('wife3_enabled') ~= nil and getVar('wife3_enabled') == true)
    return wife3Available
end

-- Check if osu!mania scoring system is available
local function checkOsuAvailability()
    osuAvailable = (getVar('osu_enabled') ~= nil and getVar('osu_enabled') == true)
    return osuAvailable
end

-- Check if osu!mania V2 scoring system is available
local function checkOsuV2Availability()
    osuv2Available = (getVar('osuv2_enabled') ~= nil and getVar('osuv2_enabled') == true)
    return osuv2Available
end

-- Check if ITG scoring system is available
local function checkITGAvailability()
    itgAvailable = (getVar('itg_enabled') ~= nil and getVar('itg_enabled') == true)
    return itgAvailable
end

-- Check if Ruthless scoring system is available
local function checkRuthlessAvailability()
    ruthlessAvailable = (getVar('ruthless_enabled') ~= nil and getVar('ruthless_enabled') == true)
    return ruthlessAvailable
end

-- Check if IIDX scoring system is available
local function checkIIDXAvailability()
    iidxAvailable = (getVar('iidx_enabled') ~= nil and getVar('iidx_enabled') == true)
    return iidxAvailable
end

-- Check if DJMAX scoring system is available
local function checkDJMAXAvailability()
    djmaxAvailable = (getVar('djmax_enabled') ~= nil and getVar('djmax_enabled') == true)
    return djmaxAvailable
end

-- Check if Quaver scoring system is available
local function checkQuaverAvailability()
    quaverAvailable = (getVar('quaver_enabled') ~= nil and getVar('quaver_enabled') == true)
    return quaverAvailable
end

-- Detect active scoring system
local function detectScoringSystem()
    local setting = getModSetting('scoring_system')
    if setting ~= nil then
        scoringSystem = setting
    end

    checkWife3Availability()
    checkOsuAvailability()
    checkOsuV2Availability()
    checkITGAvailability()
    checkRuthlessAvailability()
    checkIIDXAvailability()
    checkDJMAXAvailability()
    checkQuaverAvailability()

    -- Fallback detection if settings aren't available
    if setting == nil then
        if wife3Available then
            scoringSystem = 'Wife3'
        elseif osuAvailable then
            scoringSystem = 'OsuMania'
        elseif osuv2Available then
            scoringSystem = 'OsuManiaV2'
        elseif itgAvailable then
            scoringSystem = 'ITG'
        elseif ruthlessAvailable then
            scoringSystem = 'Ruthless'
        elseif iidxAvailable then
            scoringSystem = 'IIDX'
        elseif djmaxAvailable then
            scoringSystem = 'DJMAX'
        elseif quaverAvailable then
            scoringSystem = 'Quaver'
        else
            scoringSystem = 'Psych'
        end
    end
end

-- Get judgment counts based on active scoring system
local function getJudgmentCounts()
    if scoringSystem == 'O2Jam' then
        return {
            { count = tier1Count },
            { count = tier2Count },
            { count = tier3Count },
            { count = missCount }
        }
    elseif scoringSystem == 'Quaver' then
        return {
            { count = tier1Count },
            { count = tier2Count },
            { count = tier3Count },
            { count = tier4Count },
            { count = tier5Count },
            { count = missCount }
        }
    elseif scoringSystem == 'DJMAX' then
        return {
            { count = tier1Count },
            { count = tier2Count },
            { count = tier3Count },
            { count = tier4Count },
            { count = missCount }
        }
    elseif scoringSystem == 'Wife3' or scoringSystem == 'OsuMania' or scoringSystem == 'OsuManiaV2' or scoringSystem == 'ITG' or scoringSystem == 'Ruthless' or scoringSystem == 'IIDX' then
        if scoringSystem == 'Ruthless' then
            return {
                { count = tier1Count },
                { count = tier2Count },
                { count = tier3Count },
                { count = tier4Count },
                { count = tier5Count },
                { count = tier6Count },
                { count = tier7Count },
                { count = missCount }
            }
        elseif scoringSystem == 'IIDX' then
            return {
                { count = tier1Count },
                { count = tier2Count },
                { count = tier3Count },
                { count = tier4Count },
                { count = tier5Count },
                { count = missCount }
            }
        else
            return {
                { count = tier1Count },
                { count = tier2Count },
                { count = tier3Count },
                { count = tier4Count },
                { count = tier5Count },
                { count = missCount }
            }
        end
    else
        return {
            { count = tier1Count },
            { count = tier2Count },
            { count = tier3Count },
            { count = tier4Count },
            { count = missCount }
        }
    end
end

-- Get judgment definitions (labels + colors) based on active scoring system
local function getJudgmentDefinitions()
    if scoringSystem == 'O2Jam' then
        return {
            { name = 'tier1', label = 'Cool', color = 'FFFF00' },
            { name = 'tier2', label = 'Good', color = '00FFFF' },
            { name = 'tier3', label = 'Bad',  color = 'FF00FF' },
            { name = 'miss',  label = 'Miss', color = 'FF8000' }
        }
    elseif scoringSystem == 'OsuMania' then
        return {
            { name = 'tier1', label = 'MAX',  color = '00FFFF' },
            { name = 'tier2', label = '300',  color = 'FFFF00' },
            { name = 'tier3', label = '200',  color = '00FF00' },
            { name = 'tier4', label = '100',  color = '0088FF' },
            { name = 'tier5', label = '50',   color = '888888' },
            { name = 'miss',  label = 'Miss', color = 'FF0000' }
        }
    elseif scoringSystem == 'OsuManiaV2' then
        return {
            { name = 'tier1', label = 'MAX',  color = '00FFFF' },
            { name = 'tier2', label = '300',  color = 'FFFF00' },
            { name = 'tier3', label = '200',  color = '00FF00' },
            { name = 'tier4', label = '100',  color = '0088FF' },
            { name = 'tier5', label = '50',   color = '888888' },
            { name = 'miss',  label = 'Miss', color = 'FF0000' }
        }
    elseif scoringSystem == 'ITG' then
        return {
            { name = 'tier1', label = 'Fantastic', color = '00FFFF' },
            { name = 'tier2', label = 'Excellent', color = 'FFFF00' },
            { name = 'tier3', label = 'Great',     color = '00FF00' },
            { name = 'tier4', label = 'Decent',    color = 'FF00FF' },
            { name = 'tier5', label = 'Way Off',   color = 'FF6600' },
            { name = 'miss',  label = 'Miss',      color = 'FF0000' }
        }
    elseif scoringSystem == 'Wife3' then
        return {
            { name = 'tier1', label = 'Marvelous', color = 'FFFFFF' },
            { name = 'tier2', label = 'Perfect',   color = 'FFFF00' },
            { name = 'tier3', label = 'Great',     color = '00FF00' },
            { name = 'tier4', label = 'Good',      color = '00FFFF' },
            { name = 'tier5', label = 'Bad',       color = 'FF00FF' },
            { name = 'miss',  label = 'Miss',      color = 'FF0000' }
        }
    elseif scoringSystem == 'Ruthless' then
        return {
            { name = 'tier1', label = 'Flawless', color = 'E6FFFF' },
            { name = 'tier2', label = 'Precise',  color = '7DF9FF' },
            { name = 'tier3', label = 'Great',    color = '4CFF6A' },
            { name = 'tier4', label = 'Good',     color = '00CC44' },
            { name = 'tier5', label = 'Ok',       color = 'FFE066' },
            { name = 'tier6', label = 'Sloppy',   color = 'FF9A3D' },
            { name = 'tier7', label = 'Barely',   color = 'FF4DB8' },
            { name = 'miss',  label = 'Miss',     color = 'FF0000' }
        }
    elseif scoringSystem == 'IIDX' then
        return {
            { name = 'tier1', label = 'PGreat', color = '00FFFF' },
            { name = 'tier2', label = 'Great',  color = 'FFD700' },
            { name = 'tier3', label = 'Good',   color = '00FF00' },
            { name = 'tier4', label = 'Bad',    color = '0088FF' },
            { name = 'tier5', label = 'Awful',  color = 'FF00FF' },
            { name = 'miss',  label = 'Miss',   color = 'FF0000' }
        }
    elseif scoringSystem == 'DJMAX' then
        return {
            { name = 'tier1', label = 'MAX 100%', color = '00FFFF' },
            { name = 'tier2', label = 'MAX 90%',  color = 'FFFF00' },
            { name = 'tier3', label = 'Good',     color = '00FF00' },
            { name = 'tier4', label = 'Bad',      color = 'FF8800' },
            { name = 'miss',  label = 'Miss',     color = 'FF0000' }
        }
    elseif scoringSystem == 'Quaver' then
        return {
            { name = 'tier1', label = 'Marvelous', color = 'FFFFFF' },
            { name = 'tier2', label = 'Perfect',   color = 'FFE76B' },
            { name = 'tier3', label = 'Great',     color = '5FFF7B' },
            { name = 'tier4', label = 'Good',      color = '00EFFF' },
            { name = 'tier5', label = 'Okay',      color = 'F877EB' },
            { name = 'miss',  label = 'Miss',      color = 'F9645D' }
        }
    else
        -- Psych Engine default (4 hit windows)
        return {
            { name = 'tier1', label = 'Sick', color = '00FFFF' },
            { name = 'tier2', label = 'Good', color = '00FF00' },
            { name = 'tier3', label = 'Bad',  color = 'FF8800' },
            { name = 'tier4', label = 'Shit', color = 'FF0000' },
            { name = 'miss',  label = 'Miss', color = 'FF0000' }
        }
    end
end

-- Update all judgment text displays
local function updateJudgmentTexts()
    local counts = getJudgmentCounts()
    local defs = getJudgmentDefinitions()

    for i, def in ipairs(defs) do
        local textTag = 'judgementText_' .. def.name
        if def.label ~= '' then
            setTextString(textTag, def.label .. ': ' .. counts[i].count)
        else
            setTextString(textTag, '')
        end
    end
end

-- Create the judgment counter UI
local function createJudgmentCounter()
    -- Size background to fit the number of tiers
    local defs = getJudgmentDefinitions()
    local dynamicHeight = textPadding * 2 + lineSpacing * #defs

    -- Create transparent background
    makeLuaSprite('judgementBg', '', counterX, counterY)
    makeGraphic('judgementBg', counterWidth, dynamicHeight, bgColor)
    setProperty('judgementBg.alpha', bgAlpha)
    addLuaSprite('judgementBg', false)
    setObjectCamera('judgementBg', 'hud')

    -- Create text objects for each judgment type
    for i, def in ipairs(defs) do
        local textTag = 'judgementText_' .. def.name
        local initialLabel = def.label ~= '' and (def.label .. ': 0') or ''
        local yPos = counterY + textPadding + lineSpacing * (i - 1)

        makeLuaText(textTag, initialLabel, counterWidth - textPadding * 2, counterX + textPadding, yPos)
        setTextSize(textTag, fontSize)
        setTextFont(textTag, fontName)
        setTextColor(textTag, def.color)
        setTextBorder(textTag, borderSize, '000000')
        setTextAlignment(textTag, 'left')
        addLuaText(textTag)
        setObjectCamera(textTag, 'hud')

        judgementTexts[def.name] = textTag
    end
end

-- Reset all judgment counters
local function resetJudgmentCounters()
    tier1Count = 0
    tier2Count = 0
    tier3Count = 0
    tier4Count = 0
    tier5Count = 0
    tier6Count = 0
    tier7Count = 0
    missCount = 0
    updateJudgmentTexts()
end

-- Classify hit based on timing offset for Wife3/osu!mania
local function classifyHit(noteDiff)
    local absOffset = math.abs(noteDiff)

    if scoringSystem == 'OsuMania' or scoringSystem == 'OsuManiaV2' then
        -- osu!mania windows using OD from the scoring system
        local od = getVar('osu_od') or getVar('osuv2_od') or 8
        if absOffset <= 16 then
            return 1 -- MAX
        elseif absOffset <= (64 - 3 * od) then
            return 2 -- 300
        elseif absOffset <= (97 - 3 * od) then
            return 3 -- 200
        elseif absOffset <= (127 - 3 * od) then
            return 4 -- 100
        else
            return 5 -- 50
        end
    elseif scoringSystem == 'ITG' then
        -- ITG windows (default scale 1.0: 22.5, 45, 90, 135, 180)
        if absOffset <= 22.5 then
            return 1 -- Fantastic
        elseif absOffset <= 45 then
            return 2 -- Excellent
        elseif absOffset <= 90 then
            return 3 -- Great
        elseif absOffset <= 135 then
            return 4 -- Decent
        else
            return 5 -- Way Off
        end
    elseif scoringSystem == 'Ruthless' then
        -- Ruthless windows (10, 20, 30, 40, 50, 75, 100)
        if absOffset <= 10 then
            return 1 -- Flawless
        elseif absOffset <= 20 then
            return 2 -- Precise
        elseif absOffset <= 30 then
            return 3 -- Great
        elseif absOffset <= 40 then
            return 4 -- Good
        elseif absOffset <= 50 then
            return 5 -- Ok
        elseif absOffset <= 75 then
            return 6 -- Sloppy
        else
            return 7 -- Barely
        end
    elseif scoringSystem == 'IIDX' then
        -- IIDX windows (16.67, 33.33, 66.67, 100, 180)
        if absOffset <= 16.67 then
            return 1 -- PGreat
        elseif absOffset <= 33.33 then
            return 2 -- Great
        elseif absOffset <= 66.67 then
            return 3 -- Good
        elseif absOffset <= 100 then
            return 4 -- Bad
        else
            return 5 -- Awful
        end
    elseif scoringSystem == 'O2Jam' then
        -- O2Jam windows (cool ≤ 33ms, good ≤ 67ms, bad ≤ 100ms)
        if absOffset <= 33 then
            return 1 -- Cool
        elseif absOffset <= 67 then
            return 2 -- Good
        else
            return 3 -- Bad
        end
    elseif scoringSystem == 'DJMAX' then
        -- DJMAX windows (MAX100% ≤ 16ms, MAX90% ≤ 33ms, GOOD ≤ 66ms, BAD ≤ 100ms)
        if absOffset <= 16 then
            return 1 -- MAX 100%
        elseif absOffset <= 33 then
            return 2 -- MAX 90%
        elseif absOffset <= 66 then
            return 3 -- Good
        else
            return 4 -- Bad
        end
    elseif scoringSystem == 'Quaver' then
        -- Quaver windows (Standard: 18, 43, 76, 106, 127)
        if absOffset <= 18 then
            return 1 -- Marvelous
        elseif absOffset <= 43 then
            return 2 -- Perfect
        elseif absOffset <= 76 then
            return 3 -- Great
        elseif absOffset <= 106 then
            return 4 -- Good
        else
            return 5 -- Okay
        end
    else
        -- Wife3 windows
        if absOffset <= 22 then
            return 1 -- Marvelous
        elseif absOffset <= 45 then
            return 2 -- Perfect
        elseif absOffset <= 90 then
            return 3 -- Great
        elseif absOffset <= 135 then
            return 4 -- Good
        else
            return 5 -- Bad
        end
    end
end

-- ========================================
-- PSYCH ENGINE CALLBACKS
-- ========================================

function onCreate()
    local setting = getModSetting('scoring_showJudgementCounter')
    if setting ~= nil then
        counterEnabled = setting
    end
    detectScoringSystem()
end

function onCreatePost()
    if not counterEnabled then return end
    createJudgmentCounter()
    resetJudgmentCounters()
end

function onSongStart()
    resetJudgmentCounters()
end

function onUpdatePost(elapsed)
    if not counterEnabled then return end

    -- osu!mania: read counters directly from the scoring system
    -- This ensures tail release judgements (with 1.5x lenient windows) are counted correctly
    if scoringSystem == 'OsuMania' and osuAvailable then
        tier1Count = getVar('osu_maxHits') or 0
        tier2Count = getVar('osu_300Hits') or 0
        tier3Count = getVar('osu_200Hits') or 0
        tier4Count = getVar('osu_100Hits') or 0
        tier5Count = getVar('osu_50Hits') or 0
        missCount = getProperty('songMisses') or 0
    elseif scoringSystem == 'OsuManiaV2' and osuv2Available then
        tier1Count = getVar('osuv2_maxHits') or 0
        tier2Count = getVar('osuv2_300Hits') or 0
        tier3Count = getVar('osuv2_200Hits') or 0
        tier4Count = getVar('osuv2_100Hits') or 0
        tier5Count = getVar('osuv2_50Hits') or 0
        missCount = getProperty('songMisses') or 0
    end

    updateJudgmentTexts()
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if not counterEnabled then return end
    if isSustainNote then
        return
    end

    -- osu!mania: counters are read from the scoring system in onUpdatePost
    -- (includes tail judgements with 1.5x lenient windows)
    if (scoringSystem == 'OsuMania' and osuAvailable) or (scoringSystem == 'OsuManiaV2' and osuv2Available) then
        return
    end

    -- Psych mode: read the engine's own rating
    -- Other systems: classify via timing windows
    if scoringSystem == 'Psych' then
        local rating = getPropertyFromGroup('notes', id, 'rating')

        if rating == 'sick' then
            tier1Count = tier1Count + 1
        elseif rating == 'good' then
            tier2Count = tier2Count + 1
        elseif rating == 'bad' then
            tier3Count = tier3Count + 1
        elseif rating == 'shit' then
            tier4Count = tier4Count + 1
        end
    else
        local noteDiff = math.abs(getPropertyFromGroup('notes', id, 'strumTime') - getSongPosition())
        local tier = classifyHit(noteDiff)

        if tier == 1 then
            tier1Count = tier1Count + 1
        elseif tier == 2 then
            tier2Count = tier2Count + 1
        elseif tier == 3 then
            tier3Count = tier3Count + 1
        elseif tier == 4 then
            tier4Count = tier4Count + 1
        elseif tier == 5 then
            tier5Count = tier5Count + 1
        elseif tier == 6 then
            tier6Count = tier6Count + 1
        elseif tier == 7 then
            tier7Count = tier7Count + 1
        end
    end
end

function noteMiss(id, direction, noteType, isSustainNote)
    if not counterEnabled then return end

    -- osu!mania: miss count is read from the scoring system in onUpdatePost
    if (scoringSystem == 'OsuMania' and osuAvailable) or (scoringSystem == 'OsuManiaV2' and osuv2Available) then
        return
    end

    if not isSustainNote then
        missCount = missCount + 1
    end
end

function onDestroy()
    -- Clean up
    for name, textTag in pairs(judgementTexts) do
        removeLuaText(textTag)
    end
    removeLuaSprite('judgementBg')
end

-- ========================================
-- PUBLIC API FUNCTIONS
-- ========================================

-- Function to reposition the judgment counter
function setJudgmentCounterPosition(x, y)
    counterX = x
    counterY = y

    if getProperty('judgementBg') ~= nil then
        setProperty('judgementBg.x', counterX)
        setProperty('judgementBg.y', counterY)

        -- Update text positions
        local defs = getJudgmentDefinitions()
        local textY = counterY + textPadding
        for i, def in ipairs(defs) do
            local textTag = 'judgementText_' .. def.name
            setProperty(textTag .. '.x', counterX + textPadding)
            setProperty(textTag .. '.y', textY)
            textY = textY + lineSpacing
        end
    end
end

-- Function to set background transparency
function setJudgmentCounterAlpha(alpha)
    bgAlpha = math.max(0, math.min(1, alpha))
    if getProperty('judgementBg') ~= nil then
        setProperty('judgementBg.alpha', bgAlpha)
    end
end

-- Function to show/hide the judgment counter
function setJudgmentCounterVisible(visible)
    local alpha = visible and bgAlpha or 0
    local textAlpha = visible and 1 or 0

    if getProperty('judgementBg') ~= nil then
        setProperty('judgementBg.alpha', alpha)

        for name, textTag in pairs(judgementTexts) do
            setProperty(textTag .. '.alpha', textAlpha)
        end
    end
end

-- Function to get current judgment counts (for other scripts)
function getJudgmentCounterData()
    return getJudgmentCounts()
end
