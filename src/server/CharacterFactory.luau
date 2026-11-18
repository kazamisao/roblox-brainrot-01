-- CharacterFactory: builds a brainrot character as a real 3D Model out
-- of primitive Parts — a shaped body in the tier's colour on a dark
-- pedestal disc with a neon rarity glow, a ball head, two eyes and a
-- floating nameplate that reads name, income, rarity and price. It
-- also owns the floating "+$N" income popup shown over a placed
-- brainrot each time it pays. Characters are anchored and never
-- simulated; movement is the factory's GlideTo, a PivotTo ride with
-- a little hop.

local BrainrotData = require(script.Parent.BrainrotData)

local CharacterFactory = {}

local function part(parent: Instance, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
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

-- Indonesian-style money text: 150000 -> "150.000".
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

	local bodySize = def.BodySize
	-- A cylinder part's length axis runs along X, while a cast member's
	-- logical BodySize is (width, thickness, depth) — so for cylinders the
	-- physical size puts the thickness on X, and the Z-90° rotation below
	-- stands that axis vertical, leaving a flat disc of diameter
	-- bodySize.X/Z whose vertical extent is exactly bodySize.Y.
	local physicalSize = bodySize
	if def.Shape == Enum.PartType.Cylinder then
		physicalSize = Vector3.new(bodySize.Y, bodySize.X, bodySize.Z)
	end
	local body = part(model, "Body", physicalSize, CFrame.new(), def.Color)
	body.Shape = def.Shape
	if def.Shape == Enum.PartType.Cylinder then
		-- A cylinder part's axis runs along X; stand the cracker upright.
		body.CFrame = CFrame.Angles(0, 0, math.rad(90))
	end

	-- A dark pedestal disc under everything, wider than the body: it
	-- draws a hard outline around the character on any floor colour,
	-- so the silhouette can never melt into the plaza. On top of it a
	-- fully opaque neon glow disc in the rarity colour, so a brainrot
	-- reads from across the plaza even before its nameplate does.
	-- A cylinder's axis runs along X, so rotate both discs flat.
	local footDiameter = math.max(bodySize.X, bodySize.Z)
	local rimDiameter = math.min(footDiameter * 1.5, 6.2)
	local rim = part(model, "Pedestal", Vector3.new(rimDiameter, 0.16, rimDiameter),
		CFrame.new(0, -(bodySize.Y / 2) - 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(24, 21, 32), Enum.Material.SmoothPlastic)
	rim.Shape = Enum.PartType.Cylinder
	local disc = part(model, "GlowDisc", Vector3.new(math.min(footDiameter * 1.3, 5.6), 0.22, math.min(footDiameter * 1.3, 5.6)),
		CFrame.new(0, -(bodySize.Y / 2) + 0.13, 0) * CFrame.Angles(0, 0, math.rad(90)),
		BrainrotData.RarityColors[def.Rarity] or Color3.new(1, 1, 1), Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder

	local headSize = math.max(bodySize.X, bodySize.Z) * 0.55
	local headY = bodySize.Y / 2 + headSize / 2 - 0.15
	local head = part(model, "Head", Vector3.new(headSize, headSize, headSize),
		CFrame.new(0, headY, 0), def.Accent or def.Color)
	head.Shape = Enum.PartType.Ball

	-- Eyes look along +X, the direction the conveyor travels.
	local headR = headSize / 2
	for _, side in { -1, 1 } do
		local eye = part(model, "Eye", Vector3.new(0.46, 0.46, 0.46),
			CFrame.new(headR * 0.82, headY + headR * 0.12, side * headR * 0.4),
			Color3.fromRGB(18, 16, 22))
		eye.Shape = Enum.PartType.Ball
	end

	if def.Accent then
		local topper = part(model, "Topper", Vector3.new(headSize * 0.45, 0.35, headSize * 0.45),
			CFrame.new(0, headY + headR + 0.05, 0), def.Accent, Enum.Material.Neon)
		topper.Shape = Enum.PartType.Ball
	end

	-- The nameplate carries the whole sales pitch in one glance:
	-- the name in its rarity colour, the income rate with the rarity,
	-- and the price — each line on a dark backing plate so it stays
	-- readable over any background, bright sky included.
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

	model.PrimaryPart = body
	return model, body
end

-- A floating "+$N" that rises over a placed brainrot each time it
-- pays, so income is visible in the world itself, not only in the
-- HUD. One reusable BillboardGui per body; a token keeps a fresh
-- tick from being faded by the previous tick's animation.
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

-- Ride a model to a target position over `seconds`, keeping its facing
-- and adding a small hop arc. Calls `done` at the end unless the model
-- was destroyed on the way.
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
