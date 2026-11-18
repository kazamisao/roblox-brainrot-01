-- ConveyorService: the heart of the loop. Every 3.5 seconds a new
-- brainrot appears at the west end of the belt (at most 7 riding at
-- once), travels east at 6 studs per second, and despawns at the far
-- end if nobody buys it. Buying is a ProximityPrompt on the character;
-- the purchase is validated here on the server — still on the belt,
-- enough cash, a free slot at the buyer's base — before any cash
-- moves, and the character then glides to the buyer's slot.

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
	local def = BrainrotData.Roll(EventService.IsNight())
	local model, body = CharacterFactory.Build(def)
	model.Parent = folder
	local startPos = Vector3.new(WorldBuilder.BeltStartX,
		WorldBuilder.BeltTopY + def.BodySize.Y / 2, WorldBuilder.BeltZ)
	model:PivotTo(CFrame.new(startPos))

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
		-- Reserve the slot for the whole glide so a second rapid buy
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

	-- The ride east; ends when the entry is bought or leaves the belt.
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
