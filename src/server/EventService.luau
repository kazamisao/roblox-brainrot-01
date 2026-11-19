-- EventService: the island's small surprises. Every cycle a
-- treasure chest lands on open plaza away from the belt strip;
-- walking up and tapping its prompt pays a random handful of cash
-- to whoever opens it first, then it is gone. The chest is three
-- plain parts placed with direct CFrames, like everything the
-- world builder makes. The service also drifts the sky slowly
-- through a day/night cycle so the plaza light keeps changing.

local Lighting = game:GetService("Lighting")

local EconomyService = require(script.Parent.EconomyService)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(script.Parent.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)

local EventService = {}

EventService.CycleSeconds = 75
EventService.ChestLifetime = 45
EventService.RewardMin = 150
EventService.RewardMax = 450

local worldFolder: Folder? = nil

local function buildChest(at: Vector3): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "TreasureChest"

	local function chestPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local base = chestPart("ChestBase", Vector3.new(2.4, 1.1, 1.7),
		CFrame.new(at.X, at.Y + 0.55, at.Z), Color3.fromRGB(120, 78, 40), Enum.Material.Wood)
	chestPart("ChestTrim", Vector3.new(2.55, 0.18, 1.85),
		CFrame.new(at.X, at.Y + 1.05, at.Z), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	chestPart("ChestLid", Vector3.new(2.5, 0.5, 1.8),
		CFrame.new(at.X, at.Y + 1.35, at.Z), Color3.fromRGB(145, 95, 48), Enum.Material.Wood)
	return model, base
end

local function spawnChest()
	local folder = worldFolder
	if not folder then
		return
	end
	-- Open plaza, but never inside the belt strip (|z| < 9) and
	-- never inside a base row (|z| > 31 is base land).
	local x = math.random(-46, 46)
	local zSide = math.random(0, 1) == 0 and -1 or 1
	local z = zSide * math.random(10, 26)
	local floorPoint = Vector3.new(x, WorldBuilder.FloorTop, z)
	local chest, base = buildChest(floorPoint)
	chest.Parent = folder

	local claimed = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText = "Buka Peti"
	prompt.ObjectText = "Peti Harta Karun"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(function(player: Player)
		if claimed then
			return
		end
		local record = PlayerState.Get(player)
		if not record then
			return
		end
		claimed = true
		local reward = math.random(EventService.RewardMin, EventService.RewardMax)
		PlayerState.AddCash(record, reward)
		Remotes.Toast(player, "Peti harta karun: +$" .. reward .. "!")
		EconomyService.SendHud(record)
		chest:Destroy()
	end)

	task.delay(EventService.ChestLifetime, function()
		if not claimed and chest.Parent then
			chest:Destroy()
		end
	end)
end

function EventService.Start(world: any)
	worldFolder = world.Folder

	task.spawn(function()
		while true do
			task.wait(EventService.CycleSeconds)
			spawnChest()
		end
	end)

	-- A slow sky: the clock creeps forward, so daylight comes and
	-- goes over a long session.
	task.spawn(function()
		while true do
			task.wait(1)
			Lighting.ClockTime = (Lighting.ClockTime + 0.02) % 24
		end
	end)
end

return EventService
