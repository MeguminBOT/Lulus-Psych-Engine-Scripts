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

-- Scalable window settings (loaded from settings.json, used as classifyHit fallback)
local wife3JudgeScale = 1.0
local itgWindowScale = 1.0
local ruthlessPerfectWindow = 10.0
local quaverWindows = { 18, 43, 76, 106, 127 }

-- Quaver difficulty presets (Marvelous, Perfect, Great, Good, Okay)
local QUAVER_DIFFICULTIES = {
    Peaceful   = { 23, 57, 101, 141, 169 },
    Lenient    = { 21, 52, 91, 128, 153 },
    Chill      = { 19, 47, 83, 116, 139 },
    Standard   = { 18, 43, 76, 106, 127 },
    Strict     = { 16, 39, 69, 96, 127 },
    Tough      = { 14, 35, 62, 87, 127 },
    Extreme    = { 13, 32, 57, 79, 127 },
    Impossible = { 8, 20, 35, 49, 127 }
}

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
local cbCount = 0

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
local o2jamAvailable = false

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

-- Check if O2Jam scoring system is available
local function checkO2JamAvailability()
    o2jamAvailable = (getVar('o2jam_enabled') ~= nil and getVar('o2jam_enabled') == true)
    return o2jamAvailable
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
    checkO2JamAvailability()

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
        elseif o2jamAvailable then
            scoringSystem = 'O2Jam'
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
                { count = cbCount },
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
    cbCount = 0
    updateJudgmentTexts()
end

