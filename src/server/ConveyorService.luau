-- ConveyorService: the loop at the centre of the game. A fresh
-- brainrot spawns at the west end of the belt every 3.5 seconds (at
-- most 7 riding at once), rides east at 6 studs per second, and
-- despawns at the far end if nobody takes it. Buying runs through a
-- ProximityPrompt on the character and is fully validated here on
-- the server — still on the belt, cash covers the price, a slot is
-- free at the buyer's base — before any cash moves; the character
-- then glides over to the buyer's slot.

local BrainrotData = require(script.Parent.BrainrotData)
local CharacterFactory = require(script.Parent.CharacterFactory)
local PlayerState = require(script.Parent.PlayerState)
local BaseService = require(script.Parent.BaseService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local EventService = require(script.Parent.EventService)

local ConveyorService = {}

ConveyorService.SpawnInterval = 3.5
ConveyorService.MaxOnBelt = 7
ConveyorService.BeltSpeed = 6

local beltFolder: Folder? = nil
local placedFolder: Folder? = nil
local notify: (Player, string) -> () = function() end
local onBelt: { PlayerState.Entry } = {}

-- A fresh server does not roll its first spawns: two copies of the
-- $25 opener and the $75 second tier ride out first, scripted, so a
-- brand-new player (starting cash $100) can finish a first buy
-- within seconds instead of waiting on the weighted roll.
local OPENER_SEQUENCE = { 1, 2, 1, 3 }
local spawnsSoFar = 0

local function beltCount(): number
	local n = 0
	for _, entry in onBelt do
		if entry.State == "belt" then
			n += 1
		end
	end
	return n
end

local function spawnOne()
	local folder = beltFolder
	if not folder then
		return
	end
	spawnsSoFar += 1
	local def: BrainrotData.Def
	if spawnsSoFar <= #OPENER_SEQUENCE then
		def = BrainrotData.Cast[OPENER_SEQUENCE[spawnsSoFar]]
	else
		def = BrainrotData.Roll(EventService.IsNight())
	end
	local model, body = CharacterFactory.Build(def)
	model.Parent = folder
	local startPos = Vector3.new(WorldBuilder.BeltStartX,
		WorldBuilder.BeltTopY + def.BodySize.Y / 2, WorldBuilder.BeltZ)
	model:PivotTo(CFrame.new(startPos))

	-- One-shot placement check, done once here and never in the
	-- movement tick. The body is authored sitting on the model
	-- origin, so after the PivotTo its world Position has to be
	-- exactly startPos; if anything displaced the model (a pivot
	-- that is off the authored origin does this silently), shift
	-- the whole model back by the measured error. Position only —
	-- a cylinder body legitimately carries rotation.
	if (body.Position - startPos).Magnitude > 0.05 then
		model:PivotTo(model:GetPivot() * CFrame.new(startPos - body.Position))
	end

	local entry: PlayerState.Entry = {
		Model = model,
		Body = body,
		Def = def,
		State = "belt",
	}
	table.insert(onBelt, entry)

	local buyPrompt = Instance.new("ProximityPrompt")
	buyPrompt.Name = "BuyPrompt"
	buyPrompt.ActionText = "Beli $" .. CharacterFactory.FormatMoney(def.Price)
	buyPrompt.ObjectText = def.Name
	buyPrompt.HoldDuration = 0.35
	buyPrompt.MaxActivationDistance = 10
	buyPrompt.RequiresLineOfSight = false
	buyPrompt.Parent = body
	entry.BuyPrompt = buyPrompt

	buyPrompt.Triggered:Connect(function(player)
		if entry.State ~= "belt" or entry.Dead then
			return
		end
		local record = PlayerState.Records[player]
		if not record then
			return
		end
		if not record.BaseIndex then
			notify(player, "Kamu belum punya base!")
			return
		end
		local slot = PlayerState.FreeSlot(record)
		if not slot then
			notify(player, "Base kamu PENUH! Jual dulu salah satu brainrot.")
			return
		end
		if not PlayerState.TrySpend(record, def.Price) then
			notify(player, "Cash kurang! " .. def.Name .. " harganya $" .. CharacterFactory.FormatMoney(def.Price) .. ".")
			return
		end
		-- Hold the slot for the entire glide, so a second rapid buy
		-- cannot be promised the same spot.
		entry.Slot = slot
		record.SlotTaken[slot] = entry
		entry.State = "walking"
		buyPrompt.Enabled = false
		for i = #onBelt, 1, -1 do
			if onBelt[i] == entry then
				table.remove(onBelt, i)
			end
		end
		if placedFolder then
			model.Parent = placedFolder
		end
		notify(player, "Kamu membeli " .. def.Name .. "!")
		local target = BaseService.SlotPosition(record, slot, def)
		if not target then
			record.SlotTaken[slot] = nil
			entry.Slot = nil
			BaseService.DestroyEntry(entry)
			return
		end
		CharacterFactory.GlideTo(model, target, 1.4, function()
			if entry.Dead then
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
			BaseService.PlaceEntry(entry, record, slot)
		end)
	end)

	-- The ride east. Runs until the entry is bought or rolls off
	-- the far end of the belt, whichever comes first.
	task.spawn(function()
		while entry.State == "belt" and not entry.Dead and model.Parent do
			local dt = task.wait()
			local pivot = model:GetPivot()
			local nextX = pivot.Position.X + ConveyorService.BeltSpeed * dt
			if nextX > WorldBuilder.BeltEndX then
				for i = #onBelt, 1, -1 do
					if onBelt[i] == entry then
						table.remove(onBelt, i)
					end
				end
				BaseService.DestroyEntry(entry)
				return
			end
			model:PivotTo(CFrame.new(nextX, pivot.Position.Y, pivot.Position.Z)
				* (pivot - pivot.Position))
		end
	end)
end

function ConveyorService.Start(world: any, notifyFn: (Player, string) -> ())
	beltFolder = world.BeltFolder
	placedFolder = world.PlacedFolder
	notify = notifyFn
	task.spawn(function()
		while true do
			task.wait(ConveyorService.SpawnInterval)
			if beltCount() < ConveyorService.MaxOnBelt then
				spawnOne()
			end
		end
	end)
end

return ConveyorService
