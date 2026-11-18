-- CharacterFactory: assembles one brainrot character as a Model of
-- plain Parts. The recipe: a shaped body in the tier colour standing
-- on a dark pedestal disc ringed by a neon rarity glow, a ball head
-- with two eyes and an optional accent topper, and a three-line
-- billboard nameplate (name, rate + rarity, price) doing the selling.
-- This module also renders the floating "+$N" popup that appears
-- over a placed brainrot whenever it pays out. Nothing here is
-- physics-simulated — every part is anchored, and all travel goes
-- through GlideTo, a PivotTo glide with a small hop in the middle.

local BrainrotData = require(script.Parent.BrainrotData)

local CharacterFactory = {}

-- Shorthand for one anchored, non-colliding Part with smooth faces.
local function makePart(parent: Instance, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Money the Indonesian way: 150000 renders as "150.000".
function CharacterFactory.FormatMoney(amount: number): string
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if grouped:sub(1, 1) == "." then
		grouped = grouped:sub(2)
	end
	return grouped
end

function CharacterFactory.Build(def: BrainrotData.Def): (Model, Part)
	local model = Instance.new("Model")
	model.Name = def.Name

	-- A def's BodySize is (width, thickness, depth) in character
	-- terms, but a Cylinder part's long axis runs along X. For
	-- cylinders the physical part therefore takes the thickness on
	-- X, and the Z-90° twist further down tips that axis upright:
	-- the result is a flat disc whose diameter is BodySize.X/Z and
	-- whose height is exactly BodySize.Y.
	local bodySize = def.BodySize
	local physicalSize = bodySize
	if def.Shape == Enum.PartType.Cylinder then
		physicalSize = Vector3.new(bodySize.Y, bodySize.X, bodySize.Z)
	end
	local body = makePart(model, "Body", physicalSize, CFrame.new(), def.Color)
	body.Shape = def.Shape
	if def.Shape == Enum.PartType.Cylinder then
		body.CFrame = CFrame.Angles(0, 0, math.rad(90))
	end

	-- Under the body sits a wide, near-black pedestal disc: it draws
	-- a hard outline against any floor, so the silhouette can never
	-- blend into the plaza. Above it, an opaque neon disc in the
	-- rarity colour makes the tier readable from across the island.
	-- Both discs are cylinders, so both get the same flat Z-90° lay.
	local footDiameter = math.max(bodySize.X, bodySize.Z)
	local rimDiameter = math.min(footDiameter * 1.5, 6.2)
	local rim = makePart(model, "Pedestal", Vector3.new(rimDiameter, 0.16, rimDiameter),
		CFrame.new(0, -(bodySize.Y / 2) - 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(24, 21, 32), Enum.Material.SmoothPlastic)
	rim.Shape = Enum.PartType.Cylinder
	local glowDiameter = math.min(footDiameter * 1.3, 5.6)
	local disc = makePart(model, "GlowDisc", Vector3.new(glowDiameter, 0.22, glowDiameter),
		CFrame.new(0, -(bodySize.Y / 2) + 0.13, 0) * CFrame.Angles(0, 0, math.rad(90)),
		BrainrotData.RarityColors[def.Rarity] or Color3.new(1, 1, 1), Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder

	local headSize = math.max(bodySize.X, bodySize.Z) * 0.55
	local headY = bodySize.Y / 2 + headSize / 2 - 0.15
	local head = makePart(model, "Head", Vector3.new(headSize, headSize, headSize),
		CFrame.new(0, headY, 0), def.Accent or def.Color)
	head.Shape = Enum.PartType.Ball

	-- The eyes sit on +X, the way the conveyor runs, so a riding
	-- brainrot always looks where it is going.
	local headR = headSize / 2
	for _, side in { -1, 1 } do
		local eye = makePart(model, "Eye", Vector3.new(0.46, 0.46, 0.46),
			CFrame.new(headR * 0.82, headY + headR * 0.12, side * headR * 0.4),
			Color3.fromRGB(18, 16, 22))
		eye.Shape = Enum.PartType.Ball
	end

	if def.Accent then
		local topper = makePart(model, "Topper", Vector3.new(headSize * 0.45, 0.35, headSize * 0.45),
			CFrame.new(0, headY + headR + 0.05, 0), def.Accent, Enum.Material.Neon)
		topper.Shape = Enum.PartType.Ball
	end

	-- The nameplate is the whole pitch at a glance: the name in its
	-- rarity colour, the per-second rate beside the rarity, and the
	-- price — every line backed by a dark plate so it survives a
	-- bright sky behind it.
	local rarityColor = BrainrotData.RarityColors[def.Rarity] or Color3.new(1, 1, 1)
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.new(11.5, 0, 3.6, 0)
	plate.StudsOffset = Vector3.new(0, bodySize.Y / 2 + 2.4, 0)
	plate.AlwaysOnTop = true
	plate.Parent = body

	local function plateLine(name: string, y: number, h: number, text: string, color: Color3): TextLabel
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
		return label
	end

	plateLine("Name", 0, 0.42, def.Name, rarityColor)
	plateLine("Sub", 0.42, 0.31, "$" .. def.PerSec .. "/dtk • " .. def.Rarity, Color3.fromRGB(255, 255, 255))
	plateLine("Price", 0.73, 0.27, "Harga $" .. CharacterFactory.FormatMoney(def.Price), Color3.fromRGB(160, 255, 170))

	-- The pivot must NOT ride on the body part. A cylinder body
	-- carries that Z-90° twist in its own CFrame; if the body were
	-- the PrimaryPart, the model pivot would inherit the twist and
	-- every later PivotTo — belt spawn, base-slot glide, the hero
	-- statue, the golden visitor — would tip the whole character
	-- sideways and bury half of it under the floor. Instead the
	-- pivot is pinned to the bare model origin, where every part
	-- offset above is authored: no PrimaryPart, and a WorldPivot of
	-- plain identity, so GetPivot() hands every caller the same
	-- translation-only frame whatever the body shape is.
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new()
	return model, body
end

-- The "+$N" popup: income made visible in the world, not just in
-- the HUD. Each body keeps one reusable BillboardGui; a per-body
-- token stops a fresh tick's animation from being faded out by the
-- tail of the previous tick's.
local popupTokens: { [Part]: number } = setmetatable({}, { __mode = "k" }) :: any

function CharacterFactory.ShowIncomePopup(body: Part, amount: number)
	if amount <= 0 or not body.Parent then
		return
	end
	local gui = body:FindFirstChild("IncomePopup") :: BillboardGui?
	local label: TextLabel
	if gui then
		label = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
	else
		gui = Instance.new("BillboardGui")
		gui.Name = "IncomePopup"
		gui.Size = UDim2.new(6, 0, 1.6, 0)
		gui.AlwaysOnTop = true
		gui.Parent = body
		label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(140, 255, 150)
		label.TextStrokeTransparency = 0.25
		label.Parent = gui
	end
	local bodyHeight = body.Size.Y
	popupTokens[body] = (popupTokens[body] or 0) + 1
	local token = popupTokens[body]
	label.Text = "+$" .. CharacterFactory.FormatMoney(amount)
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.25
	task.spawn(function()
		local elapsed = 0
		while elapsed < 0.9 and popupTokens[body] == token and body.Parent do
			local dt = task.wait()
			elapsed += dt
			local t = math.min(1, elapsed / 0.9)
			if gui then
				gui.StudsOffset = Vector3.new(0, bodyHeight / 2 + 5.2 + t * 1.4, 0)
			end
			label.TextTransparency = t
			label.TextStrokeTransparency = 0.25 + 0.75 * t
		end
	end)
end

-- Glide a model to a target position over `seconds`, holding the
-- facing it started with and arcing through a small hop on the way.
-- `done` fires at the end, unless the model died mid-ride.
function CharacterFactory.GlideTo(model: Model, targetPos: Vector3, seconds: number, done: (() -> ())?)
	task.spawn(function()
		if not model.Parent then
			return
		end
		local startPivot = model:GetPivot()
		local rotation = startPivot - startPivot.Position
		local startPos = startPivot.Position
		local elapsed = 0
		while elapsed < seconds and model.Parent do
			local dt = task.wait()
			elapsed += dt
			local t = math.min(1, elapsed / seconds)
			local pos = startPos:Lerp(targetPos, t)
			pos = Vector3.new(pos.X, pos.Y + math.sin(t * math.pi) * 1.6, pos.Z)
			model:PivotTo(CFrame.new(pos) * rotation)
		end
		if not model.Parent then
			return
		end
		model:PivotTo(CFrame.new(targetPos) * rotation)
		if done then
			done()
		end
	end)
end

return CharacterFactory
