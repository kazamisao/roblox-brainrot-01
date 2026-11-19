-- PlayerState: one record per player -- cash, rebirths, the base
-- assignment and the characters they own -- plus the only
-- persistence in the game. Cash and rebirths (nothing else) are
-- saved to a DataStore; every store call is wrapped in pcall, so a
-- place without API access, or a Studio session, simply plays with
-- session-only progress instead of erroring.

local DataStoreService = game:GetService("DataStoreService")

local PlayerState = {}

export type Record = {
	Player: Player,
	Cash: number,
	Rebirths: number,
	BaseIndex: number?,
	Placed: { any },
	SlotTaken: { [number]: any },
	Carrying: any?,
}

PlayerState.Records = {} :: { [Player]: Record }
PlayerState.StartCash = 100
PlayerState.StoreName = "BrainrotBaru_v1"

local store: DataStore? = nil
local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(PlayerState.StoreName)
	end)
	if ok then
		store = result
	end
	return store
end

-- Create the record for a joining player and load their saved cash
-- and rebirths when the store answers. The store read yields, so
-- callers run this in its own thread.
function PlayerState.Join(player: Player): Record
	local existing = PlayerState.Records[player]
	if existing then
		return existing
	end
	local record: Record = {
		Player = player,
		Cash = PlayerState.StartCash,
		Rebirths = 0,
		BaseIndex = nil,
		Placed = {},
		SlotTaken = {},
		Carrying = nil,
	}
	PlayerState.Records[player] = record

	local ds = getStore()
	if ds then
		local ok, data = pcall(function()
			return ds:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			local savedCash = tonumber(data.cash)
			if savedCash then
				record.Cash = math.floor(savedCash)
			end
			local savedRebirths = tonumber(data.rebirths)
			if savedRebirths then
				record.Rebirths = math.floor(savedRebirths)
			end
		end
	end
	return record
end

function PlayerState.Get(player: Player): Record?
	return PlayerState.Records[player]
end

function PlayerState.AddCash(record: Record, amount: number)
	record.Cash += amount
end

-- Spend only when the full price is covered; returns success.
function PlayerState.TrySpend(record: Record, amount: number): boolean
	if record.Cash < amount then
		return false
	end
	record.Cash -= amount
	return true
end

-- The income multiplier a record's placed characters earn with:
-- every rebirth adds a flat +25%.
function PlayerState.Multiplier(record: Record): number
	return 1 + 0.25 * record.Rebirths
end

-- What the next rebirth costs this record: 500.000 scaled by
-- (1 + 3 per rebirth already taken).
function PlayerState.RebirthCost(record: Record): number
	return 500000 * (1 + 3 * record.Rebirths)
end

function PlayerState.Save(record: Record)
	local ds = getStore()
	if not ds then
		return
	end
	local snapshot = {
		cash = math.floor(record.Cash),
		rebirths = record.Rebirths,
	}
	pcall(function()
		ds:SetAsync("player_" .. record.Player.UserId, snapshot)
	end)
end

function PlayerState.SaveAll()
	for _, record in PlayerState.Records do
		PlayerState.Save(record)
	end
end

-- Final save, then drop the record. Base cleanup is the caller's
-- job (BaseService.ReleaseBase) before this runs.
function PlayerState.Leave(player: Player)
	local record = PlayerState.Records[player]
	if not record then
		return
	end
	PlayerState.Save(record)
	PlayerState.Records[player] = nil
end

return PlayerState
