-- PlayerState: the one authoritative store for per-player game state
-- on Brainrot Island. Cash, the rebirth level, placed brainrots, the
-- carried brainrot, the base assignment and the lock timers all live
-- in records here; leaderstats and the player's attributes are display
-- mirrors the client reads, never the source of truth.
--
-- Persistence is best-effort: cash and the rebirth level are saved
-- through a DataStore wrapped in pcall, so a place with Studio API
-- access off (or any store error) simply plays session-only.

local DataStoreService = game:GetService("DataStoreService")

local PlayerState = {}

export type Entry = {
	Model: Model,
	Body: Part,
	Def: any,
	State: string, -- "belt" | "walking" | "placed" | "carried" | "returning" | "wild"
	Owner: Record?,
	OwnerPlayer: Player?,
	Slot: number?,
	Carrier: Player?,
	BuyPrompt: ProximityPrompt?,
	StealPrompt: ProximityPrompt?,
	SellPrompt: ProximityPrompt?,
	Dead: boolean?,
}

export type Record = {
	Player: Player,
	Cash: number,
	Rebirths: number,
	TotalEarned: number,
	Placed: { Entry },
	SlotTaken: { [number]: Entry },
	Carrying: Entry?,
	BaseIndex: number?,
	LockUntil: number,
	LockReadyAt: number,
	CashValue: IntValue?,
}

PlayerState.Records = {} :: { [Player]: Record }
PlayerState.StartCash = 100
PlayerState.MaxRebirths = 5
PlayerState.BaseSlots = 6
PlayerState.StoreName = "BrainrotIsland_PlayerData_v1"

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(PlayerState.StoreName)
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
			local savedCash = tonumber(data.cash)
			if savedCash and savedCash >= 0 then
				record.Cash = math.floor(savedCash)
			end
			local savedRebirths = tonumber(data.rebirths) or 0
			record.Rebirths = math.clamp(math.floor(savedRebirths), 0, PlayerState.MaxRebirths)
			record.TotalEarned = math.floor(tonumber(data.totalEarned) or 0)
		end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = math.floor(record.Cash)
	cashValue.Parent = leaderstats
	leaderstats.Parent = player
	record.CashValue = cashValue

	player:SetAttribute("RebirthLevel", record.Rebirths)
	player:SetAttribute("IncomePerSec", 0)

	PlayerState.Records[player] = record
	return record
end

function PlayerState.SyncMirrors(record: Record)
	if record.CashValue then
		record.CashValue.Value = math.floor(record.Cash)
	end
	record.Player:SetAttribute("RebirthLevel", record.Rebirths)
end

function PlayerState.AddCash(record: Record, amount: number)
	record.Cash += amount
	if amount > 0 then
		record.TotalEarned += amount
	end
	PlayerState.SyncMirrors(record)
end

-- Spend only when the balance covers it; returns whether it spent.
function PlayerState.TrySpend(record: Record, amount: number): boolean
	if record.Cash < amount then
		return false
	end
	record.Cash -= amount
	PlayerState.SyncMirrors(record)
	return true
end

-- Raw per-second income of the placed cast (carried brainrots earn
-- nothing), scaled by the rebirth multiplier. BaseService pays the
-- floored per-brainrot amounts; this is the HUD's display number.
function PlayerState.IncomePerSecond(record: Record): number
	local sum = 0
	for _, entry in record.Placed do
		if entry.State == "placed" then
			sum += entry.Def.PerSec
		end
	end
	return sum * PlayerState.Multiplier(record)
end

-- A slot counts as taken while its brainrot is placed OR out being
-- carried: the slot stays reserved for the brainrot's way home.
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
			cash = math.floor(record.Cash),
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
