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
		Color = Color3.fromRGB(242, 138, 44),
		Accent = Color3.fromRGB(255, 226, 170),
		Shape = Enum.PartType.Ball,
		BodySize = Vector3.new(3.6, 3.6, 3.6),
	},
	{
		Name = "Kerupuk Terbang",
		Rarity = "Common",
		Price = 75,
		PerSec = 3,
		Weight = 26,
		Color = Color3.fromRGB(255, 196, 64),
		Accent = Color3.fromRGB(232, 116, 28),
		Shape = Enum.PartType.Cylinder,
		BodySize = Vector3.new(4.8, 1.1, 4.8),
	},
	{
		Name = "Sate Berjalan",
		Rarity = "Rare",
		Price = 250,
		PerSec = 8,
		Weight = 16,
		Color = Color3.fromRGB(232, 78, 46),
		Accent = Color3.fromRGB(255, 205, 84),
		Shape = Enum.PartType.Block,
		BodySize = Vector3.new(2.6, 5.4, 2.6),
	},
	{
		Name = "Bakso Raksasa",
		Rarity = "Epic",
		Price = 1000,
		PerSec = 25,
		Weight = 9,
		Color = Color3.fromRGB(240, 112, 92),
		Accent = Color3.fromRGB(255, 224, 188),
		Shape = Enum.PartType.Ball,
		BodySize = Vector3.new(5.4, 5.4, 5.4),
	},
	{
		Name = "Rendang Sakti",
		Rarity = "Legendary",
		Price = 5000,
		PerSec = 80,
		Weight = 5,
		Color = Color3.fromRGB(208, 42, 34),
		Accent = Color3.fromRGB(255, 192, 60),
		Shape = Enum.PartType.Block,
		BodySize = Vector3.new(5.1, 3.5, 5.1),
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
		BodySize = Vector3.new(4.8, 4.1, 4.8),
	},
	{
		Name = "Naga Sambal Legendaris",
		Rarity = "Secret",
		Price = 150000,
		PerSec = 500,
		Weight = 1,
		Color = Color3.fromRGB(238, 38, 32),
		Accent = Color3.fromRGB(255, 164, 40),
		Shape = Enum.PartType.Ball,
		BodySize = Vector3.new(6.6, 6.6, 6.6),
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
