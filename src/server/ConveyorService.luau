-- ConveyorService: the heart of the loop. Every few seconds a new
-- brainrot rides in from the west end of the belt, walks its length at a
-- fixed speed with a bob, and rides off the east end if nobody buys it.
-- Buying is a ProximityPrompt on the character itself; the purchase is
-- validated here on the server (still on the belt, enough cash, a free
-- slot at the buyer's base) before any cash moves, and the character
-- then walks itself to the buyer's base slot.

local RunService = game:GetService("RunService")

local BrainrotData = require(script.Parent.BrainrotData)
local CharacterFactory = require(script.Parent.CharacterFactory)
local PlayerState = require(script.Parent.PlayerState)
local BaseService = require(script.Parent.BaseService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ConveyorService = {}

ConveyorService.BeltSpeed = 6 -- studs per second
ConveyorService.SpawnInterval = 3.5
ConveyorService.MaxOnBelt = 7

type Walker = {
	Model: Model,
	Def: any,
	X: number,
	Sold: boolean,
}

local walkers: { Walker } = {}
local rng = Random.new()
local notify: (Player, string) -> () = function() end

local function beltCFrame(x: number, bob: number): CFrame
	-- Models face +Z; a +90 degree yaw turns them to face +X, the way
	-- the belt travels.
	return CFrame.new(x, WorldBuilder.BeltTopY + bob, WorldBuilder.BeltZ) * CFrame.Angles(0, math.rad(90), 0)
end

local function tryBuy(player: Player, walker: Walker)
	if walker.Sold then
		return
	end
	local record = PlayerState.Records[player]
	if not record then
		return
	end
	if not record.BaseIndex then
		notify(player, "Kamu belum punya base!")
		return
	end
	if PlayerState.FreeSlot(record) == nil then
		notify(player, "Base kamu penuh! (maks 8)")
		return
	end
	if record.Cash < walker.Def.price then
		notify(player, "Uang kurang! " .. walker.Def.name .. " harganya " .. CharacterFactory.FormatMoney(walker.Def.price))
		return
	end
	if not PlayerState.TrySpend(record, walker.Def.price) then
		return
	end
	walker.Sold = true
	local at = table.find(walkers, walker)
	if at then
		table.remove(walkers, at)
	end
	local prompt = walker.Model:FindFirstChild("ActionPrompt", true)
	if prompt then
		prompt.Enabled = false
	end
	notify(player, "Dapat " .. walker.Def.name .. "! Dia jalan ke base kamu.")
	BaseService.PlaceCharacter(record, walker.Model, walker.Def)
end

local function spawnWalker(parent: Instance)
	local def = BrainrotData.Roll(rng)
	local model = CharacterFactory.Build(def)
	model:PivotTo(beltCFrame(WorldBuilder.BeltStartX, 0))
	model.Parent = parent
	local walker: Walker = { Model = model, Def = def, X = WorldBuilder.BeltStartX, Sold = false }
	local prompt = model:FindFirstChild("ActionPrompt", true) :: ProximityPrompt
	prompt.ActionText = "Beli"
	prompt.ObjectText = def.name .. " " .. CharacterFactory.FormatMoney(def.price)
	prompt.HoldDuration = 0
	prompt.Enabled = true
	prompt.Triggered:Connect(function(player)
		tryBuy(player, walker)
	end)
	table.insert(walkers, walker)
end

function ConveyorService.Start(worldFolder: Instance, notifyFn: (Player, string) -> ())
	notify = notifyFn
	local beltFolder = Instance.new("Folder")
	beltFolder.Name = "OnBelt"
	beltFolder.Parent = worldFolder

	task.spawn(function()
		while true do
			task.wait(ConveyorService.SpawnInterval)
			if #walkers < ConveyorService.MaxOnBelt then
				spawnWalker(beltFolder)
			end
		end
	end)

	-- One movement loop for the whole belt, so walkers keep an even
	-- spacing and every client sees the same ride.
	task.spawn(function()
		local elapsed = 0
		while true do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			for i = #walkers, 1, -1 do
				local walker = walkers[i]
				walker.X += ConveyorService.BeltSpeed * dt
				if walker.X >= WorldBuilder.BeltEndX then
					walker.Model:Destroy()
					table.remove(walkers, i)
				else
					local bob = math.abs(math.sin(elapsed * 8 + walker.X * 0.2)) * 0.3
					walker.Model:PivotTo(beltCFrame(walker.X, bob))
				end
			end
		end
	end)
end

return ConveyorService
