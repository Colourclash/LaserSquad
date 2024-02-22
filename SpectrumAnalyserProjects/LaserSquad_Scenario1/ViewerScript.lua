TileViewer = 
{
	name = "Tile Viewer",
	tileNum = 0,
	
	onAdd = function(self)
		self.graphicsView = CreateZXGraphicsView(256, 256)
		ClearGraphicsView(self.graphicsView, 0)
		DrawMapTileToView(self.graphicsView, self.tileNum, 0, 0)
	end,

	onDrawUI = function(self)
		local changed = false

		-- Use ImGui widget for setting tile number to draw
		changed, self.tileNum = imgui.InputInt("Tile Number", self.tileNum)

		if self.tileNum < 0 then
			self.tileNum = 0
		end
		
		if changed == true then
			ClearGraphicsView(self.graphicsView, 0)
			DrawMapTileToView(self.graphicsView, self.tileNum, 0, 0)
		end

		-- Update and draw to screen
		DrawGraphicsView(self.graphicsView)
	end,

}

BlockViewer = 
{
	name = "Block Viewer",
	blockNum = 0,
	
	onAdd = function(self)
		self.graphicsView = CreateZXGraphicsView(256, 256)
		ClearGraphicsView(self.graphicsView, 0)
		DrawBlockToView(self.graphicsView, self.blockNum, 0x0f, 0, 0)
	end,

	onDrawUI = function(self)
		local changed = false

		-- Use ImGui widget for setting block number to draw
		changed, self.blockNum = imgui.InputInt("Block Number", self.blockNum)

		if self.blockNum < 0 then
			self.blockNum = 0
		end

		if changed == true then
			ClearGraphicsView(self.graphicsView, 0)
			DrawBlockToView(self.graphicsView, self.blockNum, 0x0f, 0, 0)
		end

		-- Update and draw to screen
		DrawGraphicsView(self.graphicsView)
	end,

}

-- Initialise the template viewer
print("Laser Squad Viewer Initialised")
AddViewer(BlockViewer);
AddViewer(TileViewer);