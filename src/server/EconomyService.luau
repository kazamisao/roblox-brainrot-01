-- EconomyService: the money rhythm of the game. Once a second,
-- every placed character pays its owner its per-second rate times
-- the owner's rebirth multiplier, a "+$N" popup floats over the
-- character, and the owner's HUD is refreshed. This module also
-- owns rebirth -- pay the scaling cost, cash resets to the starting
-- amount, placed characters are cleared, and the multiplier grows
-- by +25% forever -- and binds the two client intents (rebirth and
-- lock) to their server-checked rules.

local BaseService = require(script.Parent.BaseService)
local CharacterFactory = require(script.Parent.CharacterFactory)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(script.Parent.Remotes)

local EconomyService = {}

-- Raw per-second income of a record before the multiplier.
function EconomyService.BaseIncome(record): number
	local sum = 0
	for _, entry in record.Placed do
		sum += entry.Def.PerSec
	end
	return sum
end

function EconomyService.IncomePerSec(record): number
	return math.floor(EconomyService.BaseIncome(record) * PlayerState.Multiplier(record))
end

function EconomyService.HudPayload(record): { [string]: any }
	local base = BaseService.BaseOf(record)
	return {
		cash = math.floor(record.Cash),
		income = EconomyService.IncomePerSec(record),
		placed = #record.Placed,
		slots = BaseService.MaxSlots,
		rebirths = record.Rebirths,
		multiplier = PlayerState.Multiplier(record),
		rebirthCost = PlayerState.RebirthCost(record),
		locked = base ~= nil and base.Locked == true,
	}
end

function EconomyService.SendHud(record)
	Remotes.Hud(record.Player, EconomyService.HudPayload(record))
end

-- Rebirth, fully checked here: enough cash, then the reset. Placed
-- characters are destroyed (their slots free up with them), cash
-- returns to the starting amount, and the rebirth count -- the
-- thing persistence keeps -- goes up by one.
function EconomyService.TryRebirth(record): boolean
	local cost = PlayerState.RebirthCost(record)
	if record.Cash < cost then
		Remotes.Toast(record.Player, "Cash kurang untuk rebirth! Butuh $" .. CharacterFactory.FormatMoney(cost))
		return false
	end
	local placed = table.clone(record.Placed)
	for _, entry in placed do
		BaseService.DestroyEntry(entry)
	end
	record.Cash = PlayerState.StartCash
	record.Rebirths += 1
	PlayerState.Save(record)
	EconomyService.SendHud(record)
	Remotes.Toast(record.Player, "REBIRTH! Penghasilan sekarang x" .. string.format("%.2f", PlayerState.Multiplier(record)))
	return true
end

local function onAction(player: Player, action: string)
	local record = PlayerState.Get(player)
	if not record then
		return
	end
	if action == "rebirth" then
		EconomyService.TryRebirth(record)
	elseif action == "lock" then
		if record.BaseIndex then
			BaseService.LockBase(record, BaseService.LockSeconds)
			Remotes.Toast(player, "Base dikunci 60 detik!")
			EconomyService.SendHud(record)
		end
	end
end

function EconomyService.Start()
	Remotes.OnAction(onAction)

	-- The income heartbeat: pay every placed character, float its
	-- popup, refresh its owner's HUD.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, record in PlayerState.Records do
				if #record.Placed > 0 then
					local mult = PlayerState.Multiplier(record)
					local total = 0
					for _, entry in record.Placed do
						local gain = math.floor(entry.Def.PerSec * mult)
						total += gain
						CharacterFactory.ShowIncomePopup(entry, gain)
					end
					PlayerState.AddCash(record, total)
				end
				EconomyService.SendHud(record)
			end
		end
	end)

	-- Autosave every minute; leaving saves too (PlayerState.Leave).
	task.spawn(function()
		while true do
			task.wait(60)
			PlayerState.SaveAll()
		end
	end)
end

return EconomyService
