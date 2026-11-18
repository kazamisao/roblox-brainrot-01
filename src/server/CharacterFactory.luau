-- CharacterFactory: builds a brainrot character as a real 3D Model out
-- of primitive Parts — a shaped body in the tier's colour, a ball head,
-- two eyes and a floating nameplate that reads name, income and rarity
-- in the rarity's colour. Characters are anchored and never simulated;
-- movement is the factory's GlideTo, a PivotTo ride with a little hop.

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
	local body = part(model, "Body", bodySize, CFrame.new(), def.Color)
	body.Shape = def.Shape
	if def.Shape == Enum.PartType.Cylinder then
		-- A cylinder part's axis runs along X; stand the cracker upright.
		body.CFrame = CFrame.Angles(0, 0, math.rad(90))
	end

	local headSize = math.max(bodySize.X, bodySize.Z) * 0.55
	local headY = bodySize.Y / 2 + headSize / 2 - 0.15
	local head = part(model, "Head", Vector3.new(headSize, headSize, headSize),
		CFrame.new(0, headY, 0), def.Accent or def.Color)
	head.Shape = Enum.PartType.Ball

	-- Eyes look along +X, the direction the conveyor travels.
	local headR = headSize / 2
	for _, side in { -1, 1 } do
		local eye = part(model, "Eye", Vector3.new(0.34, 0.34, 0.34),
			CFrame.new(headR * 0.82, headY + headR * 0.12, side * headR * 0.4),
			Color3.fromRGB(18, 16, 22))
		eye.Shape = Enum.PartType.Ball
	end

	if def.Accent then
		local topper = part(model, "Topper", Vector3.new(headSize * 0.45, 0.35, headSize * 0.45),
			CFrame.new(0, headY + headR + 0.05, 0), def.Accent, Enum.Material.Neon)
		topper.Shape = Enum.PartType.Ball
	end

	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.new(7.5, 0, 2, 0)
	plate.StudsOffset = Vector3.new(0, bodySize.Y / 2 + 1.6, 0)
	plate.AlwaysOnTop = true
	plate.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = plate

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Sub"
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "$" .. def.PerSec .. "/dtk • " .. def.Rarity
	subLabel.TextColor3 = BrainrotData.RarityColors[def.Rarity] or Color3.new(1, 1, 1)
	subLabel.Font = Enum.Font.FredokaOne
	subLabel.TextScaled = true
	subLabel.TextStrokeTransparency = 0.4
	subLabel.Parent = plate

	model.PrimaryPart = body
	return model, body
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
