CurDrawListBase = CommandListTable 	-- address of current cmd list being drawn
CurDrawListCmd = CommandListTable 	-- address of current individual cmd being processed
CurString = StringTable				-- address of current string being drawn

-- Constants
CmdListMaxIndex = 109
StringMaxIndex = 168

-- Store which command lists are designed to be called with double height flag set by default
CmdListIsDoubleHeight = {}
for i=28, 40 do
	CmdListIsDoubleHeight[i] = true
end
CmdListIsDoubleHeight[69] = true
CmdListIsDoubleHeight[70] = true
CmdListIsDoubleHeight[106] = true
CmdListIsDoubleHeight[107] = true

CmdListRenderer = 
{
	-- command related
	charMode = false,

	-- drawing state
	xp = 0,
	yp = 0,
	drawVertical = false,
	colour1 = 0xf,
	colour2 = 0xf,
	lastSetXPosCmd = 0,
	doubleHeight = false,
	spaces = true, -- spaces between strings

	reset = function(self)
		self.charMode = false

		-- reset drawing state
		self.xp = 0
		self.yp = 0
		self.drawVertical = false
		self.colour1 = 0xf
		self.colour2 = 0xf
		self.lastSetXPosCmd = 0
		self.doubleHeight = false
		self.spaces = true
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
				self.spaces = false
			elseif cmd == 0xf4 then
				self.spaces = true
			elseif cmd == 0xf5 then 
				-- set cursor position
				self.yp = ReadByte(cmdPtr) * 8
				cmdPtr = cmdPtr + 1
				self.xp = ReadByte(cmdPtr) * 8
				self.lastSetXPosCmd = self.xp
				cmdPtr = cmdPtr + 1
			elseif cmd == 0xf6 then
				-- change attribute colour
				self.colour1 = ReadByte(cmdPtr)
				cmdPtr = cmdPtr + 1
				if self.doubleHeight == true then
					self.colour2 = ReadByte(cmdPtr)
					cmdPtr = cmdPtr + 1
				else
					self.colour2 = self.colour1
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
				-- treat all non-command bytes as individual characters
				self.charMode = true
			elseif cmd == 0xfc then
				-- treat all non-command bytes as string tokens
				self.charMode = false
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

			isCommand, cmdPtr = self:processNextCommand(cmd, cmdPtr, false)

			if isCommand == false then
				if self.charMode == true then
					self:drawFontGlyph(graphicsView, cmd - 32, x, y)
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
				if self.spaces then
					self.xp = self.xp + 8
				end
				return stringStart -- we have hit the terminating "|"" character
			end

			isCommand, cmdPtr = self:processNextCommand(cmd, cmdPtr, false)

			if isCommand == false then
				self:drawFontGlyph(graphicsView, cmd - 32, x, y)
			end
		end
	end,

	drawFontGlyph = function(self, graphicsView, glyphIndex, x, y)
		if self.doubleHeight == true then
			DrawDoubleHeightFontGlyphToView(graphicsView, glyphIndex, self.colour1, self.colour2, self.xp + x, self.yp + y)
		else			
			DrawFontGlyphToView(graphicsView, glyphIndex, self.colour1, self.xp + x, self.yp + y)
		end
		if self.drawVertical == true then
			self.yp = self.yp + 8
		else
			self.xp = self.xp + 8
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
				-- strip trailing and leading spaces
				str = string.gsub(str, '^%s*(.-)%s*$', '%1')
				return str
			end

			isCommand, cmdPtr = self:processNextCommand(cmd, cmdPtr)

			local addSpace = false
			if isCommand == false then
				if self.charMode == false then
					local s = self:getString(cmd, StringTable)
					if s ~= '' then
						str = str .. s
						addSpace = self.spaces
						if s == ' ' then
							addSpace = true 
						end
					end
				end
			else
				if cmd == 0x2f or cmd == 0xf5 then
					addSpace = true
				end
			end

			if addSpace == true then
				if string.sub(str, -1) ~= ' ' then
					str = str .. ' '
				end
			end
		end
	end,

	-- Get a string from the string table.
	getString = function(self, stringIndex, stringTableAddr)
		local cmdPtr = self:skipEntries(stringTableAddr, stringIndex)
		local isCommand = nil
		local stringStart = cmdPtr
		str = ""

		while true do
			local char = ReadByte(cmdPtr)
			if char == 0x7c then
				return str
			end

			isCommand, cmdPtr = self:processNextCommand(char, cmdPtr, false)

			if isCommand == false then
				if char > 31 and char < 96 then
					str = str .. string.char(char)
				end
			end
		end
	end,

	-- Set data comments for a single command
	setCommandComments = function(self, cmd, cmdPtr)
		if cmd > 0xf1 then
			if cmd == 0xf3 then 
				SetDataItemComment(cmdPtr, "[No Spaces]")
			elseif cmd == 0xf4 then
				SetDataItemComment(cmdPtr, "[Spaces]")
			elseif cmd == 0xf5 then 
				SetDataItemComment(cmdPtr, "[Position]")
				SetDataItemComment(cmdPtr + 1, "y = " .. self.yp)
				SetDataItemComment(cmdPtr + 2, "x = " .. self.xp)
			elseif cmd == 0xf6 then
				SetDataItemComment(cmdPtr, "[Colour]")
				if self.doubleHeight then
					SetDataItemComment(cmdPtr + 1, "Attrib 1")
					SetDataItemComment(cmdPtr + 2, "Attrib 2")
				else
					SetDataItemComment(cmdPtr + 1, "Attrib")
				end
			elseif cmd == 0xf7 then
				SetDataItemComment(cmdPtr, "[Vertical]")
			elseif cmd == 0xf8 then
				SetDataItemComment(cmdPtr, "[Horizontal]")
			elseif cmd == 0xf9 then	
				SetDataItemComment(cmdPtr, "[Single Height]")
			elseif cmd == 0xfa then
				SetDataItemComment(cmdPtr, "[Double Height]")
			elseif cmd == 0xfb then
				SetDataItemComment(cmdPtr, "[Char Mode]")
			elseif cmd == 0xfc then
				SetDataItemComment(cmdPtr, "[String Mode]")
			end
		elseif cmd == 0x2f then
			SetDataItemComment(cmdPtr, "[New Line]")
		else
			-- not a command. byte will be treated as a string or character lookup
			if self.charMode == false then
				if cmd == 1 then
					SetDataItemComment(cmdPtr, "{Emblem Graphic}")
				else
					SetDataItemComment(cmdPtr, "'" .. self:getString(cmd, StringTable) .. "'")
				end
			end
		end
	end,

	-- For a cmd list, set comments in the code analysis describing what each command does 
	addDataComments = function(self, cmdListIndex, doubleHeight)
		self:reset()
		self.doubleHeight = doubleHeight

		local cmdPtr = self:skipEntries(CommandListTable, cmdListIndex)
		local isCommand = nil

		SetDataItemComment(cmdPtr - 1, "--- Cmd List " .. tostring(cmdListIndex) .. " ---")

		while true do
			local cmd = ReadByte(cmdPtr)
			if cmd == 0x7c then
				return -- we have hit the terminating "|"" character
			end

			local cmdPtrTmp = cmdPtr
			isCommand, cmdPtr = self:processNextCommand(cmd, cmdPtr, true)
			self:setCommandComments(cmd, cmdPtrTmp)
		end
	end,
}

