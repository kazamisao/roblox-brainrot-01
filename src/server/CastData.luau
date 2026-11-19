-- CastData: the eight brainrot characters of Brainrot Island BARU,
-- defined as pure data. Every character is a stack of boxes (with an
-- occasional ball or cylinder for silhouette) authored around one
-- shared convention: the character origin is the BOTTOM CENTER of
-- the character, the point between its feet. Each box lists the size
-- of the part, the offset of the part's center from that origin, and
-- its color. A box whose lowest point must touch the ground simply
-- has Offset.Y equal to half its height, so the whole cast stands on
-- the origin plane and placement math stays trivially auditable:
-- a character placed at floor point P has every part at P + offset.
--
-- Optional box fields:
--   Shape   -- Enum.PartType.Ball or .Cylinder (default Block)
--   RotY    -- yaw in degrees baked into the part's local frame
--   RotZ    -- roll in degrees; a cylinder lying with its length on
--              X stands upright when rolled 90 degrees around Z
--   Neon    -- use the Neon material
--   Rainbow -- the part joins the hue cycle (the Secret fridge)

local CastData = {}

CastData.RarityColors = {
	Common = Color3.fromRGB(205, 205, 210),
	Rare = Color3.fromRGB(85, 170, 255),
	Epic = Color3.fromRGB(185, 95, 255),
	Legendary = Color3.fromRGB(255, 185, 45),
	Mythic = Color3.fromRGB(255, 85, 185),
	Secret = Color3.fromRGB(255, 105, 80),
}

-- Relative spawn weights when the conveyor rolls a rarity.
CastData.RarityWeights = {
	Common = 55,
	Rare = 27,
	Epic = 11,
	Legendary = 4.5,
	Mythic = 1.8,
	Secret = 0.7,
}

local function box(size: Vector3, offset: Vector3, color: Color3, extra: { [string]: any }?): { [string]: any }
	local b: { [string]: any } = { Size = size, Offset = offset, Color = color }
	if extra then
		for k, v in extra do
			b[k] = v
		end
	end
	return b
end

