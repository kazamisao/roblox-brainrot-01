-- Brainrot Island BARU -- client HUD.
-- The 3D game is the world itself; this script only draws the
-- screen over it: cash and income up top, the base lock and
-- rebirth buttons down below, and one-line toasts. Every number
-- shown arrives from the server in a Hud payload; the buttons send
-- bare intent words back, and the server checks every rule again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local hudEvent = remotesFolder:WaitForChild("Hud") :: RemoteEvent
local toastEvent = remotesFolder:WaitForChild("Toast") :: RemoteEvent
local actionEvent = remotesFolder:WaitForChild("Action") :: RemoteEvent

local function formatMoney(amount: number): string
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if grouped:sub(1, 1) == "." then
		grouped = grouped:sub(2)
	end
	return grouped
end

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function panel(name: string, size: UDim2, pos: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = pos
	frame.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	return frame
end

local function label(parent: Instance, name: string, size: UDim2, pos: UDim2, text: string, color: Color3, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.Font = Enum.Font.FredokaOne
	l.TextSize = textSize
	l.TextScaled = false
	l.Parent = parent
	return l
end

-- Top bar: cash in green, income + base count under it.
local topBar = panel("TopBar", UDim2.new(0, 340, 0, 84), UDim2.new(0.5, -170, 0, 8))
local cashLabel = label(topBar, "Cash", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 2), "$100", Color3.fromRGB(120, 255, 140), 30)
cashLabel.TextXAlignment = Enum.TextXAlignment.Center
local infoLabel = label(topBar, "Info", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 40),
	"Penghasilan: $0/dtk • Brainrot di base: 0/6", Color3.fromRGB(255, 255, 255), 15)
infoLabel.TextXAlignment = Enum.TextXAlignment.Center
local rebirthLabel = label(topBar, "RebirthInfo", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 60),
	"Rebirth 0 (100%)", Color3.fromRGB(200, 170, 255), 14)
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Bottom buttons: lock and rebirth.
local function actionButton(name: string, pos: UDim2, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(0, 250, 0, 56)
	b.Position = pos
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 19
	b.AutoButtonColor = true
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = b
	return b
end

local lockButton = actionButton("LockButton", UDim2.new(0.5, -260, 1, -72), "KUNCI BASE (60 dtk)", Color3.fromRGB(220, 60, 60))
local rebirthButton = actionButton("RebirthButton", UDim2.new(0.5, 10, 1, -72), "REBIRTH $500.000 (+25%)", Color3.fromRGB(140, 70, 220))

lockButton.Activated:Connect(function()
	actionEvent:FireServer("lock")
end)
rebirthButton.Activated:Connect(function()
	actionEvent:FireServer("rebirth")
end)

-- Toasts: one line at a time under the top bar, fading after a
-- couple of seconds. A token keeps a fresh toast from being hidden
-- by the previous one's timer.
local toastFrame = panel("Toast", UDim2.new(0, 420, 0, 40), UDim2.new(0.5, -210, 0, 100))
toastFrame.Visible = false
local toastLabel = label(toastFrame, "ToastText", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "", Color3.fromRGB(255, 240, 170), 17)
toastLabel.TextXAlignment = Enum.TextXAlignment.Center
local toastToken = 0

toastEvent.OnClientEvent:Connect(function(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastFrame.Visible = true
	task.delay(2.5, function()
		if toastToken == token then
			toastFrame.Visible = false
		end
	end)
end)

hudEvent.OnClientEvent:Connect(function(payload: { [string]: any })
	cashLabel.Text = "$" .. formatMoney(payload.cash or 0)
	infoLabel.Text = "Penghasilan: $" .. formatMoney(payload.income or 0) .. "/dtk • Brainrot di base: "
		.. tostring(payload.placed or 0) .. "/" .. tostring(payload.slots or 6)
	local multPercent = math.floor((payload.multiplier or 1) * 100)
	rebirthLabel.Text = "Rebirth " .. tostring(payload.rebirths or 0) .. " (" .. multPercent .. "%)"
	rebirthButton.Text = "REBIRTH $" .. formatMoney(payload.rebirthCost or 500000) .. " (+25%)"
	if payload.locked then
		lockButton.Text = "BASE TERKUNCI"
	else
		lockButton.Text = "KUNCI BASE (60 dtk)"
	end
end)
