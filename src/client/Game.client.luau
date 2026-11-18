-- Brainrot Island — client HUD.
-- The 3D game is the world itself; this script only draws the screen
-- over it: cash and income up top (clear of Roblox's own menu corner),
-- the treasure-chest countdown with a day/night marker, the base lock
-- and rebirth buttons, and one-line toasts. Every number that matters
-- is the server's: cash is read from leaderstats, the rest arrives on
-- the HudUpdate remote, and the buttons only send intents the server
-- re-validates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("IslandRemotes")
local hudUpdate = remotesFolder:WaitForChild("HudUpdate") :: RemoteEvent
local toastEvent = remotesFolder:WaitForChild("Toast") :: RemoteEvent
local lockRequest = remotesFolder:WaitForChild("LockRequest") :: RemoteEvent
local rebirthRequest = remotesFolder:WaitForChild("RebirthRequest") :: RemoteEvent

local function makeLabel(parent: Instance, name: string, size: UDim2, position: UDim2, text: string, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.Font = Enum.Font.FredokaOne
	label.TextStrokeTransparency = 0.5
	label.Parent = parent
	return label
end

local function makePanel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.AnchorPoint = anchor
	panel.BackgroundColor3 = Color3.fromRGB(16, 26, 34)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	return panel
end

local gui = Instance.new("ScreenGui")
gui.Name = "IslandHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Top-centre wallet panel: cash, income, cast count, rebirth level.
local wallet = makePanel(gui, "WalletPanel", UDim2.fromOffset(340, 86), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
local cashLabel = makeLabel(wallet, "Cash", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 2), "$0", 32, Color3.fromRGB(140, 255, 150))
-- A "+$X" flash beside the cash number whenever the balance rises:
-- the per-second income made visible on the HUD itself.
local deltaLabel = makeLabel(wallet, "CashDelta", UDim2.new(0, 110, 0, 40), UDim2.new(1, -118, 0, 2), "", 24, Color3.fromRGB(190, 255, 160))
deltaLabel.TextTransparency = 1
deltaLabel.TextXAlignment = Enum.TextXAlignment.Right
local incomeLabel = makeLabel(wallet, "Income", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 44), "Penghasilan: $0/dtk", 17, Color3.fromRGB(255, 240, 200))
local castLabel = makeLabel(wallet, "Cast", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 64), "Brainrot di base: 0/6", 15, Color3.fromRGB(200, 220, 255))

-- Top-right event panel.
local eventPanel = makePanel(gui, "EventPanel", UDim2.fromOffset(250, 62), UDim2.new(1, -10, 0, 10), Vector2.new(1, 0))
local eventTitle = makeLabel(eventPanel, "EventTitle", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 4), "PETI HARTA KARUN", 16, Color3.fromRGB(255, 200, 80))
local eventLabel = makeLabel(eventPanel, "EventTimer", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 28), "dalam 60 dtk", 20, Color3.fromRGB(255, 255, 255))

-- Bottom-centre action buttons.
local buttonRow = Instance.new("Frame")
buttonRow.Name = "Buttons"
buttonRow.Size = UDim2.fromOffset(560, 58)
buttonRow.Position = UDim2.new(0.5, 0, 1, -72)
buttonRow.AnchorPoint = Vector2.new(0.5, 0)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 14)
layout.Parent = buttonRow

