-- StealService: the tension of Brainrot Island. A placed brainrot can
-- be snatched off a rival's base (a 0.6 s hold on its prompt), rides
-- above the thief's head while the thief walks 15% slower, and becomes
-- the thief's when the thief reaches their own base with a free slot.
-- The victim's slot stays reserved the whole time — no income is paid
-- for a carried brainrot, and if the thief dies or leaves, the catch
-- glides home to that reserved slot. The owner can instead sell a
-- placed brainrot back for half its price.

local PlayerState = require(script.Parent.PlayerState)
local BaseService = require(script.Parent.BaseService)
local CharacterFactory = require(script.Parent.CharacterFactory)

local StealService = {}

StealService.CarrySpeedFactor = 0.85
StealService.DepositRadius = 11 -- studs from the thief's base centre
StealService.BaseWalkSpeed = 16

local notify: (Player, string) -> () = function() end

local function setPrompts(entry: PlayerState.Entry)
	local placed = entry.State == "placed"
	if entry.StealPrompt then
		entry.StealPrompt.Enabled = placed
	end
	if entry.SellPrompt then
		entry.SellPrompt.Enabled = placed
	end
end

local function setCarrierSpeed(player: Player, carrying: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = carrying
		and StealService.BaseWalkSpeed * StealService.CarrySpeedFactor
		or StealService.BaseWalkSpeed
end

-- Send a carried (or dropped) entry back to its owner's reserved slot.
function StealService.ReturnHome(entry: PlayerState.Entry)
	local owner = entry.Owner
	local ownerPlayer = entry.OwnerPlayer
	if entry.Carrier then
		local carrierRecord = PlayerState.Records[entry.Carrier]
		if carrierRecord and carrierRecord.Carrying == entry then
			carrierRecord.Carrying = nil
		end
		setCarrierSpeed(entry.Carrier, false)
		entry.Carrier = nil
	end
	if not owner or not ownerPlayer or PlayerState.Records[ownerPlayer] ~= owner or not owner.BaseIndex or not entry.Slot then
		BaseService.DestroyEntry(entry)
		return
	end
	entry.State = "returning"
	setPrompts(entry)
	local target = BaseService.SlotPosition(owner, entry.Slot, entry.Def)
	if not target then
		BaseService.DestroyEntry(entry)
		return
	end
	notify(ownerPlayer, entry.Def.Name .. " kembali ke base kamu.")
	CharacterFactory.GlideTo(entry.Model, target, 1, function()
		if entry.Dead then
			return
		end
		if PlayerState.Records[ownerPlayer] ~= owner then
			BaseService.DestroyEntry(entry)
			return
		end
		entry.State = "placed"
		-- The grab detached it from the owner's Placed list; earning
		-- (and the HUD count) only see entries on that list.
		local listed = false
		for _, e in owner.Placed do
			if e == entry then
				listed = true
			end
		end
		if not listed then
			table.insert(owner.Placed, entry)
		end
		setPrompts(entry)
	end)
end

-- Drop whatever a player is carrying (death, leaving, rebirth).
function StealService.DropCarry(player: Player, _reason: string?)
	local record = PlayerState.Records[player]
	local entry = record and record.Carrying or nil
	if not entry then
		-- Fallback: scan by carrier in case the record is already gone.
		for _, other in PlayerState.Records do
			for _, e in other.SlotTaken do
				if e.Carrier == player then
					entry = e
				end
			end
		end
	end
	if entry and entry.State == "carried" then
		StealService.ReturnHome(entry)
	end
end

local function completeSteal(entry: PlayerState.Entry, thief: Player, thiefRecord: PlayerState.Record)
	local slot = PlayerState.FreeSlot(thiefRecord)
	if not slot then
		return -- base filled up on the way home; keep carrying
	end
	local oldOwner = entry.Owner
	local oldOwnerPlayer = entry.OwnerPlayer
	-- The catch changes hands for good: free the victim's reservation.
	BaseService.DetachEntry(entry, false)
	entry.State = "walking"
	entry.Carrier = nil
	thiefRecord.Carrying = nil
	setCarrierSpeed(thief, false)
	setPrompts(entry)
	if oldOwnerPlayer then
		notify(oldOwnerPlayer, entry.Def.Name .. " resmi dicuri " .. thief.Name .. "!")
	end
	notify(thief, entry.Def.Name .. " sekarang milikmu!")
	local target = BaseService.SlotPosition(thiefRecord, slot, entry.Def)
	if not target then
		-- Nowhere to put it: send it back to the victim if they remain.
		entry.Owner = oldOwner
		entry.OwnerPlayer = oldOwnerPlayer
		StealService.ReturnHome(entry)
		return
	end
	CharacterFactory.GlideTo(entry.Model, target, 0.7, function()
		if entry.Dead then
			return
		end
		if PlayerState.Records[thief] ~= thiefRecord or not thiefRecord.BaseIndex then
			entry.Owner = oldOwner
			entry.OwnerPlayer = oldOwnerPlayer
			StealService.ReturnHome(entry)
			return
		end
		local finalSlot = PlayerState.FreeSlot(thiefRecord)
		if not finalSlot then
			entry.Owner = oldOwner
			entry.OwnerPlayer = oldOwnerPlayer
			StealService.ReturnHome(entry)
			return
		end
		BaseService.PlaceEntry(entry, thiefRecord, finalSlot)
		setPrompts(entry)
	end)
end

local function startCarry(entry: PlayerState.Entry, thief: Player, thiefRecord: PlayerState.Record)
	entry.State = "carried"
	entry.Carrier = thief
	thiefRecord.Carrying = entry
	setPrompts(entry)
	setCarrierSpeed(thief, true)
	notify(thief, "Kamu mencuri " .. entry.Def.Name .. "! Bawa pulang ke base kamu!")
	if entry.OwnerPlayer then
		notify(entry.OwnerPlayer, "ALARM! " .. entry.Def.Name .. " dicuri " .. thief.Name .. "!")
	end

	task.spawn(function()
		while entry.State == "carried" and not entry.Dead do
			task.wait()
			local character = thief.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not thief.Parent or not hrp or not humanoid or humanoid.Health <= 0 then
				StealService.ReturnHome(entry)
				return
			end
			local base = BaseService.BaseOf(thiefRecord)
			if base then
				local flat = Vector3.new(hrp.Position.X - base.Center.X, 0, hrp.Position.Z - base.Center.Z)
				if flat.Magnitude < StealService.DepositRadius then
					completeSteal(entry, thief, thiefRecord)
					if entry.State ~= "carried" then
						return
					end
				end
			end
			if entry.State == "carried" and entry.Model.Parent then
				local above = hrp.Position + Vector3.new(0, 3.4 + entry.Def.BodySize.Y / 2, 0)
				entry.Model:PivotTo(CFrame.new(above))
			end
		end
	end)
end

-- Called by BaseService's OnPlaced hook for every freshly placed entry:
-- builds the steal prompt (for rivals) and the sell prompt (owner).
function StealService.ArmPrompt(entry: PlayerState.Entry)
	if entry.StealPrompt or entry.SellPrompt then
		setPrompts(entry)
		return
	end
	local def = entry.Def

	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.Name = "StealPrompt"
	stealPrompt.ActionText = "Curi"
	stealPrompt.ObjectText = def.Name
	stealPrompt.HoldDuration = 0.6
	stealPrompt.MaxActivationDistance = 10
	stealPrompt.RequiresLineOfSight = false
	stealPrompt.Parent = entry.Body
	entry.StealPrompt = stealPrompt

	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Jual $" .. CharacterFactory.FormatMoney(math.floor(def.Price / 2))
	sellPrompt.ObjectText = def.Name
	sellPrompt.HoldDuration = 0.5
	sellPrompt.MaxActivationDistance = 10
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = entry.Body
	entry.SellPrompt = sellPrompt

	stealPrompt.Triggered:Connect(function(player)
		if entry.State ~= "placed" or entry.Dead then
			return
		end
		local thiefRecord = PlayerState.Records[player]
		if not thiefRecord then
			return
		end
		if entry.Owner == thiefRecord then
			notify(player, "Ini brainrot milikmu sendiri.")
			return
		end
		if thiefRecord.Carrying then
			notify(player, "Tanganmu penuh! Bawa pulang dulu curianmu.")
			return
		end
		local owner = entry.Owner
		if owner and BaseService.IsLocked(owner) then
			notify(player, "Base ini sedang TERKUNCI. Coba lagi nanti.")
			return
		end
		if not thiefRecord.BaseIndex then
			notify(player, "Kamu belum punya base!")
			return
		end
		if not PlayerState.FreeSlot(thiefRecord) then
			notify(player, "Base kamu PENUH! Jual dulu salah satu brainrot.")
			return
		end
		-- Leave the owner's Placed list (no income, no double-count)
		-- but keep the slot reservation for the way home.
		BaseService.DetachEntry(entry, true)
		startCarry(entry, player, thiefRecord)
	end)

	sellPrompt.Triggered:Connect(function(player)
		if entry.State ~= "placed" or entry.Dead then
			return
		end
		local record = PlayerState.Records[player]
		if not record or entry.Owner ~= record then
			notify(player, "Ini bukan brainrot milikmu.")
			return
		end
		local refund = math.floor(def.Price / 2)
		PlayerState.AddCash(record, refund)
		notify(player, def.Name .. " terjual. +$" .. CharacterFactory.FormatMoney(refund))
		BaseService.DestroyEntry(entry)
	end)

	setPrompts(entry)
end

function StealService.Start(notifyFn: (Player, string) -> ())
	notify = notifyFn
end

return StealService
