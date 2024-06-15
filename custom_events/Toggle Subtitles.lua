--[[

>>> Simple event to toggle subtitles on and off. // AutisticLulu

(Requires the following code to be inside the lua for your stage or song:
#------------------------------------------------------------------------#
	local function createSubtitles()
		makeLuaText('SubtitleText', '', 1200, 50, 545)
		setTextSize('SubtitleText', 45)
		setTextFont('SubtitleText', 'YOURFONTNAME.ttf')
		setObjectCamera('SubtitleText', 'camOther')

		local subTextWidth = getTextWidth('SubtitleText')

		makeLuaSprite('SubtitleTextBG', nil, 0, 535)
		makeGraphic(SubtitleTextBG, subTextWidth, 72, '000000')
		setObjectCamera('SubtitleTextBG', 'camOther')
		setProperty('SubtitleTextBG.alpha', 0)

		addLuaSprite('SubtitleTextBG', true)
		addLuaText('SubtitleText')
	end

	function onCreate()
		createSubtitles()
	end
#------------------------------------------------------------------------#

Value 1:
	Subtitle Text
	(Example: "Hello, world!")
	
	Leave value 1 empty to remove subtitles.
Value 2:
	Colour [HEX]
	(Example: 9DCFED) 

	If value 2 isn't specified, the color will default to white.
]]

function onEvent(name, value1, value2)
	if name == 'Toggle Subtitles' then
		if value1 == nil or value1 == '' or value1 == ' ' then
			setTextString('SubtitleText', '')
			setProperty('SubtitleTextBG.alpha', 0)
		else
			setProperty('SubtitleTextBG.alpha', 0.5)
			setProperty('SubtitleText.alpha', 1)
			setTextString('SubtitleText', value1)
			setTextColor('SubtitleText', value2)
		end
	end
end