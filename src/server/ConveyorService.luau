-- ConveyorService: the loop at the centre of the game. A fresh
-- character spawns at the west end of the belt every few seconds
-- (at most seven riding at once), travels east, and despawns at the
-- far end if nobody takes it. Riding the belt is deliberately
-- boring arithmetic: each tick advances the entry's placement along
-- X and re-applies it through the Mover, so the character's feet
-- stay exactly on the belt surface the whole way. Buying runs
-- through a ProximityPrompt on the character and is fully
-- validated here on the server -- base, free slot, cash -- before
-- the character glides to the buyer's slot and locks the base
-- behind it.

local BaseService = require(script.Parent.BaseService)
local CastData = require(script.Parent.CastData)
local CharacterFactory = require(script.Parent.CharacterFactory)
local EconomyService = require(script.Parent.EconomyService)
local Mover = require(script.Parent.Mover)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(script.Parent.Remotes)
local StealService = require(script.Parent.StealService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ConveyorService = {}

ConveyorService.SpawnInterval = 3.5
ConveyorService.MaxOnBelt = 7
ConveyorService.BeltSpeed = 4.5

local beltFolder: Folder? = nil
local placedFolder: Folder? = nil
local onBelt: { any } = {}
local spawnsSoFar = 0

-- The first rides are a fixed gentle ladder (starter, second
-- common, starter again, first rare); after that the weighted
-- rarity roll takes over.
local OPENER_SEQUENCE = { 1, 2, 1, 3 }

local function removeFromBelt(entry)
	for i = #onBelt, 1, -1 do
		if onBelt[i] == entry then
			table.remove(onBelt, i)
		end
	end
end

local function buyFlow(entry, player: Player)
	if entry.State ~= "belt" then
		return
	end
	local record = PlayerState.Get(player)
	if not record then
		return
	end
	if not record.BaseIndex then
		Remotes.Toast(player, "Kamu belum punya base!")
		return
	end
	local slot = BaseService.FreeSlot(record)
	if not slot then
		Remotes.Toast(player, "Base kamu PENUH! Rebirth atau tunggu slot kosong.")
		return
	end
	local def = entry.Def
	if not PlayerState.TrySpend(record, def.Price) then
		Remotes.Toast(player, "Cash kurang! " .. def.Name .. " harganya $" .. CharacterFactory.FormatMoney(def.Price))
		return
	end

	-- Reserve the slot for the whole glide so a second rapid buy
	-- cannot be promised the same spot.
	entry.Slot = slot
	record.SlotTaken[slot] = entry
	entry.State = "walking"
	if entry.BuyPrompt then
		entry.BuyPrompt.Enabled = false
	end
	removeFromBelt(entry)
	if placedFolder then
		entry.Model.Parent = placedFolder
	end
	Remotes.Toast(player, "Kamu membeli " .. def.Name .. "!")
	EconomyService.SendHud(record)

	local target = BaseService.SlotPosition(record, slot)
	if not target then
		record.SlotTaken[slot] = nil
		entry.Slot = nil
		BaseService.DestroyEntry(entry)
		return
	end
	Mover.Glide(entry, target, 1.4, function()
		if not entry.Alive then
			return
		end
		-- The buyer may have left mid-glide; then the catch is void.
		if PlayerState.Records[player] ~= record or record.BaseIndex == nil then
			if record.SlotTaken[slot] == entry then
				record.SlotTaken[slot] = nil
			end
			entry.Slot = nil
			BaseService.DestroyEntry(entry)
			return
		end
		StealService.AttachStealPrompt(entry)
		BaseService.PlaceEntry(entry, record, slot)
		BaseService.LockBase(record, BaseService.LockSeconds)
		EconomyService.SendHud(record)
	end)
end

local function spawnOne()
	local folder = beltFolder
	if not folder then
		return
	end
	spawnsSoFar += 1
	local def
	if spawnsSoFar <= #OPENER_SEQUENCE then
		def = CastData.List[OPENER_SEQUENCE[spawnsSoFar]]
	else
		def = CastData.Roll()
	end
	local entry = CharacterFactory.Build(def)
	entry.Model.Parent = folder
	entry.State = "belt"
	-- The spawn placement: feet exactly on the belt surface at the
	-- west end. This one line is the whole placement story.
	CharacterFactory.Place(entry, CFrame.new(WorldBuilder.BeltStartX, WorldBuilder.BeltTopY, WorldBuilder.BeltZ))
	table.insert(onBelt, entry)

	local buyPrompt = Instance.new("ProximityPrompt")
	buyPrompt.Name = "BuyPrompt"
	buyPrompt.ActionText = "Beli $" .. CharacterFactory.FormatMoney(def.Price)
	buyPrompt.ObjectText = def.Name
	buyPrompt.HoldDuration = 0.35
	buyPrompt.MaxActivationDistance = 10
	buyPrompt.RequiresLineOfSight = false
	buyPrompt.Parent = entry.BodyPart
	entry.BuyPrompt = buyPrompt
	buyPrompt.Triggered:Connect(function(player: Player)
		buyFlow(entry, player)
	end)
end

function ConveyorService.Start(world: any)
	beltFolder = world.BeltFolder
	placedFolder = world.PlacedFolder

	-- The ride east: advance each belt entry's placement by the
	-- belt speed, re-apply, and despawn whatever reaches the end.
	task.spawn(function()
		while true do
			local dt = task.wait()
			for i = #onBelt, 1, -1 do
				local entry = onBelt[i]
				if not entry.Alive or entry.State ~= "belt" then
					table.remove(onBelt, i)
				else
					local pos = entry.Placement.Position
					local nextX = pos.X + ConveyorService.BeltSpeed * dt
					if nextX > WorldBuilder.BeltEndX then
						table.remove(onBelt, i)
						CharacterFactory.Destroy(entry)
					else
						Mover.Apply(entry, CFrame.new(nextX, WorldBuilder.BeltTopY, WorldBuilder.BeltZ))
					end
				end
			end
		end
	end)

	-- The spawner.
	task.spawn(function()
		while true do
			task.wait(ConveyorService.SpawnInterval)
			if #onBelt < ConveyorService.MaxOnBelt then
				spawnOne()
			end
		end
	end)
end

return ConveyorService
