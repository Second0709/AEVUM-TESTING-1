--!nonstrict
-- AEVUM · Tablero 3D: posiciones puras (v1.3.0)
-- Sin instancias ni tipos de Roblox: solo números y tablas, así se puede probar con `luau`.
-- Sistema de coordenadas (relativo al centro del tablero, en studs):
--   +X = derecha de la pantalla · +Z = hacia el jugador local · -Z = hacia el rival · Y = arriba.
-- El jugador local siempre se ve en +Z ("Self"), el rival en -Z ("Enemy").
-- El índice de casilla 1 queda a la izquierda para ambos bandos (igual que el tablero 2D).

local Layout = {}

-- Carta tumbada sobre la mesa
Layout.CARD = { w = 4, d = 5.6, h = 0.12 }

Layout.SLOT_PITCH = 5 -- distancia entre centros de casilla en X
Layout.ROW_COMBAT = 5.2 -- |z| de la fila de Combate
Layout.ROW_BENCH = 12.4 -- |z| de la fila de Banca (7.2 entre filas: el cristal cabe en medio)
Layout.SIDE_X = 16.5 -- |x| de las columnas laterales (cristal, mazo, cementerio)
Layout.PEDESTAL_R = 2.2 -- radio de pedestales y pozos de las columnas laterales
Layout.DISC_R = 2.0 -- radio del disco de turno (la franja libre entre filas de Combate mide 4.8)
Layout.BARRIER_GAP = 1.3 -- de la Banca a la barrera (desde el borde de la carta)

-- Alturas (Y = 0 es la superficie de la mesa)
Layout.CARD_Y = 0.6 -- centro de una carta que flota sobre su casilla
Layout.SEL_LIFT = 0.9 -- cuánto se eleva una carta seleccionada
Layout.HOVER_Y = 2.8 -- altura a la que se alza una carta antes de volar a otra zona
Layout.PILE_Y = 0.95 -- altura de entrada/salida en mazo y cementerio

local function sign(side)
	return side == "Self" and 1 or -1
end

-- x de la casilla `index` de `count` casillas (centrado en 0)
function Layout.slotX(index, count)
	return (index - (count + 1) / 2) * Layout.SLOT_PITCH
end

-- Centro de una casilla. side: "Self" | "Enemy" · zone: "Bench" | "Combat"
function Layout.slot(side, zone, index, count)
	count = count or 5
	local row = zone == "Combat" and Layout.ROW_COMBAT or Layout.ROW_BENCH
	return { x = Layout.slotX(index, count), z = sign(side) * row }
end

-- Cristal de vida del avatar (objetivo "Avatar"): columna izquierda, entre Combate y Banca
function Layout.vital(side)
	return { x = -Layout.SIDE_X, z = sign(side) * (Layout.ROW_COMBAT + Layout.ROW_BENCH) / 2 }
end

-- Mazo: columna derecha, a la altura de la Banca
function Layout.deck(side)
	return { x = Layout.SIDE_X, z = sign(side) * Layout.ROW_BENCH }
end

-- Cementerio: columna derecha, a la altura del Combate
function Layout.graveyard(side)
	return { x = Layout.SIDE_X, z = sign(side) * Layout.ROW_COMBAT }
end

-- Punto de salida de las cartas robadas (cima del mazo)
function Layout.deckTop(side)
	local d = Layout.deck(side)
	return { x = d.x, y = Layout.PILE_Y, z = d.z }
end

-- Punto de llegada de las cartas que van al cementerio
function Layout.graveDrop(side)
	local g = Layout.graveyard(side)
	return { x = g.x, y = Layout.PILE_Y, z = g.z }
end

