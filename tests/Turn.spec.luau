-- Textos de la tarjeta de turno (lógica pura).
local TurnCard = require("../src/StarterPlayerScripts/AEVUM/UI/TurnCard")

local function expect(c, m) if not c then error(m, 2) end end

local function full(attackerIdx, attackOpen)
	return TurnCard.texts({ attackerIdx = attackerIdx, you = 1, attackOpen = attackOpen }).full
end

expect(full(1, false) == "Tu turno", "mío, sin ataque: " .. full(1, false))
expect(full(1, true) == "Tu turno ¡Al ataque!", "mío, con ataque: " .. full(1, true))
expect(full(2, false) == "Turno enemigo", "rival, sin ataque: " .. full(2, false))
expect(full(2, true) == "Turno enemigo ¡A defender!", "rival, con ataque: " .. full(2, true))
expect(TurnCard.texts({ attackerIdx = 1, you = 1, attackOpen = true }).mine == true, "mine = true en mi turno")
expect(TurnCard.texts({ attackerIdx = 2, you = 1, attackOpen = false }).mine == false, "mine = false en el del rival")
expect(TurnCard.TOTAL >= 1.5 and TurnCard.TOTAL <= 2.5, "dura ~2 s")
expect(TurnCard.REST_X < 0.835, "queda a la izquierda de la columna derecha")

print("Turn.spec OK")
