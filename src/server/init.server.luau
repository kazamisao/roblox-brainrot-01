-- Brainrot Island — server bootstrap.
-- Builds the island, wires every service to the shared player state
-- and the remotes, and runs the per-second HUD push. The game loop
-- itself lives in the services: ConveyorService rides characters in,
-- BaseService pays income and runs the base lock, StealService
-- handles snatches and carries, EventService runs the treasure-chest
-- drops, the day/night cycle and the golden night visitor, and
-- RebirthService sells permanent income multipliers for cash.

local Players = game:GetService("Players")

local Remotes = require(script.Remotes)
local PlayerState = require(script.PlayerState)
local WorldBuilder = require(script.WorldBuilder)
local CharacterFactory = require(script.CharacterFactory)
local BaseService = require(script.BaseService)
local ConveyorService = require(script.ConveyorService)
local StealService = require(script.StealService)
local EventService = require(script.EventService)
local RebirthService = require(script.RebirthService)

local remotes = Remotes.Get()

local function toast(player: Player, message: string)
	remotes.Toast:FireClient(player, message)
end

local function toastAll(message: string)
	remotes.Toast:FireAllClients(message)
end

-- The world is built further below. The player lifecycle is connected
-- first, so a joining player always gets a character even if the
-- build ever stalls or fails; the game-state setup that needs the
-- world polls worldReady instead.
local world = nil
local worldReady = false

-- Player lifecycle. CharacterAutoLoads is off in the project, so the
-- server loads characters itself — immediately on join, before any
-- game-state work. State and base setup wait for the world.
local function onCharacterAdded(player: Player, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if hrp and world then
		hrp.CFrame = world.SpawnCFrame
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.Died:Connect(function()
			-- A dead thief drops the catch; it glides home on its own.
			StealService.DropCarry(player, "death")
			task.wait(3)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:LoadCharacter()
	-- Game state needs bases, and bases need the world: defer it
	-- until the build below has finished (20 s at the very most).
	task.spawn(function()
		local waited = 0
		while not worldReady and waited < 20 do
			task.wait(0.25)
			waited += 0.25
		end
		if not worldReady then
			warn("Brainrot Island: world not ready after 20 s, skipping setup for " .. player.Name)
			return
		end
		if not player.Parent then
			return
		end
		local ok, err = pcall(function()
			local record = PlayerState.Create(player)
			BaseService.AssignBase(record)
		end)
		if not ok then
			warn("Brainrot Island: setup failed for " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

local function onPlayerRemoving(player: Player)
	local record = PlayerState.Records[player]
	if record then
		-- A leaving thief's catch goes home before the record is dropped.
		StealService.DropCarry(player, "leave")
		BaseService.ReleaseBase(record)
	end
	PlayerState.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Build the world: bases must exist before any player is assigned one.
world = WorldBuilder.Build()
BaseService.Init(world.Bases)
worldReady = true

-- Cross-service wiring, kept here so the services stay decoupled:
-- placing a character arms its steal/sell prompts, and the golden
-- night visitor is claimed by gliding it into the claimant's base.
BaseService.OnPlaced = function(entry)
	StealService.ArmPrompt(entry)
end

EventService.OnGoldenClaim = function(entry, player)
	local record = PlayerState.Records[player]
	if not record or not record.BaseIndex then
		BaseService.DestroyEntry(entry)
		return
	end
	local slot = PlayerState.FreeSlot(record)
	if not slot then
		BaseService.DestroyEntry(entry)
		return
	end
	toast(player, "Kamu mendapatkan " .. entry.Def.Name .. " GRATIS!")
	entry.State = "walking"
	local target = BaseService.SlotPosition(record, slot, entry.Def)
	if not target then
		BaseService.DestroyEntry(entry)
		return
	end
	CharacterFactory.GlideTo(entry.Model, target, 1.2, function()
		if entry.Dead then
			return
		end
		if PlayerState.Records[player] ~= record or not record.BaseIndex then
			BaseService.DestroyEntry(entry)
			return
		end
		local finalSlot = PlayerState.FreeSlot(record)
		if not finalSlot then
			BaseService.DestroyEntry(entry)
			return
		end
		BaseService.PlaceEntry(entry, record, finalSlot)
	end)
end

-- Lock pads: stepping up to your own base's pad and using its prompt
-- runs the same validated lock as the HUD button.
for _, base in world.Bases do
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.ActionText = "Kunci Base"
	prompt.ObjectText = "30 detik anti-curi"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base.LockPad
	prompt.Triggered:Connect(function(player)
		local record = PlayerState.Records[player]
		if record and record.BaseIndex == base.Index then
			local _ok, message = BaseService.TryLock(record)
			toast(player, message)
		else
			toast(player, "Ini bukan base kamu!")
		end
	end)
end

-- Each service starts fault-isolated: one bad start must not kill the
-- rest of init, especially the fall rescue and HUD push loops below.
local function startSafely(name: string, start: () -> ())
	local ok, err = pcall(start)
	if not ok then
		warn("Brainrot Island: " .. name .. " failed to start: " .. tostring(err))
	end
end

startSafely("ConveyorService", function()
	ConveyorService.Start(world, toast)
end)
startSafely("StealService", function()
	StealService.Start(toast)
end)
startSafely("EventService", function()
	EventService.Start(world, toastAll, toast)
end)
startSafely("RebirthService", function()
	RebirthService.Start(world.RebirthPad, toast)
end)
startSafely("BaseService.StartLoops", function()
	BaseService.StartLoops()
end)

-- Client intents: the HUD buttons. Both are re-validated server-side.
remotes.LockRequest.OnServerEvent:Connect(function(player)
	local record = PlayerState.Records[player]
	if record then
		local _ok, message = BaseService.TryLock(record)
		toast(player, message)
	end
end)

remotes.RebirthRequest.OnServerEvent:Connect(function(player)
	local _ok, message = RebirthService.TryRebirth(player)
	toast(player, message)
end)

game:BindToClose(function()
	for _, record in PlayerState.Records do
		PlayerState.Save(record)
	end
end)

-- Fall rescue: the sea has no floor, so anyone who ends up under the
-- island is returned to the plaza.
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Position.Y < -5 then
				hrp.CFrame = world.SpawnCFrame
				toast(player, "Kamu tercebur dan kembali ke plaza.")
			end
		end
	end
end)

-- The HUD push: once a second each player gets the numbers its screen
-- cannot read from leaderstats alone.
task.spawn(function()
	while true do
		task.wait(1)
		local status = EventService.GetStatus()
		for player, record in PlayerState.Records do
			local cost = PlayerState.RebirthCost(record)
			remotes.HudUpdate:FireClient(player, {
				Income = math.floor(PlayerState.IncomePerSecond(record)),
				Rebirths = record.Rebirths,
				MaxRebirths = PlayerState.MaxRebirths,
				MultiplierPct = math.floor(PlayerState.Multiplier(record) * 100),
				RebirthCost = cost,
				RebirthCostText = cost and CharacterFactory.FormatMoney(cost) or nil,
				LockLeft = BaseService.LockSecondsLeft(record),
				LockCooldownLeft = BaseService.LockCooldownLeft(record),
				PlacedCount = #record.Placed,
				BaseSlots = PlayerState.BaseSlots,
				EventPhase = status.Phase,
				EventSeconds = status.SecondsLeft,
				IsNight = EventService.IsNight(),
			})
		end
	end
end)

print("Brainrot Island — pulau buka!")
