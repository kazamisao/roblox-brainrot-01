-- BrainrotData: the cast of Brainrot Island. Seven original Indonesian
-- food characters, one per rarity tier, each with a price, a per-second
-- income and a conveyor spawn weight. At night the rare half of the
-- cast (Epic and above) rolls twice as often, so the dark hours are
-- when the belt gets interesting.

local BrainrotData = {}

export type Def = {
	Name: string,
	Rarity: string,
	Price: number,
	PerSec: number,
	Weight: number,
	Color: Color3,
	Accent: Color3?,
	Shape: Enum.PartType,
	BodySize: Vector3,
}

BrainrotData.RarityColors = {
	Common = Color3.fromRGB(235, 235, 235),
	Rare = Color3.fromRGB(90, 200, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 180, 60),
	Mythic = Color3.fromRGB(255, 95, 175),
	Secret = Color3.fromRGB(255, 70, 60),
}

BrainrotData.Cast = {
	{
		Name = "Kancil Ngantuk",
		Rarity = "Common",
		Price = 25,
		PerSec = 1,
		Weight = 40,
		Color = Color3.fromRGB(168, 124, 78),
		Accent = Color3.fromRGB(120, 84, 50),
		Shape = Enum.PartType.Ball,
		BodySize = Vector3.new(2.4, 2.4, 2.4),
	},
	{
		Name = "Kerupuk Terbang",
		Rarity = "Common",
		Price = 75,
		PerSec = 3,
		Weight = 26,
		Color = Color3.fromRGB(233, 203, 141),
		Accent = Color3.fromRGB(198, 158, 92),
		Shape = Enum.PartType.Cylinder,
		BodySize = Vector3.new(3.2, 0.7, 3.2),
	},
	{
		Name = "Sate Berjalan",
		Rarity = "Rare",
		Price = 250,
		PerSec = 8,
		Weight = 16,
		Color = Color3.fromRGB(150, 84, 44),
		Accent = Color3.fromRGB(96, 50, 24),
		Shape = Enum.PartType.Block,
		BodySize = Vector3.new(1.7, 3.6, 1.7),
	},
	{
		Name = "Bakso Raksasa",
		Rarity = "Epic",
		Price = 1000,
		PerSec = 25,
		Weight = 9,
		Color = Color3.fromRGB(146, 108, 82),
		Accent = Color3.fromRGB(104, 74, 52),
		Shape = Enum.PartType.Ball,
		BodySize = Vector3.new(3.6, 3.6, 3.6),
	},
	{
		Name = "Rendang Sakti",
		Rarity = "Legendary",
		Price = 5000,
		PerSec = 80,
		Weight = 5,
		Color = Color3.fromRGB(112, 52, 30),
		Accent = Color3.fromRGB(74, 32, 18),
		Shape = Enum.PartType.Block,
		BodySize = Vector3.new(3.4, 2.3, 3.4),
	},
	{
		Name = "Tungku Sate Emas",
		Rarity = "Mythic",
		Price = 25000,
		PerSec = 220,
		Weight = 3,
		Color = Color3.fromRGB(255, 196, 40),
		Accent = Color3.fromRGB(255, 120, 40),
		Shape = Enum.PartType.Block,
		BodySize = Vector3.new(3.2, 2.7, 3.2),
	},
	{
		Name = "Naga Sambal Legendaris",
		Rarity = "Secret",
		Price = 150000,
		PerSec = 500,
		Weight = 1,
		Color = Color3.fromRGB(214, 44, 40),
		Accent = Color3.fromRGB(255, 140, 40),
		Shape = Enum.PartType.Ball,
		BodySize = Vector3.new(4.4, 4.4, 4.4),
	},
}

BrainrotData.ByName = {}
for _, def in BrainrotData.Cast do
	BrainrotData.ByName[def.Name] = def
end

-- The golden night visitor is always the Mythic.
BrainrotData.GoldenDef = BrainrotData.Cast[6]

local NIGHT_BONUS_RARITIES: { [string]: boolean } = {
	Epic = true,
	Legendary = true,
	Mythic = true,
	Secret = true,
}

local rng = Random.new()

-- Weighted pick from the cast; Epic-and-above weights double at night.
function BrainrotData.Roll(isNight: boolean): Def
	local total = 0
	for _, def in BrainrotData.Cast do
		local w = def.Weight
		if isNight and NIGHT_BONUS_RARITIES[def.Rarity] then
			w *= 2
		end
		total += w
	end
	local roll = rng:NextNumber(0, total)
	for _, def in BrainrotData.Cast do
		local w = def.Weight
		if isNight and NIGHT_BONUS_RARITIES[def.Rarity] then
			w *= 2
		end
		roll -= w
		if roll <= 0 then
			return def
		end
	end
	return BrainrotData.Cast[1]
end

return BrainrotData
