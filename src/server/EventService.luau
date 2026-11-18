-- EventService: the island's sky. Three rhythms run here:
--  * "Hujan Meteor Sambal" — every 90 seconds (60 calm, 10 warning,
--    20 active) sambal meteors rain on the plaza. A marker disc shows
--    each landing point from the moment the meteor spawns; the landed
--    meteor is a big neon ball with a light pillar, lives 20 seconds,
--    and pays $50 x the collector's rebirth multiplier to whoever
--    touches it or stands within 6 studs.
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
EventService.ActiveSeconds = 20
EventService.BonusCash = 50
EventService.MeteorLifetime = 20
EventService.CollectRadius = 6
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
local announcedLanding = false -- first meteor touchdown of this active phase already announced

function EventService.GetStatus(): { Phase: string, SecondsLeft: number }
	return {
		Phase = phase,
		SecondsLeft = math.max(0, math.ceil(phaseEndsAt - os.clock())),
	}
end

function EventService.IsNight(): boolean
	return isNight
end

local function collectMeteor(player: Player, meteor: Part, pillar: Part)
	local record = PlayerState.Records[player]
	if not record then
		return
	end
	local bonus = math.floor(EventService.BonusCash * PlayerState.Multiplier(record))
	PlayerState.AddCash(record, bonus)
	notify(player, "Meteor Sambal! +$" .. bonus)
	meteor:Destroy()
	pillar:Destroy()
end

local function spawnMeteor()
	local folder = meteorsFolder
	if not folder then
		return
	end
	local x = rng:NextNumber(-45, 45)
	local z = rng:NextNumber(-28, 28)
	local target = Vector3.new(x, WorldBuilder.FloorTop + 1.6, z)

	local marker = Instance.new("Part")
	marker.Name = "MeteorMarker"
	marker.Size = Vector3.new(4.8, 0.25, 4.8)
	marker.Shape = Enum.PartType.Cylinder
	marker.CFrame = CFrame.new(target.X, WorldBuilder.FloorTop + 0.15, target.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	marker.Color = Color3.fromRGB(255, 120, 50)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35
	marker.Anchored = true
	marker.CanCollide = false
	marker.Parent = folder

	local meteor = Instance.new("Part")
	meteor.Name = "MeteorSambal"
	meteor.Size = Vector3.new(3.2, 3.2, 3.2)
	meteor.Shape = Enum.PartType.Ball
	meteor.CFrame = CFrame.new(x, 62, z)
	meteor.Color = Color3.fromRGB(255, 90, 40)
	meteor.Material = Enum.Material.Neon
	meteor.Anchored = true
	meteor.CanCollide = false
	meteor.Parent = folder
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 50)
	glow.Range = 16
	glow.Brightness = 2
	glow.Parent = meteor

	task.spawn(function()
		local startPos = meteor.Position
		local duration = 0.9
		local elapsed = 0
		while elapsed < duration and meteor.Parent do
			local dt = task.wait()
			elapsed += dt
			local t = math.min(1, elapsed / duration)
			meteor.CFrame = CFrame.new(startPos:Lerp(target, t * t))
		end
		if not meteor.Parent then
			marker:Destroy()
			return
		end
		meteor.CFrame = CFrame.new(target)
		marker:Destroy()

		local pillar = Instance.new("Part")
		pillar.Name = "MeteorPillar"
		pillar.Size = Vector3.new(1.4, 30, 1.4)
		pillar.Shape = Enum.PartType.Cylinder
		pillar.CFrame = CFrame.new(target.X, target.Y + 15, target.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		pillar.Color = Color3.fromRGB(255, 120, 50)
		pillar.Material = Enum.Material.Neon
		pillar.Transparency = 0.35
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.Parent = folder

		if not announcedLanding then
			announcedLanding = true
			notifyAll("Meteor Sambal jatuh di dekat plaza — dekati pilar cahayanya untuk bonus cash!")
		end

		local collected = false
		local conn: RBXScriptConnection? = nil
		conn = meteor.Touched:Connect(function(hit)
			if collected then
				return
			end
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				collected = true
				if conn then
					conn:Disconnect()
				end
				collectMeteor(player, meteor, pillar)
			end
		end)
		local deadline = os.clock() + EventService.MeteorLifetime
		while not collected and os.clock() < deadline and meteor.Parent do
			task.wait(0.15)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - target).Magnitude <= EventService.CollectRadius then
					collected = true
					if conn then
						conn:Disconnect()
					end
					collectMeteor(player, meteor, pillar)
					break
				end
			end
		end
		if conn then
			conn:Disconnect()
		end
		if meteor.Parent then
			meteor:Destroy()
		end
		if pillar.Parent then
			pillar:Destroy()
		end
	end)
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

	-- The meteor cycle.
	task.spawn(function()
		while true do
			phase = "calm"
			phaseEndsAt = os.clock()
				+ (EventService.PeriodSeconds - EventService.WarnSeconds - EventService.ActiveSeconds)
			task.wait(EventService.PeriodSeconds - EventService.WarnSeconds - EventService.ActiveSeconds)

			phase = "warn"
			phaseEndsAt = os.clock() + EventService.WarnSeconds
			notifyAll("Langit memerah... HUJAN METEOR SAMBAL sebentar lagi!")
			task.wait(EventService.WarnSeconds)

			phase = "active"
			announcedLanding = false
			phaseEndsAt = os.clock() + EventService.ActiveSeconds
			notifyAll("HUJAN METEOR SAMBAL! Dekati meteor untuk bonus cash!")
			local activeUntil = os.clock() + EventService.ActiveSeconds
			while os.clock() < activeUntil do
				spawnMeteor()
				task.wait(0.65)
			end
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
