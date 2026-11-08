local Config = require("../src/ReplicatedStorage/AEVUM/Config")
local Cards = require("../src/ReplicatedStorage/AEVUM/CardDatabase").Data
local Match = require("../src/ServerScriptService/AEVUM/Match")
local BotBrain = require("../src/ServerScriptService/AEVUM/BotBrain")
local ProfileSchema = require("../src/ServerScriptService/AEVUM/ProfileSchema")
local Validator = require("../src/ServerScriptService/AEVUM/Validator")

local function makeMatch(clock)
	return Match.new({
		cfg = Config.Match,
		cards = Cards,
		players = {
			{ id = 1, name = "Bot", deck = { "APRENDIZ" } },
			{ id = 2, name = "Rival", deck = { "APRENDIZ" } },
		},
		rand = function(min) return min end,
		clock = clock,
	})
end

local function expect(condition, message)
	if not condition then error(message, 2) end
end

local match = makeMatch(function() return 0 end)
local ally = match.players[1]
local enemy = match.players[2]
ally.combat[1] = { uid = 1, cardId = "GROTO", ownerIdx = 1, damage = 0 }
ally.combat[2] = { uid = 2, cardId = "GROTO", ownerIdx = 1, damage = 0 }
enemy.combat[1] = { uid = 3, cardId = "TITAN", ownerIdx = 2, damage = 2 }
expect(match:effectiveMaxHp(enemy.combat[1]) == 2, "Groto auras should stack on a damaged creature")
match:clampAllDamage()
expect(enemy.combat[1].damage == 1, "Stacked Groto auras should clamp lethal damage")

enemy.bench[1] = { uid = 4, cardId = "ESPORA", ownerIdx = 2, damage = 0 }
match:tryDeathFromEffect(2, "Bench", 1, 1)
expect(ally.combat[1].atkModifiers == nil, "Spell kills should not apply ReduceAtk onDeath without a combat pair")

Cards.TEST_REDUCE_MAX = {
	id = "TEST_REDUCE_MAX", name = "Test Reducer", type = "Creature", hp = 2,
	onDeath = { kind = "ReduceMaxHp", amount = 1 },
}
enemy.bench[1] = { uid = 5, cardId = "TEST_REDUCE_MAX", ownerIdx = 2, damage = 0 }
match:tryDeathFromEffect(2, "Bench", 1, 1)
expect(ally.combat[1].hpModifiers == nil, "Spell kills should not apply ReduceMaxHp onDeath without a combat pair")

enemy.bench[1] = { uid = 5, cardId = "ASALTANTE", ownerIdx = 2, damage = 0 }
local damageBeforeArea = ally.combat[1].damage
match:tryDeathFromEffect(2, "Bench", 1, 1)
expect(ally.combat[1].damage == damageBeforeArea + 1, "AreaDamage onDeath should still trigger for spell kills")

local fastView = {
	you = 1,
	attackerIdx = 2,
	waiting = { player = 1, kind = "AttackResponse" },
	activatable = {
		{ slot = 1, targets = { { side = "Enemy", zone = "Combat", slot = 1 } } },
	},
	me = {
		bench = { { uid = 6, cardId = "LIANA" } },
		combat = {},
		hand = {},
		energy = 0,
		evolutions = 0,
	},
	opp = {
		combat = { { uid = 7, cardId = "CAZADOR", attacking = true } },
	},
	attack = { attackers = { 7 }, blocks = {} },
}
local fastAction = BotBrain.decide(fastView, Cards, Config.Match)
expect(fastAction.type == "ActivateFast" and fastAction.slot == 1,
	"Bot should use Liana against an attacker during AttackResponse")

fastView.activatable = {
	{ slot = 1, targets = { { side = "Self", zone = "Avatar", slot = 0 } } },
}
fastView.me.bench[1] = { uid = 6, cardId = "BARRERA" }
expect(BotBrain.decide(fastView, Cards, Config.Match).type == "Pass",
	"Bot should save avatar shield until block assignments are known")
fastView.waiting.kind = "FastWindow"
local shieldAction = BotBrain.decide(fastView, Cards, Config.Match)
expect(shieldAction.type == "ActivateFast" and shieldAction.target.zone == "Avatar",
	"Bot should shield its avatar from an unblocked attack")

local evolveView = {
	waiting = { player = 1, kind = "AttackEvolve" },
	evolveOpen = true,
	me = {
		evolutions = 0,
		energy = 2,
		hand = { { uid = 8, cardId = "HEROE", cost = 2 } },
		combat = { { uid = 9, cardId = "APRENDIZ" } },
	},
}
local evolveAction = BotBrain.decide(evolveView, Cards, Config.Match)
expect(evolveAction.type == "Evolve" and evolveAction.form == 8 and evolveAction.target == 9,
	"Bot should evolve an eligible creature during AttackEvolve")

local now = 0
local clockMatch = makeMatch(function() return now end)
clockMatch:setWaiting(1, "Actions")
clockMatch.waiting.deadline = 10
now = 9
expect(not clockMatch:isExpired(), "Injected match clock should not expire early")
now = 10
expect(clockMatch:isExpired(), "Injected match clock should expire at the deadline")

local defaults = { Collection = { APRENDIZ = 2 }, Deck = { "APRENDIZ" } }
local legacyProfile = { Collection = {}, Deck = {} }
ProfileSchema.migrate(legacyProfile, 2, defaults)
expect(legacyProfile.Version == 2 and legacyProfile.Collection.APRENDIZ == 2 and #legacyProfile.Deck == 1,
	"Unversioned empty profiles should receive starter data during migration")

local existingProfile = { Version = 1, Collection = { APRENDIZ = 7 }, Deck = { "APRENDIZ", "TITAN" } }
ProfileSchema.migrate(existingProfile, 2, defaults)
expect(existingProfile.Version == 2 and existingProfile.Collection.APRENDIZ == 7 and #existingProfile.Deck == 2,
	"Profile migration should preserve existing collection and deck data")

expect(Validator.lobby({ type = "DebugPause" }) == nil, "DebugPause should be rejected unless explicitly enabled")
expect(Validator.lobby({ type = "DebugPause" }, true).type == "DebugPause",
	"DebugPause should remain available when the server explicitly enables it")

print("AEVUM Match tests passed")
