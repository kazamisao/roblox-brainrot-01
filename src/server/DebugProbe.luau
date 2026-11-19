-- DebugProbe: the Build 17 diagnostic layer. The game logic reads
-- correct on disk yet players report an empty world, so this module
-- reads the LIVE state inside a running server -- world part count,
-- plaza and marker positions, avatar positions, and the vertical
-- span of the first belt character -- and pushes a plain-text
-- report to every client every two seconds. It changes nothing in
-- the game; it only looks and reports.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Remotes = require(script.Parent.Remotes)

local DebugProbe = {}

local function fmtVec(v: Vector3): string
	return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
end

local function worldLines(lines: { string })
	local world = Workspace:FindFirstChild("BrainrotWorld")
	if not world then
		table.insert(lines, "WORLD MISSING")
		table.insert(lines, "PLAZA MISSING")
		table.insert(lines, "MARKER MISSING")
		return nil
	end

	local partCount = 0
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end
	table.insert(lines, string.format("WORLD OK parts=%d", partCount))

	local plaza = world:FindFirstChild("Plaza")
	if plaza and plaza:IsA("BasePart") then
		table.insert(lines, string.format("PLAZA pos=%s size=%s",
			fmtVec(plaza.Position), fmtVec(plaza.Size)))
	else
		table.insert(lines, "PLAZA MISSING")
	end

	local marker = world:FindFirstChild("MarkerObelisk")
	if marker and marker:IsA("BasePart") then
		table.insert(lines, string.format("MARKER pos=%s", fmtVec(marker.Position)))
	else
		table.insert(lines, "MARKER MISSING")
	end

	return world
end

local function avatarLines(lines: { string })
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(lines, string.format("AVATAR %s pos=%s",
				player.DisplayName, fmtVec(root.Position)))
		end
	end
end

local function beltLines(lines: { string }, world: Instance?)
	local beltFolder = world and world:FindFirstChild("BeltBrainrots")
	local models = beltFolder and beltFolder:GetChildren() or {}
	table.insert(lines, string.format("BELT models=%d", #models))

	local first = models[1]
	if not first then
		return
	end
	local partCount = 0
	local minBottom = math.huge
	local maxTop = -math.huge
	for _, descendant in first:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
			local bottom = descendant.Position.Y - descendant.Size.Y / 2
			local top = descendant.Position.Y + descendant.Size.Y / 2
			if bottom < minBottom then
				minBottom = bottom
			end
			if top > maxTop then
				maxTop = top
			end
		end
	end
	table.insert(lines, string.format("FIRST %s parts=%d minBottom=%.1f maxTop=%.1f",
		first.Name, partCount, minBottom, maxTop))
end

local function buildReport(): string
	local lines: { string } = {}
	local world = worldLines(lines)
	avatarLines(lines)
	beltLines(lines, world)
	return table.concat(lines, "\n")
end

-- The loop: fire the report to every client each cycle, and print
-- the same text to the server log only every fifth cycle so the
-- log stays readable.
function DebugProbe.Start()
	task.spawn(function()
		local cycle = 0
		while true do
			cycle += 1
			local report = buildReport()
			Remotes.DebugAll(report)
			if cycle % 5 == 0 then
				print(report)
			end
			task.wait(2)
		end
	end)
end

return DebugProbe
