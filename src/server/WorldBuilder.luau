-- WorldBuilder: constructs Brainrot Island BARU out of plain Parts
-- at server start -- the grass island, the plaza, the conveyor belt
-- down its middle, six player bases with six slot pads each, the
-- spawn, the welcome board and the rebirth stall -- and hands the
-- services the references they need. Every part is placed with a
-- direct CFrame computed from the constants below, and the surface
-- heights are the contract the rest of the game stands on:
--
--   IslandTop = 0     top of the grass island shell
--   FloorTop  = 1     top of the plaza and of every base floor
--   BeltTopY  = 1.6   top of the conveyor belt surface
--   SlotTopY  = 1.25  top of a base slot pad
--
-- A character's origin is its feet, so a character standing on the
-- belt is placed at Y = BeltTopY and one on a slot pad at SlotTopY.
-- If it stands in the world, it is built here.

local Workspace = game:GetService("Workspace")

local WorldBuilder = {}

export type BaseSpot = {
	Index: number,
	Center: Vector3, -- at base-floor height (Y = FloorTop)
	Slots: { Vector3 }, -- standing points, Y = SlotTopY
	LockPad: Part,
	LockWall: Part,
	OwnerSign: TextLabel,
	Locked: boolean,
	LockToken: number,
}

WorldBuilder.IslandTop = 0
WorldBuilder.FloorTop = 1
WorldBuilder.BeltTopY = 1.6
WorldBuilder.SlotTopY = 1.25
WorldBuilder.BeltStartX = -50
WorldBuilder.BeltEndX = 50
WorldBuilder.BeltZ = 0

local SLOT_OFFSETS = {
	Vector3.new(-6.5, 0, -3.6), Vector3.new(0, 0, -3.6), Vector3.new(6.5, 0, -3.6),
	Vector3.new(-6.5, 0, 3.6), Vector3.new(0, 0, 3.6), Vector3.new(6.5, 0, 3.6),
}

