-- WorldBuilder: constructs the whole night market out of Parts at server
-- start — plaza floor, the central conveyor, six player bases with eight
-- slots each, gerobak stalls, string lights, entrance arches, trees and
-- the rebirth stall — and hands the services the references they need
-- (belt ends, base slot CFrames, lock pads, spawn). Nothing decorative
-- lives anywhere else; if it stands in the world, it is built here.

local WorldBuilder = {}

export type BaseSpot = {
	Index: number,
	Center: Vector3,
	TopY: number,
	Slots: { CFrame },
	LockPad: Part,
	OwnerSign: TextLabel,
	LockSign: TextLabel,
	BorderParts: { Part },
	Color: Color3,
}

WorldBuilder.FloorTop = 0.2
WorldBuilder.BeltTopY = 1.2
WorldBuilder.BeltStartX = -46
WorldBuilder.BeltEndX = 46
WorldBuilder.BeltZ = 0

local BASE_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(90, 160, 255),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(255, 200, 70),
	Color3.fromRGB(200, 120, 255),
	Color3.fromRGB(90, 230, 220),
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

local function signBoard(parent: Instance, name: string, size: Vector2, cf: CFrame, boardColor: Color3, text: string, textColor: Color3, textSize: number): (Part, TextLabel)
	local board = part(parent, name, Vector3.new(size.X, size.Y, 0.3), cf, boardColor, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize
	constraint.Parent = label
	return board, label
end

local function buildStall(parent: Instance, cf: CFrame, color: Color3, signText: string)
	local stall = Instance.new("Model")
	stall.Name = "Gerobak" .. signText
	stall.Parent = parent
	local local_ = function(size: Vector3, offset: Vector3, c: Color3, mat: Enum.Material?): Part
		return part(stall, "Part", size, cf * CFrame.new(offset), c, mat)
	end
	local_(Vector3.new(7, 3, 4), Vector3.new(0, 1.9, 0), color, Enum.Material.Wood) -- cart body
	local_(Vector3.new(7.6, 0.3, 4.6), Vector3.new(0, 3.6, 0), Color3.fromRGB(60, 55, 60)) -- counter top
	local canopy = Instance.new("WedgePart")
	canopy.Name = "Canopy"
	canopy.Size = Vector3.new(8.4, 1.6, 5.6)
	canopy.CFrame = cf * CFrame.new(0, 5.2, 0)
	canopy.Color = color
	canopy.Material = Enum.Material.Fabric
	canopy.Anchored = true
	canopy.Parent = stall
	for _, sx in { -3.4, 3.4 } do
		for _, sz in { -2.2, 2.2 } do
			local_(Vector3.new(0.3, 3.4, 0.3), Vector3.new(sx, 4.4, sz), Color3.fromRGB(90, 70, 50), Enum.Material.Wood)
		end
	end
	for _, sx in { -2.6, 2.6 } do
		local wheel = part(stall, "Wheel", Vector3.new(1.4, 1.4, 0.3), cf * CFrame.new(sx, 0.7, 2.1) * CFrame.Angles(0, 0, 0), Color3.fromRGB(40, 35, 40))
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CFrame = cf * CFrame.new(sx, 0.7, 2.1) * CFrame.Angles(math.rad(90), 0, 0)
	end
	signBoard(stall, "StallSign", Vector2.new(6.4, 1.2), cf * CFrame.new(0, 4.35, 2.45), Color3.fromRGB(45, 38, 55), signText, Color3.fromRGB(255, 230, 150), 40)
	return stall
end

local function buildTree(parent: Instance, pos: Vector3)
	local tree = Instance.new("Model")
	tree.Name = "Pohon"
	tree.Parent = parent
	part(tree, "Trunk", Vector3.new(1.2, 6, 1.2), CFrame.new(pos.X, pos.Y + 3, pos.Z), Color3.fromRGB(96, 66, 42), Enum.Material.Wood)
	for i, off in { Vector3.new(0, 7.6, 0), Vector3.new(1.6, 6.6, 0.6), Vector3.new(-1.5, 6.8, -0.7) } do
		local leaf = part(tree, "Leaves" .. i, Vector3.new(4.6, 3.6, 4.6), CFrame.new(pos + off), Color3.fromRGB(38, 92, 46))
		leaf.Shape = Enum.PartType.Ball
	end
	return tree
end

function WorldBuilder.Build(): { Bases: { BaseSpot }, SpawnCFrame: CFrame, RebirthPad: Part }
	local workspace = game:GetService("Workspace")
	local world = Instance.new("Folder")
	world.Name = "WarungWorld"
	world.Parent = workspace
	local floorTop = WorldBuilder.FloorTop

	-- Plaza floor over the starter baseplate.
	part(world, "PlazaFloor", Vector3.new(240, 1, 240), CFrame.new(0, floorTop - 0.5, 0), Color3.fromRGB(38, 36, 54), Enum.Material.Asphalt)
	part(world, "PlazaCenter", Vector3.new(130, 0.12, 90), CFrame.new(0, floorTop + 0.06, 0), Color3.fromRGB(52, 48, 74), Enum.Material.SmoothPlastic)

	-- Spawn pad in the middle of the south walkway.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPad"
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, floorTop + 0.2, 20)
	spawn.Color = Color3.fromRGB(255, 170, 60)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = world

	-- The conveyor: a long belt down the middle of the plaza, with side
	-- glow strips, support legs and moving-look stripes.
	local belt = Instance.new("Folder")
	belt.Name = "Conveyor"
	belt.Parent = world
	local beltTop = WorldBuilder.BeltTopY
	part(belt, "Belt", Vector3.new(100, 1, 8), CFrame.new(0, beltTop - 0.5, 0), Color3.fromRGB(28, 28, 36), Enum.Material.Metal)
	for _, side in { -1, 1 } do
		part(belt, "GlowStrip", Vector3.new(100, 0.25, 0.4), CFrame.new(0, beltTop + 0.05, side * 4.1), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
		for x = -45, 45, 15 do
			part(belt, "Leg", Vector3.new(0.8, beltTop - 0.2, 0.8), CFrame.new(x, (beltTop - 0.2) / 2 + 0.1, side * 3.4), Color3.fromRGB(70, 70, 85), Enum.Material.Metal)
		end
	end
	for x = -48, 48, 8 do
		part(belt, "Stripe", Vector3.new(1.2, 0.06, 7.6), CFrame.new(x, beltTop + 0.03, 0), Color3.fromRGB(70, 66, 60))
	end
	signBoard(belt, "BeltSignStart", Vector2.new(16, 2.6), CFrame.new(-53, 6.4, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 40, 90), "WARUNG BRAINROT", Color3.fromRGB(255, 240, 180), 64)
	signBoard(belt, "BeltSignEnd", Vector2.new(16, 2.6), CFrame.new(53, 6.4, 0) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(30, 90, 110), "GEROBAK GACOR", Color3.fromRGB(200, 255, 240), 64)
	for _, x in { -53, 53 } do
		for _, side in { -1, 1 } do
			part(belt, "ArchPost", Vector3.new(0.9, 6.4, 0.9), CFrame.new(x, 3.2 + floorTop, side * 5.4), Color3.fromRGB(90, 60, 110), Enum.Material.Wood)
		end
		part(belt, "ArchTop", Vector3.new(0.9, 1.1, 12), CFrame.new(x, 7.6, 0), Color3.fromRGB(90, 60, 110), Enum.Material.Wood)
	end

	-- Six bases: two rows of three, each with eight slots, a lock pad, an
	-- owner sign and a lock status sign.
	local bases: { BaseSpot } = {}
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = world
	local basePositions = {
		Vector3.new(-56, 0, -44), Vector3.new(0, 0, -44), Vector3.new(56, 0, -44),
		Vector3.new(-56, 0, 44), Vector3.new(0, 0, 44), Vector3.new(56, 0, 44),
	}
	for index, pos in basePositions do
		local color = BASE_COLORS[index]
		local folder = Instance.new("Folder")
		folder.Name = "Base" .. index
		folder.Parent = basesFolder
		local plateTop = floorTop + 0.45
		part(folder, "Plate", Vector3.new(32, 0.45, 24), CFrame.new(pos.X, floorTop + 0.225, pos.Z), Color3.fromRGB(48, 46, 66), Enum.Material.SmoothPlastic)
		local borders: { Part } = {}
		for _, edge in {
			{ Vector3.new(32.6, 0.7, 0.7), Vector3.new(0, 0, -12) },
			{ Vector3.new(32.6, 0.7, 0.7), Vector3.new(0, 0, 12) },
			{ Vector3.new(0.7, 0.7, 24.6), Vector3.new(-16, 0, 0) },
			{ Vector3.new(0.7, 0.7, 24.6), Vector3.new(16, 0, 0) },
		} do
			local b = part(folder, "Border", edge[1], CFrame.new(pos.X + edge[2].X, plateTop + 0.1, pos.Z + edge[2].Z), color, Enum.Material.Neon)
			table.insert(borders, b)
		end
		local slots: { CFrame } = {}
		for row = 0, 1 do
			for col = 0, 3 do
				local sx = pos.X - 11.25 + col * 7.5
				local sz = pos.Z - 5.5 + row * 11
				local pad = part(folder, "SlotPad", Vector3.new(4.6, 0.25, 4.6), CFrame.new(sx, plateTop + 0.125, sz), Color3.fromRGB(66, 63, 88))
				pad:SetAttribute("SlotIndex", row * 4 + col + 1)
				-- Slots face the plaza centre so nameplates read from the belt.
				local facing = CFrame.lookAt(Vector3.new(sx, plateTop + 0.25, sz), Vector3.new(sx, plateTop + 0.25, 0))
				table.insert(slots, facing)
			end
		end
		-- Lock pad on the plaza side of the plot.
		local lockZ = pos.Z + ((pos.Z < 0) and 15.5 or -15.5)
		local lockPad = part(folder, "LockPad", Vector3.new(4.4, 0.5, 4.4), CFrame.new(pos.X, floorTop + 0.25, lockZ), Color3.fromRGB(220, 60, 60), Enum.Material.Neon)
		lockPad.Shape = Enum.PartType.Cylinder
		-- Owner + lock signs at the back of the plot.
		local backZ = pos.Z + ((pos.Z < 0) and -13.4 or 13.4)
		local faceAngle = (pos.Z < 0) and 0 or math.rad(180)
		local _, ownerLabel = signBoard(folder, "OwnerSign", Vector2.new(15, 2.4), CFrame.new(pos.X, plateTop + 3.4, backZ) * CFrame.Angles(0, faceAngle, 0), Color3.fromRGB(40, 36, 60), "BASE " .. index .. " — KOSONG", Color3.fromRGB(255, 255, 255), 54)
		local _, lockLabel = signBoard(folder, "LockSign", Vector2.new(11, 1.5), CFrame.new(pos.X, plateTop + 1.6, backZ) * CFrame.Angles(0, faceAngle, 0), Color3.fromRGB(40, 36, 60), "TIDAK TERKUNCI", Color3.fromRGB(160, 255, 170), 40)
		bases[index] = {
			Index = index,
			Center = Vector3.new(pos.X, plateTop, pos.Z),
			TopY = plateTop + 0.25,
			Slots = slots,
			LockPad = lockPad,
			OwnerSign = ownerLabel,
			LockSign = lockLabel,
			BorderParts = borders,
			Color = color,
		}
	end

	-- Decorative gerobak stalls around the edges.
	local stalls = Instance.new("Folder")
	stalls.Name = "Stalls"
	stalls.Parent = world
	buildStall(stalls, CFrame.new(-78, floorTop, -16) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 70, 60), "SATE")
	buildStall(stalls, CFrame.new(-78, floorTop, 16) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(70, 160, 220), "ES TEH")
	buildStall(stalls, CFrame.new(78, floorTop, -16) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(150, 100, 60), "BAKSO")
	buildStall(stalls, CFrame.new(78, floorTop, 16) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(220, 170, 60), "GORENGAN")
	buildStall(stalls, CFrame.new(-30, floorTop, -68) * CFrame.Angles(0, 0, 0), Color3.fromRGB(90, 180, 90), "RENDANG")
	buildStall(stalls, CFrame.new(30, floorTop, 68) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(230, 220, 190), "KERUPUK")

	-- The rebirth stall, east of the spawn walkway.
	buildStall(stalls, CFrame.new(64, floorTop, 30) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(255, 215, 0), "REBIRTH")
	local rebirthPad = part(stalls, "RebirthPad", Vector3.new(5, 0.4, 5), CFrame.new(57, floorTop + 0.2, 30), Color3.fromRGB(255, 215, 0), Enum.Material.Neon)
	rebirthPad.Shape = Enum.PartType.Cylinder

	-- Trees in the corners.
	for _, pos in { Vector3.new(-95, floorTop, -70), Vector3.new(95, floorTop, -70), Vector3.new(-95, floorTop, 70), Vector3.new(95, floorTop, 70), Vector3.new(-95, floorTop, 0), Vector3.new(95, floorTop, 0) } do
		buildTree(world, pos)
	end

	-- String lights: poles around the plaza with sagging bulb lines.
	local lights = Instance.new("Folder")
	lights.Name = "StringLights"
	lights.Parent = world
	local poleTops: { Vector3 } = {}
	local polePositions = {
		Vector3.new(-70, 0, -58), Vector3.new(0, 0, -62), Vector3.new(70, 0, -58),
		Vector3.new(70, 0, 58), Vector3.new(0, 0, 62), Vector3.new(-70, 0, 58),
		Vector3.new(-88, 0, 0), Vector3.new(88, 0, 0),
	}
	for _, pos in polePositions do
		part(lights, "Pole", Vector3.new(0.5, 13, 0.5), CFrame.new(pos.X, floorTop + 6.5, pos.Z), Color3.fromRGB(60, 50, 60), Enum.Material.Wood)
		table.insert(poleTops, Vector3.new(pos.X, floorTop + 13, pos.Z))
	end
	local bulbColors = { Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 110, 130), Color3.fromRGB(120, 220, 255), Color3.fromRGB(160, 255, 150) }
	local function stringBetween(a: Vector3, b: Vector3)
		local steps = 9
		for i = 1, steps - 1 do
			local t = i / steps
			local mid = a:Lerp(b, t)
			local sag = math.sin(t * math.pi) * 1.6
			local bulb = part(lights, "Bulb", Vector3.new(0.55, 0.55, 0.55), CFrame.new(mid.X, mid.Y - sag, mid.Z), bulbColors[(i % #bulbColors) + 1], Enum.Material.Neon)
			bulb.Shape = Enum.PartType.Ball
			bulb.CanCollide = false
		end
	end
	for i = 1, #poleTops do
		stringBetween(poleTops[i], poleTops[i % #poleTops + 1])
	end
	stringBetween(poleTops[2], poleTops[5])

	-- A warm lamp over each base so bases read at night.
	for _, base in bases do
		local lamp = part(world, "BaseLamp", Vector3.new(1.1, 1.1, 1.1), CFrame.new(base.Center.X, base.TopY + 9, base.Center.Z), Color3.fromRGB(255, 210, 130), Enum.Material.Neon)
		lamp.Shape = Enum.PartType.Ball
		lamp.CanCollide = false
		part(world, "LampPole", Vector3.new(0.4, 9, 0.4), CFrame.new(base.Center.X + 14, base.TopY + 4.5, base.Center.Z), Color3.fromRGB(60, 55, 70), Enum.Material.Metal)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 130)
		light.Range = 30
		light.Brightness = 1.6
		light.Parent = lamp
	end

	return {
		Bases = bases,
		SpawnCFrame = CFrame.new(0, floorTop + 3, 20) * CFrame.Angles(0, math.rad(180), 0),
		RebirthPad = rebirthPad,
	}
end

return WorldBuilder
