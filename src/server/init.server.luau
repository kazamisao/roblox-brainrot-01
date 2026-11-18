-- Brainrot Island — server bootstrap.
-- Builds the island, wires every service to the shared player state
-- and the remotes, and runs the per-second HUD push. The game loop
-- itself lives in the services: ConveyorService rides characters in,
-- BaseService pays income and runs the base lock, StealService
-- handles snatches and carries, EventService runs the sambal-meteor
-- rain, the day/night cycle and the golden night visitor, and
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

-- Build the world first: bases must exist before any player is assigned.
local world = WorldBuilder.Build()
BaseService.Init(world.Bases)

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

ConveyorService.Start(world, toast)
StealService.Start(toast)
EventService.Start(world, toastAll, toast)
RebirthService.Start(world.RebirthPad, toast)
BaseService.StartLoops()

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

-- Player lifecycle. CharacterAutoLoads is off in the project, so the
-- server loads characters itself once their state and base exist.
local function onCharacterAdded(player: Player, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if hrp then
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
	local record = PlayerState.Create(player)
	BaseService.AssignBase(record)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:LoadCharacter()
end

local function onPlayerRemoving(player: Player)
	-- A leaving thief's catch goes home before the record is dropped.
	StealService.DropCarry(player, "leave")
	local record = PlayerState.Records[player]
	if record then
		BaseService.ReleaseBase(record)
	end
	PlayerState.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

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