-- Classify hit based on timing offset (fallback when scoring system script isn't loaded)
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
        -- ITG windows (base: 21.5, 43, 102, 135, 180 * windowScale)
        if absOffset <= 21.5 * itgWindowScale then
            return 1 -- Fantastic
        elseif absOffset <= 43 * itgWindowScale then
            return 2 -- Excellent
        elseif absOffset <= 102 * itgWindowScale then
            return 3 -- Great
        elseif absOffset <= 135 * itgWindowScale then
            return 4 -- Decent
        else
            return 5 -- Way Off
        end
    elseif scoringSystem == 'Ruthless' then
        -- Ruthless windows (perfectWindow, 20, 30, 40, 50, 75, 100)
        if absOffset <= ruthlessPerfectWindow then
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
        -- IIDX fixed windows (16.67, 33.33, 66.67, 100, 180)
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
        -- O2Jam fixed fallback windows (cool <= 33ms, good <= 67ms, bad <= 100ms)
        if absOffset <= 33 then
            return 1 -- Cool
        elseif absOffset <= 67 then
            return 2 -- Good
        else
            return 3 -- Bad
        end
    elseif scoringSystem == 'DJMAX' then
        -- DJMAX fixed windows (MAX100% <= 16ms, MAX90% <= 33ms, GOOD <= 66ms, BAD <= 100ms)
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
        -- Quaver windows (from difficulty preset)
        if absOffset <= quaverWindows[1] then
            return 1 -- Marvelous
        elseif absOffset <= quaverWindows[2] then
            return 2 -- Perfect
        elseif absOffset <= quaverWindows[3] then
            return 3 -- Great
        elseif absOffset <= quaverWindows[4] then
            return 4 -- Good
        else
            return 5 -- Okay
        end
    else
        -- Wife3 windows (scaled by judge scale)
        if absOffset <= 22 * wife3JudgeScale then
            return 1 -- Marvelous
        elseif absOffset <= 45 * wife3JudgeScale then
            return 2 -- Perfect
        elseif absOffset <= 90 * wife3JudgeScale then
            return 3 -- Great
        elseif absOffset <= 135 * wife3JudgeScale then
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
    -- Load scalable window settings (for classifyHit fallback)
    local JUDGE_WINDOWS = { 4.0, 3.0, 2.0, 1.0, 0.9, 0.75, 0.6, 0.5, 0.4 }
    local judgePreset = getModSetting('wife3_judgePreset')
    if judgePreset ~= nil and judgePreset >= 1 and judgePreset <= 9 then
        wife3JudgeScale = JUDGE_WINDOWS[judgePreset]
    end
    local judgeScale = getModSetting('wife3_judgeScale')
    if judgeScale ~= nil and judgeScale >= 0.009 and judgeScale <= 4.0 then
        wife3JudgeScale = judgeScale
    end

    local itgScale = getModSetting('itg_windowScale')
    if itgScale ~= nil and itgScale >= 0.1 and itgScale <= 4.0 then
        itgWindowScale = itgScale
    end

    local rPerfWin = getModSetting('ruthless_perfectWindow')
    if rPerfWin ~= nil and rPerfWin >= 0.0 and rPerfWin <= 25.0 then
        ruthlessPerfectWindow = rPerfWin
    end

    local qDiff = getModSetting('quaver_difficulty')
    if qDiff ~= nil and QUAVER_DIFFICULTIES[qDiff] ~= nil then
        quaverWindows = QUAVER_DIFFICULTIES[qDiff]
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

    -- Read hit tier counters from each scoring system (always matches their exact windows)
    -- Miss count is tracked separately in noteMiss (songMisses includes sustain pieces)
    if scoringSystem == 'OsuMania' and osuAvailable then
        tier1Count = getVar('osu_maxHits') or 0
        tier2Count = getVar('osu_300Hits') or 0
        tier3Count = getVar('osu_200Hits') or 0
        tier4Count = getVar('osu_100Hits') or 0
        tier5Count = getVar('osu_50Hits') or 0
    elseif scoringSystem == 'OsuManiaV2' and osuv2Available then
        tier1Count = getVar('osuv2_maxHits') or 0
        tier2Count = getVar('osuv2_300Hits') or 0
        tier3Count = getVar('osuv2_200Hits') or 0
        tier4Count = getVar('osuv2_100Hits') or 0
        tier5Count = getVar('osuv2_50Hits') or 0
    elseif scoringSystem == 'Wife3' and wife3Available then
        tier1Count = getVar('wife3_marvelousHits') or 0
        tier2Count = getVar('wife3_perfectHits') or 0
        tier3Count = getVar('wife3_greatHits') or 0
        tier4Count = getVar('wife3_goodHits') or 0
        tier5Count = getVar('wife3_badHits') or 0
    elseif scoringSystem == 'ITG' and itgAvailable then
        tier1Count = getVar('itg_fantasticHits') or 0
        tier2Count = getVar('itg_excellentHits') or 0
        tier3Count = getVar('itg_greatHits') or 0
        tier4Count = getVar('itg_decentHits') or 0
        tier5Count = getVar('itg_wayOffHits') or 0
    elseif scoringSystem == 'Ruthless' and ruthlessAvailable then
        tier1Count = getVar('ruthless_flawlessHits') or 0
        tier2Count = getVar('ruthless_preciseHits') or 0
        tier3Count = getVar('ruthless_greatHits') or 0
        tier4Count = getVar('ruthless_goodHits') or 0
        tier5Count = getVar('ruthless_okHits') or 0
        tier6Count = getVar('ruthless_sloppyHits') or 0
        tier7Count = getVar('ruthless_barelyHits') or 0
        cbCount = getVar('ruthless_comboBreaks') or 0
    elseif scoringSystem == 'IIDX' and iidxAvailable then
        tier1Count = getVar('iidx_pgreatHits') or 0
        tier2Count = getVar('iidx_greatHits') or 0
        tier3Count = getVar('iidx_goodHits') or 0
        tier4Count = getVar('iidx_badHits') or 0
        tier5Count = getVar('iidx_awfulHits') or 0
    elseif scoringSystem == 'DJMAX' and djmaxAvailable then
        tier1Count = getVar('djmax_max100Hits') or 0
        tier2Count = getVar('djmax_max90Hits') or 0
        tier3Count = getVar('djmax_goodHits') or 0
        tier4Count = getVar('djmax_badHits') or 0
    elseif scoringSystem == 'O2Jam' and o2jamAvailable then
        tier1Count = getVar('o2jam_coolHits') or 0
        tier2Count = getVar('o2jam_goodHits') or 0
        tier3Count = getVar('o2jam_badHits') or 0
    elseif scoringSystem == 'Quaver' and quaverAvailable then
        tier1Count = getVar('quaver_marvelousHits') or 0
        tier2Count = getVar('quaver_perfectHits') or 0
        tier3Count = getVar('quaver_greatHits') or 0
        tier4Count = getVar('quaver_goodHits') or 0
        tier5Count = getVar('quaver_okayHits') or 0
    end

    updateJudgmentTexts()
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if not counterEnabled then return end
    if isSustainNote then return end

    -- Scoring systems with available scripts: counters are read in onUpdatePost
    if scoringSystem ~= 'Psych' then
        if (scoringSystem == 'OsuMania' and osuAvailable)
            or (scoringSystem == 'OsuManiaV2' and osuv2Available)
            or (scoringSystem == 'Wife3' and wife3Available)
            or (scoringSystem == 'ITG' and itgAvailable)
            or (scoringSystem == 'Ruthless' and ruthlessAvailable)
            or (scoringSystem == 'IIDX' and iidxAvailable)
            or (scoringSystem == 'DJMAX' and djmaxAvailable)
            or (scoringSystem == 'O2Jam' and o2jamAvailable)
            or (scoringSystem == 'Quaver' and quaverAvailable) then
            return
        end

        -- Fallback: scoring system selected but script not loaded, classify locally
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
        return
    end

    -- Psych mode: read the engine's own rating
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
end

function noteMiss(id, direction, noteType, isSustainNote)
    if not counterEnabled then return end

    -- Count non-sustain misses directly
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