-- Find and optionally display all calls to draw command lists in the machine's RAM. 
-- Also optionally adds comments to code.
function FindCmdListCalls(doubleHeight, display, addComment)
	-- 3e NN 		LD NN
	-- cd XX XX		CALL XXXX
	local funcAddr
	if doubleHeight then
		funcAddr = DrawCmdListFuncDblHeight
	else
		funcAddr = DrawCmdListFunc
	end
	local curPtr = RAMSearchStart
	while curPtr < RAMSearchEnd do
		local byte1 = ReadByte(curPtr)
		local byte3 = ReadByte(curPtr + 2)
		if byte3 == 0xcd then
			-- found possible CALL instruction
			local word = ReadWord(curPtr + 3)
			if word == funcAddr then
				local cmdIndex = nil
				if byte1 == 0x3e then
					-- found possible LD instruction that loads the cmd list index
					cmdIndex = ReadByte(curPtr + 1)
				end
				if display then
					if cmdIndex == nil then
						imgui.Text("Unknown cmd list at ")
					else
						imgui.Text("Cmd list " .. tostring(cmdIndex) .. " at ")
					end
					DrawAddressLabel(curPtr)
					if cmdIndex ~= nil then 
						imgui.SameLine(500)
						local summary = CmdListRenderer:getTextSummary(cmdIndex, doubleHeight)
						imgui.Text("'" .. summary .. "'") 
					end
				elseif addComment then
					if cmdIndex ~= nil then 
						local summary = CmdListRenderer:getTextSummary(cmdIndex, doubleHeight)
						SetCodeItemComment(curPtr, summary)
					end
				else 
					if cmdIndex ~= nil then
						CmdListIsDoubleHeight[cmdIndex] = doubleHeight
					end
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
		self.graphicsView = CreateGraphicsView(320, 256)
		ClearGraphicsView(self.graphicsView, 0xff202020)
		SetColourFonts(self.colourFonts)
		CmdListRenderer:drawString(self.graphicsView, self.stringNum, StringTable, 0, 0)
		CmdListRenderer:render(self.graphicsView, self.cmdListNum, 0, 64, false, 0)
		
		-- identify which command lists are double height by looking at code usage
		FindCmdListCalls(false, false, false)
		FindCmdListCalls(true, false, false)
	end,

	onDrawUI = function(self)
		local changedStringNum = false
		changedStringNum, self.stringNum = imgui.InputInt("String Index", self.stringNum)

		if self.stringNum < 1 then
			self.stringNum = 1
		end
		if self.stringNum > StringMaxIndex then
			self.stringNum = StringMaxIndex
		end

		DrawAddressLabel(CurString)

		local changedcmdListNum = false
		changedcmdListNum, self.cmdListNum = imgui.InputInt("Cmd List Num", self.cmdListNum)

		if self.cmdListNum < 1 then
			self.cmdListNum = 1
		end
		if self.cmdListNum > CmdListMaxIndex then
			self.cmdListNum = CmdListMaxIndex
		end

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
			if dblHeightchanged == false then
				if CmdListIsDoubleHeight[self.cmdListNum] == nil then
					self.doubleHeight = false
				else
					self.doubleHeight = CmdListIsDoubleHeight[self.cmdListNum]
				end
			end

			ClearGraphicsView(self.graphicsView, 0xff202020)
			CmdListRenderer:drawString(self.graphicsView, self.stringNum, StringTable, 0, 0)
			CmdListRenderer:render(self.graphicsView, self.cmdListNum, 0, 64, self.doubleHeight, self.numBytesToDraw)
			print("Cmd list summary is '" .. CmdListRenderer:getTextSummary(self.cmdListNum, self.doubleHeight, 0) .. "'")
		end

		if imgui.Button("Set Cur Cmd List Comments") then
			CmdListRenderer:addDataComments(self.cmdListNum, self.doubleHeight)
		end

		-- Update and draw to screen
		DrawGraphicsView(self.graphicsView)
		
		if imgui.Button("Clear All Data Comments") then
			local curPtr = CommandListTable
			while curPtr < StringTable do
				SetDataItemComment(curPtr, "")
				curPtr = curPtr + 1
			end
		end

		if imgui.Button("Set All Code Comments") then
			FindCmdListCalls(false, false, true)
			FindCmdListCalls(true, false, true)
		end

		if imgui.Button("Set All Data Comments") then
			for c = 1, CmdListMaxIndex do
				CmdListRenderer:addDataComments(c, CmdListIsDoubleHeight[c])
			end 
		end

		local drawCallsChanged = false
		drawCallsChanged, self.drawCalls = imgui.Checkbox("Show Draw Calls", self.drawCalls)

		if self.drawCalls == true then
			imgui.Text("Cmd List calls:")
			FindCmdListCalls(false, true, false)
			imgui.Text("\nCmd List double height calls:")
			FindCmdListCalls(true, true, false)
		end
	end,

}

-- Initialise the template viewer
print("Laser Squad Command List Viewer Initialised")
AddViewer(CommandListViewer);