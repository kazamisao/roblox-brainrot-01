-- CharacterFactory: turns a CastData definition into a live
-- character entry. The factory creates one anchored Part per box,
-- groups them in a Model, and records every part's authored local
-- CFrame in entry.Locals. From that moment on the factory never
-- positions anything itself: the first placement and every later
-- move go through Mover.Apply, which stamps each part at
-- placement * local. The factory also owns the two billboards a
-- character carries -- the sales nameplate (name / rate + rarity /
-- price) and the floating "+$N" income popup -- plus the hue cycle
-- that animates Rainbow parts.

local CastData = require(script.Parent.CastData)
local Mover = require(script.Parent.Mover)

local CharacterFactory = {}

-- Entries with Rainbow parts, so one heartbeat loop can tint them
-- all. Weak keys: a destroyed entry falls out on its own.
local rainbowEntries: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local rainbowRunning = false

local function startRainbowLoop()
	if rainbowRunning then
		return
	end
	rainbowRunning = true
	task.spawn(function()
		while true do
			local hue = (os.clock() * 0.12) % 1
			local color = Color3.fromHSV(hue, 0.55, 1)
			for entry in rainbowEntries do
				if entry.Alive then
					for _, part in entry.RainbowParts do
						part.Color = color
					end
				end
			end
			task.wait(0.15)
		end
	end)
end

-- Indonesian thousands grouping: 150000 comes out as "150.000".
function CharacterFactory.FormatMoney(amount: number): string
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if grouped:sub(1, 1) == "." then
		grouped = grouped:sub(2)
	end
	return grouped
end

-- The local frame of one authored box: its center offset, with any
-- baked-in roll/yaw from the data applied on top.
local function localFrameOf(b: { [string]: any }): CFrame
	local cf = CFrame.new(b.Offset)
	if b.RotY then
		cf *= CFrame.Angles(0, math.rad(b.RotY), 0)
	end
	if b.RotZ then
		cf *= CFrame.Angles(0, 0, math.rad(b.RotZ))
	end
	return cf
end

-- How high a box reaches above the origin plane. A cylinder rolled
-- upright on Z stands on its length (Size.X); everything else
-- stands on its height (Size.Y).
local function topOf(b: { [string]: any }): number
	if b.RotZ then
		return b.Offset.Y + b.Size.X / 2
	end
	return b.Offset.Y + b.Size.Y / 2
end

function CharacterFactory.Build(def): any
	local model = Instance.new("Model")
	model.Name = def.Name

	local entry: any = {
		Def = def,
		Model = model,
		Parts = {},
		Locals = {},
		RainbowParts = {},
		Alive = true,
		GlideToken = 0,
		State = "new",
		Placement = CFrame.new(),
	}

	local topY = 0
	for i, b in def.Boxes do
		local part = Instance.new("Part")
		part.Name = "Box" .. i
		part.Size = b.Size
		part.Color = b.Color
		part.Material = if b.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if b.Shape then
			part.Shape = b.Shape
		end
		local localCf = localFrameOf(b)
		part.CFrame = localCf
		part.Parent = model
		table.insert(entry.Parts, part)
		entry.Locals[part] = localCf
		if b.Rainbow then
			table.insert(entry.RainbowParts, part)
		end
		topY = math.max(topY, topOf(b))
	end
	entry.BodyPart = entry.Parts[1]
	entry.TopY = topY

	-- The nameplate floats a little above the tallest box. It rides
	-- on the first part with a world-space offset, so it stays above
	-- the character no matter how that part is rotated.
	local rarityColor = CastData.RarityColors[def.Rarity] or Color3.new(1, 1, 1)
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.new(11.5, 0, 3.4, 0)
	plate.StudsOffsetWorldSpace = Vector3.new(0, topY + 1.1 - def.Boxes[1].Offset.Y, 0)
	plate.AlwaysOnTop = true
	plate.Parent = entry.BodyPart

	local function plateLine(name: string, y: number, h: number, text: string, color: Color3)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.new(1, 0, h, 0)
		label.Position = UDim2.new(0, 0, y, 0)
		label.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
		label.BackgroundTransparency = 0.3
		label.Text = text
		label.TextColor3 = color
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0.35
		label.Parent = plate
	end

	plateLine("Name", 0, 0.42, def.Name, rarityColor)
	plateLine("Sub", 0.42, 0.31, "$" .. def.PerSec .. "/dtk • " .. def.Rarity, Color3.fromRGB(255, 255, 255))
	local priceText = if def.Price > 0 then "Harga $" .. CharacterFactory.FormatMoney(def.Price) else "GRATIS"
	plateLine("Price", 0.73, 0.27, priceText, Color3.fromRGB(160, 255, 170))
	entry.Nameplate = plate

	if #entry.RainbowParts > 0 then
		rainbowEntries[entry] = true
		startRainbowLoop()
	end

	return entry
end

-- Stamp the entry at a world placement for the first time. Every
-- later move also goes through Mover; this is just the tidy name
-- callers use when a character enters the world.
function CharacterFactory.Place(entry, placement: CFrame)
	Mover.Apply(entry, placement)
end

-- The "+$N" popup over a placed character when it pays out. One
-- reusable billboard per entry; a token keeps a fresh tick's float
-- animation from being faded by the tail of the previous one.
function CharacterFactory.ShowIncomePopup(entry, amount: number)
	if amount <= 0 or not entry.Alive then
		return
	end
	local gui = entry.PopupGui :: BillboardGui?
	local label: TextLabel
	if gui then
		label = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
	else
		gui = Instance.new("BillboardGui")
		gui.Name = "IncomePopup"
		gui.Size = UDim2.new(6, 0, 1.6, 0)
		gui.AlwaysOnTop = true
		gui.Parent = entry.BodyPart
		entry.PopupGui = gui
		label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(140, 255, 150)
		label.TextStrokeTransparency = 0.25
		label.Parent = gui
	end
	entry.PopupToken = (entry.PopupToken or 0) + 1
	local token = entry.PopupToken
	local baseLift = entry.TopY + 2.6 - entry.Def.Boxes[1].Offset.Y
	label.Text = "+$" .. CharacterFactory.FormatMoney(amount)
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.25
	task.spawn(function()
		local elapsed = 0
		while elapsed < 0.9 and entry.Alive and entry.PopupToken == token do
			local dt = task.wait()
			elapsed += dt
			local t = math.min(1, elapsed / 0.9)
			if gui then
				gui.StudsOffsetWorldSpace = Vector3.new(0, baseLift + t * 1.4, 0)
			end
			label.TextTransparency = t
			label.TextStrokeTransparency = 0.25 + 0.75 * t
		end
	end)
end

function CharacterFactory.Destroy(entry)
	if not entry.Alive then
		return
	end
	entry.Alive = false
	entry.GlideToken += 1
	rainbowEntries[entry] = nil
	if entry.Model then
		entry.Model:Destroy()
	end
end

return CharacterFactory
