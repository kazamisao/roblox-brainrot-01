-- Gameplay: all the wiring that turns WorldBuilder's static world
-- into the obby game — leaderstats (Aura + Stage), checkpoint saves
-- and respawns, kill bricks and lava, collectible Aura orbs that
-- respawn after 20 s, the finish pad jackpot, and a fall safety net.
-- Everything arrives as references from WorldBuilder.Build(); this
-- module never builds world geometry itself (except replacement
-- orbs, which go through WorldBuilder.CreateOrb).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.WorldBuilder)

local Gameplay = {}

local ORB_RESPAWN_SECONDS = 20
local FINISH_DEBOUNCE_SECONDS = 5

function Gameplay.Start(refs)
	-- The one remote the client HUD listens to.
	local toast = Instance.new("RemoteEvent")
	toast.Name = "ObbyToast"
	toast.Parent = ReplicatedStorage

	local function sendToast(player: Player, text: string)
		toast:FireClient(player, text)
	end

	-- Per-player run state, cleared on PlayerRemoving.
	local savedStage: { [Player]: number } = {}
	local savedCFrame: { [Player]: CFrame } = {}
	local lastFinishAt: { [Player]: number } = {}

	local function statsOf(player: Player): (IntValue?, IntValue?)
		local stats = player:FindFirstChild("leaderstats")
		if not stats then
			return nil, nil
		end
		return stats:FindFirstChild("Aura") :: IntValue?, stats:FindFirstChild("Stage") :: IntValue?
	end

	local function addAura(player: Player, amount: number)
		local aura = statsOf(player)
		if aura then
			aura.Value += amount
		end
	end

	local function setStage(player: Player, stage: number)
		local _, stageValue = statsOf(player)
		if stageValue then
			stageValue.Value = stage
		end
	end

	--------------------------------------------------------------
	-- Players: leaderstats, checkpoint respawn, cleanup.
	--------------------------------------------------------------
	local function onCharacterAdded(player: Player, character: Model)
		local cf = savedCFrame[player]
		if not cf then
			return
		end
		task.spawn(function()
			task.wait(0.3)
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and character.Parent then
				hrp.CFrame = cf + Vector3.new(0, 3, 0)
			end
		end)
	end

	local function onPlayerAdded(player: Player)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"

		local aura = Instance.new("IntValue")
		aura.Name = "Aura"
		aura.Value = 0
		aura.Parent = stats

		local stage = Instance.new("IntValue")
		stage.Name = "Stage"
		stage.Value = 1
		stage.Parent = stats

		stats.Parent = player

		savedStage[player] = 0

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		savedStage[player] = nil
		savedCFrame[player] = nil
		lastFinishAt[player] = nil
	end)

	--------------------------------------------------------------
	-- Checkpoints: touching a pad beyond your saved stage saves
	-- it as your respawn point.
	--------------------------------------------------------------
	for _, cp in refs.Checkpoints do
		cp.Pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			if cp.Stage <= (savedStage[player] or 0) then
				return
			end
			savedStage[player] = cp.Stage
			savedCFrame[player] = cp.Pad.CFrame
			setStage(player, cp.Stage)
			sendToast(player, string.format("Checkpoint! Stage %d — %s", cp.Stage, cp.Name))
		end)
	end

	--------------------------------------------------------------
	-- Kill parts: kill bricks and the lava plane.
	--------------------------------------------------------------
	for _, killPart in refs.KillParts do
		killPart.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end)
	end

	--------------------------------------------------------------
	-- Orbs: +10 Aura on touch, then a fresh orb at home in 20 s.
	--------------------------------------------------------------
	local function wireOrb(orbData)
		local orb = orbData.Part
		local collected = false
		orb.Touched:Connect(function(hit)
			if collected then
				return
			end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			collected = true
			addAura(player, 10)
			sendToast(player, "+10 Aura")
			orb:Destroy()
			task.delay(ORB_RESPAWN_SECONDS, function()
				local fresh = WorldBuilder.CreateOrb(refs.OrbFolder, orbData.CFrame, orbData.Color)
				orbData.Part = fresh
				wireOrb(orbData)
			end)
		end)
	end
	for _, orbData in refs.Orbs do
		wireOrb(orbData)
	end

	--------------------------------------------------------------
	-- Finish pad: +500 Aura, Stage 999, back to the lobby.
	--------------------------------------------------------------
	refs.FinishPad.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastFinishAt[player] or -math.huge) < FINISH_DEBOUNCE_SECONDS then
			return
		end
		lastFinishAt[player] = now

		addAura(player, 500)
		setStage(player, 999)
		sendToast(player, "FINISH! +500 Aura — kamu TAMAT!")
		-- A fresh run starts from the lobby again.
		savedStage[player] = 0
		savedCFrame[player] = nil

		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.CFrame = refs.SpawnCFrame + Vector3.new(0, 3, 0)
		end
	end)

	--------------------------------------------------------------
	-- Safety net: anyone who somehow falls past the lava dies.
	--------------------------------------------------------------
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if hrp and hrp.Position.Y < -20 then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						humanoid.Health = 0
					end
				end
			end
		end
	end)

	print("[Gameplay] Obby gameplay wired")
end

return Gameplay
