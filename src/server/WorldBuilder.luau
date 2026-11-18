-- WorldBuilder: constructs the whole of Brainrot Island out of Parts
-- at server start — the grass island and its beaches, the plaza with
-- the central conveyor, six player bases with six slots each, the
-- rebirth stall, palm trees around the rim and the spawn — and hands
-- the services the references they need (base slot positions, lock
-- pads and walls, belt geometry, spawn). If it stands in the world,
-- it is built here.

local Workspace = game:GetService("Workspace")

local WorldBuilder = {}

export type BaseSpot = {
	Index: number,
	Center: Vector3, -- at plaza-floor height (Y = FloorTop)
	Slots: { Vector3 }, -- floor positions characters stand on
	LockPad: Part,
	LockWall: Part,
	OwnerSign: TextLabel,
}

WorldBuilder.FloorTop = 1 -- plaza surface height
WorldBuilder.IslandTop = 0 -- grass surface height away from the plaza
WorldBuilder.BeltTopY = 1.6
WorldBuilder.BeltStartX = -50
WorldBuilder.BeltEndX = 50
WorldBuilder.BeltZ = 0

local SLOT_OFFSETS = {
	Vector3.new(-6.5, 0, -3.6), Vector3.new(0, 0, -3.6), Vector3.new(6.5, 0, -3.6),
	Vector3.new(-6.5, 0, 3.6), Vector3.new(0, 0, 3.6), Vector3.new(6.5, 0, 3.6),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, anchored: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = anchored ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function boardText(parent: Part, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
	return label
end

function WorldBuilder.Build()
	local old = Workspace:FindFirstChild("BrainrotWorld")
	if old then
		old:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "BrainrotWorld"
	world.Parent = Workspace

	local beltFolder = Instance.new("Folder")
	beltFolder.Name = "BeltBrainrots"
	beltFolder.Parent = world
	local placedFolder = Instance.new("Folder")
	placedFolder.Name = "PlacedBrainrots"
	placedFolder.Parent = world
	local meteorsFolder = Instance.new("Folder")
	meteorsFolder.Name = "Meteors"
	meteorsFolder.Parent = world

	-- The island shell: grass, sand rims, and a sea you cannot stand on.
	part(world, "MainIsland", Vector3.new(260, 8, 260), CFrame.new(0, -4, 0),
		Color3.fromRGB(73, 145, 75), Enum.Material.Grass)
	part(world, "BeachNorth", Vector3.new(260, 1, 24), CFrame.new(0, 0.2, -118),
		Color3.fromRGB(231, 211, 151), Enum.Material.Sand)
	part(world, "BeachSouth", Vector3.new(260, 1, 24), CFrame.new(0, 0.2, 118),
		Color3.fromRGB(231, 211, 151), Enum.Material.Sand)
	local ocean = part(world, "Ocean", Vector3.new(650, 2, 650), CFrame.new(0, -7, 0),
		Color3.fromRGB(30, 118, 166), Enum.Material.Water)
	ocean.CanCollide = false

	-- The plaza the game happens on.
	part(world, "Plaza", Vector3.new(120, 1, 62), CFrame.new(0, 0.5, 0),
		Color3.fromRGB(120, 91, 62), Enum.Material.WoodPlanks)

	-- The conveyor: a dark belt down the middle with neon rails.
	part(world, "Belt", Vector3.new(104, 0.6, 9), CFrame.new(0, 1.3, 0),
		Color3.fromRGB(38, 38, 46), Enum.Material.Metal)
	part(world, "BeltRailA", Vector3.new(104, 0.5, 0.5), CFrame.new(0, 1.85, -4.7),
		Color3.fromRGB(255, 170, 40), Enum.Material.Neon)
	part(world, "BeltRailB", Vector3.new(104, 0.5, 0.5), CFrame.new(0, 1.85, 4.7),
		Color3.fromRGB(255, 170, 40), Enum.Material.Neon)
	for _, endX in { -52, 52 } do
		part(world, "BeltPost", Vector3.new(1.2, 3.4, 10), CFrame.new(endX, 1.7, 0),
			Color3.fromRGB(70, 70, 84), Enum.Material.Metal)
	end

	-- Spawn, on the plaza south of the belt.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "IslandSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, WorldBuilder.FloorTop + 0.5, 14)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Color = Color3.fromRGB(120, 91, 62)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Parent = world

	-- The welcome board, facing the belt from the plaza's north edge.
	local board = part(world, "WelcomeBoard", Vector3.new(17, 8, 1),
		CFrame.new(0, WorldBuilder.FloorTop + 4.6, -24), Color3.fromRGB(92, 58, 35), Enum.Material.Wood)
	boardText(board, Enum.NormalId.Front,
		"BRAINROT ISLAND\nBeli dari conveyor - pajang di base\nCuri punya orang - kunci basemu\nRebirth: penghasilan +25% per level",
		Color3.new(1, 1, 1))

	-- Palm trees around the rim, clear of the plaza and the bases.
	for i = 1, 30 do
		local angle = math.rad(i * 12)
		local radius = 78 + (i % 4) * 12
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local scale = 0.8 + (i % 3) * 0.12
		local tree = Instance.new("Model")
		tree.Name = "PalmTree"
		tree.Parent = world
		local trunk = part(tree, "Trunk", Vector3.new(12 * scale, 2 * scale, 2 * scale),
			CFrame.new(x, 6 * scale, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(111, 75, 43), Enum.Material.Wood)
		trunk.Shape = Enum.PartType.Cylinder
		local crown = part(tree, "Leaves", Vector3.new(10 * scale, 5 * scale, 10 * scale),
			CFrame.new(x, 12 * scale, z), Color3.fromRGB(35, 116, 54), Enum.Material.Grass)
		crown.Shape = Enum.PartType.Ball
		tree.PrimaryPart = trunk
	end

	-- Six bases in two rows facing the plaza.
	local bases: { BaseSpot } = {}
	for i = 1, 6 do
		local row = (i <= 3) and -1 or 1
		local col = ((i - 1) % 3) - 1
		local cx, cz = col * 42, row * 40
		local center = Vector3.new(cx, WorldBuilder.FloorTop, cz)

		part(world, "BaseFloor" .. i, Vector3.new(24, 1, 18), CFrame.new(cx, 0.5, cz),
			Color3.fromRGB(96, 74, 54), Enum.Material.WoodPlanks)

		local slots: { Vector3 } = {}
		for s, offset in SLOT_OFFSETS do
			local pos = center + offset
			slots[s] = pos
			part(world, "SlotPad" .. i .. "_" .. s, Vector3.new(3.6, 0.25, 3.6),
				CFrame.new(pos.X, WorldBuilder.FloorTop + 0.12, pos.Z),
				Color3.fromRGB(52, 46, 60), Enum.Material.Slate)
		end

		local wall = part(world, "LockWall" .. i, Vector3.new(24, 9, 18),
			CFrame.new(cx, WorldBuilder.FloorTop + 4.5, cz),
			Color3.fromRGB(80, 220, 255), Enum.Material.Neon)
		wall.Transparency = 1
		wall.CanCollide = false

		-- The owner sign sits on the plaza-facing edge, turned to the plaza.
		local signZ = cz - row * 9.4
		local sign = part(world, "BaseSign" .. i, Vector3.new(14, 3.4, 0.6),
			CFrame.new(cx, WorldBuilder.FloorTop + 2.2, signZ),
			Color3.fromRGB(92, 58, 35), Enum.Material.Wood)
		local face = (row < 0) and Enum.NormalId.Front or Enum.NormalId.Back
		local signLabel = boardText(sign, face, "BASE KOSONG", Color3.new(1, 1, 1))

		local pad = part(world, "LockPad" .. i, Vector3.new(3.4, 0.5, 3.4),
			CFrame.new(cx, WorldBuilder.FloorTop + 0.25, cz - row * 7.6),
			Color3.fromRGB(80, 220, 255), Enum.Material.Neon)
		pad.Shape = Enum.PartType.Cylinder

		bases[i] = {
			Index = i,
			Center = center,
			Slots = slots,
			LockPad = pad,
			LockWall = wall,
			OwnerSign = signLabel,
		}
	end

	-- The rebirth stall on the plaza, east side.
	local stall = part(world, "RebirthStall", Vector3.new(8, 4, 5), CFrame.new(30, WorldBuilder.FloorTop + 2, -22),
		Color3.fromRGB(90, 40, 120), Enum.Material.WoodPlanks)
	part(world, "RebirthRoof", Vector3.new(10, 0.6, 7), CFrame.new(30, WorldBuilder.FloorTop + 4.6, -22),
		Color3.fromRGB(60, 25, 85), Enum.Material.Wood)
	local stallSign = part(world, "RebirthSign", Vector3.new(9, 2.6, 0.6), CFrame.new(30, WorldBuilder.FloorTop + 6.2, -22),
		Color3.fromRGB(60, 25, 85), Enum.Material.Wood)
	boardText(stallSign, Enum.NormalId.Front, "REBIRTH\n+25% penghasilan per level",
		Color3.fromRGB(230, 190, 255))

	return {
		Folder = world,
		BeltFolder = beltFolder,
		PlacedFolder = placedFolder,
		MeteorsFolder = meteorsFolder,
		Bases = bases,
		SpawnCFrame = CFrame.new(0, WorldBuilder.FloorTop + 3.5, 14),
		RebirthPad = stall,
	}
end

return WorldBuilder
