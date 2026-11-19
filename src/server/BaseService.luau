-- BaseService: owns the six base plots -- who holds which base,
-- which of its six slots are filled, and the base lock. A character
-- becomes "placed" here (arriving from the conveyor or from a
-- completed steal): this module does the bookkeeping, tracks every
-- placed entry per base so the lock can silence their steal
-- prompts at once, and runs the lock itself -- the neon wall turns
-- visible and every steal prompt inside goes dark for the duration.
-- Movement is never done here; callers glide characters with the
-- Mover and report the arrival.

local CharacterFactory = require(script.Parent.CharacterFactory)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(script.Parent.Remotes)

local BaseService = {}

local bases: { any } = {}
local ownerByBase: { [number]: any } = {}
local entriesByBase: { [number]: { [any]: boolean } } = {}

BaseService.MaxSlots = 6
BaseService.LockSeconds = 60

function BaseService.Init(world: any)
	bases = world.Bases
	for _, base in bases do
		entriesByBase[base.Index] = {}
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LockPrompt"
		prompt.ActionText = "Kunci Base (60 dtk)"
		prompt.ObjectText = "Base"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = base.LockPad
		prompt.Triggered:Connect(function(player: Player)
			local record = PlayerState.Get(player)
			if record and record.BaseIndex == base.Index then
				BaseService.LockBase(record, BaseService.LockSeconds)
				Remotes.Toast(player, "Base dikunci 60 detik!")
			end
		end)
	end
end

function BaseService.BaseOf(record): any?
	if not record or not record.BaseIndex then
		return nil
	end
	return bases[record.BaseIndex]
end

function BaseService.AssignBase(record): number?
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

function BaseService.FreeSlot(record): number?
	for s = 1, BaseService.MaxSlots do
		if not record.SlotTaken[s] then
			return s
		end
	end
	return nil
end

-- The standing point of a slot: the pad-top position the world
-- builder recorded. A character's origin is its feet, so this is
-- the whole answer -- no per-character adjustment exists.
function BaseService.SlotPosition(record, slot: number): Vector3?
	local base = BaseService.BaseOf(record)
	if not base then
		return nil
	end
	return base.Slots[slot]
end

-- Attach an entry to a record's slot. The caller has already moved
-- the model onto the slot; this does the bookkeeping.
function BaseService.PlaceEntry(entry, record, slot: number)
	entry.Owner = record
	entry.OwnerPlayer = record.Player
	entry.Slot = slot
	entry.State = "placed"
	record.SlotTaken[slot] = entry
	table.insert(record.Placed, entry)
	local base = BaseService.BaseOf(record)
	if base then
		entriesByBase[base.Index][entry] = true
	end
end

-- Detach an entry from its owner's lists without destroying the
-- model (a steal in progress calls this when the catch is taken).
function BaseService.DetachEntry(entry)
	local owner = entry.Owner
	if not owner then
		return
	end
	for i = #owner.Placed, 1, -1 do
		if owner.Placed[i] == entry then
			table.remove(owner.Placed, i)
		end
	end
	if entry.Slot and owner.SlotTaken[entry.Slot] == entry then
		owner.SlotTaken[entry.Slot] = nil
	end
	local base = BaseService.BaseOf(owner)
	if base then
		entriesByBase[base.Index][entry] = nil
	end
	entry.Owner = nil
	entry.OwnerPlayer = nil
	entry.Slot = nil
end

function BaseService.DestroyEntry(entry)
	BaseService.DetachEntry(entry)
	CharacterFactory.Destroy(entry)
end

local function setStealPrompts(base, enabled: boolean)
	for entry in entriesByBase[base.Index] do
		if entry.StealPrompt then
			entry.StealPrompt.Enabled = enabled
		end
	end
end

-- Lock a base for `seconds`: wall visible, steal prompts inside
-- dark. A token guards the timer so re-locking never lets an older
-- timer unlock the base early.
function BaseService.LockBase(record, seconds: number)
	local base = BaseService.BaseOf(record)
	if not base then
		return
	end
	base.Locked = true
	base.LockToken += 1
	local token = base.LockToken
	base.LockWall.Transparency = 0.35
	setStealPrompts(base, false)
	task.delay(seconds, function()
		if base.LockToken == token and base.Locked then
			BaseService.UnlockBase(base)
		end
	end)
end

function BaseService.UnlockBase(base)
	base.Locked = false
	base.LockToken += 1
	base.LockWall.Transparency = 1
	setStealPrompts(base, true)
end

function BaseService.IsLocked(record): boolean
	local base = BaseService.BaseOf(record)
	return base ~= nil and base.Locked == true
end

-- Release a base when its owner leaves: every character on it is
-- destroyed and the plot returns to the pool.
function BaseService.ReleaseBase(record)
	local index = record.BaseIndex
	if not index then
		return
	end
	local placed = table.clone(record.Placed)
	for _, entry in placed do
		BaseService.DestroyEntry(entry)
	end
	record.Placed = {}
	record.SlotTaken = {}
	local base = bases[index]
	if base then
		if base.Locked then
			BaseService.UnlockBase(base)
		end
		base.OwnerSign.Text = "BASE KOSONG"
	end
	ownerByBase[index] = nil
	record.BaseIndex = nil
end

return BaseService
