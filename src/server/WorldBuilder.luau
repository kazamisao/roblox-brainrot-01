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

-- One saturated awning color per base, so each base reads as its own
-- little shop stall from across the plaza.
local BASE_ROOF_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(255, 215, 60),
	Color3.fromRGB(80, 220, 90),
	Color3.fromRGB(60, 200, 255),
	Color3.fromRGB(180, 100, 255),
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

	-- Bright neon trim around the plaza edges, and a golden walkway
	-- from the spawn pad straight to the belt.
	local trimNS = Color3.fromRGB(255, 70, 160)
	local trimEW = Color3.fromRGB(60, 220, 255)
	part(world, "PlazaTrimN", Vector3.new(120, 0.25, 1), CFrame.new(0, WorldBuilder.FloorTop + 0.12, -30.4),
		trimNS, Enum.Material.Neon)
	part(world, "PlazaTrimS", Vector3.new(120, 0.25, 1), CFrame.new(0, WorldBuilder.FloorTop + 0.12, 30.4),
		trimNS, Enum.Material.Neon)
	part(world, "PlazaTrimE", Vector3.new(1, 0.25, 62), CFrame.new(59.4, WorldBuilder.FloorTop + 0.12, 0),
		trimEW, Enum.Material.Neon)
	part(world, "PlazaTrimW", Vector3.new(1, 0.25, 62), CFrame.new(-59.4, WorldBuilder.FloorTop + 0.12, 0),
		trimEW, Enum.Material.Neon)
	part(world, "SpawnWalkway", Vector3.new(4, 0.12, 5), CFrame.new(0, WorldBuilder.FloorTop + 0.06, 7.5),
		Color3.fromRGB(255, 200, 60), Enum.Material.SmoothPlastic)

	-- The conveyor: a dark belt down the middle with neon rails.
	part(world, "Belt", Vector3.new(104, 0.6, 9), CFrame.new(0, 1.3, 0),
		Color3.fromRGB(38, 38, 46), Enum.Material.Metal)
	part(world, "BeltRailA", Vector3.new(104, 0.5, 0.5), CFrame.new(0, 1.85, -4.7),
		Color3.fromRGB(255, 235, 60), Enum.Material.Neon)
	part(world, "BeltRailB", Vector3.new(104, 0.5, 0.5), CFrame.new(0, 1.85, 4.7),
		Color3.fromRGB(255, 235, 60), Enum.Material.Neon)
	for _, endX in { -52, 52 } do
		part(world, "BeltPost", Vector3.new(1.2, 3.4, 10), CFrame.new(endX, 1.7, 0),
			Color3.fromRGB(70, 70, 84), Enum.Material.Metal)
	end

	-- Neon chevrons along both sides of the belt, pointing the way the
	-- brainrots walk (+X), and a start sign over the west belt post.
	local chevronColors = { Color3.fromRGB(255, 140, 0), Color3.fromRGB(0, 220, 255) }
	for ci, chevX in { -40, -20, 0, 20, 40 } do
		local chevColor = chevronColors[(ci - 1) % #chevronColors + 1]
		for _, side in { -3.1, 3.1 } do
			part(world, "BeltChevron", Vector3.new(1.7, 0.15, 0.55),
				CFrame.new(chevX, WorldBuilder.BeltTopY + 0.08, side - 0.38) * CFrame.Angles(0, math.rad(-35), 0),
				chevColor, Enum.Material.Neon)
			part(world, "BeltChevron", Vector3.new(1.7, 0.15, 0.55),
				CFrame.new(chevX, WorldBuilder.BeltTopY + 0.08, side + 0.38) * CFrame.Angles(0, math.rad(35), 0),
				chevColor, Enum.Material.Neon)
		end
	end
	local startSign = part(world, "BeltStartSign", Vector3.new(5, 2, 0.5), CFrame.new(-52, 4.4, 0),
		Color3.fromRGB(60, 200, 90), Enum.Material.SmoothPlastic)
	boardText(startSign, Enum.NormalId.Front, "MULAI", Color3.new(1, 1, 1))
	boardText(startSign, Enum.NormalId.Back, "MULAI", Color3.new(1, 1, 1))

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

	-- A welcome arch over the spawn pad: two orange pillars and a
	-- purple title board with a subtitle, readable from both sides.
	for _, pillarX in { -5.5, 5.5 } do
		part(world, "ArchPillar", Vector3.new(1.2, 7, 1.2), CFrame.new(pillarX, WorldBuilder.FloorTop + 3.5, 14),
			Color3.fromRGB(255, 120, 40), Enum.Material.SmoothPlastic)
	end
	local archBoard = part(world, "ArchBoard", Vector3.new(13, 2.6, 0.8), CFrame.new(0, WorldBuilder.FloorTop + 8.3, 14),
		Color3.fromRGB(140, 60, 220), Enum.Material.SmoothPlastic)
	boardText(archBoard, Enum.NormalId.Front, "BRAINROT ISLAND", Color3.new(1, 1, 1))
	boardText(archBoard, Enum.NormalId.Back, "BRAINROT ISLAND", Color3.new(1, 1, 1))
	local archSub = part(world, "ArchSubBoard", Vector3.new(13, 1.4, 0.8), CFrame.new(0, WorldBuilder.FloorTop + 6.3, 14),
		Color3.fromRGB(140, 60, 220), Enum.Material.SmoothPlastic)
	boardText(archSub, Enum.NormalId.Front, "Beli brainrot di conveyor • Kumpulkan cash • Rebirth!", Color3.new(1, 1, 1))
	boardText(archSub, Enum.NormalId.Back, "Beli brainrot di conveyor • Kumpulkan cash • Rebirth!", Color3.new(1, 1, 1))

	-- A giant floating title over the plaza's north side, readable
	-- from the spawn pad: a dark purple board held up by two neon
	-- beams, its text showing on both faces.
	local titleBoard = part(world, "TitleBoard", Vector3.new(30, 7, 0.8), CFrame.new(0, 26, -20),
		Color3.fromRGB(60, 25, 95), Enum.Material.SmoothPlastic)
	boardText(titleBoard, Enum.NormalId.Front, "BRAINROT ISLAND", Color3.new(1, 1, 1))
	boardText(titleBoard, Enum.NormalId.Back, "BRAINROT ISLAND", Color3.new(1, 1, 1))
	for _, beamX in { -14, 14 } do
		part(world, "TitleBeam", Vector3.new(0.8, 22, 0.8), CFrame.new(beamX, 12, -20),
			Color3.fromRGB(255, 70, 160), Enum.Material.Neon)
	end

	-- A rainbow arch over the belt start — the gateway every brainrot
	-- walks through. Five saturated segments on a semicircle spanning
	-- z -7..7, peaking at height 9.
	local archColors = {
		Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 150, 40),
		Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 220, 90),
		Color3.fromRGB(70, 140, 255),
	}
	for seg = 0, 4 do
		local a = math.rad(seg * 45)
		local segPart = part(world, "RainbowArch", Vector3.new(1.2, 4.8, 1.2),
			CFrame.new(WorldBuilder.BeltStartX, 2 + 7 * math.sin(a), -7 * math.cos(a))
				* CFrame.Angles(a, 0, 0),
			archColors[seg + 1], Enum.Material.SmoothPlastic)
		segPart.CanCollide = false
	end

	-- Saturated quadrant inlays inset into the plaza floor, clear of
	-- the belt strip and the spawn walkway.
	local inlayColors = {
		Color3.fromRGB(255, 70, 70), Color3.fromRGB(70, 140, 255),
		Color3.fromRGB(80, 220, 90), Color3.fromRGB(255, 220, 60),
	}
	local inlaySpots = { { -32, -17 }, { 32, -17 }, { -32, 17 }, { 32, 17 } }
	for idx, spot in inlaySpots do
		part(world, "PlazaInlay" .. idx, Vector3.new(26, 0.06, 14),
			CFrame.new(spot[1], WorldBuilder.FloorTop + 0.03, spot[2]),
			inlayColors[idx], Enum.Material.SmoothPlastic)
	end

	-- Palm trees around the island rim, clear of the plaza and the
	-- bases: a 7-stud trunk standing on the grass (y = IslandTop) with
	-- its canopy centered right at the trunk top, coconuts underneath.
	for i = 1, 14 do
		local angle = math.rad(i * (360 / 14) + 10)
		local x, z = math.cos(angle) * 100, math.sin(angle) * 100
		local trunk = part(world, "PalmTrunk", Vector3.new(7, 1.3, 1.3),
			CFrame.new(x, WorldBuilder.IslandTop + 3.5, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(111, 75, 43), Enum.Material.Wood)
		trunk.Shape = Enum.PartType.Cylinder
		local canopy = part(world, "PalmCanopy", Vector3.new(6.5, 5, 6.5),
			CFrame.new(x, WorldBuilder.IslandTop + 7.2, z), Color3.fromRGB(35, 150, 60), Enum.Material.Grass)
		canopy.Shape = Enum.PartType.Ball
		for c = 1, 2 do
			local nut = part(world, "Coconut", Vector3.new(0.9, 0.9, 0.9),
				CFrame.new(x + (c == 1 and 1.1 or -1.2), WorldBuilder.IslandTop + 6.3, z + (c == 1 and 0.6 or -0.7)),
				Color3.fromRGB(90, 60, 35), Enum.Material.SmoothPlastic)
			nut.Shape = Enum.PartType.Ball
		end
	end

	-- Four giant palms towering over the plaza corners, just outside
	-- the trim — the rim palms' construction at double scale.
	for _, spot in { { -64, -36 }, { 64, -36 }, { -64, 36 }, { 64, 36 } } do
		local gx, gz = spot[1], spot[2]
		local gTrunk = part(world, "GiantPalmTrunk", Vector3.new(14, 1.8, 1.8),
			CFrame.new(gx, WorldBuilder.IslandTop + 7, gz) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(111, 75, 43), Enum.Material.Wood)
		gTrunk.Shape = Enum.PartType.Cylinder
		local gCanopy = part(world, "GiantPalmCanopy", Vector3.new(12, 9, 12),
			CFrame.new(gx, WorldBuilder.IslandTop + 14.5, gz), Color3.fromRGB(35, 150, 60), Enum.Material.Grass)
		gCanopy.Shape = Enum.PartType.Ball
		for c = 1, 3 do
			local gNut = part(world, "GiantCoconut", Vector3.new(1.6, 1.6, 1.6),
				CFrame.new(gx + (c - 2) * 2.2, WorldBuilder.IslandTop + 13.2, gz + ((c % 2) * 2 - 1) * 1.4),
				Color3.fromRGB(90, 60, 35), Enum.Material.SmoothPlastic)
			gNut.Shape = Enum.PartType.Ball
		end
	end

	-- Scatter props on the grass, outside the plaza and away from the
	-- bases: rocks, squashed bushes and neon flowers.
	local rockSpots = {
		{ -80, -60 }, { -100, 20 }, { -70, 80 }, { 75, -85 }, { 95, 55 },
		{ 115, -20 }, { -120, -70 }, { 70, 95 }, { -120, 60 }, { 120, 90 },
	}
	for i, spot in rockSpots do
		local rockSize = 1.6 + (i % 4) * 0.6
		local rock = part(world, "Rock", Vector3.new(rockSize, rockSize * 0.8, rockSize),
			CFrame.new(spot[1], WorldBuilder.IslandTop + rockSize * 0.25, spot[2])
				* CFrame.Angles(0, math.rad(i * 37), 0),
			Color3.fromRGB(130, 130, 138), Enum.Material.Slate)
		if i % 2 == 0 then
			rock.Shape = Enum.PartType.Ball
		end
	end
	local bushSpots = {
		{ -75, -20 }, { -95, -80 }, { -65, 45 }, { -110, 85 }, { 80, 10 },
		{ 100, -60 }, { 68, -95 }, { 118, 30 }, { -118, -40 }, { 85, 80 },
		{ -85, 100 }, { 105, 100 }, { -105, -15 }, { 66, -60 },
	}
	for _, spot in bushSpots do
		local bush = part(world, "Bush", Vector3.new(2.6, 1.6, 2.6),
			CFrame.new(spot[1], WorldBuilder.IslandTop + 0.7, spot[2]),
			Color3.fromRGB(40, 140, 60), Enum.Material.Grass)
		bush.Shape = Enum.PartType.Ball
	end
	local flowerColors = {
		Color3.fromRGB(255, 80, 180), Color3.fromRGB(255, 220, 60),
		Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 140, 40),
		Color3.fromRGB(190, 110, 255),
	}
	for i = 1, 20 do
		local side = (i <= 10) and -1 or 1
		local flowerZ = -27 + ((i - 1) % 10) * 6
		local flower = part(world, "Flower", Vector3.new(0.55, 0.55, 0.55),
			CFrame.new(side * 64, WorldBuilder.IslandTop + 0.3, flowerZ),
			flowerColors[(i - 1) % #flowerColors + 1], Enum.Material.Neon)
		flower.Shape = Enum.PartType.Ball
	end

	-- Lamp posts around the plaza corners and belt ends.
	for _, spot in { { -58, -29 }, { 58, -29 }, { -58, 29 }, { 58, 29 }, { -58, 0 }, { 58, 0 } } do
		part(world, "LampPole", Vector3.new(0.35, 5, 0.35),
			CFrame.new(spot[1], WorldBuilder.FloorTop + 2.5, spot[2]),
			Color3.fromRGB(40, 40, 48), Enum.Material.Metal)
		local bulb = part(world, "LampBulb", Vector3.new(1.3, 1.3, 1.3),
			CFrame.new(spot[1], WorldBuilder.FloorTop + 5.4, spot[2]),
			Color3.fromRGB(255, 230, 120), Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		local lampLight = Instance.new("PointLight")
		lampLight.Color = Color3.fromRGB(255, 220, 130)
		lampLight.Range = 18
		lampLight.Brightness = 2
		lampLight.Parent = bulb
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

		-- A colored awning over the base's back edge on two posts, so
		-- the base reads as a little shop stall in its own color.
		part(world, "BaseRoof" .. i, Vector3.new(25, 0.5, 6),
			CFrame.new(cx, WorldBuilder.FloorTop + 6.5, cz + row * 7.5),
			BASE_ROOF_COLORS[i], Enum.Material.SmoothPlastic)
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

	-- Beach umbrellas on the sand rims (beach surface is y = 0.7).
	local umbrellaColors = {
		Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 170, 40),
		Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 110, 200),
	}
	for ui, spot in { { -40, -118 }, { 35, -118 }, { -20, 118 }, { 50, 118 } } do
		local pole = part(world, "UmbrellaPole", Vector3.new(3.2, 0.25, 0.25),
			CFrame.new(spot[1], 0.7 + 1.6, spot[2]) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(240, 240, 240), Enum.Material.Metal)
		pole.Shape = Enum.PartType.Cylinder
		local umbrellaTop = part(world, "UmbrellaCanopy", Vector3.new(5, 1.2, 5),
			CFrame.new(spot[1], 0.7 + 3.6, spot[2]), umbrellaColors[ui], Enum.Material.SmoothPlastic)
		umbrellaTop.Shape = Enum.PartType.Ball
	end

	-- A small wooden dock reaching into the sea on the south side.
	part(world, "Dock", Vector3.new(6, 0.5, 26), CFrame.new(10, -0.25, 143),
		Color3.fromRGB(120, 91, 62), Enum.Material.WoodPlanks)
	for _, postSpot in { { 7.5, 133 }, { 12.5, 133 }, { 7.5, 153 }, { 12.5, 153 } } do
		local dockPost = part(world, "DockPost", Vector3.new(6, 0.5, 0.5),
			CFrame.new(postSpot[1], -3, postSpot[2]) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(96, 74, 54), Enum.Material.Wood)
		dockPost.Shape = Enum.PartType.Cylinder
	end

	-- A volcano backdrop in the north-west corner: three shrinking
	-- cylinders stacked into a cone, with a neon lava disc on top.
	local volcanoColor = Color3.fromRGB(70, 70, 78)
	local volcanoTier1 = part(world, "VolcanoBase", Vector3.new(9, 36, 36),
		CFrame.new(-105, 4.5, -105) * CFrame.Angles(0, 0, math.rad(90)), volcanoColor, Enum.Material.Slate)
	volcanoTier1.Shape = Enum.PartType.Cylinder
	local volcanoTier2 = part(world, "VolcanoMid", Vector3.new(8, 26, 26),
		CFrame.new(-105, 13, -105) * CFrame.Angles(0, 0, math.rad(90)), volcanoColor, Enum.Material.Slate)
	volcanoTier2.Shape = Enum.PartType.Cylinder
	local volcanoTier3 = part(world, "VolcanoTop", Vector3.new(7, 17, 17),
		CFrame.new(-105, 20.5, -105) * CFrame.Angles(0, 0, math.rad(90)), volcanoColor, Enum.Material.Slate)
	volcanoTier3.Shape = Enum.PartType.Cylinder
	local lava = part(world, "VolcanoLava", Vector3.new(0.6, 13, 13),
		CFrame.new(-105, 24.2, -105) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 100, 20), Enum.Material.Neon)
	lava.Shape = Enum.PartType.Cylinder
	local lavaLight = Instance.new("PointLight")
	lavaLight.Color = Color3.fromRGB(255, 120, 40)
	lavaLight.Range = 34
	lavaLight.Brightness = 2
	lavaLight.Parent = lava

	-- Flat white clouds floating over the island.
	for _, spot in { { -60, 58, -40 }, { 30, 64, -70 }, { 80, 60, 30 }, { -20, 68, 60 }, { -90, 62, 50 }, { 55, 56, -10 } } do
		local cloud = part(world, "Cloud", Vector3.new(16, 3, 10),
			CFrame.new(spot[1], spot[2], spot[3]), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = 0.1
		cloud.CanCollide = false
	end

	print("[BrainrotIsland] world built OK — bases:", #bases)

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
