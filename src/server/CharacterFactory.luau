-- CharacterFactory: builds a single brainrot character out of plain
-- anchored Parts grouped in a Model. Layout, all relative to the
-- model origin: a shaped body in the tier colour, a near-black
-- pedestal disc under it ringed by a neon rarity glow disc, a round
-- head with two eyes and maybe a glowing topper, and a three-line
-- billboard (name / rate + rarity / price) that does the selling.
-- This module also owns the "+$N" popup shown when a placed
-- brainrot pays out. No physics anywhere: movement is GlideTo, a
-- PivotTo glide with a little hop in the middle.

local BrainrotData = require(script.Parent.BrainrotData)

local CharacterFactory = {}

-- One anchored Part that never collides and has smooth top/bottom
-- faces. Every visible piece of a character goes through here.
local function newPart(parent: Instance, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
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

function CharacterFactory.Build(def: BrainrotData.Def): (Model, Part)
	local model = Instance.new("Model")
	model.Name = def.Name

	-- BodySize speaks in character terms: (width, thickness, depth).
	-- A Cylinder part, though, runs its long axis along X, so for a
	-- cylinder def the physical part swaps the axes — thickness on X,
	-- diameter on Y/Z — and the Z-90° twist below stands that axis
	-- up. The visible result is a flat upright disc of height
	-- BodySize.Y and diameter BodySize.X/Z.
	local bodySize = def.BodySize
	local physicalSize = bodySize
	if def.Shape == Enum.PartType.Cylinder then
		physicalSize = Vector3.new(bodySize.Y, bodySize.X, bodySize.Z)
	end
	local body = newPart(model, "Body", physicalSize, CFrame.new(), def.Color)
	body.Shape = def.Shape
	if def.Shape == Enum.PartType.Cylinder then
		body.CFrame = CFrame.Angles(0, 0, math.rad(90))
	end

	-- Two flat cylinders under the body, both laid over with the same
	-- Z-90° twist. The wide near-black pedestal draws a hard outline
	-- against any floor so the silhouette cannot melt into the
	-- plaza; the smaller neon disc on top of it carries the rarity
	-- colour, readable from across the island.
	local footDiameter = math.max(bodySize.X, bodySize.Z)
	local rim = newPart(model, "Pedestal",
		Vector3.new(math.min(footDiameter * 1.5, 6.2), 0.16, math.min(footDiameter * 1.5, 6.2)),
		CFrame.new(0, -(bodySize.Y / 2) - 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(24, 21, 32), Enum.Material.SmoothPlastic)
	rim.Shape = Enum.PartType.Cylinder
	local glow = newPart(model, "GlowDisc",
		Vector3.new(math.min(footDiameter * 1.3, 5.6), 0.22, math.min(footDiameter * 1.3, 5.6)),
		CFrame.new(0, -(bodySize.Y / 2) + 0.13, 0) * CFrame.Angles(0, 0, math.rad(90)),
		BrainrotData.RarityColors[def.Rarity] or Color3.new(1, 1, 1), Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder

	local headSize = math.max(bodySize.X, bodySize.Z) * 0.55
	local headY = bodySize.Y / 2 + headSize / 2 - 0.15
	local head = newPart(model, "Head", Vector3.new(headSize, headSize, headSize),
		CFrame.new(0, headY, 0), def.Accent or def.Color)
	head.Shape = Enum.PartType.Ball

	-- Eyes face +X, the direction the conveyor travels, so a riding
	-- brainrot always looks where it is heading.
	local headR = headSize / 2
	for _, side in { -1, 1 } do
		local eye = newPart(model, "Eye", Vector3.new(0.46, 0.46, 0.46),
			CFrame.new(headR * 0.82, headY + headR * 0.12, side * headR * 0.4),
			Color3.fromRGB(18, 16, 22))
		eye.Shape = Enum.PartType.Ball
	end

	if def.Accent then
		local topper = newPart(model, "Topper",
			Vector3.new(headSize * 0.45, 0.35, headSize * 0.45),
			CFrame.new(0, headY + headR + 0.05, 0), def.Accent, Enum.Material.Neon)
		topper.Shape = Enum.PartType.Ball
	end

	-- The pitch at a glance, on a dark-backed billboard so it stays
	-- legible against a bright sky: name in the rarity colour, rate
	-- beside the rarity, then the price.
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

	-- The pivot anchor. The model gets a dedicated invisible Root
	-- part parked exactly on the authored origin — the point every
	-- offset above is measured from — and the PrimaryPart is pointed
	-- at it once all parts are in. Two failure modes this avoids:
	-- riding the pivot on the body breaks cylinders (the body's
	-- Z-90° twist would leak into the pivot and tip the whole
	-- character), and leaving the PrimaryPart unset breaks
	-- everything (the pivot then falls back to a heuristic origin
	-- nobody authored, and PivotTo buries the model by that error).
	-- Root never rotates, so GetPivot() returns the clean authored
	-- origin for Ball, Block and Cylinder alike.
	local root = newPart(model, "Root", Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanQuery = false
	root.CanTouch = false
	model.PrimaryPart = root
	return model, body
end

-- The "+$N" popup: income you can see in the world, not only in the
-- HUD. One reusable BillboardGui per body; a per-body token keeps a
-- fresh tick's animation from being faded out by the tail of the
-- previous tick's.
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

-- Glide a model to a target position over `seconds`: it keeps the
-- facing it started with and arcs through a small hop on the way.
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
