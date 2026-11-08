--!nonstrict
-- AEVUM · Reglas de partida (v1.3.0)

local Config = {}

Config.Match = {
	AvatarHealth = 20,
	DeckSize = 40,
	MaxCopies = 2,
	MaxLegendaryCopies = 1,
	StartingHand = 5,
	HandLimit = 8,
	GuaranteeLowCostCreature = true,
	LowCostMax = 2,

	MaxEnergy = 6,
	MaxReserve = 2,
	MaxCostReduction = 1,
	MinCost = 1,

	BenchSlots = 5,
	CombatSlots = 5,

	FirstAttackTurn = 3,
	FirstEvolveTurn = 3,
	EvolutionsPerTurn = 1,
	EvolveHeal = 2,
	MaxEmergentBlockers = 2,

	ActionTimeSeconds = 30,
	MaxMatchSeconds = 1800,

	AutoSkipEmptyWindows = true,
	AutoPassWhenNoActions = true,
}

Config.Sounds = {
	Select = "rbxassetid://74677332039786",
	Deselect = "rbxassetid://95511902174465",
	BlockKill = "rbxassetid://94408979417525",
	Overkill = "rbxassetid://95221069837224",
	Volume = 0.6,
}

return Config
