--!nonstrict
-- AEVUM · Movimiento de cartas 3D (v1.3.0)
-- Pura: solo números (sin Vector3/CFrame), así se puede probar con `luau`.
-- Cada carta tiene un "estado" { x, y, z, flip, tilt, scale } y una "pista" (track) que ejecuta
-- una secuencia de tramos. CardView convierte el estado en CFrame.
--   flip  = giro sobre el eje largo de la carta (0 = cara arriba, pi = boca abajo)
--   tilt  = inclinación hacia la cámara (rad)
-- Un tramo: { dur, to = tabla | función, arc, ease, delay, onStart, onEnd }
--   `to` puede ser una función: se evalúa en cada paso, así el destino puede ser "vivo"
--   (por ejemplo, la posición de la mano en pantalla, que cambia al redibujarse).

local Motion = {}

local FIELDS = { "x", "y", "z", "flip", "tilt", "scale" }

local function clamp01(t) return t < 0 and 0 or (t > 1 and 1 or t) end

Motion.ease = {
	linear = function(t) return t end,
	quadOut = function(t) return 1 - (1 - t) * (1 - t) end,
	quadInOut = function(t)
		if t < 0.5 then return 2 * t * t end
		return 1 - ((-2 * t + 2) ^ 2) / 2
	end,
	sineInOut = function(t) return -(math.cos(math.pi * t) - 1) / 2 end,
	backOut = function(t)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
	end,
}

function Motion.newState(init)
	local s = { x = 0, y = 0, z = 0, flip = 0, tilt = 0, scale = 1 }
	for k, v in pairs(init or {}) do s[k] = v end
	return s
end

function Motion.newTrack(state)
	return { s = state, segs = nil, i = 0, t = 0, from = nil, started = false, active = false }
end

-- Empieza una secuencia nueva desde el estado actual (cancela la anterior sin llamar a sus onEnd)
function Motion.play(track, segs)
	track.segs, track.i, track.t, track.from, track.started, track.active = segs, 1, 0, nil, false, #segs > 0
end

function Motion.stop(track)
	track.segs, track.from, track.active = nil, nil, false
end

-- Avanza `dt` segundos. Devuelve true si la pista sigue activa.
function Motion.step(track, dt)
	if not track.active then return false end
	local s = track.s
	local remaining = dt
	while true do
		local seg = track.segs[track.i]
		if not seg then
			track.active = false
			return false
		end
		if not track.from then
			track.from = {}
			for _, f in ipairs(FIELDS) do track.from[f] = s[f] end
			track.t = -(seg.delay or 0)
			track.started = false
		end
		track.t += remaining
		remaining = 0
		if track.t < 0 then return true end
		if not track.started then
			track.started = true
			if seg.onStart then seg.onStart() end
		end
		local dur = seg.dur or 0
		local alpha = dur <= 0 and 1 or clamp01(track.t / dur)
		local e = (Motion.ease[seg.ease or "quadInOut"] or Motion.ease.quadInOut)(alpha)
		local to = type(seg.to) == "function" and seg.to() or seg.to or {}
		for _, f in ipairs(FIELDS) do
			local target = to[f]
			if target ~= nil then s[f] = track.from[f] + (target - track.from[f]) * e end
		end
		if seg.arc then s.y += seg.arc * math.sin(math.pi * alpha) end
		if alpha < 1 then return true end
		local leftover = track.t - dur
		if seg.onEnd then seg.onEnd() end
		if track.segs == nil or not track.active then return false end -- onEnd pudo detener/reemplazar la pista
		if track.segs[track.i] ~= seg then return track.active end -- onEnd lanzó una secuencia nueva
		track.i += 1
		track.from = nil
		remaining = leftover
	end
end

return Motion
