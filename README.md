# LaserSquad
Disassembly of the 1988 game Laser Squad using Spectrum Analyser.

## Status
The disassembly is partially complete and is a work in progress.

## Instructions
To open the disassembly you need to download or build the Spectrum Analyser tool.
  - Either build your own: https://github.com/TheGoodDoktor/8BitAnalysers
  - Or download a pre-built version: https://colourclash.co.uk/spectrum-analyser/
  - Copy the `LaserSquad_Scenario1` folder from `SpectrumAnalyserProjects` to your workspace root.* 
  - Copy the `LaserSquad_Scenario1.z80` to your snapshot folder.**
  - Start Spectrum Analyser
  - Select the `Open Game` option in the `File` menu
  - Select `LaserSquad_Scenario1`

\*   The workspace root is the folder `WorkspaceRoot` points to in the `GlobalConfig.json` file.

\**  The snapshot folder is the folder `SnapshotFolder` points to in the `GlobalConfig.json` file.

Note: the GlobalConfig.json file will be created the first time you run Spectrum Analyser

## Custom viewers
Viewers have been written in Lua to visualise the game data, to understand how the game works. 

### Map viewer. 
The map updates in realtime as you play the game.

<img width="1280" alt="image" src="https://github.com/Colourclash/LaserSquad/assets/883891/01259044-bbbb-41b3-888a-0bfdd7e9181a">

### Command list viewer
To understand how the command list system works for drawing the UI, I wrote a command list viewer in Lua.

<img width="583" alt="image" src="https://github.com/Colourclash/LaserSquad/assets/883891/2c3fab97-8602-40ef-9e6a-a2b339f2441a">

### Tile and Block viewer

<img width="584" alt="image" src="https://github.com/Colourclash/LaserSquad/assets/883891/65d7a413-0c5f-4799-a765-910efe80a2ea">

More viewers will be added...


## Disclaimer
Julian Gollop is the original author of the game, and owner of the ideas therein.
This repository contains Laser Squad snapshot files. This game was previously commercially available. If you own the copyright to these files please let me know and I will remove them.