local function makeButton(name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(270, 56)
	button.BackgroundColor3 = color
	button.Text = text
	button.TextSize = 19
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.FredokaOne
	button.TextStrokeTransparency = 0.6
	button.AutoButtonColor = true
	button.Parent = buttonRow
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	return button
end

local lockButton = makeButton("LockButton", "KUNCI BASE (30 dtk)", Color3.fromRGB(200, 60, 70))
local rebirthButton = makeButton("RebirthButton", "REBIRTH", Color3.fromRGB(140, 80, 200))

-- Toast line under the wallet panel.
local toastLabel = makeLabel(gui, "Toast", UDim2.new(0.8, 0, 0, 34), UDim2.new(0.5, 0, 0, 108), "", 22, Color3.fromRGB(255, 255, 180))
toastLabel.AnchorPoint = Vector2.new(0.5, 0)
toastLabel.TextTransparency = 1

local toastToken = 0
local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.TextTransparency = 0
	task.wait(2.6)
	if toastToken == token then
		local tween = TweenService:Create(toastLabel, TweenInfo.new(0.6), { TextTransparency = 1 })
		tween:Play()
	end
end

toastEvent.OnClientEvent:Connect(function(message: string)
	task.spawn(showToast, message)
end)

lockButton.Activated:Connect(function()
	lockRequest:FireServer()
end)
rebirthButton.Activated:Connect(function()
	rebirthRequest:FireServer()
end)

-- Cash mirrors leaderstats exactly.
local leaderstats = player:WaitForChild("leaderstats")
local cashValue = leaderstats:WaitForChild("Cash") :: IntValue
local lastCash: number? = nil
local deltaToken = 0
local function renderCash()
	local value = cashValue.Value
	cashLabel.Text = "$" .. tostring(value)
	if lastCash ~= nil and value > lastCash then
		deltaToken += 1
		local token = deltaToken
		deltaLabel.Text = "+$" .. tostring(value - lastCash)
		deltaLabel.TextTransparency = 0
		task.spawn(function()
			task.wait(0.9)
			if deltaToken == token then
				local tween = TweenService:Create(deltaLabel, TweenInfo.new(0.5), { TextTransparency = 1 })
				tween:Play()
			end
		end)
	end
	lastCash = value
end
cashValue.Changed:Connect(renderCash)
renderCash()

hudUpdate.OnClientEvent:Connect(function(state)
	incomeLabel.Text = "Penghasilan: $" .. state.Income .. "/dtk  •  Rebirth " .. state.Rebirths .. " (" .. state.MultiplierPct .. "%)"
	castLabel.Text = "Brainrot di base: " .. state.PlacedCount .. "/" .. state.BaseSlots

	if state.LockLeft > 0 then
		lockButton.Text = "TERKUNCI " .. state.LockLeft .. " dtk"
		lockButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	elseif state.LockCooldownLeft > 0 then
		lockButton.Text = "KUNCI — cooldown " .. state.LockCooldownLeft .. " dtk"
		lockButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	else
		lockButton.Text = "KUNCI BASE (30 dtk)"
		lockButton.BackgroundColor3 = Color3.fromRGB(200, 60, 70)
	end

	if state.RebirthCost then
		rebirthButton.Text = "REBIRTH $" .. state.RebirthCostText .. " (+25%)"
		rebirthButton.BackgroundColor3 = Color3.fromRGB(140, 80, 200)
	else
		rebirthButton.Text = "REBIRTH MAKSIMAL"
		rebirthButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	end

	local sky = state.IsNight and "MALAM" or "SIANG"
	if state.EventPhase == "active" then
		eventTitle.Text = "PETI HARTA MUNCUL!"
		eventTitle.TextColor3 = Color3.fromRGB(255, 200, 60)
		eventLabel.Text = "BUKA PETINYA! " .. state.EventSeconds .. " dtk"
	elseif state.EventPhase == "warn" then
		eventTitle.Text = "PETI SEBENTAR LAGI!"
		eventTitle.TextColor3 = Color3.fromRGB(255, 190, 80)
		eventLabel.Text = "siap-siap... " .. state.EventSeconds .. " dtk"
	else
		eventTitle.Text = "PETI HARTA KARUN • " .. sky
		eventTitle.TextColor3 = Color3.fromRGB(255, 200, 80)
		eventLabel.Text = "dalam " .. state.EventSeconds .. " dtk"
	end
end)

showToast("Selamat datang di Brainrot Island! Beli brainrot dari conveyor di plaza.")
