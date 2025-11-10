function onCreate()
	makeLuaSprite('blackBG', '', 0, 0)
	makeGraphic('blackBG', screenWidth * 2, screenHeight * 2, '#212121')
	screenCenter('blackBG', 'xy')
	setScrollFactor('blackBG', 0, 0)
	addLuaSprite('blackBG', true)
end