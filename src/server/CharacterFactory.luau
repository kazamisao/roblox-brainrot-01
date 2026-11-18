-- CharacterFactory: builds every brainrot character as a real 3D Model
-- out of primitive Parts. Each cast member gets its own builder so the
-- seven silhouettes read differently at a glance: a flying cracker disc,
-- a giant iced-tea glass, a singing fried snack, an exploding meatball,
-- a flying plate of nasi padang, a giant rendang pot and a golden satay
-- stove. Every model carries a BillboardGui nameplate with its name, its
-- rarity (in the rarity color) and its $/second, plus one ProximityPrompt
-- the services configure (buy on the conveyor, steal on a base).

local CharacterFactory = {}

type PartSpec = {
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?,
	rotation: Vector3?, -- degrees
	transparency: number?,
}

local function addPart(model: Model, root: Part, spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = spec.size
	part.Color = spec.color
	part.Shape = spec.shape or Enum.PartType.Block
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	local cf = CFrame.new(spec.offset)
	if spec.rotation then
		cf *= CFrame.Angles(math.rad(spec.rotation.X), math.rad(spec.rotation.Y), math.rad(spec.rotation.Z))
	end
	part.CFrame = cf
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addEyes(model: Model, root: Part, y: number, z: number, spread: number, s: number)
	for _, side in { -1, 1 } do
		addPart(model, root, {
			name = "Eye",
			size = Vector3.new(0.22, 0.3, 0.12) * s,
			offset = Vector3.new(side * spread, y, z),
			color = Color3.fromRGB(20, 16, 20),
			shape = Enum.PartType.Ball,
		})
	end
end

local builders: { [string]: (Model, Part, any) -> () } = {}

-- A flat cracker disc with two little wings.
builders.kerupuk = function(model, root, def)
	local s = def.scale
	addPart(model, root, {
		name = "Body",
		size = Vector3.new(2.6, 0.35, 2.6) * s,
		offset = Vector3.new(0, 1.7, 0) * s,
		color = def.bodyColor,
		shape = Enum.PartType.Cylinder,
		rotation = Vector3.new(0, 0, 90),
	})
	for _, side in { -1, 1 } do
		addPart(model, root, {
			name = "Wing",
			size = Vector3.new(1.3, 0.12, 0.8) * s,
			offset = Vector3.new(side * 1.8, 1.9, 0) * s,
			color = def.accentColor,
			rotation = Vector3.new(0, 0, side * 18),
		})
	end
	addEyes(model, root, 1.75 * s, 1.15 * s, 0.45 * s, s)
end

-- A tall glass of amber tea with a straw and ice cubes.
builders.esteh = function(model, root, def)
	local s = def.scale
	addPart(model, root, {
		name = "Glass",
		size = Vector3.new(1.7, 2.4, 1.7) * s,
		offset = Vector3.new(0, 1.5, 0) * s,
		color = def.bodyColor,
		material = Enum.Material.Glass,
		transparency = 0.25,
	})
	addPart(model, root, {
		name = "TeaTop",
		size = Vector3.new(1.8, 0.25, 1.8) * s,
		offset = Vector3.new(0, 2.75, 0) * s,
		color = Color3.fromRGB(160, 90, 30),
	})
	addPart(model, root, {
		name = "Straw",
		size = Vector3.new(0.22, 1.6, 0.22) * s,
		offset = Vector3.new(0.45, 3.3, 0) * s,
		color = Color3.fromRGB(255, 80, 90),
		shape = Enum.PartType.Cylinder,
		rotation = Vector3.new(0, 0, -18),
	})
	for i = 1, 3 do
		addPart(model, root, {
			name = "Ice",
			size = Vector3.new(0.45, 0.45, 0.45) * s,
			offset = Vector3.new(-0.4 + 0.4 * i, 2.45, (i % 2 == 0) and 0.3 or -0.3) * s,
			color = Color3.fromRGB(235, 248, 255),
			rotation = Vector3.new(i * 20, i * 35, 0),
		})
	end
	addEyes(model, root, 1.8 * s, 0.88 * s, 0.4 * s, s)
end

-- A golden fried blob with an open singing mouth and music notes.
builders.gorengan = function(model, root, def)
	local s = def.scale
	addPart(model, root, {
		name = "Body",
		size = Vector3.new(2.3, 1.9, 2.1) * s,
		offset = Vector3.new(0, 1.45, 0) * s,
		color = def.bodyColor,
		shape = Enum.PartType.Ball,
	})
	addPart(model, root, {
		name = "Mouth",
		size = Vector3.new(0.7, 0.5, 0.15) * s,
		offset = Vector3.new(0, 1.15, 1.0) * s,
		color = Color3.fromRGB(60, 25, 15),
		shape = Enum.PartType.Ball,
	})
	for i = 1, 2 do
		local x = (i == 1) and 0.9 or 1.5
		local y = (i == 1) and 3.0 or 3.5
		addPart(model, root, {
			name = "NoteStem",
			size = Vector3.new(0.12, 0.7, 0.12) * s,
			offset = Vector3.new(x, y, 0) * s,
			color = def.accentColor,
			material = Enum.Material.Neon,
		})
		addPart(model, root, {
			name = "NoteHead",
			size = Vector3.new(0.42, 0.32, 0.2) * s,
			offset = Vector3.new(x - 0.15, y - 0.4, 0) * s,
			color = def.accentColor,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Neon,
		})
	end
	addEyes(model, root, 1.8 * s, 0.95 * s, 0.45 * s, s)
end

-- A big meatball with satellite meatballs and a lit fuse.
builders.bakso = function(model, root, def)
	local s = def.scale
	local body = addPart(model, root, {
		name = "Body",
		size = Vector3.new(2.7, 2.7, 2.7) * s,
		offset = Vector3.new(0, 1.7, 0) * s,
		color = def.bodyColor,
		shape = Enum.PartType.Ball,
	})
	local satellites = {
		Vector3.new(1.6, 1.1, 0.6),
		Vector3.new(-1.5, 2.3, -0.5),
		Vector3.new(0.4, 2.9, 0.9),
	}
	for _, off in satellites do
		addPart(model, root, {
			name = "MiniBakso",
			size = Vector3.new(0.95, 0.95, 0.95) * s,
			offset = off * s,
			color = Color3.fromRGB(150, 100, 66),
			shape = Enum.PartType.Ball,
		})
	end
	addPart(model, root, {
		name = "Fuse",
		size = Vector3.new(0.14, 0.7, 0.14) * s,
		offset = Vector3.new(0, 3.35, 0) * s,
		color = Color3.fromRGB(40, 40, 40),
		shape = Enum.PartType.Cylinder,
		rotation = Vector3.new(0, 0, 25),
	})
	local light = Instance.new("PointLight")
	light.Name = "FuseLight"
	light.Color = def.accentColor
	light.Range = 7
	light.Brightness = 2
	light.Parent = body
	addEyes(model, root, 1.9 * s, 1.3 * s, 0.55 * s, s)
end

-- A mound of rice on a banana-leaf plate, with wings and rendang chunks.
builders.nasipadang = function(model, root, def)
	local s = def.scale
	addPart(model, root, {
		name = "Plate",
		size = Vector3.new(3.6, 0.3, 3.6) * s,
		offset = Vector3.new(0, 0.95, 0) * s,
		color = def.accentColor,
		shape = Enum.PartType.Cylinder,
		rotation = Vector3.new(0, 0, 90),
	})
	addPart(model, root, {
		name = "Rice",
		size = Vector3.new(2.3, 1.5, 2.3) * s,
		offset = Vector3.new(0, 1.7, 0) * s,
		color = def.bodyColor,
		shape = Enum.PartType.Ball,
	})
	for i = 1, 3 do
		addPart(model, root, {
			name = "RendangChunk",
			size = Vector3.new(0.6, 0.45, 0.6) * s,
			offset = Vector3.new(-0.8 + 0.8 * (i - 1), 1.35, 1.15) * s,
			color = Color3.fromRGB(110, 32, 24),
			rotation = Vector3.new(0, i * 40, 0),
		})
	end
	for _, side in { -1, 1 } do
		addPart(model, root, {
			name = "LeafWing",
			size = Vector3.new(1.5, 0.1, 1.0) * s,
			offset = Vector3.new(side * 2.2, 1.2, 0) * s,
			color = Color3.fromRGB(80, 170, 70),
			rotation = Vector3.new(0, 0, side * 15),
		})
	end
	addEyes(model, root, 1.95 * s, 1.05 * s, 0.45 * s, s)
end

-- A stacked dark-red rendang giant with chili horns.
builders.rendang = function(model, root, def)
	local s = def.scale
	addPart(model, root, {
		name = "Body",
		size = Vector3.new(2.7, 2.1, 2.7) * s,
		offset = Vector3.new(0, 1.35, 0) * s,
		color = def.bodyColor,
		material = Enum.Material.Slate,
	})
	local top = addPart(model, root, {
		name = "TopChunk",
		size = Vector3.new(1.9, 1.3, 1.9) * s,
		offset = Vector3.new(0.2, 3.0, 0) * s,
		color = Color3.fromRGB(140, 40, 30),
		material = Enum.Material.Slate,
		rotation = Vector3.new(0, 20, 0),
	})
	for _, side in { -1, 1 } do
		addPart(model, root, {
			name = "Chili",
			size = Vector3.new(0.22, 1.0, 0.22) * s,
			offset = Vector3.new(side * 0.8, 3.9, 0) * s,
			color = def.accentColor,
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Neon,
			rotation = Vector3.new(0, 0, side * -30),
		})
	end
	local light = Instance.new("PointLight")
	light.Name = "RendangGlow"
	light.Color = def.accentColor
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = top
	addEyes(model, root, 1.6 * s, 1.38 * s, 0.55 * s, s)
end

-- A golden satay stove: metal box, grill, skewers, sparkles and glow.
builders.sateemas = function(model, root, def)
	local s = def.scale
	local stove = addPart(model, root, {
		name = "Stove",
		size = Vector3.new(2.4, 1.7, 2.4) * s,
		offset = Vector3.new(0, 1.15, 0) * s,
		color = def.bodyColor,
		material = Enum.Material.Metal,
	})
	addPart(model, root, {
		name = "Grill",
		size = Vector3.new(2.5, 0.2, 2.5) * s,
		offset = Vector3.new(0, 2.1, 0) * s,
		color = Color3.fromRGB(50, 45, 50),
		material = Enum.Material.Metal,
	})
	for i = 1, 3 do
		local x = -0.7 + 0.7 * (i - 1)
		addPart(model, root, {
			name = "Skewer",
			size = Vector3.new(0.1, 0.1, 2.6) * s,
			offset = Vector3.new(x, 2.45, 0) * s,
			color = Color3.fromRGB(190, 150, 90),
			shape = Enum.PartType.Cylinder,
			rotation = Vector3.new(90, 0, 0),
		})
		for j = 1, 3 do
			addPart(model, root, {
				name = "SatePiece",
				size = Vector3.new(0.42, 0.42, 0.42) * s,
				offset = Vector3.new(x, 2.45, -0.8 + 0.8 * (j - 1)) * s,
				color = Color3.fromRGB(255, 205, 70),
				material = Enum.Material.Neon,
			})
		end
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = "GoldSparkles"
	sparkles.SparkleColor = def.accentColor
	sparkles.Parent = stove
	local light = Instance.new("PointLight")
	light.Name = "GoldGlow"
	light.Color = def.bodyColor
	light.Range = 10
	light.Brightness = 2.5
	light.Parent = stove
	addEyes(model, root, 1.35 * s, 1.23 * s, 0.5 * s, s)
end

local function formatMoney(n: number): string
	if n >= 1000 then
		local text = string.format("%.1f", n / 1000):gsub("%.0$", "")
		return "$" .. text .. "rb"
	end
	return "$" .. tostring(math.floor(n))
end
CharacterFactory.FormatMoney = formatMoney

-- Build one character model for a definition. The model pivots around a
-- small invisible root at its feet; services move it with PivotTo.
function CharacterFactory.Build(def): Model
	local model = Instance.new("Model")
	model.Name = def.name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1.2, 0.4, 1.2) * def.scale
	root.CFrame = CFrame.new(0, 0.2 * def.scale, 0)
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	-- A little saucer the character stands on, so it reads as a carried
	-- warung dish while it rides the conveyor.
	addPart(model, root, {
		name = "Saucer",
		size = Vector3.new(3.0, 0.22, 3.0) * def.scale,
		offset = Vector3.new(0, 0.3, 0) * def.scale,
		color = Color3.fromRGB(240, 240, 245),
		shape = Enum.PartType.Cylinder,
		rotation = Vector3.new(0, 0, 90),
	})

	local build = builders[def.build]
	if build then
		build(model, root, def)
	end

	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(220, 74)
	plate.StudsOffset = Vector3.new(0, 4.4 * def.scale, 0)
	plate.AlwaysOnTop = false
	plate.MaxDistance = 60
	plate.Parent = root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 26)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 20
	nameLabel.Parent = plate

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Position = UDim2.new(0, 0, 0, 25)
	rarityLabel.Size = UDim2.new(1, 0, 0, 20)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = def.rarity
	rarityLabel.TextColor3 = def.rarityColor
	rarityLabel.TextStrokeTransparency = 0.35
	rarityLabel.Font = Enum.Font.FredokaOne
	rarityLabel.TextSize = 16
	rarityLabel.Parent = plate

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Position = UDim2.new(0, 0, 0, 44)
	rateLabel.Size = UDim2.new(1, 0, 0, 22)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = "$" .. def.rate .. "/dtk"
	rateLabel.TextColor3 = Color3.fromRGB(140, 255, 150)
	rateLabel.TextStrokeTransparency = 0.35
	rateLabel.Font = Enum.Font.FredokaOne
	rateLabel.TextSize = 18
	rateLabel.Parent = plate

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ActionPrompt"
	prompt.ActionText = "Beli"
	prompt.ObjectText = def.name .. " " .. formatMoney(def.price)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = root

	model:SetAttribute("DefId", def.id)
	model:SetAttribute("Rate", def.rate)
	model:SetAttribute("Price", def.price)
	return model
end

return CharacterFactory
