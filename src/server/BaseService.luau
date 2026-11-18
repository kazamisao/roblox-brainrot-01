-- BaseService: owns the six base plots — who holds which, which slots
-- are filled, the per-second income tick, and the 30-second base lock
-- (60-second cooldown after it ends). Characters arrive here from the
-- conveyor, from a completed steal, or from the golden night visitor,
-- and are placed onto a slot of their owner's base.

local PlayerState = require(script.Parent.PlayerState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local CharacterFactory = require(script.Parent.CharacterFactory)

local BaseService = {}

BaseService.LockSeconds = 30
BaseService.LockCooldownSeconds = 60

local bases: { WorldBuilder.BaseSpot } = {}
local ownerByBase: { [number]: PlayerState.Record } = {}

-- Set by init.server.luau: called after a character is placed so the
-- steal service can arm its prompts. A hook, so this module never has
-- to require the steal service (which requires this one).
BaseService.OnPlaced = nil :: ((PlayerState.Entry) -> ())?

function BaseService.Init(worldBases: { WorldBuilder.BaseSpot })
	bases = worldBases
end

function BaseService.GetBase(index: number): WorldBuilder.BaseSpot?
	return bases[index]
end

function BaseService.BaseOf(record: PlayerState.Record): WorldBuilder.BaseSpot?
	if record.BaseIndex then
		return bases[record.BaseIndex]
	end
	return nil
end

-- Where a character of this def stands on the given slot: the slot's
-- floor position lifted by half the body's height.
function BaseService.SlotPosition(record: PlayerState.Record, slot: number, def: any): Vector3?
	local base = BaseService.BaseOf(record)
	if not base then
		return nil
	end
	local floor = base.Slots[slot]
	return Vector3.new(floor.X, floor.Y + def.BodySize.Y / 2, floor.Z)
end

function BaseService.AssignBase(record: PlayerState.Record): number?
	for _, base in bases do
		if ownerByBase[base.Index] == nil then
			ownerByBase[base.Index] = record
			record.BaseIndex = base.Index
			base.OwnerSign.Text = "BASE MILIK:\n" .. record.Player.Name
			return base.Index
		end
	end
	return nil
end

-- Attach an entry to a record's slot. The caller has already moved the
-- model; this does the bookkeeping and fires the OnPlaced hook.
function BaseService.PlaceEntry(entry: PlayerState.Entry, record: PlayerState.Record, slot: number)
	entry.Owner = record
	entry.OwnerPlayer = record.Player
	entry.Slot = slot
	entry.State = "placed"
	record.SlotTaken[slot] = entry
	table.insert(record.Placed, entry)
	if BaseService.OnPlaced then
		BaseService.OnPlaced(entry)
	end
end

-- Detach an entry from its owner's lists without destroying the model
-- (a steal in progress keeps the slot reservation, so it calls this
-- only when the catch changes hands for good).
function BaseService.DetachEntry(entry: PlayerState.Entry, keepSlotReservation: boolean)
	local owner = entry.Owner
	if not owner then
		return
	end
	for i = #owner.Placed, 1, -1 do
		if owner.Placed[i] == entry then
			table.remove(owner.Placed, i)
		end
	end
	if not keepSlotReservation and entry.Slot and owner.SlotTaken[entry.Slot] == entry then
		owner.SlotTaken[entry.Slot] = nil
	end
end

function BaseService.DestroyEntry(entry: PlayerState.Entry)
	if entry.Dead then
		return
	end
	entry.Dead = true
	BaseService.DetachEntry(entry, false)
	if entry.Model then
		entry.Model:Destroy()
	end
end

-- Release a base when its owner leaves: every brainrot on it goes with
-- them (one being carried away is cut loose from its thief first).
function BaseService.ReleaseBase(record: PlayerState.Record)
	local index = record.BaseIndex
	if not index then
		return
	end
	-- Collect first: DestroyEntry mutates the lists being walked.
	local mine: { PlayerState.Entry } = {}
	for _, entry in record.Placed do
		table.insert(mine, entry)
	end
	for _, entry in record.SlotTaken do
		local seen = false
		for _, e in mine do
			if e == entry then
				seen = true
			end
		end
		if not seen then
			table.insert(mine, entry)
		end
	end
	for _, entry in mine do
		local carrier = entry.Carrier
		if carrier then
			local carrierRecord = PlayerState.Records[carrier]
			if carrierRecord and carrierRecord.Carrying == entry then
				carrierRecord.Carrying = nil
			end
			entry.Carrier = nil
		end
		BaseService.DestroyEntry(entry)
	end
	record.Placed = {}
	record.SlotTaken = {}
	ownerByBase[index] = nil
	record.BaseIndex = nil
	local base = bases[index]
	if base then
		base.OwnerSign.Text = "BASE KOSONG"
		base.LockWall.Transparency = 1
		base.LockWall.CanCollide = false
	end
end

function BaseService.IsLocked(record: PlayerState.Record): boolean
	return os.clock() < record.LockUntil
end

function BaseService.LockSecondsLeft(record: PlayerState.Record): number
	return math.max(0, math.ceil(record.LockUntil - os.clock()))
end

function BaseService.LockCooldownLeft(record: PlayerState.Record): number
	if BaseService.IsLocked(record) then
		return 0
	end
	return math.max(0, math.ceil(record.LockReadyAt - os.clock()))
end

function BaseService.TryLock(record: PlayerState.Record): (boolean, string)
	local base = BaseService.BaseOf(record)
	if not base then
		return false, "Kamu belum punya base!"
	end
	local now = os.clock()
	if now < record.LockUntil then
		return false, "Base sudah terkunci (" .. BaseService.LockSecondsLeft(record) .. " dtk lagi)."
	end
	if now < record.LockReadyAt then
		return false, "Kunci masih cooldown " .. BaseService.LockCooldownLeft(record) .. " dtk lagi."
	end
	record.LockUntil = now + BaseService.LockSeconds
	record.LockReadyAt = record.LockUntil + BaseService.LockCooldownSeconds
	base.LockWall.Transparency = 0.65
	base.LockWall.CanCollide = true
	task.delay(BaseService.LockSeconds, function()
		base.LockWall.Transparency = 1
		base.LockWall.CanCollide = false
	end)
	return true, "Base TERKUNCI selama " .. BaseService.LockSeconds .. " detik!"
end

-- The income tick: once a second, every placed brainrot pays its owner
-- floor(PerSec x multiplier); carried brainrots earn nothing. Each
-- paying brainrot pops a floating "+$N" over itself so the income is
-- visible in the world, and the paid total is mirrored into the
-- IncomePerSec attribute for the HUD. The same loop keeps the base
-- sign honest about the lock: while the base is locked the sign
-- counts the remaining seconds down for every rival to read.
function BaseService.StartLoops()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, record in PlayerState.Records do
				local mult = PlayerState.Multiplier(record)
				local paid = 0
				for _, entry in record.Placed do
					if entry.State == "placed" then
						local pay = math.floor(entry.Def.PerSec * mult)
						paid += pay
						if pay > 0 then
							CharacterFactory.ShowIncomePopup(entry.Body, pay)
						end
					end
				end
				if paid > 0 then
					PlayerState.AddCash(record, paid)
				end
				record.Player:SetAttribute("IncomePerSec", paid)

				local base = BaseService.BaseOf(record)
				if base then
					if BaseService.IsLocked(record) then
						base.OwnerSign.Text = "BASE MILIK:\n" .. record.Player.Name
							.. "\nTERKUNCI " .. BaseService.LockSecondsLeft(record) .. " dtk"
					elseif string.find(base.OwnerSign.Text, "TERKUNCI") then
						base.OwnerSign.Text = "BASE MILIK:\n" .. record.Player.Name
					end
				end
			end
		end
	end)
end

return BaseService
