-- RebirthService: the long-term progression of Brainrot Island.
-- Rebirthing costs cash only — the cost quadruples each level
-- (1000 x 4^level, up to level 5) — and in exchange every future
-- income is multiplied by +25% per level. Unlike a hard reset, the
-- player KEEPS their placed brainrots; only the purse is spent.
-- Triggered from the HUD button (RebirthRequest) or the prompt at
-- the purple stall on the plaza; both paths land in TryRebirth.

local PlayerState = require(script.Parent.PlayerState)
local CharacterFactory = require(script.Parent.CharacterFactory)

local RebirthService = {}

local notify: (Player, string) -> () = function() end

function RebirthService.TryRebirth(player: Player): (boolean, string)
	local record = PlayerState.Records[player]
	if not record then
		return false, "Data pemain belum siap."
	end
	local cost = PlayerState.RebirthCost(record)
	if cost == nil then
		return false, "Rebirth sudah MAKSIMAL (Lv " .. PlayerState.MaxRebirths .. ")!"
	end
	if record.Cash < cost then
		return false, "Rebirth Lv " .. (record.Rebirths + 1) .. " butuh $"
			.. CharacterFactory.FormatMoney(cost) .. " — cash kamu kurang!"
	end
	PlayerState.TrySpend(record, cost)
	record.Rebirths += 1
	PlayerState.SyncMirrors(record)
	PlayerState.Save(record)
	return true, "REBIRTH Lv " .. record.Rebirths
		.. "! Penghasilan sekarang x" .. string.format("%.2f", PlayerState.Multiplier(record)):gsub("%.", ",")
end

function RebirthService.Start(stall: Instance, notifyFn: (Player, string) -> ())
	notify = notifyFn
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "Kios Rebirth (+25% per level)"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = stall
	prompt.Triggered:Connect(function(player)
		local _ok, message = RebirthService.TryRebirth(player)
		notify(player, message)
	end)
end

return RebirthService
