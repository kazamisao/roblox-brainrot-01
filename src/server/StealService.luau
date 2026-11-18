-- StealService: the tension. A placed character can be grabbed off a
-- rival's base (a short hold on its prompt, so it is a snatch, not a
-- misclick), rides welded above the thief's head at a 15% slower walk,
-- and becomes the thief's when the thief reaches their own base with a
-- free slot. A locked base refuses grabs. Death, leaving, or a sambal
-- meteor landing nearby drops the catch, and it walks home to its owner.

local PlayerState = require(script.Parent.PlayerState)
local BaseService = require(script.Parent.BaseService)

local StealService = {}

StealService.CarrySpeedPenalty = 0.85 -- carriers walk at 85% speed
StealService.DepositRadius = 17 -- studs from the thief's base centre

local notify: (Player, string) -> () = function() end
local normalSpeed: { [Player]: number } = {}

local function setCarrierSpeed(player: Player, carrying: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if carrying then
		normalSpeed[player] = humanoid.WalkSpeed
		humanoid.WalkSpeed = humanoid.WalkSpeed * StealService.CarrySpeedPenalty
	else
		humanoid.WalkSpeed = normalSpeed[player] or 16
		normalSpeed[player] = nil
	end
end

-- Give a freshly placed character its steal prompt. Called through the
-- BaseService.OnPlaced hook so the two services stay decoupled.
function StealService.ArmPrompt(entry)
	local model = entry.Model
	local prompt = model:FindFirstChild("ActionPrompt", true) :: ProximityPrompt?
	if not prompt then
		return
	end
	entry.Prompt = prompt
	prompt.ActionText = "Curi"
	prompt.ObjectText = entry.Def.name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.Enabled = true
	prompt.Triggered:Connect(function(player)
		StealService.TryGrab(player, entry)
	end)
end

function StealService.TryGrab(thief: Player, entry)
	local thiefRecord = PlayerState.Records[thief]
	local ownerRecord = entry.Owner
	if not thiefRecord or not ownerRecord then
		return
	end
	if thiefRecord == ownerRecord then
		return -- your own cast is not stealable by you
	end
	if thiefRecord.Carrying then
		notify(thief, "Tangan kamu sudah penuh!")
		return
	end
	if not thiefRecord.BaseIndex or PlayerState.FreeSlot(thiefRecord) == nil then
		notify(thief, "Base kamu penuh, tidak bisa mencuri!")
		return
	end
	if BaseService.IsLocked(ownerRecord) then
		notify(thief, "Base " .. ownerRecord.Player.DisplayName .. " sedang TERKUNCI!")
		return
	end
	-- Still standing on its slot? (It may have been grabbed a frame ago.)
	if not BaseService.RemoveCharacter(entry) then
		return
	end

	local model = entry.Model
	local root = model.PrimaryPart
	if not root then
		return
	end
	if entry.Prompt then
		entry.Prompt.Enabled = false
	end

	local carry = {
		Model = model,
		Def = entry.Def,
		OriginalOwner = ownerRecord,
		OriginalSlot = entry.Slot,
	}
	thiefRecord.Carrying = carry

	-- Weld the catch above the thief's head.
	local character = thief.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		root.Anchored = false
		model:PivotTo(hrp.CFrame * CFrame.new(0, 3.4, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CarryWeld"
		weld.Part0 = root
		weld.Part1 = hrp
		weld.Parent = root
	end
	setCarrierSpeed(thief, true)
	notify(thief, "Kamu mencuri " .. entry.Def.name .. "! Bawa pulang ke base kamu!")
	notify(ownerRecord.Player, entry.Def.name .. " kamu DICURI " .. thief.DisplayName .. "!")
end

-- Deposit check: while anyone carries, watch for them reaching home.
local function depositLoop()
	while true do
		task.wait(0.25)
		for player, record in PlayerState.Records do
			local carry = record.Carrying
			if carry and record.BaseIndex then
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				local base = BaseService.GetBase(record.BaseIndex)
				if hrp and base then
					local flat = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
					local home = Vector3.new(base.Center.X, 0, base.Center.Z)
					if (flat - home).Magnitude <= StealService.DepositRadius then
						StealService.Deposit(player)
					end
				end
			end
		end
	end
end

-- The thief made it home: the catch changes owner for good.
function StealService.Deposit(thief: Player)
	local record = PlayerState.Records[thief]
	if not record or not record.Carrying then
		return
	end
	local carry = record.Carrying
	if PlayerState.FreeSlot(record) == nil then
		notify(thief, "Base kamu penuh! " .. carry.Def.name .. " lepas lagi!")
		StealService.DropCarry(thief, "full")
		return
	end
	record.Carrying = nil
	local model = carry.Model
	local root = model.PrimaryPart
	if root then
		local weld = root:FindFirstChild("CarryWeld")
		if weld then
			weld:Destroy()
		end
		root.Anchored = true
	end
	setCarrierSpeed(thief, false)
	BaseService.PlaceCharacter(record, model, carry.Def)
	notify(thief, carry.Def.name .. " sekarang milik kamu!")
end

-- Drop whatever a player carries and send it home to its owner: used on
-- death, on leaving, and when a sambal meteor lands on the carrier.
function StealService.DropCarry(player: Player, _reason: string?)
	local record = PlayerState.Records[player]
	if not record or not record.Carrying then
		return
	end
	local carry = record.Carrying
	record.Carrying = nil
	setCarrierSpeed(player, false)
	local model = carry.Model
	local root = model.PrimaryPart
	if root then
		local weld = root:FindFirstChild("CarryWeld")
		if weld then
			weld:Destroy()
		end
		root.Anchored = true
	end
	local owner = carry.OriginalOwner
	if owner and PlayerState.Records[owner.Player] == owner and owner.BaseIndex then
		local slot = nil
		if owner.SlotTaken[carry.OriginalSlot] == nil then
			slot = carry.OriginalSlot
		else
			slot = PlayerState.FreeSlot(owner)
		end
		if slot then
			BaseService.PlaceCharacter(owner, model, carry.Def, slot)
			notify(owner.Player, carry.Def.name .. " kamu pulang sendiri ke base!")
			return
		end
	end
	-- Nowhere to go home to: the catch scatters.
	model:Destroy()
end

function StealService.Start(notifyFn: (Player, string) -> ())
	notify = notifyFn
	task.spawn(depositLoop)
end

return StealService
