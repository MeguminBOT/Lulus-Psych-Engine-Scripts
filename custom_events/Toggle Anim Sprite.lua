--[[

>>> Simple Event for Psych Engine to toggle animated sprites on and off. // AutisticLulu

Value 1:
	Object Tag, Animation Tag (Optional)

Value 2:
	On or Off
]]

function onEvent(name, value1, value2)
	if name == 'Toggle Anim Sprite' or name == 'Toggle_Anim_Sprite' then
		local spriteName, animName = value1:match("([^,]+),?(.*)")
		if value2 == 'on' then
			setProperty(spriteName .. '.visible', true)
			-- If animName is provided (there was a comma in value1)
			if animName and animName ~= "" then
				playAnim(spriteName, animName, true)
			end
		elseif value2 == 'off' then
			setProperty(spriteName .. '.visible', false)
		end
	end
end