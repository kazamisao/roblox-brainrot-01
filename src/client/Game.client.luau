-- Italian Brainrot Obby — client HUD.
-- Deliberately tiny: a top-centre toast label fed by the ObbyToast
-- remote (checkpoint saves, orb pickups, the finish), and a small
-- top-left panel mirroring the player's leaderstats (Aura + Stage).
-- The game itself is the 3D world; this script only draws text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

-- Toast label, top centre.
local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "Toast"
toastLabel.AnchorPoint = Vector2.new(0.5, 0)
toastLabel.Position = UDim2.new(0.5, 0, 0, 18)
toastLabel.Size = UDim2.new(0, 560, 0, 52)
toastLabel.BackgroundColor3 = Color3.fromRGB(24, 20, 38)
toastLabel.BackgroundTransparency = 1
toastLabel.Text = ""
toastLabel.TextColor3 = Color3.fromRGB(255, 240, 180)
toastLabel.Font = Enum.Font.FredokaOne
toastLabel.TextScaled = true
toastLabel.TextTransparency = 1
toastLabel.Parent = gui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 14)
toastCorner.Parent = toastLabel

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(255, 205, 60)
toastStroke.Thickness = 2
toastStroke.Transparency = 1
toastStroke.Parent = toastLabel

-- Stats panel, top left.
local statsPanel = Instance.new("TextLabel")
statsPanel.Name = "Stats"
statsPanel.Position = UDim2.new(0, 14, 0, 14)
statsPanel.Size = UDim2.new(0, 250, 0, 44)
statsPanel.BackgroundColor3 = Color3.fromRGB(24, 20, 38)
statsPanel.BackgroundTransparency = 0.25
statsPanel.Text = "Aura: 0 • Stage: 1"
statsPanel.TextColor3 = Color3.new(1, 1, 1)
statsPanel.Font = Enum.Font.FredokaOne
statsPanel.TextScaled = true
statsPanel.Parent = gui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 12)
statsCorner.Parent = statsPanel

-- Mirror leaderstats into the stats panel.
local function bindStats()
	local stats = player:WaitForChild("leaderstats")
	local aura = stats:WaitForChild("Aura") :: IntValue
	local stage = stats:WaitForChild("Stage") :: IntValue
	local function refresh()
		statsPanel.Text = string.format("Aura: %d • Stage: %s", aura.Value, if stage.Value >= 999 then "TAMAT" else tostring(stage.Value))
	end
	aura.Changed:Connect(refresh)
	stage.Changed:Connect(refresh)
	refresh()
end
task.spawn(bindStats)

-- Toasts: each new toast replaces the old one; a generation counter
-- keeps an older toast's fade-out from hiding a newer toast.
local toastGeneration = 0
local function showToast(text: string)
	toastGeneration += 1
	local generation = toastGeneration
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.2
	toastStroke.Transparency = 0
	task.spawn(function()
		task.wait(2.5)
		if generation ~= toastGeneration then
			return
		end
		for step = 1, 10 do
			if generation ~= toastGeneration then
				return
			end
			local t = step / 10
			toastLabel.TextTransparency = t
			toastLabel.BackgroundTransparency = 0.2 + 0.8 * t
			toastStroke.Transparency = t
			task.wait(0.04)
		end
	end)
end

local toastEvent = ReplicatedStorage:WaitForChild("ObbyToast") :: RemoteEvent
toastEvent.OnClientEvent:Connect(showToast)
