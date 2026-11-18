-- WorldBuilder: constructs the whole Italian Brainrot Obby out of
-- static anchored Parts at server start — the pink lobby with the
-- game's single SpawnLocation, five themed parkour stages in a
-- serpentine line, checkpoint pads, glowing Aura orbs, kill bricks,
-- the lava plane underneath everything and the grand finish platform.
--
-- HARD RULE for this world: every Part is anchored and placed with a
-- plain world CFrame. Nothing moves, nothing is pivoted after the
-- fact — statues are individual parts parented straight into the
-- world folder, each with its own world CFrame.
--
-- Build() returns the references Gameplay needs:
--   Folder, OrbFolder, Spawn, SpawnCFrame,
--   Checkpoints = { { Pad, Stage, Name }, ... },
--   KillParts = { Part, ... } (kill bricks + lava),
--   Orbs = { { Part, CFrame, Color }, ... },
--   FinishPad

local Workspace = game:GetService("Workspace")

local WorldBuilder = {}

-- Counted as parts are created, so the bootstrap can report the
-- rough size of the world it built.
WorldBuilder.PartCount = 0

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
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
	WorldBuilder.PartCount += 1
	return p
end

local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	WorldBuilder.PartCount += 1
	return p
end

local function ball(
	parent: Instance,
	name: string,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A flat cylinder standing on its round face (axis vertical).
local function disc(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- One text face of a board: a SurfaceGui holding a single TextLabel.
local function boardFace(board: Part, face: Enum.NormalId, text: string, textColor: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = gui
end

-- A two-sided standing board with a title and a smaller subtitle.
local function makeBoard(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	title: string,
	subtitle: string?
): Part
	local board = part(parent, name, size, cf, color, Enum.Material.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Face_" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = board

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.new(1, 0, if subtitle then 0.62 else 1, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = title
		titleLabel.TextColor3 = Color3.new(1, 1, 1)
		titleLabel.Font = Enum.Font.FredokaOne
		titleLabel.TextScaled = true
		titleLabel.TextStrokeTransparency = 0.3
		titleLabel.Parent = gui

		if subtitle then
			local subLabel = Instance.new("TextLabel")
			subLabel.Name = "Subtitle"
			subLabel.Size = UDim2.new(1, 0, 0.38, 0)
			subLabel.Position = UDim2.new(0, 0, 0.62, 0)
			subLabel.BackgroundTransparency = 1
			subLabel.Text = subtitle
			subLabel.TextColor3 = Color3.fromRGB(255, 240, 180)
			subLabel.Font = Enum.Font.FredokaOne
			subLabel.TextScaled = true
			subLabel.TextStrokeTransparency = 0.3
			subLabel.Parent = gui
		end
	end
	return board
end

-- A floating nameplate (BillboardGui) over a statue part.
local function nameplate(adornee: Part, text: string, offsetY: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.new(13, 0, 2.6, 0)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
	label.BackgroundTransparency = 0.35
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label
end

-- One glowing collectible orb. Gameplay calls this again to respawn
-- an orb at its home CFrame after it has been collected.
function WorldBuilder.CreateOrb(parent: Instance, cf: CFrame, color: Color3): Part
	local orb = ball(parent, "AuraOrb", 1.6, cf, color, Enum.Material.Neon)
	orb.CanCollide = false

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = color
	light.Range = 9
	light.Brightness = 2
	light.Parent = orb
	return orb
end

-- Statue-local part: positions a part relative to a statue origin
-- with a facing yaw, so each statue reads as one little figure even
-- though every part carries its own plain world CFrame.
local function statuePart(
	parent: Instance,
	baseCf: CFrame,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
	extra: CFrame?
): Part
	local cf = baseCf * CFrame.new(offset)
	if extra then
		cf = cf * extra
	end
	return part(parent, name, size, cf, color, material)
end

local function statueBall(
	parent: Instance,
	baseCf: CFrame,
	name: string,
	diameter: number,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = statuePart(parent, baseCf, name, Vector3.new(diameter, diameter, diameter), offset, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Stage 1 statue: Tralalero Tralala, a gray-blue shark.
local function buildShark(parent: Instance, baseCf: CFrame): Part
	local bodyColor = Color3.fromRGB(86, 138, 184)
	local lightColor = Color3.fromRGB(140, 185, 220)
	-- Body: a horizontal cylinder reads as the shark's torpedo body.
	local body = statuePart(
		parent,
		baseCf,
		"SharkBody",
		Vector3.new(6.5, 2.8, 2.8),
		Vector3.new(0, 2.8, 0),
		bodyColor,
		nil,
		CFrame.Angles(0, 0, math.rad(90))
	)
	body.Shape = Enum.PartType.Cylinder
	statueBall(parent, baseCf, "SharkNose", 2.6, Vector3.new(3.4, 2.8, 0), lightColor)
	-- Dorsal fin and tail fin, both wedges.
	wedge(parent, "SharkFin", Vector3.new(2.4, 2.4, 0.5), baseCf * CFrame.new(-0.2, 5.2, 0) * CFrame.Angles(0, math.rad(90), 0), bodyColor)
	wedge(parent, "SharkTail", Vector3.new(2.8, 2.8, 0.5), baseCf * CFrame.new(-4.1, 3.4, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), bodyColor)
	statueBall(parent, baseCf, "SharkEyeL", 0.45, Vector3.new(4.1, 3.5, 0.95), Color3.fromRGB(15, 15, 20))
	statueBall(parent, baseCf, "SharkEyeR", 0.45, Vector3.new(4.1, 3.5, -0.95), Color3.fromRGB(15, 15, 20))
	return body
end

-- Stage 2 statue: Tung Tung Tung Sahur, a brown log with a round head.
local function buildLog(parent: Instance, baseCf: CFrame): Part
	local logColor = Color3.fromRGB(122, 82, 46)
	local body = statuePart(
		parent,
		baseCf,
		"LogBody",
		Vector3.new(6, 2.6, 2.6),
		Vector3.new(0, 3, 0),
		logColor,
		Enum.Material.Wood,
		CFrame.Angles(0, 0, math.rad(90))
	)
	body.Shape = Enum.PartType.Cylinder
	local head = statueBall(parent, baseCf, "LogHead", 2.5, Vector3.new(0, 7.1, 0), Color3.fromRGB(205, 165, 115))
	statuePart(parent, baseCf, "LogArmL", Vector3.new(0.5, 3.6, 0.5), Vector3.new(0, 4.4, 1.9), logColor, nil, CFrame.Angles(math.rad(28), 0, 0))
	statuePart(parent, baseCf, "LogArmR", Vector3.new(0.5, 3.6, 0.5), Vector3.new(0, 4.4, -1.9), logColor, nil, CFrame.Angles(math.rad(-28), 0, 0))
	statueBall(parent, baseCf, "LogEyeL", 0.4, Vector3.new(0.95, 7.5, 0.55), Color3.fromRGB(15, 15, 20))
	statueBall(parent, baseCf, "LogEyeR", 0.4, Vector3.new(0.95, 7.5, -0.55), Color3.fromRGB(15, 15, 20))
	return head
end

-- Stage 3 statue: Bombardiro Crocodilo, a long green crocodile.
local function buildCroc(parent: Instance, baseCf: CFrame): Part
	local green = Color3.fromRGB(64, 165, 74)
	local darkGreen = Color3.fromRGB(40, 120, 52)
	local body = statuePart(parent, baseCf, "CrocBody", Vector3.new(8, 2, 3), Vector3.new(0, 1.9, 0), green)
	statuePart(parent, baseCf, "CrocSnout", Vector3.new(3.6, 1.2, 2.2), Vector3.new(5.6, 1.5, 0), darkGreen)
	wedge(parent, "CrocTail", Vector3.new(3.6, 1.7, 2.4), baseCf * CFrame.new(-5.7, 1.6, 0) * CFrame.Angles(0, math.rad(-90), 0), darkGreen)
	for _, dx in { -2.8, 2.8 } do
		for _, dz in { -1.7, 1.7 } do
			statuePart(parent, baseCf, "CrocLeg", Vector3.new(0.9, 1, 0.9), Vector3.new(dx, 0.5, dz), darkGreen)
		end
	end
	for i = -1, 1 do
		wedge(parent, "CrocRidge", Vector3.new(1.1, 0.9, 0.7), baseCf * CFrame.new(i * 2, 3.3, 0) * CFrame.Angles(0, math.rad(90), 0), darkGreen)
	end
	statueBall(parent, baseCf, "CrocEyeL", 0.5, Vector3.new(3.4, 3.2, 0.8), Color3.fromRGB(15, 15, 20))
	statueBall(parent, baseCf, "CrocEyeR", 0.5, Vector3.new(3.4, 3.2, -0.8), Color3.fromRGB(15, 15, 20))
	return body
end

-- Stage 4 statue: Ballerina Cappuccina, cream head over a pink skirt.
local function buildBallerina(parent: Instance, baseCf: CFrame): Part
	local pink = Color3.fromRGB(255, 130, 195)
	local cream = Color3.fromRGB(255, 228, 190)
	statuePart(parent, baseCf, "DancerLegL", Vector3.new(0.5, 2.4, 0.5), Vector3.new(0, 1.2, 0.7), cream)
	statuePart(parent, baseCf, "DancerLegR", Vector3.new(0.5, 2.4, 0.5), Vector3.new(0, 1.2, -0.7), cream)
	local skirtLow = statuePart(
		parent,
		baseCf,
		"DancerSkirtLow",
		Vector3.new(1.3, 5, 5),
		Vector3.new(0, 3, 0),
		pink,
		nil,
		CFrame.Angles(0, 0, math.rad(90))
	)
	skirtLow.Shape = Enum.PartType.Cylinder
	local skirtHigh = statuePart(
		parent,
		baseCf,
		"DancerSkirtHigh",
		Vector3.new(1.3, 3.6, 3.6),
		Vector3.new(0, 4.2, 0),
		Color3.fromRGB(255, 165, 215),
		nil,
		CFrame.Angles(0, 0, math.rad(90))
	)
	skirtHigh.Shape = Enum.PartType.Cylinder
	statuePart(parent, baseCf, "DancerTorso", Vector3.new(1.3, 2, 1.7), Vector3.new(0, 5.6, 0), pink)
	statuePart(parent, baseCf, "DancerArmL", Vector3.new(0.4, 2.8, 0.4), Vector3.new(0, 5.9, 1.6), cream, nil, CFrame.Angles(math.rad(40), 0, 0))
	statuePart(parent, baseCf, "DancerArmR", Vector3.new(0.4, 2.8, 0.4), Vector3.new(0, 5.9, -1.6), cream, nil, CFrame.Angles(math.rad(-40), 0, 0))
	local head = statueBall(parent, baseCf, "DancerHead", 2.3, Vector3.new(0, 7.6, 0), cream)
	statueBall(parent, baseCf, "DancerBun", 1, Vector3.new(0, 8.9, 0), Color3.fromRGB(120, 78, 45))
	return head
end

-- Stage 5 statue: the Final Brainrot, a big golden body with a crown.
local function buildFinal(parent: Instance, baseCf: CFrame): Part
	local gold = Color3.fromRGB(255, 196, 40)
	local body = statueBall(parent, baseCf, "FinalBody", 5.6, Vector3.new(0, 3.4, 0), gold, Enum.Material.Metal)
	statueBall(parent, baseCf, "FinalEyeL", 0.6, Vector3.new(2.35, 4.3, 1.05), Color3.fromRGB(15, 15, 20))
	statueBall(parent, baseCf, "FinalEyeR", 0.6, Vector3.new(2.35, 4.3, -1.05), Color3.fromRGB(15, 15, 20))
	statuePart(parent, baseCf, "FinalArmL", Vector3.new(0.8, 3.4, 0.8), Vector3.new(0, 3.2, 3.3), gold, Enum.Material.Metal, CFrame.Angles(math.rad(20), 0, 0))
	statuePart(parent, baseCf, "FinalArmR", Vector3.new(0.8, 3.4, 0.8), Vector3.new(0, 3.2, -3.3), gold, Enum.Material.Metal, CFrame.Angles(math.rad(-20), 0, 0))
	-- Crown: a ring of gold blocks with a red gem in the middle.
	for i = 0, 5 do
		local angle = (i / 6) * math.pi * 2
		local off = Vector3.new(math.cos(angle) * 1.7, 6.9, math.sin(angle) * 1.7)
		statuePart(parent, baseCf, "CrownBlock", Vector3.new(0.85, 1.3, 0.85), off, gold, Enum.Material.Neon)
	end
	statueBall(parent, baseCf, "CrownGem", 1.1, Vector3.new(0, 7.1, 0), Color3.fromRGB(235, 40, 60), Enum.Material.Neon)
	return body
end

local STATUE_BUILDERS = { buildShark, buildLog, buildCroc, buildBallerina, buildFinal }

local STAGE_DEFS = {
	{
		Name = "TRALALERO TRALALA",
		Colors = {
			Color3.fromRGB(40, 120, 255),
			Color3.fromRGB(0, 180, 255),
			Color3.fromRGB(60, 200, 230),
			Color3.fromRGB(30, 90, 200),
		},
		Rise = 1.2,
		Count = 10,
	},
	{
		Name = "TUNG TUNG TUNG SAHUR",
		Colors = {
			Color3.fromRGB(255, 140, 40),
			Color3.fromRGB(190, 110, 50),
			Color3.fromRGB(255, 170, 60),
			Color3.fromRGB(150, 85, 40),
		},
		Rise = 1.1,
		Count = 10,
	},
	{
		Name = "BOMBARDIRO CROCODILO",
		Colors = {
			Color3.fromRGB(50, 200, 80),
			Color3.fromRGB(30, 170, 60),
			Color3.fromRGB(120, 230, 90),
			Color3.fromRGB(0, 150, 90),
		},
		Rise = 0.85,
		Count = 11,
	},
	{
		Name = "BALLERINA CAPPUCCINA",
		Colors = {
			Color3.fromRGB(255, 120, 190),
			Color3.fromRGB(255, 170, 215),
			Color3.fromRGB(255, 210, 230),
			Color3.fromRGB(240, 120, 160),
		},
		Rise = 0.2,
		Count = 10,
	},
	{
		Name = "FINAL BRAINROT",
		Colors = {
			Color3.fromRGB(255, 70, 70),
			Color3.fromRGB(255, 150, 40),
			Color3.fromRGB(255, 220, 60),
			Color3.fromRGB(80, 220, 90),
			Color3.fromRGB(60, 160, 255),
			Color3.fromRGB(180, 100, 255),
		},
		Rise = 0,
		Count = 10,
	},
}

-- Serpentine travel directions: north, east, north, west, north.
local STAGE_DIRS = {
	Vector3.new(0, 0, -1),
	Vector3.new(1, 0, 0),
	Vector3.new(0, 0, -1),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 0, -1),
}

local ORB_COLORS = {
	Color3.fromRGB(255, 196, 40), -- gold
	Color3.fromRGB(255, 110, 200), -- pink
	Color3.fromRGB(70, 220, 255), -- cyan
	Color3.fromRGB(140, 255, 110), -- lime
	Color3.fromRGB(190, 120, 255), -- purple
}

local KILL_COLOR = Color3.fromRGB(255, 45, 45)
local CHECKPOINT_COLOR = Color3.fromRGB(45, 225, 95)

function WorldBuilder.Build()
	WorldBuilder.PartCount = 0

	local world = Instance.new("Folder")
	world.Name = "ObbyWorld"
	world.Parent = Workspace

	local orbFolder = Instance.new("Folder")
	orbFolder.Name = "Orbs"
	orbFolder.Parent = world

	local killParts = {}
	local checkpoints = {}
	local orbs = {}

	----------------------------------------------------------------
	-- Lava: one big neon plane under the whole course. Touching it
	-- is death (Gameplay wires it as a kill part).
	----------------------------------------------------------------
	local lava = part(
		world,
		"Lava",
		Vector3.new(460, 1, 580),
		CFrame.new(60, -8.5, -195),
		Color3.fromRGB(255, 70, 30),
		Enum.Material.Neon
	)
	table.insert(killParts, lava)

	----------------------------------------------------------------
	-- Lobby: pink neon platform, top at y = 0, the game's single
	-- SpawnLocation, boards, palms, balloons and the golden path.
	----------------------------------------------------------------
	part(world, "Lobby", Vector3.new(60, 2, 40), CFrame.new(0, -1, 0), Color3.fromRGB(255, 105, 180), Enum.Material.Neon)
	-- A calmer inner floor so the neon reads as a border, not a sun.
	part(world, "LobbyFloor", Vector3.new(52, 0.4, 32), CFrame.new(0, 0.2, 0), Color3.fromRGB(255, 150, 205))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "IslandSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.9, 10)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world
	WorldBuilder.PartCount += 1

	-- Welcome board, facing the spawn (front toward +Z).
	makeBoard(
		world,
		"WelcomeBoard",
		Vector3.new(26, 6.5, 0.6),
		CFrame.new(0, 7.5, -15),
		Color3.fromRGB(120, 40, 160),
		"ITALIAN BRAINROT OBBY",
		"Lompat dari platform ke platform sampai FINISH!"
	)
	for _, px in { -12, 12 } do
		part(world, "WelcomePole", Vector3.new(0.5, 4.5, 0.5), CFrame.new(px, 2.25, -15), Color3.fromRGB(90, 90, 100))
	end

	-- How-to-play board, angled toward the spawn.
	local caraCf = CFrame.new(-19, 4.6, 2) * CFrame.Angles(0, math.rad(38), 0)
	local caraBoard = part(world, "CaraMainBoard", Vector3.new(13, 5.4, 0.6), caraCf, Color3.fromRGB(35, 120, 190))
	local caraText = "CARA MAIN\nLompat antar platform warna-warni\nInjak CHECKPOINT hijau untuk simpan posisi\nKumpulkan orb Aura: +10 Aura\nHindari bata merah dan lava!\nSentuh FINISH: +500 Aura"
	boardFace(caraBoard, Enum.NormalId.Front, caraText, Color3.new(1, 1, 1))
	boardFace(caraBoard, Enum.NormalId.Back, caraText, Color3.new(1, 1, 1))
	part(world, "CaraMainPole", Vector3.new(0.5, 2.2, 0.5), CFrame.new(-19, 1.1, 2), Color3.fromRGB(90, 90, 100))

	-- Golden path from the spawn toward stage 1, plus the bridge
	-- platform that carries players from the lobby edge (z = -20)
	-- up to the stage 1 checkpoint (top y = 2).
	part(world, "GoldenPath", Vector3.new(4, 0.25, 30), CFrame.new(0, 0.55, -5), Color3.fromRGB(255, 205, 60), Enum.Material.Neon)
	part(world, "LobbyBridge", Vector3.new(9, 2, 9), CFrame.new(0, 1, -27), Color3.fromRGB(255, 215, 110))

	-- Palms and balloons in the lobby corners.
	for _, corner in { Vector3.new(-25, 0, -15), Vector3.new(25, 0, -15), Vector3.new(-25, 0, 15), Vector3.new(25, 0, 15) } do
		part(world, "PalmTrunk", Vector3.new(1.1, 7, 1.1), CFrame.new(corner.X, 3.5, corner.Z), Color3.fromRGB(130, 90, 50), Enum.Material.Wood)
		disc(world, "PalmCanopy", 5.5, 0.8, CFrame.new(corner.X, 7.4, corner.Z), Color3.fromRGB(45, 175, 70))
		ball(world, "PalmFruit", 1.1, CFrame.new(corner.X + 0.8, 6.7, corner.Z + 0.5), Color3.fromRGB(110, 75, 40))
	end
	local balloonColors = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(80, 200, 255),
		Color3.fromRGB(255, 220, 80),
	}
	for i, bx in { -14, 0, 14 } do
		part(world, "BalloonString", Vector3.new(0.12, 3.4, 0.12), CFrame.new(bx, 1.7, 17), Color3.fromRGB(240, 240, 240))
		ball(world, "Balloon", 2.3, CFrame.new(bx, 4.6, 17), balloonColors[i], Enum.Material.Neon)
	end

	----------------------------------------------------------------
	-- The five stages, laid out as a serpentine. Each stage start
	-- gets a checkpoint platform + pad, a statue on its own platform
	-- beside the pad, and a big name board; then 10-11 platforms
	-- step away from it, gently rising, with kill bricks and orbs.
	----------------------------------------------------------------
	local cursorTop = Vector3.new(0, 2, -38) -- top centre of the stage 1 checkpoint platform
	local lastTopCenter = cursorTop
	local lastDir = STAGE_DIRS[1]

	for si, def in STAGE_DEFS do
		local dir = STAGE_DIRS[si]
		local side = Vector3.new(-dir.Z, 0, dir.X)
		lastDir = dir
		if si > 1 then
			local nextY = math.min(lastTopCenter.Y + 1.5, 40)
			cursorTop = Vector3.new(
				lastTopCenter.X + dir.X * 13,
				nextY,
				lastTopCenter.Z + dir.Z * 13
			)
		end
		local topY = cursorTop.Y

		-- Checkpoint platform and its green pad.
		part(
			world,
			"StageStart" .. si,
			Vector3.new(12, 1.5, 12),
			CFrame.new(cursorTop.X, topY - 0.75, cursorTop.Z),
			Color3.fromRGB(228, 228, 235)
		)
		local pad = part(
			world,
			"Checkpoint" .. si,
			Vector3.new(8, 0.6, 8),
			CFrame.new(cursorTop.X, topY + 0.3, cursorTop.Z),
			CHECKPOINT_COLOR,
			Enum.Material.Neon
		)
		nameplate(pad, "CHECKPOINT " .. si, 3.4)
		-- Little flag on the pad's back corner.
		local flagBase = cursorTop - dir * 3.2 + side * 3.2
		part(world, "CheckpointPole", Vector3.new(0.28, 5, 0.28), CFrame.new(flagBase.X, topY + 2.5, flagBase.Z), Color3.fromRGB(240, 240, 240))
		part(world, "CheckpointFlag", Vector3.new(0.15, 1.1, 1.9), CFrame.new(flagBase.X, topY + 4.6, flagBase.Z + 0.8), CHECKPOINT_COLOR, Enum.Material.Neon)
		table.insert(checkpoints, { Pad = pad, Stage = si, Name = def.Name })

		-- Statue platform + pedestal + statue beside the pad. The
		-- statue faces the pad (its local +X toward -side).
		local statueCenter = cursorTop + side * 11
		part(
			world,
			"StatueBase" .. si,
			Vector3.new(10, 1.5, 10),
			CFrame.new(statueCenter.X, topY - 0.75, statueCenter.Z),
			Color3.fromRGB(200, 200, 215)
		)
		local pedestal = part(
			world,
			"StatuePedestal" .. si,
			Vector3.new(6.5, 1, 6.5),
			CFrame.new(statueCenter.X, topY + 0.5, statueCenter.Z),
			Color3.fromRGB(150, 150, 175)
		)
		local front = -side
		local statueYaw = math.atan2(-front.Z, front.X)
		local statueBaseCf = CFrame.new(statueCenter.X, topY + 1, statueCenter.Z) * CFrame.Angles(0, statueYaw, 0)
		STATUE_BUILDERS[si](world, statueBaseCf)
		nameplate(pedestal, def.Name, 10.8)

		-- Big stage name board over the checkpoint, facing the
		-- incoming player (its faces look back along -dir).
		local boardYaw = math.atan2(-dir.X, -dir.Z)
		local boardPos = Vector3.new(cursorTop.X, topY + 10, cursorTop.Z)
		makeBoard(
			world,
			"StageBoard" .. si,
			Vector3.new(18, 5, 0.6),
			CFrame.new(boardPos) * CFrame.Angles(0, boardYaw, 0),
			Color3.fromRGB(45, 45, 70),
			"STAGE " .. si,
			def.Name
		)
		for _, s in { -7.5, 7.5 } do
			local polePos = cursorTop + side * s
			part(world, "StageBoardPole", Vector3.new(0.4, 7.5, 0.4), CFrame.new(polePos.X, topY + 3.75, polePos.Z), Color3.fromRGB(90, 90, 100))
		end

		-- The stage's jump platforms.
		for i = 1, def.Count do
			local sideOff = math.sin(i * 1.35 + si * 0.9) * 4.5
			local topYi = topY + i * def.Rise
			local center = cursorTop + dir * (i * 11.5) + side * sideOff
			local topCenter = Vector3.new(center.X, topYi, center.Z)

			local size: Vector3
			if i % 5 == 4 then
				-- A thin beam platform, long in the travel direction.
				if dir.X ~= 0 then
					size = Vector3.new(10, 1, 2.4)
				else
					size = Vector3.new(2.4, 1, 10)
				end
			elseif i % 3 == 0 then
				size = Vector3.new(10, 1.2, 10)
			else
				size = Vector3.new(8, 1.2, 8)
			end
			part(
				world,
				"Platform",
				size,
				CFrame.new(center.X, topYi - size.Y / 2, center.Z),
				def.Colors[(i % #def.Colors) + 1]
			)

			-- Kill bricks: on two platforms per stage (offset to one
			-- side so the player can slip past) ...
			if i == 3 or i == 7 then
				local kbPos = topCenter + side * 2.3
				local kb = part(
					world,
					"KillBrick",
					Vector3.new(2.2, 1.1, 2.2),
					CFrame.new(kbPos.X, topYi + 0.55, kbPos.Z),
					KILL_COLOR,
					Enum.Material.Neon
				)
				table.insert(killParts, kb)
			end
			-- ... and one floating in the gap after platform 5.
			if i == 5 then
				local nextSideOff = math.sin(6 * 1.35 + si * 0.9) * 4.5
				local nextCenter = cursorTop + dir * (6 * 11.5) + side * nextSideOff
				local mid = (topCenter + Vector3.new(nextCenter.X, topYi, nextCenter.Z)) / 2 + side * 2.6
				local kb = part(
					world,
					"KillBrick",
					Vector3.new(2, 2, 2),
					CFrame.new(mid.X, topYi + 0.5, mid.Z),
					KILL_COLOR,
					Enum.Material.Neon
				)
				table.insert(killParts, kb)
			end

			-- Orbs hover over every second platform.
			if i % 2 == 0 then
				local orbCf = CFrame.new(center.X, topYi + 2.2, center.Z)
				local orbColor = ORB_COLORS[((si + i) % #ORB_COLORS) + 1]
				local orb = WorldBuilder.CreateOrb(orbFolder, orbCf, orbColor)
				table.insert(orbs, { Part = orb, CFrame = orbCf, Color = orbColor })
			end

			lastTopCenter = topCenter
		end
	end

	----------------------------------------------------------------
	-- Finish: a grand gold platform with a checkered heart, a big
	-- FINISH board and confetti pillars.
	----------------------------------------------------------------
	local finishTopY = lastTopCenter.Y
	local finishCenter = Vector3.new(
		lastTopCenter.X + lastDir.X * 17,
		finishTopY,
		lastTopCenter.Z + lastDir.Z * 17
	)
	local finishSide = Vector3.new(-lastDir.Z, 0, lastDir.X)
	part(
		world,
		"FinishPlatform",
		Vector3.new(26, 2, 26),
		CFrame.new(finishCenter.X, finishTopY - 1, finishCenter.Z),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Metal
	)
	-- Checkered tiles under the pad.
	for tx = -2, 2 do
		for tz = -2, 2 do
			local tileColor = if (tx + tz) % 2 == 0 then Color3.fromRGB(25, 25, 30) else Color3.fromRGB(245, 245, 245)
			part(
				world,
				"FinishTile",
				Vector3.new(1.7, 0.3, 1.7),
				CFrame.new(finishCenter.X + tx * 1.75, finishTopY + 0.15, finishCenter.Z + tz * 1.75),
				tileColor
			)
		end
	end
	local finishPad = part(
		world,
		"FinishPad",
		Vector3.new(10, 0.5, 10),
		CFrame.new(finishCenter.X, finishTopY + 0.55, finishCenter.Z),
		Color3.fromRGB(255, 215, 80),
		Enum.Material.Neon
	)
	finishPad.Transparency = 0.45
	finishPad.CanCollide = false

	local finishYaw = math.atan2(-lastDir.X, -lastDir.Z)
	local finishBoardPos = finishCenter + lastDir * 11 + Vector3.new(0, 10.5, 0)
	makeBoard(
		world,
		"FinishBoard",
		Vector3.new(20, 6, 0.6),
		CFrame.new(finishBoardPos) * CFrame.Angles(0, finishYaw, 0),
		Color3.fromRGB(120, 40, 160),
		"FINISH",
		"Injak landasan emasnya: +500 Aura!"
	)
	for _, s in { -8.5, 8.5 } do
		local polePos = finishCenter + lastDir * 11 + finishSide * s
		part(world, "FinishBoardPole", Vector3.new(0.4, 7.5, 0.4), CFrame.new(polePos.X, finishTopY + 3.75, polePos.Z), Color3.fromRGB(90, 90, 100))
	end
	-- Confetti pillars in the finish platform's corners.
	local confetti = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(255, 170, 40),
		Color3.fromRGB(80, 220, 90),
		Color3.fromRGB(60, 160, 255),
		Color3.fromRGB(180, 100, 255),
	}
	for _, cx in { -11, 11 } do
		for _, cz in { -11, 11 } do
			local basePos = Vector3.new(finishCenter.X + cx, finishTopY, finishCenter.Z + cz)
			for level = 0, 2 do
				part(
					world,
					"ConfettiPillar",
					Vector3.new(2.2, 1.6, 2.2),
					CFrame.new(basePos.X, finishTopY + 0.8 + level * 1.6, basePos.Z),
					confetti[(level % #confetti) + 1],
					Enum.Material.Neon
				)
			end
			ball(world, "ConfettiTop", 1.6, CFrame.new(basePos.X, finishTopY + 5.6, basePos.Z), confetti[((cx + cz) % #confetti) + 1], Enum.Material.Neon)
		end
	end

	print(string.format(
		"[WorldBuilder] ObbyWorld built: %d parts, %d checkpoints, %d orbs",
		WorldBuilder.PartCount,
		#checkpoints,
		#orbs
	))

	return {
		Folder = world,
		OrbFolder = orbFolder,
		Spawn = spawn,
		SpawnCFrame = spawn.CFrame,
		Checkpoints = checkpoints,
		KillParts = killParts,
		Orbs = orbs,
		FinishPad = finishPad,
	}
end

return WorldBuilder
