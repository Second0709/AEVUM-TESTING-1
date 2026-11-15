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
Layout.ROW_COMBAT = 5.6 -- |z| de la fila de Combate
Layout.ROW_BENCH = 12.8 -- |z| de la fila de Banca
Layout.SIDE_X = 17.5 -- |x| de las columnas laterales (cristal, mazo, cementerio)

-- Alturas (Y = 0 es la superficie de la mesa)
Layout.CARD_Y = 0.2 -- centro de una carta tumbada
Layout.HOVER_Y = 3 -- altura de una carta "levantada"
Layout.ORB_Y = 4 -- altura del orbe central

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

-- Orbe central. attacker: "Self" | "Enemy" | nil (neutro). Se desplaza hacia quien ataca.
function Layout.orb(attacker)
	local z = 0
	if attacker then z = sign(attacker) * 1.2 end
	return { x = 0, z = z }
end

-- Semi-extensiones de la mesa jugable (sin marco)
function Layout.halfExtents()
	local halfX = Layout.SIDE_X + 3
	local halfZ = Layout.ROW_BENCH + Layout.CARD.d / 2 + 2.5
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

return Layout
