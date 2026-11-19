-- StealService: the tension of the game. A placed character can be
-- snatched off a rival's base with a short hold on its steal
-- prompt, rides above the thief's head while the thief walks it
-- home, and becomes the thief's the moment the thief reaches their
-- own base with a free slot -- whereupon the thief's base locks
-- behind it. Every check happens here on the server: the victim's
-- base must be unlocked, the thief must have a base and a free
-- slot, and nobody can carry two catches at once. Carrying is the
-- same movement story as everything else: each tick the entry's
-- placement is set to a point above the carrier's head and
-- re-applied through the Mover.

local BaseService = require(script.Parent.BaseService)
local CharacterFactory = require(script.Parent.CharacterFactory)
local EconomyService = require(script.Parent.EconomyService)
local Mover = require(script.Parent.Mover)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(script.Parent.Remotes)

local StealService = {}

StealService.CarryHeight = 3.6
StealService.DepositRadius = 12

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Give a placed entry its steal prompt. The prompt lives on the
-- entry so the base lock can silence it (and BaseService does, via
-- entry.StealPrompt) whenever the owner's base locks.
function StealService.AttachStealPrompt(entry)
	if entry.StealPrompt then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Curi"
	prompt.ObjectText = entry.Def.Name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = entry.BodyPart
	entry.StealPrompt = prompt
	prompt.Triggered:Connect(function(player: Player)
		StealService.TrySteal(entry, player)
	end)
end

local function deposit(entry, thiefRecord)
	local slot = BaseService.FreeSlot(thiefRecord)
	if not slot then
		return false
	end
	entry.State = "walking"
	thiefRecord.Carrying = nil
	local target = BaseService.SlotPosition(thiefRecord, slot)
	if not target then
		return false
	end
	Mover.Glide(entry, target, 0.8, function()
		if not entry.Alive then
			return
		end
		if PlayerState.Records[thiefRecord.Player] ~= thiefRecord or thiefRecord.BaseIndex == nil then
			BaseService.DestroyEntry(entry)
			return
		end
		BaseService.PlaceEntry(entry, thiefRecord, slot)
		if entry.StealPrompt then
			entry.StealPrompt.Enabled = not BaseService.IsLocked(thiefRecord)
		end
		BaseService.LockBase(thiefRecord, BaseService.LockSeconds)
		Remotes.Toast(thiefRecord.Player, "Hasil curian masuk base! " .. entry.Def.Name)
		EconomyService.SendHud(thiefRecord)
	end)
	return true
end

local function carryLoop(entry, thiefRecord)
	task.spawn(function()
		while entry.Alive and entry.State == "carried" do
			local thief = thiefRecord.Player
			if thief.Parent == nil or PlayerState.Records[thief] ~= thiefRecord then
				-- The thief vanished mid-carry; the catch is lost.
				thiefRecord.Carrying = nil
				BaseService.DestroyEntry(entry)
				return
			end
			local character = thief.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local base = BaseService.BaseOf(thiefRecord)
			if root and base then
				Mover.Apply(entry, CFrame.new(root.Position + Vector3.new(0, StealService.CarryHeight, 0)))
				if horizontalDistance(root.Position, base.Center) < StealService.DepositRadius then
					if deposit(entry, thiefRecord) then
						return
					end
				end
			end
			task.wait(0.1)
		end
	end)
end

function StealService.TrySteal(entry, thiefPlayer: Player)
	if entry.State ~= "placed" then
		return
	end
	local thiefRecord = PlayerState.Get(thiefPlayer)
	if not thiefRecord or not thiefRecord.BaseIndex then
		return
	end
	local victimRecord = entry.Owner
	if not victimRecord then
		return
	end
	if victimRecord == thiefRecord then
		Remotes.Toast(thiefPlayer, "Ini punya kamu sendiri!")
		return
	end
	if BaseService.IsLocked(victimRecord) then
		Remotes.Toast(thiefPlayer, "Base lawan sedang TERKUNCI!")
		return
	end
	if thiefRecord.Carrying then
		Remotes.Toast(thiefPlayer, "Tanganmu sudah penuh!")
		return
	end
	if not BaseService.FreeSlot(thiefRecord) then
		Remotes.Toast(thiefPlayer, "Base kamu PENUH!")
		return
	end

	BaseService.DetachEntry(entry)
	entry.State = "carried"
	entry.Carrier = thiefRecord
	thiefRecord.Carrying = entry
	if entry.StealPrompt then
		entry.StealPrompt.Enabled = false
	end
	Remotes.Toast(thiefPlayer, "Kamu mencuri " .. entry.Def.Name .. "! Bawa pulang ke basemu!")
	Remotes.Toast(victimRecord.Player, entry.Def.Name .. " kamu DICURI oleh " .. thiefPlayer.Name .. "!")
	EconomyService.SendHud(victimRecord)
	carryLoop(entry, thiefRecord)
end

-- When a player leaves, any catch they were carrying is lost with
-- them (their own placed characters are released by BaseService).
function StealService.OnPlayerLeft(player: Player)
	local record = PlayerState.Get(player)
	if record and record.Carrying then
		local entry = record.Carrying
		record.Carrying = nil
		BaseService.DestroyEntry(entry)
	end
end

return StealService
