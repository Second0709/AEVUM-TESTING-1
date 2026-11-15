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
expect(Layout.orb("Self").z > 0 and Layout.orb("Enemy").z < 0 and Layout.orb(nil).z == 0, "el orbe se acerca a quien ataca")

-- Cámara: más estrecha la pantalla => más lejos; siempre distancia positiva
local wide = Layout.cameraFit(16 / 9, 45, 58)
local narrow = Layout.cameraFit(4 / 3, 45, 58)
local portrait = Layout.cameraFit(9 / 16, 45, 58)
expect(wide.distance > 0 and narrow.distance > 0 and portrait.distance > 0, "distancia positiva")
expect(narrow.distance >= wide.distance, "pantalla menos ancha exige más distancia")
expect(portrait.distance > narrow.distance, "en vertical la cámara se aleja más")
expect(wide.shift > 0, "la región libre queda sobre el centro: la mirada baja")

print("Layout.spec OK · distancia 16:9 =", string.format("%.1f", wide.distance), "· 4:3 =", string.format("%.1f", narrow.distance),
	"· 9:16 =", string.format("%.1f", portrait.distance))
