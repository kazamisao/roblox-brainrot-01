-- EventService: the island's event clock and sky. It runs three
-- rhythms:
--  * "Peti Harta Karun" — a 90-second cycle (20 calm, 10 warning,
--    60 live) in which five treasure chests land on open plaza,
--    each marked by a tall gold pillar. Opening one pays $50 times
--    the opener's rebirth multiplier in a burst of gold; whatever
--    is still shut when the live phase ends disappears.
--  * Day and night — Lighting starts at 08:00 and sweeps a full
--    day every 360 seconds; night (19:00-05:00) doubles the rare
--    weights on the conveyor (BrainrotData.Roll asks IsNight).
--  * The golden visitor — at nightfall a free Mythic brainrot
--    waits somewhere on the island under a gold pillar, and the
--    first player within 5 studs with room in their base takes
--    it. Still unclaimed at dawn, it leaves.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local BrainrotData = require(script.Parent.BrainrotData)
local CharacterFactory = require(script.Parent.CharacterFactory)
local PlayerState = require(script.Parent.PlayerState)
local BaseService = require(script.Parent.BaseService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local EventService = {}

EventService.PeriodSeconds = 90
EventService.WarnSeconds = 10
EventService.ActiveSeconds = 60
EventService.BonusCash = 50
EventService.DayLengthSeconds = 360

-- Wired by init.server.luau: takes the golden entry for a player
-- (the glide and placement live there with the rest of the
-- placement wiring).
EventService.OnGoldenClaim = nil :: ((PlayerState.Entry, Player) -> ())?

local phase = "calm" -- "calm" | "warn" | "active"
local phaseEndsAt = os.clock()
	+ (EventService.PeriodSeconds - EventService.WarnSeconds - EventService.ActiveSeconds)
local notifyAll: (string) -> () = function() end
local notify: (Player, string) -> () = function() end
local rng = Random.new()
local meteorsFolder: Folder? = nil
local placedFolder: Folder? = nil
local goldenEntry: PlayerState.Entry? = nil
local goldenPillar: Part? = nil
local isNight = false
local activeChests: { Model } = {} -- unopened chests of the live phase

-- The six base centres, mirroring WorldBuilder's layout (columns
-- at x = -42/0/42, rows at z = -40/40). Chest spots must keep
-- their distance from these so a chest never lands inside a plot.
local BASE_CENTERS: { Vector3 } = {}
for i = 1, 6 do
	local row = (i <= 3) and -1 or 1
	local col = ((i - 1) % 3) - 1
	table.insert(BASE_CENTERS, Vector3.new(col * 42, 0, row * 40))
end

function EventService.GetStatus(): { Phase: string, SecondsLeft: number }
	return {
		Phase = phase,
		SecondsLeft = math.max(0, math.ceil(phaseEndsAt - os.clock())),
	}
end

function EventService.IsNight(): boolean
	return isNight
end

-- A golden flash where a chest was opened: a neon gold ball that
-- swells from 1 to 6 studs over 0.4 s while it fades away.
local function spawnBurst(pos: Vector3)
	local folder = meteorsFolder
	if not folder then
		return
	end
	task.spawn(function()
		local burst = Instance.new("Part")
		burst.Name = "PetiBurst"
		burst.Shape = Enum.PartType.Ball
		burst.Size = Vector3.new(1, 1, 1)
		burst.CFrame = CFrame.new(pos)
		burst.Color = Color3.fromRGB(255, 215, 80)
		burst.Material = Enum.Material.Neon
		burst.Anchored = true
		burst.CanCollide = false
		burst.Parent = folder
		local elapsed = 0
		while elapsed < 0.4 and burst.Parent do
			local dt = task.wait()
			elapsed += dt
			local t = math.min(1, elapsed / 0.4)
			local s = 1 + 5 * t
			burst.Size = Vector3.new(s, s, s)
			burst.Transparency = t
		end
		burst:Destroy()
	end)
end

-- Pick a spot a chest can actually be reached at. Rolls are only
-- accepted on open walkable plaza: |x| at most 48, |z| between 8
-- and 26 — the z band keeps every chest clear of the belt strip
-- down the middle (the belt and its rails own |z| < 8) — and at
-- least 10 studs from every base centre, so no chest ever lands
-- inside a base plot where its pillar shows but its body cannot
-- be reached. Twelve rolls at most; if none fits, this chest is
-- skipped rather than dropped somewhere broken.
local function rollChestSpot(): Vector3?
	for _ = 1, 12 do
		local x = rng:NextNumber(-50, 50)
		local z = rng:NextNumber(-26, 26)
		if math.abs(x) <= 48 and math.abs(z) >= 8 then
			local clearOfBases = true
			for _, center in BASE_CENTERS do
				local dx = x - center.X
				local dz = z - center.Z
				if dx * dx + dz * dz < 100 then
					clearOfBases = false
					break
				end
			end
			if clearOfBases then
				return Vector3.new(x, 0, z)
			end
		end
	end
	return nil
