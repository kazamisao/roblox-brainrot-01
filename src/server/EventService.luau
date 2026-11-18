-- EventService: "Hujan Meteor Sambal", the plaza-wide event. Every 90
-- seconds the sky warns for 10 seconds, then for 20 seconds flaming
-- chili meteors rain around the conveyor and the bases. Touching a
-- landed meteor pays a cash bonus; a meteor landing next to a thief
-- carrying a stolen brainrot knocks the catch loose, and it walks home.

local PlayerState = require(script.Parent.PlayerState)
local StealService = require(script.Parent.StealService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local EventService = {}

EventService.PeriodSeconds = 90
EventService.WarnSeconds = 10
EventService.ActiveSeconds = 20
EventService.BonusCash = 50
EventService.DropRadius = 6.5

local phase = "calm" -- "calm" | "warn" | "active"
local phaseEndsAt = os.clock() + (EventService.PeriodSeconds - EventService.WarnSeconds - EventService.ActiveSeconds)
local notifyAll: (string) -> () = function() end
local rng = Random.new()
local meteorsFolder: Folder? = nil

function EventService.GetStatus(): { Phase: string, SecondsLeft: number }
	return {
		Phase = phase,
		SecondsLeft = math.max(0, math.ceil(phaseEndsAt - os.clock())),
	}
end

local function dropCarriersNear(point: Vector3)
	for player, record in PlayerState.Records do
		if record.Carrying then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local flat = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
				local at = Vector3.new(point.X, 0, point.Z)
				if (flat - at).Magnitude <= EventService.DropRadius then
					StealService.DropCarry(player, "meteor")
				end
			end
		end
	end
end

local function spawnMeteor()
	if not meteorsFolder then
		return
	end
	local x = rng:NextNumber(-58, 58)
	local z = rng:NextNumber(-34, 34)
	local target = Vector3.new(x, WorldBuilder.FloorTop + 1.1, z)
	local meteor = Instance.new("Part")
	meteor.Name = "MeteorSambal"
	meteor.Shape = Enum.PartType.Ball
	meteor.Size = Vector3.new(2.2, 2.2, 2.2)
	meteor.Color = Color3.fromRGB(255, 90, 40)
	meteor.Material = Enum.Material.Neon
	meteor.Anchored = true
	meteor.CanCollide = false
	meteor.CFrame = CFrame.new(x, 62, z)
	meteor.Parent = meteorsFolder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 50)
	light.Range = 12
	light.Brightness = 2
	light.Parent = meteor

	task.spawn(function()
		-- Fall for just under a second, trailing down to the plaza.
		local startPos = meteor.Position
		local duration = 0.9
		local elapsed = 0
		while elapsed < duration and meteor.Parent do
			local dt = task.wait()
			elapsed += dt
			local t = math.min(1, elapsed / duration)
			meteor.CFrame = CFrame.new(startPos:Lerp(target, t * t))
		end
		if not meteor.Parent then
			return
		end
		meteor.CFrame = CFrame.new(target)
		dropCarriersNear(target)
		-- Landed: collectible for a few seconds, then it burns out.
		local collected = false
		local conn: RBXScriptConnection? = nil
		conn = meteor.Touched:Connect(function(hit)
			if collected then
				return
			end
			local character = hit.Parent
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				return
			end
			local player = game:GetService("Players"):GetPlayerFromCharacter(character)
			local record = player and PlayerState.Records[player]
			if not record then
				return
			end
			collected = true
			local bonus = math.floor(EventService.BonusCash * PlayerState.Multiplier(record))
			PlayerState.AddCash(record, bonus)
			if conn then
				conn:Disconnect()
			end
			meteor:Destroy()
		end)
		task.wait(6)
		if conn then
			conn:Disconnect()
		end
		if meteor.Parent then
			meteor:Destroy()
		end
	end)
end

function EventService.Start(worldFolder: Instance, notifyAllFn: (string) -> ())
	notifyAll = notifyAllFn
	local folder = Instance.new("Folder")
	folder.Name = "Meteors"
	folder.Parent = worldFolder
	meteorsFolder = folder

	task.spawn(function()
		while true do
			-- Calm: the HUD counts down to the warning.
			phase = "calm"
			phaseEndsAt = os.clock() + (EventService.PeriodSeconds - EventService.WarnSeconds - EventService.ActiveSeconds)
			task.wait(EventService.PeriodSeconds - EventService.WarnSeconds - EventService.ActiveSeconds)

			phase = "warn"
			phaseEndsAt = os.clock() + EventService.WarnSeconds
			notifyAll("Langit memerah... HUJAN METEOR SAMBAL sebentar lagi!")
			task.wait(EventService.WarnSeconds)

			phase = "active"
			phaseEndsAt = os.clock() + EventService.ActiveSeconds
			notifyAll("HUJAN METEOR SAMBAL! Sentuh meteor untuk bonus, jaga bawaanmu!")
			local activeUntil = os.clock() + EventService.ActiveSeconds
			while os.clock() < activeUntil do
				spawnMeteor()
				task.wait(0.65)
			end
		end
	end)
end

return EventService
