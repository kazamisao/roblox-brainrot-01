-- PlayerState: the one authoritative store for per-player game state.
-- Every service reads and mutates records through here, so cash, placed
-- characters, the carried character, base assignment and lock timers all
-- live in exactly one place. leaderstats is only a display mirror of the
-- record; the record itself is what the server trusts.
--
-- Persistence is best-effort: the rebirth count is saved through a
-- DataStore wrapped in pcall, so a place with Studio API access off (or
-- any store error) simply plays session-only instead of failing.

local DataStoreService = game:GetService("DataStoreService")

local PlayerState = {}

export type PlacedEntry = {
	Model: Model,
	Def: any,
	Slot: number,
	Owner: any,
	Prompt: ProximityPrompt?,
}

export type Record = {
	Player: Player,
	Cash: number,
	Rebirths: number,
	TotalEarned: number,
	Placed: { PlacedEntry },
	SlotTaken: { [number]: PlacedEntry },
	Carrying: any?,
	BaseIndex: number?,
	LockUntil: number,
	LockReadyAt: number,
	CashValue: IntValue?,
	RebirthValue: IntValue?,
}

PlayerState.Records = {} :: { [Player]: Record }
PlayerState.StartCash = 50
PlayerState.MaxRebirths = 5
PlayerState.BaseSlots = 8

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("WarungBrainrot_v1")
	end)
	if ok then
		store = result
	end
end

function PlayerState.Multiplier(record: Record): number
	return 1 + 0.25 * record.Rebirths
end

-- Cost of the next rebirth, or nil when the player is at the cap.
function PlayerState.RebirthCost(record: Record): number?
	if record.Rebirths >= PlayerState.MaxRebirths then
		return nil
	end
	return 1000 * (4 ^ record.Rebirths)
end

function PlayerState.Create(player: Player): Record
	local record: Record = {
		Player = player,
		Cash = PlayerState.StartCash,
		Rebirths = 0,
		TotalEarned = 0,
		Placed = {},
		SlotTaken = {},
		Carrying = nil,
		BaseIndex = nil,
		LockUntil = 0,
		LockReadyAt = 0,
	}

	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync("player_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			local saved = tonumber(data.rebirths) or 0
			record.Rebirths = math.clamp(math.floor(saved), 0, PlayerState.MaxRebirths)
		end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = math.floor(record.Cash)
	cashValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirth"
	rebirthValue.Value = record.Rebirths
	rebirthValue.Parent = leaderstats
	leaderstats.Parent = player

	record.CashValue = cashValue
	record.RebirthValue = rebirthValue
	PlayerState.Records[player] = record
	return record
end

function PlayerState.SyncCash(record: Record)
	if record.CashValue then
		record.CashValue.Value = math.floor(record.Cash)
	end
end

function PlayerState.AddCash(record: Record, amount: number)
	record.Cash += amount
	if amount > 0 then
		record.TotalEarned += amount
	end
	PlayerState.SyncCash(record)
end

-- Spend only when the balance covers it; returns whether it spent.
function PlayerState.TrySpend(record: Record, amount: number): boolean
	if record.Cash < amount then
		return false
	end
	record.Cash -= amount
	PlayerState.SyncCash(record)
	return true
end

-- What the player's base earns each second right now: the placed cast's
-- rates summed, scaled by the rebirth multiplier.
function PlayerState.IncomePerSecond(record: Record): number
	local sum = 0
	for _, entry in record.Placed do
		sum += entry.Def.rate
	end
	return sum * PlayerState.Multiplier(record)
end

function PlayerState.FreeSlot(record: Record): number?
	for slot = 1, PlayerState.BaseSlots do
		if record.SlotTaken[slot] == nil then
			return slot
		end
	end
	return nil
end

function PlayerState.Save(record: Record)
	if not store then
		return
	end
	pcall(function()
		(store :: DataStore):SetAsync("player_" .. record.Player.UserId, {
			rebirths = record.Rebirths,
			totalEarned = math.floor(record.TotalEarned),
		})
	end)
end

function PlayerState.Remove(player: Player): Record?
	local record = PlayerState.Records[player]
	if record then
		PlayerState.Save(record)
		PlayerState.Records[player] = nil
	end
	return record
end

return PlayerState
