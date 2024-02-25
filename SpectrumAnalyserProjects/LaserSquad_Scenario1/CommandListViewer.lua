-- Addresses in Spectrum RAM
StringTable = 0xac06
CommandListTable = 0xa64e
DrawCmdListFunc = 0x676c
DrawCmdListFuncDblHeight = 0x675e
CurDrawListBase = CommandListTable 	-- address of current cmd list being drawn
CurDrawListCmd = CommandListTable 	-- address of current individual cmd being processed
CurString = StringTable				-- address of current string being drawn

-- Lookup a string from the string table. Special characters will be ignored
function GetString(index, doubleHeight)
	local str = ""
	local curPtr = CmdListRenderer:skipEntries(StringTable, index)
	while true do
		local char = ReadByte(curPtr)
		if char == 0x7c then
			return str
		end
		if char == 0xf6 then
			curPtr = curPtr + 1 
			if doubleHeight then
				curPtr = curPtr + 1 
			end
		end	
		if char > 31 and char < 96 and char ~= 0x2f then
			--print(string.char(char) .. " = " .. tostring(char))
			str = str .. string.char(char)
		end
		curPtr = curPtr + 1 
	end
end

CmdListRenderer = 
{
	-- command related
	treatAsText = false,

	-- drawing state
	xp = 0,
	yp = 0,
	drawVertical = false,
	attrib1 = 0xf,
	attrib2 = 0xf,
	lastSetXPosCmd = 0,
	doubleHeight = false,

	reset = function(self)
		self.treatAsText = false

		-- reset drawing state
		self.xp = 0
		self.yp = 0
		self.drawVertical = false
		self.attrib1 = 0xf
		self.attrib2 = 0xf
		self.lastSetXPosCmd = 0
		self.doubleHeight = false
	end,

	skipEntries = function(self, cmdPtr, numToSkip)
		for s=1, numToSkip do
			repeat
				local char = ReadByte(cmdPtr)
				cmdPtr = cmdPtr + 1
			until char == 0x7c -- "|" character
		end
		return cmdPtr
	end,

	processNextCommand = function(self, cmd, cmdPtr)
		cmdPtr = cmdPtr + 1
		local isCommand = true
		if cmd > 0xf1 then
			if cmd == 0xf3 then 
				-- single height font (think this might do more?)
				--self.doubleHeight = false
			elseif cmd == 0xf4 then
				-- ?
			elseif cmd == 0xf5 then 
				-- set cursor position
				self.yp = ReadByte(cmdPtr) * 8
				cmdPtr = cmdPtr + 1
				local v = ReadByte(cmdPtr) * 8
				self.xp = ReadByte(cmdPtr) * 8
				self.lastSetXPosCmd = self.xp
				cmdPtr = cmdPtr + 1
			elseif cmd == 0xf6 then
				-- change attribute colour
				self.attrib1 = ReadByte(cmdPtr)
				cmdPtr = cmdPtr + 1
				if self.doubleHeight == true then
					self.attrib2 = ReadByte(cmdPtr)
					cmdPtr = cmdPtr + 1
				else
					self.attrib2 = self.attrib1
				end
			elseif cmd == 0xf7 then
				-- draw vertically
				self.drawVertical = true
			elseif cmd == 0xf8 then
				-- draw horizontally
				self.drawVertical = false
			elseif cmd == 0xf9 then
				-- single height
				self.doubleHeight = false
			elseif cmd == 0xfa then
				-- set double height font
				self.doubleHeight = true
			elseif cmd == 0xfb then
				-- treat all following data as string/font data
				self.treatAsText = true
			end
		elseif cmd == 0x2f then
			-- move down a row
			if self.doubleHeight == true then
				self.yp = self.yp + 16
			else
				self.yp = self.yp + 8
			end
			self.xp = self.lastSetXPosCmd
		else
			-- not a command. byte will be treated as a string or character lookup
			isCommand = false
		end
		return isCommand, cmdPtr
	end,

	render = function(self, graphicsView, cmdListIndex, x, y, doubleHeight, numBytes)
		self:reset()
		self.doubleHeight = doubleHeight

		local cmdPtr = self:skipEntries(CommandListTable, cmdListIndex)
		local isCommand = nil

		CurDrawListBase = cmdPtr

		while true do
			local cmd = ReadByte(cmdPtr)
			if cmd == 0x7c then
				return -- we have hit the terminating "|"" character
			end

			isCommand, cmdPtr = self:processNextCommand(cmd, cmdPtr)

			if isCommand == false then
				if self.treatAsText == true then
					DrawFontGlyphToView(graphicsView, cmd - 32, self.attrib1, self.xp + x, self.yp + y)
					if self.drawVertical == true then
						self.yp = self.yp + 8
					else
						self.xp = self.xp + 8
					end
				else
					self:drawStringInternal(graphicsView, cmd, StringTable, x, y)
				end
			end

			bytesProcessed = cmdPtr - CurDrawListBase
			if numBytes > 0 and bytesProcessed >= numBytes then
				CurDrawListCmd = cmdPtr
				return
			end
		end
	end,


	drawString = function(self, graphicsView, stringIndex, stringTableAddr, x, y)
		self:reset()
		CurString = self:drawStringInternal(graphicsView, stringIndex, stringTableAddr, x, y)
	end,

	drawStringInternal = function(self, graphicsView, stringIndex, stringTableAddr, x, y)
		local cmdPtr = self:skipEntries(stringTableAddr, stringIndex)
		local isCommand = nil
		local stringStart = cmdPtr

		while true do
			local cmd = ReadByte(cmdPtr)
			
			if cmd == 0x7c then
				return stringStart -- we have hit the terminating "|"" character
			end

			isCommand, cmdPtr = self:processNextCommand(cmd, cmdPtr)

			if isCommand == false then
				if self.doubleHeight == true then
					DrawDoubleHeightFontGlyphToView(graphicsView, cmd - 32, self.attrib1, self.attrib2, self.xp + x, self.yp + y)
				else			
					DrawFontGlyphToView(graphicsView, cmd - 32, self.attrib1, self.xp + x, self.yp + y)
				end
				self.xp = self.xp + 8
			end
		end
	end,

	-- Get a text summary of a command list
	getTextSummary = function(self, cmdListIndex, doubleHeight)
		local str = ""
		self:reset()
		self.doubleHeight = doubleHeight

		local cmdPtr = self:skipEntries(CommandListTable, cmdListIndex)
		local isCommand = nil

		while true do
			local cmd = ReadByte(cmdPtr)
			if cmd == 0x7c then
				return str
			end

			isCommand, cmdPtr = self:processNextCommand(cmd, cmdPtr)

			if isCommand == false then
				if self.treatAsText == true then
					-- ?
				else
					local s = GetString(cmd, doubleHeight)
					if s ~= "" then
						str = str .. s .. " "
					end
				end
			end
		end
	end,
}

