-- Mover: the ONLY code in the game allowed to move a character.
-- A character entry carries two things that matter here:
--   entry.Locals    -- a map from each Part to the local CFrame the
--                      factory authored for it, relative to the
--                      character origin (bottom center, at the feet)
--   entry.Placement -- the world CFrame of that origin right now
-- Moving a character means choosing a new placement and re-applying
-- it: every part's world CFrame becomes placement * local. There is
-- deliberately no other mechanism -- no model-level transform API
-- is touched anywhere in this project -- so a character can never
-- drift away from the arithmetic written in CastData.

local Mover = {}

-- Re-apply a placement: stamp every part at placement * its local.
function Mover.Apply(entry, placement: CFrame)
	entry.Placement = placement
	for part, localCf in entry.Locals do
		part.CFrame = placement * localCf
	end
end

-- The rotation half of the entry's current placement, kept so a
-- glide can travel without changing where the character faces.
local function facingOf(entry): CFrame
	local cf = entry.Placement
	return cf - cf.Position
end

-- Glide the character's origin to targetPos over `seconds`, arcing
-- through a small hop in the middle, then fire `done`. Each glide
-- takes a fresh token; starting a new glide (or destroying the
-- entry) invalidates the old one, so two glides can never fight
-- over the same parts.
function Mover.Glide(entry, targetPos: Vector3, seconds: number, done: (() -> ())?)
	entry.GlideToken += 1
	local token = entry.GlideToken
	task.spawn(function()
		if not entry.Alive then
			return
		end
		local facing = facingOf(entry)
		local startPos = entry.Placement.Position
		local elapsed = 0
		while elapsed < seconds do
			local dt = task.wait()
			if not entry.Alive or entry.GlideToken ~= token then
				return
			end
			elapsed += dt
			local t = math.min(1, elapsed / seconds)
			local pos = startPos:Lerp(targetPos, t)
			pos = Vector3.new(pos.X, pos.Y + math.sin(t * math.pi) * 1.5, pos.Z)
			Mover.Apply(entry, CFrame.new(pos) * facing)
		end
		if not entry.Alive or entry.GlideToken ~= token then
			return
		end
		Mover.Apply(entry, CFrame.new(targetPos) * facing)
		if done then
			done()
		end
	end)
end

-- Cancel any glide in flight without starting a new one.
function Mover.Stop(entry)
	entry.GlideToken += 1
end

return Mover
