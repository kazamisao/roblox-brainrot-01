-- RebirthService: the long-term progression. Rebirthing hands back all
-- placed characters and resets cash to the starting purse, and in
-- exchange every future income is multiplied by +25% per rebirth level
-- (up to 5). The cost quadruples each level. It can be triggered from
-- the HUD button (RebirthRequest) or from the prompt at the golden
-- REBIRTH stall; both paths land in the same validated function here.

local PlayerState = require(script.Parent.PlayerState)
local BaseService = require(script.Parent.BaseService)

local RebirthService = {}

local notify: (Player, string) -> () = function() end

-- Set by init.server.luau: returns anything the player is carrying to
-- its owner before the reset clears the bases.
RebirthService.BeforeReset = nil :: ((Player) -> ())?

function RebirthService.TryRebirth(player: Player): (boolean, string)
	local record = PlayerState.Records[player]
	if not record then
		return false, "Data pemain belum siap."
	end
	local cost = PlayerState.RebirthCost(record)
	if cost == nil then
		return false, "Rebirth sudah MAKSIMAL (5)!"
	end
	if record.Cash < cost then
		return false, "Rebirth butuh $" .. cost .. " — uang kamu kurang!"
	end
	if RebirthService.BeforeReset then
		RebirthService.BeforeReset(player)
	end
	PlayerState.TrySpend(record, cost)
	-- The cast goes back to the warung; the slots empty.
	for i = #record.Placed, 1, -1 do
		local entry = record.Placed[i]
		BaseService.RemoveCharacter(entry)
		if entry.Model then
			entry.Model:Destroy()
		end
	end
	record.Cash = PlayerState.StartCash
	PlayerState.SyncCash(record)
	record.Rebirths += 1
	if record.RebirthValue then
		record.RebirthValue.Value = record.Rebirths
	end
	PlayerState.Save(record)
	local pct = math.floor(PlayerState.Multiplier(record) * 100)
	return true, "REBIRTH! Penghasilan sekarang " .. pct .. "% seterusnya."
end

function RebirthService.Start(rebirthPad: Part, notifyFn: (Player, string) -> ())
	notify = notifyFn
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "+25% penghasilan permanen"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = rebirthPad
	prompt.Triggered:Connect(function(player)
		local _ok, message = RebirthService.TryRebirth(player)
		notify(player, message)
	end)
end

return RebirthService
