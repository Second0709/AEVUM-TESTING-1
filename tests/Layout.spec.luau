local Layout = require("../src/StarterPlayerScripts/AEVUM/UI3D/Layout")

local function expect(condition, message)
	if not condition then error(message, 2) end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- Casillas: centradas en X, índice 1 a la izquierda, bandos en lados opuestos de Z
expect(near(Layout.slotX(3, 5), 0), "la casilla central debe estar en x = 0")
expect(near(Layout.slotX(1, 5), -2 * Layout.SLOT_PITCH), "la casilla 1 debe estar a la izquierda")
expect(near(Layout.slotX(5, 5), 2 * Layout.SLOT_PITCH), "la casilla 5 debe estar a la derecha")
expect(Layout.slot("Self", "Combat", 1).z > 0, "el jugador local va en +Z")
expect(Layout.slot("Enemy", "Combat", 1).z < 0, "el rival va en -Z")
expect(near(Layout.slot("Self", "Bench", 2).z, -Layout.slot("Enemy", "Bench", 2).z), "los bandos son simétricos")
expect(math.abs(Layout.slot("Self", "Bench", 1).z) > math.abs(Layout.slot("Self", "Combat", 1).z), "la Banca queda detrás del Combate")

-- Ninguna casilla se solapa con la columna lateral
local half = Layout.halfExtents()
for i = 1, 5 do
	local x = Layout.slotX(i, 5)
	expect(math.abs(x) + Layout.CARD.w / 2 < Layout.SIDE_X - Layout.CARD.w / 2, "las casillas no deben pisar las columnas laterales")
	expect(math.abs(x) < half.x, "las casillas caben en la mesa")
end

-- Vitales, mazos y cementerios
expect(Layout.vital("Self").z > 0 and Layout.vital("Enemy").z < 0, "cada cristal en su lado")
expect(Layout.deck("Self").x == Layout.graveyard("Self").x, "mazo y cementerio comparten columna")
expect(Layout.disc().x == 0 and Layout.disc().z == 0, "el disco de turno es fijo y está en el centro")

-- Cámara: más estrecha la pantalla => más lejos; siempre distancia positiva
local wide = Layout.cameraFit(16 / 9, 45, 58)
local narrow = Layout.cameraFit(4 / 3, 45, 58)
local portrait = Layout.cameraFit(9 / 16, 45, 58)
expect(wide.distance > 0 and narrow.distance > 0 and portrait.distance > 0, "distancia positiva")
expect(narrow.distance >= wide.distance, "pantalla menos ancha exige más distancia")
expect(portrait.distance > narrow.distance, "en vertical la cámara se aleja más")
expect(wide.shift > 0, "la región libre queda sobre el centro: la mirada baja")

-- Disco de turno: cabe en la franja libre entre las filas de Combate
local strip = 2 * (Layout.ROW_COMBAT - Layout.CARD.d / 2)
expect(2 * Layout.DISC_R <= strip, "el disco cabe entre las dos filas de Combate")

-- Pedestales de mazo y cementerio: dentro de la mesa y sin pisar la última casilla
local half2 = Layout.halfExtents()
expect(Layout.SIDE_X + Layout.PEDESTAL_R <= half2.x, "los pedestales caben en la mesa")
expect(Layout.SIDE_X - Layout.PEDESTAL_R > Layout.slotX(5, 5) + Layout.CARD.w / 2, "los pedestales no pisan la Banca/Combate")

-- Barreras: detrás de la Banca, dentro del marco, cubren las 5 casillas y no se pisan con la Banca
for _, side in ipairs({ "Self", "Enemy" }) do
	local bz = math.abs(Layout.barrierZ(side))
	expect(bz > Layout.ROW_BENCH + Layout.CARD.d / 2, "la barrera queda detrás de la Banca")
	expect(bz + 0.55 + 0.1 < half2.z, "barrera y surco caben dentro del marco")
	expect(Layout.BARRIER_HALF_W >= Layout.slotX(5, 5) + Layout.CARD.w / 2, "la barrera cubre las 5 casillas")
end
expect(Layout.barrierZ("Self") > 0 and Layout.barrierZ("Enemy") < 0, "cada barrera en su lado")

-- Camino de pulsos: nace en la barrera (clamp al panel), recorre su surco y termina en el cristal
for _, side in ipairs({ "Self", "Enemy" }) do
	local path = Layout.pulsePath(side, 999)
	local v = Layout.vital(side)
	expect(#path == 3, "el camino tiene tres puntos: impacto, esquina, cristal")
	expect(near(path[1].x, Layout.BARRIER_HALF_W), "el impacto se limita al ancho de la barrera")
	expect(near(path[1].z, path[2].z) and near(path[2].x, path[3].x), "tramos rectos: horizontal por la barrera, vertical por la columna")
	expect(near(path[3].x, v.x) and near(path[3].z, v.z), "el camino acaba en el cristal")
	expect(math.abs(path[1].z) > math.abs(Layout.barrierZ(side)) and math.abs(path[1].z) < half2.z, "el surco va tras la barrera y dentro del marco")
end

-- Las torres de las esquinas quedan en las 4 esquinas de la mesa
local corners = Layout.corners()
expect(#corners == 4, "cuatro torres")

-- Reencuadre: con el pitch nuevo (46°) la mesa cabe más cerca que con el antiguo (58°) y la carta se lee mejor
local near46 = Layout.cameraFit(16 / 9, 45, 46)
expect(near46.distance < Layout.cameraFit(16 / 9, 45, 58).distance, "pitch 46° acerca la cámara")
local px = Layout.cardScreenWidth(16 / 9, 45, 46, 1080)
expect(px >= 80, "una carta debe medir >= 80 px de ancho a 1080p (mide " .. string.format("%.1f", px) .. ")")
-- La mesa no puede quedar recortada en vertical (móvil): la distancia debe seguir creciendo
expect(Layout.cameraFit(9 / 16, 45, 46).distance > Layout.cameraFit(4 / 3, 45, 46).distance, "en vertical la cámara se aleja más")

print("Layout.spec OK · distancia 16:9 =", string.format("%.1f", wide.distance), "(pitch 46°:", string.format("%.1f", near46.distance) .. ", carta " .. string.format("%.0f", px) .. " px a 1080p)", "· 4:3 =", string.format("%.1f", narrow.distance),
	"· 9:16 =", string.format("%.1f", portrait.distance))
