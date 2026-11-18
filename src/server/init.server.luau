-- Italian Brainrot Obby — server bootstrap.
-- Pins the world to a bright permanent day, builds the obby world
-- and wires the gameplay. Everything else lives in WorldBuilder
-- (geometry) and Gameplay (rules).

local Lighting = game:GetService("Lighting")

Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(140, 140, 148)
Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 140)

local WorldBuilder = require(script.WorldBuilder)
local Gameplay = require(script.Gameplay)

local refs = WorldBuilder.Build()
Gameplay.Start(refs)

print("[BrainrotObby] Italian Brainrot Obby is open")