CastData.List = {
	{
		Name = "Skibidi Toilet Pak RT",
		Rarity = "Common",
		Price = 0,
		PerSec = 1,
		Boxes = {
			box(Vector3.new(2.6, 0.4, 2.6), Vector3.new(0, 0.2, 0), Color3.fromRGB(198, 198, 205)),
			box(Vector3.new(1.9, 1.0, 2.1), Vector3.new(0, 0.9, 0.1), Color3.fromRGB(245, 245, 240)),
			box(Vector3.new(2.0, 0.18, 2.2), Vector3.new(0, 1.45, 0.1), Color3.fromRGB(90, 160, 255)),
			box(Vector3.new(1.9, 1.5, 0.55), Vector3.new(0, 1.6, -0.95), Color3.fromRGB(245, 245, 240)),
			box(Vector3.new(1.15, 1.15, 1.15), Vector3.new(0, 2.15, 0.15), Color3.fromRGB(255, 204, 153), { Shape = Enum.PartType.Ball }),
			box(Vector3.new(1.25, 0.3, 1.25), Vector3.new(0, 2.65, 0.15), Color3.fromRGB(30, 30, 35)),
		},
	},
	{
		Name = "Tung Tung Sahur",
		Rarity = "Common",
		Price = 50,
		PerSec = 3,
		Boxes = {
			box(Vector3.new(2.7, 1.25, 1.25), Vector3.new(0, 1.35, 0), Color3.fromRGB(150, 105, 60), { Shape = Enum.PartType.Cylinder, RotZ = 90 }),
			box(Vector3.new(1.05, 1.05, 1.05), Vector3.new(0, 3.05, 0), Color3.fromRGB(190, 140, 85), { Shape = Enum.PartType.Ball }),
			box(Vector3.new(0.35, 1.3, 0.35), Vector3.new(-0.85, 1.7, 0), Color3.fromRGB(120, 82, 45)),
			box(Vector3.new(0.35, 1.3, 0.35), Vector3.new(0.85, 1.7, 0), Color3.fromRGB(120, 82, 45)),
			box(Vector3.new(0.9, 0.9, 0.9), Vector3.new(0.95, 0.45, 0.55), Color3.fromRGB(170, 60, 50)),
		},
	},
	{
		Name = "Tralalero Tralala",
		Rarity = "Rare",
		Price = 250,
		PerSec = 12,
		Boxes = {
			box(Vector3.new(0.4, 0.9, 0.4), Vector3.new(-0.45, 0.45, 0.5), Color3.fromRGB(50, 110, 190)),
			box(Vector3.new(0.4, 0.9, 0.4), Vector3.new(0.45, 0.45, 0.5), Color3.fromRGB(50, 110, 190)),
			box(Vector3.new(0.4, 0.9, 0.4), Vector3.new(-0.45, 0.45, -0.9), Color3.fromRGB(50, 110, 190)),
			box(Vector3.new(0.4, 0.9, 0.4), Vector3.new(0.45, 0.45, -0.9), Color3.fromRGB(50, 110, 190)),
			box(Vector3.new(0.5, 0.3, 1.0), Vector3.new(-0.45, 0.15, 0.65), Color3.fromRGB(250, 250, 250)),
			box(Vector3.new(0.5, 0.3, 1.0), Vector3.new(0.45, 0.15, 0.65), Color3.fromRGB(250, 250, 250)),
			box(Vector3.new(1.5, 1.3, 3.4), Vector3.new(0, 1.55, 0), Color3.fromRGB(70, 140, 220)),
			box(Vector3.new(1.1, 0.7, 0.9), Vector3.new(0, 1.45, 2.05), Color3.fromRGB(110, 175, 240)),
			box(Vector3.new(0.18, 0.9, 1.0), Vector3.new(0, 2.6, -0.2), Color3.fromRGB(40, 95, 170)),
			box(Vector3.new(0.18, 1.1, 0.9), Vector3.new(0, 1.9, -2.0), Color3.fromRGB(40, 95, 170)),
		},
	},
	{
		Name = "Bombardiro Crocodilo",
		Rarity = "Rare",
		Price = 900,
		PerSec = 40,
		Boxes = {
			box(Vector3.new(0.35, 0.7, 0.35), Vector3.new(-0.55, 0.35, 1.1), Color3.fromRGB(55, 110, 50)),
			box(Vector3.new(0.35, 0.7, 0.35), Vector3.new(0.55, 0.35, 1.1), Color3.fromRGB(55, 110, 50)),
			box(Vector3.new(0.35, 0.7, 0.35), Vector3.new(-0.55, 0.35, -1.1), Color3.fromRGB(55, 110, 50)),
			box(Vector3.new(0.35, 0.7, 0.35), Vector3.new(0.55, 0.35, -1.1), Color3.fromRGB(55, 110, 50)),
			box(Vector3.new(1.5, 1.1, 3.8), Vector3.new(0, 1.15, 0), Color3.fromRGB(80, 150, 70)),
			box(Vector3.new(1.2, 0.6, 1.3), Vector3.new(0, 0.95, 2.4), Color3.fromRGB(110, 180, 90)),
			box(Vector3.new(1.1, 0.25, 0.3), Vector3.new(0, 0.7, 2.9), Color3.fromRGB(250, 250, 250)),
			box(Vector3.new(4.6, 0.16, 1.0), Vector3.new(0, 1.95, -0.2), Color3.fromRGB(150, 155, 165)),
			box(Vector3.new(0.25, 1.7, 0.18), Vector3.new(0, 1.0, 3.15), Color3.fromRGB(60, 60, 68)),
			box(Vector3.new(1.0, 0.7, 1.2), Vector3.new(0, 1.3, -2.3), Color3.fromRGB(80, 150, 70)),
		},
	},
	{
		Name = "Brr Brr Patapim",
		Rarity = "Epic",
		Price = 3000,
		PerSec = 130,
		Boxes = {
			box(Vector3.new(1.1, 0.5, 1.6), Vector3.new(-0.7, 0.25, 0.2), Color3.fromRGB(95, 65, 38)),
			box(Vector3.new(1.1, 0.5, 1.6), Vector3.new(0.7, 0.25, 0.2), Color3.fromRGB(95, 65, 38)),
			box(Vector3.new(3.0, 1.7, 1.7), Vector3.new(0, 2.0, 0), Color3.fromRGB(120, 85, 50), { Shape = Enum.PartType.Cylinder, RotZ = 90 }),
			box(Vector3.new(3.0, 2.6, 3.0), Vector3.new(0, 4.3, 0), Color3.fromRGB(60, 160, 70), { Shape = Enum.PartType.Ball }),
			box(Vector3.new(0.45, 0.45, 1.8), Vector3.new(0, 2.9, 1.5), Color3.fromRGB(200, 170, 120)),
			box(Vector3.new(0.35, 1.6, 0.35), Vector3.new(-1.05, 2.6, 0), Color3.fromRGB(120, 85, 50)),
			box(Vector3.new(0.35, 1.6, 0.35), Vector3.new(1.05, 2.6, 0), Color3.fromRGB(120, 85, 50)),
		},
	},
	{
		Name = "Lirili Larila",
		Rarity = "Legendary",
		Price = 10000,
		PerSec = 450,
		Boxes = {
			box(Vector3.new(0.55, 1.0, 0.55), Vector3.new(-0.8, 0.5, 0.8), Color3.fromRGB(50, 130, 60)),
			box(Vector3.new(0.55, 1.0, 0.55), Vector3.new(0.8, 0.5, 0.8), Color3.fromRGB(50, 130, 60)),
			box(Vector3.new(0.55, 1.0, 0.55), Vector3.new(-0.8, 0.5, -0.8), Color3.fromRGB(50, 130, 60)),
			box(Vector3.new(0.55, 1.0, 0.55), Vector3.new(0.8, 0.5, -0.8), Color3.fromRGB(50, 130, 60)),
			box(Vector3.new(2.6, 2.3, 2.6), Vector3.new(0, 2.15, 0), Color3.fromRGB(70, 170, 80)),
			box(Vector3.new(1.5, 1.3, 1.5), Vector3.new(0, 3.2, 1.2), Color3.fromRGB(90, 190, 95)),
			box(Vector3.new(0.5, 1.6, 0.5), Vector3.new(0, 2.2, 2.0), Color3.fromRGB(70, 170, 80)),
			box(Vector3.new(0.2, 1.3, 1.1), Vector3.new(-1.05, 3.3, 1.1), Color3.fromRGB(240, 180, 200)),
			box(Vector3.new(0.2, 1.3, 1.1), Vector3.new(1.05, 3.3, 1.1), Color3.fromRGB(240, 180, 200)),
			box(Vector3.new(0.18, 0.4, 0.18), Vector3.new(-0.6, 3.5, -0.5), Color3.fromRGB(250, 250, 250)),
			box(Vector3.new(0.18, 0.4, 0.18), Vector3.new(0, 3.5, -0.5), Color3.fromRGB(250, 250, 250)),
			box(Vector3.new(0.18, 0.4, 0.18), Vector3.new(0.6, 3.5, -0.5), Color3.fromRGB(250, 250, 250)),
		},
	},
	{
		Name = "Bombombini Gusini",
		Rarity = "Mythic",
		Price = 40000,
		PerSec = 1800,
		Boxes = {
			box(Vector3.new(0.3, 0.8, 0.3), Vector3.new(-0.4, 0.4, 0.3), Color3.fromRGB(255, 150, 40)),
			box(Vector3.new(0.3, 0.8, 0.3), Vector3.new(0.4, 0.4, 0.3), Color3.fromRGB(255, 150, 40)),
			box(Vector3.new(0.4, 0.15, 0.8), Vector3.new(-0.4, 0.075, 0.45), Color3.fromRGB(255, 150, 40)),
			box(Vector3.new(0.4, 0.15, 0.8), Vector3.new(0.4, 0.075, 0.45), Color3.fromRGB(255, 150, 40)),
			box(Vector3.new(1.7, 1.5, 2.8), Vector3.new(0, 1.55, 0), Color3.fromRGB(245, 245, 245)),
			box(Vector3.new(0.55, 1.3, 0.55), Vector3.new(0, 2.6, 1.15), Color3.fromRGB(245, 245, 245)),
			box(Vector3.new(0.85, 0.75, 1.0), Vector3.new(0, 3.45, 1.3), Color3.fromRGB(245, 245, 245)),
			box(Vector3.new(0.5, 0.3, 0.8), Vector3.new(0, 3.35, 2.1), Color3.fromRGB(255, 150, 40)),
			box(Vector3.new(4.8, 0.16, 1.1), Vector3.new(0, 2.2, -0.3), Color3.fromRGB(160, 165, 175)),
			box(Vector3.new(1.4, 0.55, 0.55), Vector3.new(-0.7, 1.5, -1.8), Color3.fromRGB(70, 70, 80), { Shape = Enum.PartType.Cylinder, RotY = 90 }),
			box(Vector3.new(1.4, 0.55, 0.55), Vector3.new(0.7, 1.5, -1.8), Color3.fromRGB(70, 70, 80), { Shape = Enum.PartType.Cylinder, RotY = 90 }),
			box(Vector3.new(0.16, 0.9, 0.8), Vector3.new(0, 2.6, -1.5), Color3.fromRGB(160, 165, 175)),
		},
	},
	{
		Name = "Frigo Camelo",
		Rarity = "Secret",
		Price = 250000,
		PerSec = 9000,
		Boxes = {
			box(Vector3.new(0.5, 0.9, 0.5), Vector3.new(-0.85, 0.45, 0.55), Color3.fromRGB(195, 160, 105)),
			box(Vector3.new(0.5, 0.9, 0.5), Vector3.new(0.85, 0.45, 0.55), Color3.fromRGB(195, 160, 105)),
			box(Vector3.new(0.5, 0.9, 0.5), Vector3.new(-0.85, 0.45, -0.55), Color3.fromRGB(195, 160, 105)),
			box(Vector3.new(0.5, 0.9, 0.5), Vector3.new(0.85, 0.45, -0.55), Color3.fromRGB(195, 160, 105)),
			box(Vector3.new(2.4, 3.1, 1.7), Vector3.new(0, 2.45, 0), Color3.fromRGB(210, 230, 240), { Rainbow = true }),
			box(Vector3.new(2.0, 2.7, 0.15), Vector3.new(0, 2.45, 0.92), Color3.fromRGB(225, 240, 248), { Rainbow = true }),
			box(Vector3.new(0.18, 1.1, 0.18), Vector3.new(0.8, 2.6, 1.05), Color3.fromRGB(140, 145, 155)),
			box(Vector3.new(0.6, 1.3, 0.6), Vector3.new(0, 4.35, 0.55), Color3.fromRGB(195, 160, 105)),
			box(Vector3.new(0.95, 0.75, 1.35), Vector3.new(0, 5.15, 0.85), Color3.fromRGB(195, 160, 105)),
			box(Vector3.new(0.6, 0.5, 0.7), Vector3.new(0, 5.0, 1.8), Color3.fromRGB(215, 182, 125)),
			box(Vector3.new(0.25, 0.4, 0.25), Vector3.new(-0.4, 5.65, 0.7), Color3.fromRGB(195, 160, 105)),
			box(Vector3.new(0.25, 0.4, 0.25), Vector3.new(0.4, 5.65, 0.7), Color3.fromRGB(195, 160, 105)),
		},
	},
}

CastData.ByName = {}
CastData.ByRarity = {}
for _, def in CastData.List do
	CastData.ByName[def.Name] = def
	local bucket = CastData.ByRarity[def.Rarity]
	if not bucket then
		bucket = {}
		CastData.ByRarity[def.Rarity] = bucket
	end
	table.insert(bucket, def)
end

function CastData.Get(name: string)
	return CastData.ByName[name]
end

-- Weighted rarity roll, then a uniform pick inside that rarity.
function CastData.Roll()
	local total = 0
	for _, w in CastData.RarityWeights do
		total += w
	end
	local needle = math.random() * total
	local chosen = "Common"
	for rarity, w in CastData.RarityWeights do
		needle -= w
		if needle <= 0 then
			chosen = rarity
			break
		end
	end
	local bucket = CastData.ByRarity[chosen]
	return bucket[math.random(1, #bucket)]
end

return CastData
