-- BaseService: owns the six base plots — who holds which, which slots
-- are filled, the per-second income tick, and the 30-second base lock
-- (60-second cooldown after it ends). Characters arrive here from the
-- conveyor or from a successful steal and walk themselves to their slot.

local RunService = game:GetService("RunService")

local PlayerState = require(script.Parent.PlayerState)

local BaseService = {}

BaseService.LockSeconds = 30
BaseService.LockCooldownSeconds = 60

local bases: { any } = {}
local ownerByBase: { [number]: any } = {} -- [baseIndex] = record

-- Set by init.server.luau: called after a character is placed so the
-- steal service can arm its prompt. A hook, so this module never has to
-- require the steal service (which requires this one).
BaseService.OnPlaced = nil :: ((any) -> ())?

function BaseService.Init(worldBases: { any })
	bases = worldBases
end

function BaseService.GetBase(index: number)
	return bases[index]
end

function BaseService.IsLocked(record): boolean
	return os.clock() < record.LockUntil
end

function BaseService.LockSecondsLeft(record): number
	return math.max(0, math.ceil(record.LockUntil - os.clock()))
end

function BaseService.LockCooldownLeft(record): number
	return math.max(0, math.ceil(record.LockReadyAt - os.clock()))
end

-- Hand a joining player the first free base and paint its signs.
function BaseService.AssignBase(record): boolean
	for index, _base in bases do
		if ownerByBase[index] == nil then
			ownerByBase[index] = record
			record.BaseIndex = index
			local base = bases[index]
			base.OwnerSign.Text = "BASE " .. index .. " — " .. string.upper(record.Player.DisplayName)
			for _, border in base.BorderParts do
				border.Color = base.Color
			end
			return true
		end
	end
	return false
end

-- Free the base again when its owner leaves, clearing its characters.
function BaseService.ReleaseBase(record)
	local index = record.BaseIndex
	if not index then
		return
	end
	for _, entry in record.Placed do
		if entry.Model then
			entry.Model:Destroy()
		end
	end
	record.Placed = {}
	record.SlotTaken = {}
	ownerByBase[index] = nil
	record.BaseIndex = nil
	local base = bases[index]
	if base then
		base.OwnerSign.Text = "BASE " .. index .. " — KOSONG"
		base.LockSign.Text = "TIDAK TERKUNCI"
	end
end

-- Walk a character model from where it stands to a target CFrame, with a
-- little bob, facing its direction of travel. Runs in its own thread.
function BaseService.WalkModelTo(model: Model, target: CFrame, speed: number)
	local startPos = model:GetPivot().Position
	local targetPos = target.Position
	local distance = (targetPos - startPos).Magnitude
	if distance < 0.5 then
		model:PivotTo(target)
		return
	end
	local duration = distance / speed
	local elapsed = 0
	-- The models face +Z, so the yaw that looks along the walk direction
	-- is atan2(dx, dz).
	local startYaw = math.atan2(targetPos.X - startPos.X, targetPos.Z - startPos.Z)
	while elapsed < duration do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local t = math.min(1, elapsed / duration)
		local pos = startPos:Lerp(targetPos, t)
		local bob = math.abs(math.sin(elapsed * 10)) * 0.35
		local cf = CFrame.new(pos.X, pos.Y + bob, pos.Z) * CFrame.Angles(0, startYaw, 0)
		model:PivotTo(cf)
		if not model.Parent then
			return
		end
	end
	model:PivotTo(target)
	-- A small landing hop, so arrivals read as a bounce, not a teleport.
	for i = 1, 3 do
		local lift = (i == 2) and 0.45 or 0.15
		model:PivotTo(target * CFrame.new(0, lift, 0))
		task.wait(0.05)
	end
	model:PivotTo(target)
end

-- Place a character on a slot of its owner's base: registers the entry,
-- walks the model there from wherever it is, and arms the steal hook.
function BaseService.PlaceCharacter(record, model: Model, def, slotIndex: number?)
	local slot = slotIndex or PlayerState.FreeSlot(record)
	if not slot or not record.BaseIndex then
		return nil
	end
	local entry = {
		Model = model,
		Def = def,
		Slot = slot,
		Owner = record,
		Prompt = nil,
	}
	record.SlotTaken[slot] = entry
	table.insert(record.Placed, entry)
	model:SetAttribute("OwnerUserId", record.Player.UserId)
	local base = bases[record.BaseIndex]
	local target = base.Slots[slot]
	task.spawn(function()
		BaseService.WalkModelTo(model, target, 11)
	end)
	if BaseService.OnPlaced then
		BaseService.OnPlaced(entry)
	end
	return entry
end

-- Lift a character off its slot (a steal, or its owner rebirthing).
-- Returns the entry, or nil when it was not placed.
function BaseService.RemoveCharacter(entry): boolean
	local record = entry.Owner
	if not record or record.SlotTaken[entry.Slot] ~= entry then
		return false
	end
	record.SlotTaken[entry.Slot] = nil
	local at = table.find(record.Placed, entry)
	if at then
		table.remove(record.Placed, at)
	end
	if entry.Prompt then
		entry.Prompt.Enabled = false
	end
	return true
end

-- Try to lock the caller's base. Returns ok, and a message for the player.
function BaseService.TryLock(record): (boolean, string)
	local now = os.clock()
	if now < record.LockUntil then
		return false, "Base sudah terkunci!"
	end
	if now < record.LockReadyAt then
		return false, "Kunci masih cooldown " .. BaseService.LockCooldownLeft(record) .. " dtk"
	end
	record.LockUntil = now + BaseService.LockSeconds
	record.LockReadyAt = record.LockUntil + BaseService.LockCooldownSeconds
	return true, "Base terkunci 30 detik!"
end

-- The heartbeat of the economy: every second, every placed cast pays
-- its owner, and every lock sign counts down.
function BaseService.StartLoops(notify: (Player, string) -> ())
	task.spawn(function()
		while true do
			task.wait(1)
			for _, record in PlayerState.Records do
				local income = PlayerState.IncomePerSecond(record)
				if income > 0 then
					PlayerState.AddCash(record, income)
				end
				if record.BaseIndex then
					local base = bases[record.BaseIndex]
					if base then
						if BaseService.IsLocked(record) then
							base.LockSign.Text = "TERKUNCI " .. BaseService.LockSecondsLeft(record) .. " dtk"
							base.LockSign.TextColor3 = Color3.fromRGB(255, 120, 120)
						else
							base.LockSign.Text = "TIDAK TERKUNCI"
							base.LockSign.TextColor3 = Color3.fromRGB(160, 255, 170)
						end
					end
				end
			end
		end
	end)
	-- (notify is part of the service contract; the income tick is silent.)
	local _ = notify
end

return BaseService
