-- Brainrot Island BARU -- server bootstrap.
-- Builds the island, wires every service to the shared player
-- state and the remotes, and puts the hero statue on its pedestal.
-- The game loop itself lives in the services: ConveyorService
-- rides characters in, EconomyService pays the per-second income,
-- StealService runs the snatch-and-carry, EventService drops the
-- treasure chests. This script only assembles and starts them,
-- and owns the player join/leave sequence.

local Players = game:GetService("Players")

local BaseService = require(script.BaseService)
local CastData = require(script.CastData)
local CharacterFactory = require(script.CharacterFactory)
local ConveyorService = require(script.ConveyorService)
local DebugProbe = require(script.DebugProbe)
local EconomyService = require(script.EconomyService)
local EventService = require(script.EventService)
local Mover = require(script.Mover)
local PlayerState = require(script.PlayerState)
local Remotes = require(script.Remotes)
local StealService = require(script.StealService)
local WorldBuilder = require(script.WorldBuilder)

Remotes.Init()
local world = WorldBuilder.Build()
BaseService.Init(world)

-- The hero statue: the Secret fridge camel at full size on the
-- plaza pedestal, nameplate and all -- the ladder's top rung,
-- advertising itself to every new arrival.
local heroDef = CastData.Get("Frigo Camelo")
if heroDef then
	local hero = CharacterFactory.Build(heroDef)
	hero.Model.Name = "HeroStatue"
	hero.Model.Parent = world.Folder
	hero.State = "statue"
	Mover.Apply(hero, CFrame.new(world.HeroSpot))
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		task.wait(3)
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end

local function onPlayerAdded(player: Player)
	-- Join yields on the DataStore read; the PlayerAdded event
	-- thread is the right place for it.
	local record = PlayerState.Join(player)
	BaseService.AssignBase(record)
	EconomyService.SendHud(record)
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	end
	player:LoadCharacter()
end

local function onPlayerRemoving(player: Player)
	local record = PlayerState.Get(player)
	if not record then
		return
	end
	StealService.OnPlayerLeft(player)
	BaseService.ReleaseBase(record)
	PlayerState.Leave(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

EconomyService.Start()
ConveyorService.Start(world)
EventService.Start(world)

-- Build 16 diagnostic layer: the probe reports live world numbers
-- to every client, and the client's KE BELT button lands the
-- player on the plaza south of the belt, facing the welcome board.
Remotes.OnTeleport(function(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		(root :: BasePart).CFrame = CFrame.lookAt(Vector3.new(0, 4, 10), Vector3.new(0, 2, 0))
	end
end)
DebugProbe.Start()

print("[BrainrotIslandBaru] Build 15 live")
