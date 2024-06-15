--[[

>>> Window Name. Including shuffling the Window name letters or words // AutisticLulu
>>> Just a fun dumb thing.

Value 1 (Window Name):
	The applications Window Name, can be anything you want.
	(Example: Haha Funny Event)

Value 1 (Window Name Shuffle):
	Shuffle the Window Name [Letters/Words].
	(Example: Letters)

Value 2 (Both Events):
	Toggle the event. [On/Off]
	(Example: On)

]]

-- Shuffles the Window Name based on the specified shuffle type.
local function shuffleString(str, shuffleType)
	-- Create an empty table to store the letters or words.
	local t = {}

	-- Split the string into individual characters.
	if shuffleType == 'Letters' then
		for i = 1, #str do
			t[i] = str:sub(i,i)
		end

	-- Split the string into words.
	elseif shuffleType == 'Words' then
		for word in str:gmatch('%S+') do
			table.insert(t, word)
		end
	end
	
	-- Shuffle the table.
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end

	-- Concatenate the shuffled table elements.
	if shuffleType == 'Letters' then
		return table.concat(t)

	elseif shuffleType == 'Words' then
		return table.concat(t, ' ')
	end
end

-- Set the shuffle type.
local function setShuffleMode(shuffleType)
	shuffleTimer = 0
	shuffleDelay = 0.1
	onUpdate = function(elapsed)
		shuffleTimer = shuffleTimer + elapsed
		if shuffleTimer >= shuffleDelay then
			shuffleTimer = shuffleTimer - shuffleDelay
			
			local title = getPropertyFromClass('openfl.Lib', 'application.window.title')
			local shuffledTitle = shuffleString(title, shuffleType)
			setPropertyFromClass('openfl.Lib', 'application.window.title', shuffledTitle)
		end
	end
end

-- This function is called when an event occurs.
function onEvent(name, value1, value2)
	if name == 'Window Name' or name == 'Window_Name' then
		if value2 == 'On' then
			setPropertyFromClass('openfl.Lib', 'application.window.title', value1)

		elseif value2 == 'Off' then
			disableEvent()
		end

	elseif name == 'Window Name Shuffle' or name == 'Window_Name_Shuffle' then
		if value2 == 'On' then
			if value1 == 'Letters' or value1 == 'Words' then
				setShuffleMode(value1)
			end

		elseif value2 == 'Off' then
			disableEvent()
		end
	end
end

-- When the script is destroyed.
function onDestroy()
	disableEvent()
end

-- Disables the event and sets the window title back to Psych Engine.
function disableEvent()
	setPropertyFromClass('openfl.Lib', 'application.window.title', 'Psych Engine')
	onUpdate = nil
end