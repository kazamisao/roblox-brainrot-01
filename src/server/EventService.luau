-- EventService: the island's sky. Three rhythms run here:
--  * "Peti Harta Karun" — every 90 seconds (60 calm, 10 warning,
--    20 active) five treasure chests appear on the plaza, each under
--    a tall gold light pillar. Opening one (proximity prompt) pays
--    $50 x the opener's rebirth multiplier in a burst of gold;
--    unopened chests vanish when the active phase ends.
--  * Day and night — Lighting starts at 08:00 and completes a full
--    cycle every 360 seconds; night (19:00-05:00) doubles the rare
--    conveyor weights (BrainrotData.Roll reads IsNight).
--  * The golden visitor — at nightfall one free Mythic brainrot waits
--    somewhere on the island under a gold pillar; the first player
--    within 5 studs whose base has room claims it. Unclaimed at dawn,
--    it is gone.

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
EventService.ActiveSeconds = 35
EventService.BonusCash = 50
EventService.DayLengthSeconds = 360

-- Set by init.server.luau: claims the golden entry for a player
-- (glide + placement live there with the other placement wiring).
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
local activeChests: { Model } = {} -- unclaimed chests of the current active phase

function EventService.GetStatus(): { Phase: string, SecondsLeft: number }
	return {
		Phase = phase,
		SecondsLeft = math.max(0, math.ceil(phaseEndsAt - os.clock())),
	}
end

function EventService.IsNight(): boolean
	return isNight
end

-- A quick golden burst where a chest was opened: a neon gold sphere
-- that swells from 1 to 6 studs over 0.4 s while fading out.
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

-- One treasure chest at a random point on the plaza: a brown box with
-- gold trim, its gold lid tipped open, a gold light and a tall gold
-- pillar so it can be spotted from anywhere. The proximity prompt on
-- the body is the whole interaction — hold to open, get the bonus.
local function spawnChest()
	local folder = meteorsFolder
	if not folder then
		return
	end
	local x = rng:NextNumber(-50, 50)
	local z = rng:NextNumber(-26, 26)
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

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buka Peti"
	prompt.ObjectText = "Peti Harta Karun"
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player: Player)
		claimChest(player)
	end)

	-- Walking into a chest opens it too — no button needed.
	task.spawn(function()
		while not claimed and model.Parent do
			task.wait(0.15)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - body.Position).Magnitude <= 4 then
					claimChest(player)
					return
				end
			end
		end
	end)
end

-- Unclaimed chests vanish when the active phase ends.
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

	-- The treasure chest cycle.
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

	-- Day and night, and the golden visitor at nightfall.
	Lighting.ClockTime = 8
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(115, 115, 130)
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
