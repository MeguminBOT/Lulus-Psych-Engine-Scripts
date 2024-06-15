--[[

>>> Simple Event for Psych Engine to toggle sprites on and off. // AutisticLulu

Value 1:
	Object Tag

Value 2:
	On or Off
]]

function onEvent(name, value1, value2)
	if name == 'Toggle Sprite' or name == 'Toggle_Sprite' then
		if value2 == 'on' then
			setProperty(value1 .. '.visible', true)
		elseif value2 == 'off' then
			setProperty(value1 .. '.visible', false)
		end
	end
end