end

-- One treasure chest: a brown box with gold trim and its gold lid
-- tipped open, a warm light, and a tall gold pillar so it reads
-- from anywhere on the plaza. Three paths open it, all funnelled
-- through the same claim function and its claimed latch: the
-- proximity prompt (instant, generous range, no line of sight),
-- physically touching the box, and simply walking up close.
local function spawnChest()
	local folder = meteorsFolder
	if not folder then
		return
	end
	local spot = rollChestSpot()
	if not spot then
		return
	end
	local x, z = spot.X, spot.Z
	local floorY = WorldBuilder.FloorTop

	local model = Instance.new("Model")
	model.Name = "PetiHartaKarun"
	model.Parent = folder

	local body = Instance.new("Part")
	body.Name = "ChestBody"
	body.Size = Vector3.new(2.6, 1.8, 2.2)
	body.CFrame = CFrame.new(x, floorY + 0.9, z)
	body.Color = Color3.fromRGB(122, 74, 34)
	body.Material = Enum.Material.Wood
	body.Anchored = true
	body.Parent = model

	for _, bandY in { floorY + 0.45, floorY + 1.35 } do
		local band = Instance.new("Part")
		band.Name = "ChestTrim"
		band.Size = Vector3.new(2.7, 0.24, 2.3)
		band.CFrame = CFrame.new(x, bandY, z)
		band.Color = Color3.fromRGB(255, 196, 40)
		band.Material = Enum.Material.Metal
		band.Anchored = true
		band.CanCollide = false
		band.Parent = model
	end

	local lid = Instance.new("Part")
	lid.Name = "ChestLid"
	lid.Size = Vector3.new(2.9, 0.5, 2.5)
	lid.CFrame = CFrame.new(x, floorY + 2.1, z - 0.35) * CFrame.Angles(math.rad(-18), 0, 0)
	lid.Color = Color3.fromRGB(255, 196, 40)
	lid.Material = Enum.Material.Metal
	lid.Anchored = true
	lid.CanCollide = false
	lid.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 60)
	light.Range = 12
	light.Brightness = 2
	light.Parent = body

	local pillar = Instance.new("Part")
	pillar.Name = "PetiPillar"
	pillar.Size = Vector3.new(1.4, 30, 1.4)
	pillar.Shape = Enum.PartType.Cylinder
	pillar.CFrame = CFrame.new(x, floorY + 15, z) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Color = Color3.fromRGB(255, 210, 60)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.35
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Parent = model

	table.insert(activeChests, model)

	local claimed = false
	local function claimChest(player: Player)
		if claimed then
			return
		end
		claimed = true
		local record = PlayerState.Records[player]
		if record then
			local bonus = math.floor(EventService.BonusCash * PlayerState.Multiplier(record))
			PlayerState.AddCash(record, bonus)
			notify(player, "Peti Harta! +$" .. bonus)
		end
		for i, chest in activeChests do
			if chest == model then
				table.remove(activeChests, i)
				break
			end
		end
		model:Destroy()
		spawnBurst(Vector3.new(x, floorY + 1.2, z))
	end

	-- Path one: the prompt. No hold, a long reach, and no line of
	-- sight demanded — a chest beside a prop still opens.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buka Peti"
	prompt.ObjectText = "Peti Harta Karun"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player: Player)
		claimChest(player)
	end)

	-- Path two: bumping into the box opens it. The hit part's
	-- parent is the character; resolve that to its player and let
	-- the claimed latch sort out repeats.
	body.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if character then
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				claimChest(player)
			end
		end
	end)

	-- Path three: walking up opens it too, no button at all. The
	-- check is horizontal only — flat XZ distance within 5 studs,
	-- sampled every 0.1 s — so a player's height above the plaza
	-- (jumping, standing on the chest itself) can never push them
	-- out of range the way a 3D magnitude check did.
	task.spawn(function()
		while not claimed and model.Parent do
			task.wait(0.1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dx = hrp.Position.X - body.Position.X
					local dz = hrp.Position.Z - body.Position.Z
					if dx * dx + dz * dz <= 25 then
						claimChest(player)
						return
					end
				end
			end
		end
	end)
end

-- Whatever is still shut when the live phase ends vanishes.
local function clearChests()
	for _, chest in activeChests do
		if chest.Parent then
			chest:Destroy()
		end
	end
	table.clear(activeChests)
end

local function spawnGolden()
	if goldenEntry and not goldenEntry.Dead then
		return
	end
	local folder = placedFolder
	if not folder then
		return
	end
	local def = BrainrotData.GoldenDef
	local model, body = CharacterFactory.Build(def)
	model.Parent = folder
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(60, 100)
	local pos = Vector3.new(math.cos(angle) * radius,
		WorldBuilder.IslandTop + def.BodySize.Y / 2, math.sin(angle) * radius)
	model:PivotTo(CFrame.new(pos))

	local entry: PlayerState.Entry = {
		Model = model,
		Body = body,
		Def = def,
		State = "wild",
	}
	goldenEntry = entry

	local pillar = Instance.new("Part")
	pillar.Name = "GoldenPillar"
	pillar.Size = Vector3.new(2, 40, 2)
	pillar.Shape = Enum.PartType.Cylinder
	pillar.CFrame = CFrame.new(pos.X, 20, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Color = Color3.fromRGB(255, 210, 60)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.55
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Parent = folder
	goldenPillar = pillar

	notifyAll("BRAINROT EMAS LIAR muncul di pulau! Siapa cepat, dia dapat — GRATIS!")

	task.spawn(function()
		while entry.State == "wild" and not entry.Dead do
			task.wait(0.3)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - pos).Magnitude <= 5 then
					local record = PlayerState.Records[player]
					if record and record.BaseIndex and PlayerState.FreeSlot(record) then
						entry.State = "claimed"
						if goldenPillar then
							goldenPillar:Destroy()
							goldenPillar = nil
						end
						if EventService.OnGoldenClaim then
							EventService.OnGoldenClaim(entry, player)
						else
							BaseService.DestroyEntry(entry)
						end
					elseif record then
						notify(player, "Base kamu PENUH! Brainrot emas menunggu...")
					end
					break
				end
			end
		end
		if goldenPillar then
			goldenPillar:Destroy()
			goldenPillar = nil
		end
	end)
end

local function despawnGolden()
	if goldenEntry and goldenEntry.State == "wild" then
		BaseService.DestroyEntry(goldenEntry)
	end
	goldenEntry = nil
	if goldenPillar then
		goldenPillar:Destroy()
		goldenPillar = nil
	end
end

function EventService.Start(world: any, notifyAllFn: (string) -> (), notifyFn: (Player, string) -> ())
	meteorsFolder = world.MeteorsFolder
	placedFolder = world.PlacedFolder
	notifyAll = notifyAllFn
	notify = notifyFn

	-- The treasure chest cycle: calm, a shouted warning, then the
	-- live window with five chests on the plaza.
	task.spawn(function()
		while true do
			phase = "calm"
			phaseEndsAt = os.clock()
				+ (EventService.PeriodSeconds - EventService.WarnSeconds - EventService.ActiveSeconds)
			task.wait(EventService.PeriodSeconds - EventService.WarnSeconds - EventService.ActiveSeconds)

			phase = "warn"
			phaseEndsAt = os.clock() + EventService.WarnSeconds
			notifyAll("PETI HARTA KARUN akan muncul di plaza — bersiap!")
			task.wait(EventService.WarnSeconds)

			phase = "active"
			phaseEndsAt = os.clock() + EventService.ActiveSeconds
			notifyAll("5 PETI HARTA muncul di plaza! Dekati dan BUKA petinya untuk bonus cash!")
			for _ = 1, 5 do
				spawnChest()
			end
			task.wait(EventService.ActiveSeconds)
			clearChests()
		end
	end)

	-- The day/night sweep, with the golden visitor arriving at
	-- nightfall and leaving again at dawn.
	Lighting.ClockTime = 8
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(150, 150, 168)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 140)
	task.spawn(function()
		local elapsed = 0
		local wasNight = false
		while true do
			task.wait(1)
			elapsed += 1
			Lighting.ClockTime = (8 + (elapsed / EventService.DayLengthSeconds) * 24) % 24
			local clock = Lighting.ClockTime
			isNight = clock >= 19 or clock < 5
			if isNight and not wasNight then
				spawnGolden()
			elseif not isNight and wasNight then
				despawnGolden()
			end
			wasNight = isNight
		end
	end)
end

return EventService