local BASE_ROOF_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(255, 215, 60),
	Color3.fromRGB(80, 220, 90),
	Color3.fromRGB(60, 200, 255),
	Color3.fromRGB(180, 100, 255),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
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

	-- The island shell: a thick grass slab whose top is Y = 0.
	part(world, "MainIsland", Vector3.new(260, 8, 260), CFrame.new(0, -4, 0),
		Color3.fromRGB(73, 145, 75), Enum.Material.Grass)
	local ocean = part(world, "Ocean", Vector3.new(650, 2, 650), CFrame.new(0, -7, 0),
		Color3.fromRGB(30, 118, 166), Enum.Material.Water)
	ocean.CanCollide = false

	-- The plaza: a wooden deck whose top is exactly FloorTop.
	part(world, "Plaza", Vector3.new(120, 1, 62), CFrame.new(0, 0.5, 0),
		Color3.fromRGB(120, 91, 62), Enum.Material.WoodPlanks)
	-- Diagnostic marker (Build 16): a tall neon obelisk standing on
	-- the plaza. If the world renders, this cannot be missed; the
	-- probe reports its live position alongside the plaza's.
	part(world, "MarkerObelisk", Vector3.new(3, 30, 3), CFrame.new(0, 16, -12),
		Color3.fromRGB(255, 0, 128), Enum.Material.Neon)
	local trimNS = Color3.fromRGB(255, 70, 160)
	local trimEW = Color3.fromRGB(60, 220, 255)
	part(world, "PlazaTrimN", Vector3.new(120, 0.25, 1), CFrame.new(0, WorldBuilder.FloorTop + 0.12, -30.4), trimNS, Enum.Material.Neon)
	part(world, "PlazaTrimS", Vector3.new(120, 0.25, 1), CFrame.new(0, WorldBuilder.FloorTop + 0.12, 30.4), trimNS, Enum.Material.Neon)
	part(world, "PlazaTrimE", Vector3.new(1, 0.25, 62), CFrame.new(59.4, WorldBuilder.FloorTop + 0.12, 0), trimEW, Enum.Material.Neon)
	part(world, "PlazaTrimW", Vector3.new(1, 0.25, 62), CFrame.new(-59.4, WorldBuilder.FloorTop + 0.12, 0), trimEW, Enum.Material.Neon)

	-- The conveyor: dark belt slab (top exactly BeltTopY), neon
	-- rails, end posts and a start sign over the west post.
	part(world, "Belt", Vector3.new(104, 0.6, 9), CFrame.new(0, 1.3, 0),
		Color3.fromRGB(38, 38, 46), Enum.Material.Metal)
	part(world, "BeltRailA", Vector3.new(104, 0.5, 0.5), CFrame.new(0, 1.85, -4.7), Color3.fromRGB(255, 235, 60), Enum.Material.Neon)
	part(world, "BeltRailB", Vector3.new(104, 0.5, 0.5), CFrame.new(0, 1.85, 4.7), Color3.fromRGB(255, 235, 60), Enum.Material.Neon)
	for _, endX in { -52, 52 } do
		part(world, "BeltPost", Vector3.new(1.2, 3.4, 10), CFrame.new(endX, 1.7, 0), Color3.fromRGB(70, 70, 84), Enum.Material.Metal)
	end
	for _, chevX in { -40, -20, 0, 20, 40 } do
		for _, side in { -3.1, 3.1 } do
			part(world, "BeltChevron", Vector3.new(1.7, 0.15, 0.55),
				CFrame.new(chevX, WorldBuilder.BeltTopY + 0.08, side) * CFrame.Angles(0, math.rad(-35), 0),
				Color3.fromRGB(255, 140, 0), Enum.Material.Neon)
		end
	end
	local startSign = part(world, "BeltStartSign", Vector3.new(5, 2, 0.5), CFrame.new(-52, 4.4, 0), Color3.fromRGB(60, 200, 90))
	boardText(startSign, Enum.NormalId.Front, "MULAI", Color3.new(1, 1, 1))
	boardText(startSign, Enum.NormalId.Back, "MULAI", Color3.new(1, 1, 1))

	-- Spawn pad on the plaza south of the belt, with a golden
	-- walkway leading to the belt.
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
	part(world, "SpawnWalkway", Vector3.new(4, 0.12, 5), CFrame.new(0, WorldBuilder.FloorTop + 0.06, 7.5),
		Color3.fromRGB(255, 200, 60))

	-- The welcome board on the plaza's north edge. The last line is
	-- the build marker: a screenshot of this board proves which
	-- build the server is running.
	local board = part(world, "WelcomeBoard", Vector3.new(19, 8.5, 1),
		CFrame.new(0, WorldBuilder.FloorTop + 4.8, -24), Color3.fromRGB(92, 58, 35), Enum.Material.Wood)
	boardText(board, Enum.NormalId.Front,
		"BRAINROT ISLAND BARU\nBeli dari conveyor - pajang di base\nCuri punya orang - kunci basemu\nBuild 17",
		Color3.new(1, 1, 1))
	boardText(board, Enum.NormalId.Back,
		"BRAINROT ISLAND BARU\nBuild 17",
		Color3.new(1, 1, 1))

	-- A hero pedestal on the plaza's south-west inlay; init sets
	-- the Secret character on it as a statue.
	part(world, "HeroPedestal", Vector3.new(12, 1, 12), CFrame.new(-32, WorldBuilder.FloorTop + 0.5, 17),
		Color3.fromRGB(52, 46, 60), Enum.Material.Slate)
	part(world, "HeroPedestalTrim", Vector3.new(12.6, 0.3, 12.6), CFrame.new(-32, WorldBuilder.FloorTop + 1.05, 17),
		Color3.fromRGB(255, 70, 60), Enum.Material.Neon)

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
			local pos = Vector3.new(cx + offset.X, WorldBuilder.SlotTopY, cz + offset.Z)
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

		part(world, "BaseRoof" .. i, Vector3.new(25, 0.5, 6),
			CFrame.new(cx, WorldBuilder.FloorTop + 6.5, cz + row * 7.5),
			BASE_ROOF_COLORS[i])
		for _, postX in { cx - 11, cx + 11 } do
			part(world, "BaseRoofPost" .. i, Vector3.new(0.4, 6.3, 0.4),
				CFrame.new(postX, WorldBuilder.FloorTop + 3.15, cz + row * 7.5),
				Color3.fromRGB(70, 50, 35), Enum.Material.Wood)
		end

		bases[i] = {
			Index = i,
			Center = center,
			Slots = slots,
			LockPad = pad,
			LockWall = wall,
			OwnerSign = signLabel,
			Locked = false,
			LockToken = 0,
		}
	end

	-- The rebirth stall on the plaza's east side (rebirth itself is
	-- driven from the HUD button; the stall is the landmark).
	local stall = part(world, "RebirthStall", Vector3.new(8, 4, 5), CFrame.new(30, WorldBuilder.FloorTop + 2, -22),
		Color3.fromRGB(90, 40, 120), Enum.Material.WoodPlanks)
	part(world, "RebirthRoof", Vector3.new(10, 0.6, 7), CFrame.new(30, WorldBuilder.FloorTop + 4.6, -22),
		Color3.fromRGB(60, 25, 85), Enum.Material.Wood)
	local stallSign = part(world, "RebirthSign", Vector3.new(9, 2.6, 0.6), CFrame.new(30, WorldBuilder.FloorTop + 6.2, -22),
		Color3.fromRGB(60, 25, 85), Enum.Material.Wood)
	boardText(stallSign, Enum.NormalId.Front, "REBIRTH\n+25% penghasilan per level", Color3.fromRGB(230, 190, 255))

	-- A few palms and bushes on the grass rim for silhouette.
	for i = 1, 10 do
		local angle = math.rad(i * 36 + 10)
		local x, z = math.cos(angle) * 100, math.sin(angle) * 100
		local trunk = part(world, "PalmTrunk", Vector3.new(7, 1.3, 1.3),
			CFrame.new(x, WorldBuilder.IslandTop + 3.5, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(111, 75, 43), Enum.Material.Wood)
		trunk.Shape = Enum.PartType.Cylinder
		local canopy = part(world, "PalmCanopy", Vector3.new(6.5, 5, 6.5),
			CFrame.new(x, WorldBuilder.IslandTop + 7.2, z), Color3.fromRGB(35, 150, 60), Enum.Material.Grass)
		canopy.Shape = Enum.PartType.Ball
	end

	print("[BrainrotIslandBaru] world built OK - bases:", #bases)

	return {
		Folder = world,
		BeltFolder = beltFolder,
		PlacedFolder = placedFolder,
		Bases = bases,
		SpawnCFrame = CFrame.new(0, WorldBuilder.FloorTop + 3.5, 14),
		RebirthPad = stall,
		HeroSpot = Vector3.new(-32, WorldBuilder.FloorTop + 1.2, 17),
	}
end

return WorldBuilder
