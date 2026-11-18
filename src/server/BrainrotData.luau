-- BrainrotData: the single source of truth for the Warung Brainrot cast.
-- Every character the game can spawn is defined here: its name, rarity,
-- price, income per second, conveyor spawn weight and the colors its
-- blocky model is built from. CharacterFactory reads these definitions;
-- no other module hard-codes a character.

local BrainrotData = {}

export type BrainrotDef = {
	id: string,
	name: string,
	rarity: string,
	rarityColor: Color3,
	price: number,
	rate: number, -- cash per second while placed on a base slot
	weight: number, -- relative conveyor spawn weight (higher = more common)
	build: string, -- which builder CharacterFactory uses
	bodyColor: Color3,
	accentColor: Color3,
	scale: number,
}

BrainrotData.List = {
	{
		id = "kerupuk",
		name = "Kerupuk Terbang",
		rarity = "Common",
		rarityColor = Color3.fromRGB(210, 210, 210),
		price = 25,
		rate = 1,
		weight = 100,
		build = "kerupuk",
		bodyColor = Color3.fromRGB(232, 205, 160),
		accentColor = Color3.fromRGB(255, 246, 220),
		scale = 1,
	},
	{
		id = "esteh",
		name = "Es Teh Raksasa",
		rarity = "Uncommon",
		rarityColor = Color3.fromRGB(90, 210, 120),
		price = 150,
		rate = 4,
		weight = 55,
		build = "esteh",
		bodyColor = Color3.fromRGB(214, 138, 44),
		accentColor = Color3.fromRGB(255, 240, 200),
		scale = 1.15,
	},
	{
		id = "gorengan",
		name = "Gorengan Bernyanyi",
		rarity = "Rare",
		rarityColor = Color3.fromRGB(80, 150, 255),
		price = 600,
		rate = 12,
		weight = 30,
		build = "gorengan",
		bodyColor = Color3.fromRGB(196, 128, 44),
		accentColor = Color3.fromRGB(255, 210, 90),
		scale = 1.1,
	},
	{
		id = "bakso",
		name = "Bakso Meledak",
		rarity = "Epic",
		rarityColor = Color3.fromRGB(175, 90, 255),
		price = 2500,
		rate = 30,
		weight = 16,
		build = "bakso",
		bodyColor = Color3.fromRGB(122, 78, 52),
		accentColor = Color3.fromRGB(255, 120, 60),
		scale = 1.3,
	},
	{
		id = "nasipadang",
		name = "Nasi Padang Terbang",
		rarity = "Legendary",
		rarityColor = Color3.fromRGB(255, 165, 40),
		price = 10000,
		rate = 80,
		weight = 8,
		build = "nasipadang",
		bodyColor = Color3.fromRGB(245, 240, 230),
		accentColor = Color3.fromRGB(60, 140, 60),
		scale = 1.35,
	},
	{
		id = "rendang",
		name = "Rendang Raksasa",
		rarity = "Mythic",
		rarityColor = Color3.fromRGB(255, 70, 100),
		price = 40000,
		rate = 200,
		weight = 4,
		build = "rendang",
		bodyColor = Color3.fromRGB(120, 30, 25),
		accentColor = Color3.fromRGB(255, 80, 60),
		scale = 1.6,
	},
	{
		id = "sateemas",
		name = "Tungku Sate Emas",
		rarity = "Secret",
		rarityColor = Color3.fromRGB(255, 215, 0),
		price = 150000,
		rate = 500,
		weight = 1,
		build = "sateemas",
		bodyColor = Color3.fromRGB(255, 190, 40),
		accentColor = Color3.fromRGB(255, 240, 160),
		scale = 1.5,
	},
} :: { BrainrotDef }

BrainrotData.ById = {} :: { [string]: BrainrotDef }
for _, def in BrainrotData.List do
	BrainrotData.ById[def.id] = def
end

-- Weighted random pick for the conveyor: common faces roll often, the
-- golden Secret almost never does.
function BrainrotData.Roll(rng: Random): BrainrotDef
	local total = 0
	for _, def in BrainrotData.List do
		total += def.weight
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, def in BrainrotData.List do
		acc += def.weight
		if roll <= acc then
			return def
		end
	end
	return BrainrotData.List[1]
end

return BrainrotData
