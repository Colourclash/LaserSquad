CharacterPixelsAddr = 0xe8df
CharacterMapAddr = 0xd6bf
FontPixelsAddr = 0xb239

ColourFontsEnabled = true

function SetColourFonts(enabled)
	ColourFontsEnabled = enabled
end

-- Draw 8x8 character
function DrawCharacterToView(graphicsView, charIndex, attrib, x, y)

	local charPixels = GetMemPtr(CharacterPixelsAddr + charIndex * 8)
	DrawZXBitImage(graphicsView, charPixels, x, y, 1, 1, attrib)
end

-- Draw 2x2 block of 4 characters. Block is 16 pixels high and 16 pixels wide.
function DrawBlockToView(graphicsView, blockIndex, attrib, x, y)

	blockIndex = blockIndex * 4

	for xp=0,1 do
		for yp=0,1 do
			local charIndex = blockIndex + (yp * 2) + xp
			DrawCharacterToView(graphicsView, charIndex, attrib, x + (xp * 8), y+ (yp * 8))
		end
	end
end

-- Draw 8x8 font glyph to view
function DrawFontGlyphToView(graphicsView, glyphIndex, attrib, x, y)
	local charPixels = GetMemPtr(FontPixelsAddr + glyphIndex * 8)
	if ColourFontsEnabled then
		DrawZXBitImage(graphicsView, charPixels, x, y, 1, 1, attrib) -- draw 8 x 8 character
	else
		DrawZXBitImage(graphicsView, charPixels, x, y, 1, 1, 0xe)
	end
end

-- Draw double-height 8x16 font glyph to view using 8x8 font
function DrawDoubleHeightFontGlyphToView(graphicsView, glyphIndex, attrib1, attrib2, x, y)
	local attrib = attrib1
	for yp = 0, 7 do
		local charPixels = GetMemPtr(FontPixelsAddr + glyphIndex * 8 + yp)
		if yp == 4 then
			attrib = attrib2
		end
		DrawZXBitImageFineY(graphicsView, charPixels, x, y + (yp * 2), 1, 1, attrib) -- 8 x 1 pixel strip
		DrawZXBitImageFineY(graphicsView, charPixels, x, y + (yp * 2) + 1, 1, 1, attrib) -- 8 x 1 pixel strip
	end
end