-- Primeros `n` índices libres de una zona. `list` usa false/nil para casilla vacía (como el view).
-- Sirve para prever a qué casillas de Combate irán los atacantes que salen de la Banca.
function Layout.freeSlots(list, n, count)
	count = count or 5
	local out = {}
	for i = 1, count do
		if #out >= n then break end
		if not list[i] then out[#out + 1] = i end
	end
	return out
end

-- Disco de turno: fijo en el centro (la mitad de quien ataca brilla; no se desplaza)
function Layout.disc()
	return { x = 0, z = 0 }
end

-- Barrera: panel bajo detrás de la Banca de cada bando (alto ~1 stud). Centro en Z y semiancho en X.
function Layout.barrierZ(side)
	return sign(side) * (Layout.ROW_BENCH + Layout.CARD.d / 2 + Layout.BARRIER_GAP)
end
Layout.BARRIER_HALF_W = 2.5 * Layout.SLOT_PITCH -- cubre las 5 casillas

-- Camino de los pulsos de daño: del punto de impacto en la barrera, por el surco de su base hasta la
-- columna lateral y por ella hasta el cristal. Devuelve puntos { x, z } (Parche 3 anima a lo largo).
function Layout.pulsePath(side, impactX)
	local bz = Layout.barrierZ(side) + sign(side) * 0.55 -- el surco corre justo detrás del panel
	local v = Layout.vital(side)
	local x = math.clamp(impactX or 0, -Layout.BARRIER_HALF_W, Layout.BARRIER_HALF_W)
	return {
		{ x = x, z = bz },
		{ x = v.x, z = bz },
		{ x = v.x, z = v.z },
	}
end

-- Esquinas de la mesa (para las torres)
function Layout.corners()
	local half = Layout.halfExtents()
	return {
		{ x = -half.x, z = -half.z }, { x = half.x, z = -half.z },
		{ x = -half.x, z = half.z }, { x = half.x, z = half.z },
	}
end

-- Semi-extensiones de la mesa jugable (sin marco)
function Layout.halfExtents()
	local halfX = Layout.SIDE_X + 2.6
	local halfZ = Layout.ROW_BENCH + Layout.CARD.d / 2 + 2.4
	return { x = halfX, z = halfZ }
end

-- Región de pantalla (fracciones 0..1) que dejan libre los paneles 2D.
-- Coincide con el diseño actual: tablero entre el panel izquierdo y el derecho, sobre la mano.
Layout.SCREEN_REGION = { x0 = 0.15, x1 = 0.83, y0 = 0.08, y1 = 0.76 }

-- Encuadre de cámara para que la mesa quepa en `region` de la pantalla.
-- aspect = ancho/alto de la pantalla · vfovDeg = FOV vertical · pitchDeg = inclinación bajo el horizonte.
-- Devuelve { distance, shift }:
--   distance: distancia cámara→centro (studs)
--   shift: cuánto se baja la mirada (radianes) para que el centro de la mesa caiga en el centro de la región
function Layout.cameraFit(aspect, vfovDeg, pitchDeg, region, margin)
	region = region or Layout.SCREEN_REGION
	margin = margin or 1.12
	local half = Layout.halfExtents()
	local tanV = math.tan(math.rad(vfovDeg) / 2)
	local tanH = tanV * aspect
	local regionW = region.x1 - region.x0
	local regionH = region.y1 - region.y0
	local sinP = math.sin(math.rad(pitchDeg))

	-- Ancho: la mesa debe caber en regionW del ancho visible a esa distancia
	local dW = half.x / (regionW * tanH)
	-- Alto: la profundidad se proyecta con sin(pitch); sumamos algo por la altura de los pilares
	local dH = (half.z * sinP + 3) / (regionH * tanV)

	-- Centro de la región en coordenadas NDC (-1..1, +1 = arriba)
	local ndcY = 1 - (region.y0 + region.y1)
	return {
		distance = math.max(dW, dH) * margin,
		shift = math.atan(ndcY * tanV),
	}
end

-- Ancho aparente (píxeles) de una carta en el centro de la mesa con el encuadre de cameraFit.
-- viewportH = alto de pantalla en píxeles. Sirve para vigilar la legibilidad (objetivo: >= 80 px a 1080p).
function Layout.cardScreenWidth(aspect, vfovDeg, pitchDeg, viewportH, region, margin)
	local fit = Layout.cameraFit(aspect, vfovDeg, pitchDeg, region, margin)
	local tanV = math.tan(math.rad(vfovDeg) / 2)
	return Layout.CARD.w * viewportH / (2 * tanV * fit.distance)
end

return Layout
