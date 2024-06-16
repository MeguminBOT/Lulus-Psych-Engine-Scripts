--[[
>>> Toggleable Add Camera Zoom Event for Psych Engine. // AutisticLulu
	Triggers Add Camera Zoom events on every step or optionally between a set amount of steps.
	
	Confirmed compatible Psych Engine Versions:
	0.6.x, 0.7.X

Value 1:
    Parameters: "Stage Zoom, Hud Zoom, Number of steps *OPTIONAL*"
    (Example: 0.015, 0.03)
    (Example: 0.015, 0.03, 2)

Value 2:
    Parameters: [On/Off]
    (Example: On)
]]

-- Define local variables.
local isActive = false
local gameZoom, hudZoom, numSteps = nil, nil, nil
local stepTrigger = 1
local stepCount = 0

-- Helper function: Parses the gameZoom, hudZoom, and numSteps.
local function parseZoomValues(value)
    return value:match('([^,]+),%s*([^,]+),?%s*([^,]*)')
end

function onEvent(name, value1, value2)
    if (name == 'Toggle Zoom on Step' or name == 'Toggle_Zoom_on_Step') and cameraZoomOnStep then
        gameZoom, hudZoom, numSteps = parseZoomValues(value1)
        
        stepTrigger = tonumber(numSteps) or 1 -- Default to 1 if not specified or invalid
        isActive = (value2 == 'On')
    end
end

function onStepHit()
    stepCount = stepCount + 1
    if isActive and stepCount % stepTrigger == 0 and gameZoom and hudZoom then
        triggerEvent("Add Camera Zoom", gameZoom, hudZoom)
    end
end
