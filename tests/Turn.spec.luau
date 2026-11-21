-- Textos de la tarjeta de turno (lógica pura).
local TurnCard = require("../src/StarterPlayerScripts/AEVUM/UI/TurnCard")
local Timer = require("../src/StarterPlayerScripts/AEVUM/UI/Timer")

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

-- Cronómetro: el tiempo es de quien tiene la prioridad
local function view(o)
	local v = { you = 1, over = false, paused = false, waiting = { player = 1, timeLeft = 30 } }
	for k, val in pairs(o or {}) do v[k] = val end
	return v
end
local st = Timer.state(view(), 100, 100)
expect(st.mode == "normal" and st.seconds == 30 and st.mine, "tu prioridad: normal, 30 s")
st = Timer.state(view(), 112.2, 100)
expect(st.seconds == 18, "descuenta lo transcurrido desde que llegó la vista (redondeo hacia arriba): " .. st.seconds)
st = Timer.state(view(), 100, 100)
expect(Timer.state(view({ waiting = { player = 1, timeLeft = 5 } }), 100, 100).mode == "urgent", "últimos 5 s: urgente")
expect(Timer.state(view({ waiting = { player = 1, timeLeft = 6 } }), 100, 100).mode == "normal", "6 s todavía no es urgente")
st = Timer.state(view({ waiting = { player = 2, timeLeft = 3 } }), 100, 100)
expect(st.mode == "dim" and st.seconds == 3 and not st.mine, "prioridad del rival: sigue contando, atenuado, sin alarma")
expect(Timer.state(view({ waiting = { player = 1, timeLeft = 4 } }), 200, 100).seconds == 0, "nunca baja de 0")
expect(Timer.state(view({ paused = true }), 100, 100).mode == "paused", "en pausa: símbolo de pausa")
expect(Timer.state(view({ over = true }), 100, 100).mode == "hidden", "partida terminada: oculto")
expect(Timer.state(view({ over = true, paused = true }), 100, 100).mode == "hidden", "terminada manda sobre pausa")
expect(Timer.state(view({ waiting = false }), 100, 100).mode == "hidden", "sin ventana de espera: oculto")
expect(Timer.state(nil, 100, 100).mode == "hidden", "sin vista: oculto")

print("Turn.spec OK")