-- Find and draw all calls to draw command lists in Spectrum RAM
function DrawCmdListCalls(doubleHeight)
	-- 3e NN 		LD NN
	-- cd XX XX		CALL XXXX
	local funcAddr
	if doubleHeight then
		funcAddr = DrawCmdListFuncDblHeight
	else
		funcAddr = DrawCmdListFunc
	end
	local curPtr = 0x5b00
	while curPtr < 0xffff do
		local byte1 = ReadByte(curPtr)
		if byte1 == 0x3e then
			-- found possible LD instruction
			local byte3 = ReadByte(curPtr + 2)
			if byte3 == 0xcd then
				-- found possible CALL instruction
				local word = ReadWord(curPtr + 3)
				if word == funcAddr then
					local byte2 = ReadByte(curPtr + 1)
					imgui.Text("Cmd list " .. tostring(byte2) .. " at ")
					DrawAddressLabel(curPtr)
					imgui.SameLine(500)
					imgui.Text(CmdListRenderer:getTextSummary(byte2, doubleHeight))
				end
			end
		end
		curPtr = curPtr + 1
	end
end

CommandListViewer = 
{
	name = "Command List Viewer",
	cmdListNum = 1,
	numBytesToDraw = 0,
	stringNum = 1,
	doubleHeight = false,
	colourFonts = true,
	drawCalls = false,

	onAdd = function(self)
		self.graphicsView = CreateZXGraphicsView(256, 256)
		ClearGraphicsView(self.graphicsView, 0xff202020)
		SetColourFonts(self.colourFonts)
		CmdListRenderer:drawString(self.graphicsView, self.stringNum, StringTable, 0, 0)
		CmdListRenderer:render(self.graphicsView, self.cmdListNum, 0, 64, false, 0)
	end,

	onDrawUI = function(self)
		local changedStringNum = false
		changedStringNum, self.stringNum = imgui.InputInt("String Index", self.stringNum)

		if self.stringNum < 1 then
			self.stringNum = 1
		end
		if self.stringNum > 168 then
			self.stringNum = 168
		end

		imgui.Text("Cur String")
		DrawAddressLabel(CurString)

		local changedcmdListNum = false
		changedcmdListNum, self.cmdListNum = imgui.InputInt("Cmd List Num", self.cmdListNum)

		if self.cmdListNum < 1 then
			self.cmdListNum = 1
		end

		imgui.Text("Cmd List")
		DrawAddressLabel(CurDrawListBase)

		local colourFontsChanged = false
		colourFontsChanged, self.colourFonts = imgui.Checkbox("Colour Fonts", self.colourFonts)
		if colourFontsChanged then
			SetColourFonts(self.colourFonts)
		end

		local dblHeightchanged = false
		dblHeightchanged, self.doubleHeight = imgui.Checkbox("Double Height", self.doubleHeight)


		local changedNumBytes = false
		changedNumBytes, self.numBytesToDraw = imgui.InputInt("Num Cmd Bytes To Process", self.numBytesToDraw)

		if self.numBytesToDraw < 0 then
			self.numBytesToDraw = 0
		end
		if self.numBytesToDraw > 0 then
			imgui.Text("Cur Draw List Cmd")
			DrawAddressLabel(CurDrawListCmd)
		end

		if changedcmdListNum or changedNumBytes or changedStringNum or dblHeightchanged or colourFontsChanged then
			ClearGraphicsView(self.graphicsView, 0xff202020)
			CmdListRenderer:drawString(self.graphicsView, self.stringNum, StringTable, 0, 0)
			CmdListRenderer:render(self.graphicsView, self.cmdListNum, 0, 64, self.doubleHeight, self.numBytesToDraw)
			print("Cmd list summary is '" .. CmdListRenderer:getTextSummary(self.cmdListNum, self.doubleHeight, 0) .. "'")
		end

		-- Update and draw to screen
		DrawGraphicsView(self.graphicsView)
		
		local drawCallsChanged = false
		drawCallsChanged, self.drawCalls = imgui.Checkbox("Show Draw Calls", self.drawCalls)

		if self.drawCalls == true then
			imgui.Text("Cmd List calls:")
			DrawCmdListCalls(false)
			imgui.Text("\nCmd List double height calls:")
			DrawCmdListCalls(true)
		end
	end,

}

-- Initialise the template viewer
print("Laser Squad Command List Viewer Initialised")
AddViewer(CommandListViewer);