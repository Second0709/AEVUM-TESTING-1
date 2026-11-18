local Motion = require("../src/StarterPlayerScripts/AEVUM/UI3D/Motion")
local Layout = require("../src/StarterPlayerScripts/AEVUM/UI3D/Layout")

local function expect(c, m) if not c then error(m, 2) end end
local function near(a, b, e) return math.abs(a - b) < (e or 1e-6) end

-- Un tramo simple llega exactamente al destino y llama a onEnd una vez
do
	local s = Motion.newState({ x = 0, y = 0 })
	local t = Motion.newTrack(s)
	local ends = 0
	Motion.play(t, { { dur = 1, to = { x = 10, y = 4 }, onEnd = function() ends += 1 end } })
	for _ = 1, 11 do Motion.step(t, 0.1) end -- 11: el acumulado en coma flotante de 10 pasos puede quedar en 0.9999
	expect(near(s.x, 10) and near(s.y, 4), "debe llegar al destino")
	expect(ends == 1 and not t.active, "onEnd una sola vez y pista terminada")
end

-- Arco: a mitad del tramo la altura supera la de ambos extremos, y al final vuelve a la exacta
do
	local s = Motion.newState({ y = 1 })
	local t = Motion.newTrack(s)
	Motion.play(t, { { dur = 1, to = { y = 1 }, arc = 3, ease = "linear" } })
	Motion.step(t, 0.5)
	expect(near(s.y, 4), "el arco debe sumar su altura a mitad de camino")
	Motion.step(t, 0.5)
	expect(near(s.y, 1), "al terminar vuelve a la altura de destino")
end

-- Secuencia con retraso y arrastre del tiempo sobrante entre tramos
do
	local s = Motion.newState({ x = 0 })
	local t = Motion.newTrack(s)
	local log = {}
	Motion.play(t, {
		{ dur = 1, delay = 0.5, to = { x = 1 }, ease = "linear", onStart = function() log[#log + 1] = "a" end },
		{ dur = 1, to = { x = 3 }, ease = "linear", onStart = function() log[#log + 1] = "b" end },
	})
	Motion.step(t, 0.4)
	expect(s.x == 0 and #log == 0, "durante el retraso no se mueve ni arranca")
	Motion.step(t, 0.6) -- 0.5 de retraso + 0.5 de tramo
	expect(near(s.x, 0.5) and log[1] == "a", "el tramo arranca tras el retraso")
	Motion.step(t, 1.0) -- termina tramo 1 (0.5) y avanza 0.5 en el tramo 2
	expect(log[2] == "b" and near(s.x, 2), "el sobrante pasa al siguiente tramo")
	Motion.step(t, 5)
	expect(near(s.x, 3) and not t.active, "termina en el destino final")
end

-- Destino "vivo": si el destino se mueve durante el vuelo, llega al nuevo destino
do
	local s = Motion.newState({ x = 0 })
	local t = Motion.newTrack(s)
	local target = { x = 10 }
	Motion.play(t, { { dur = 1, to = function() return target end, ease = "linear" } })
	Motion.step(t, 0.5)
	target.x = 20
	Motion.step(t, 0.5)
	expect(near(s.x, 20), "debe terminar en el destino actualizado")
end

-- Reemplazar una secuencia en mitad del vuelo parte desde la posición actual (sin saltos)
do
	local s = Motion.newState({ x = 0 })
	local t = Motion.newTrack(s)
	Motion.play(t, { { dur = 1, to = { x = 10 }, ease = "linear" } })
	Motion.step(t, 0.5)
	local mid = s.x
	Motion.play(t, { { dur = 1, to = { x = 0 }, ease = "linear" } })
	Motion.step(t, 0.0001)
	expect(math.abs(s.x - mid) < 0.01, "sin salto al reemplazar la secuencia")
end

-- onEnd que lanza otra secuencia no se salta tramos
do
	local s = Motion.newState({ x = 0 })
	local t = Motion.newTrack(s)
	Motion.play(t, { { dur = 0.1, to = { x = 1 }, onEnd = function()
		Motion.play(t, { { dur = 0.1, to = { x = 5 }, ease = "linear" } })
	end } })
	for _ = 1, 10 do Motion.step(t, 0.05) end
	expect(near(s.x, 5), "la secuencia lanzada desde onEnd debe ejecutarse entera")
end

-- Layout.freeSlots: primeras casillas libres (false o nil)
do
	local free = Layout.freeSlots({ { uid = 1 }, false, { uid = 2 }, false, false }, 2)
	expect(#free == 2 and free[1] == 2 and free[2] == 4, "freeSlots devuelve las primeras libres en orden")
	expect(#Layout.freeSlots({ {}, {}, {}, {}, {} }, 3) == 0, "sin casillas libres")
	expect(#Layout.freeSlots({ false, false, false, false, false }, 9) == 5, "no devuelve más de las que hay")
end

print("Motion.spec OK")
