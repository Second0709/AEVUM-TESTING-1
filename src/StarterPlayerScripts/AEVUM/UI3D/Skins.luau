--!nonstrict
-- AEVUM · Skins de arena (v1.3.0)
-- Paletas intercambiables del tablero 3D. Son datos puros (colores como { r, g, b } 0-255), así se
-- pueden probar con `luau` sin Roblox. BoardBuilder las convierte con Skins.rgb / Skins.shade.
-- Se elige con Config.Client.Skin. Base recomendada: Ruinas (luminosa; la queja principal fue lo oscuro).
-- Valores tomados de docs/referencia/aevum_tablero_v2.html.
--
-- Campos:
--   rival / rivalDark · ally / allyDark   colores de bando (rojo/coral = rival, azul = jugador)
--   floor    superficie lisa de la mesa      tile / tileDark   baldosa y su sombra
--   edge     grabado de las baldosas          glow   resplandor (torres, orbes, luciérnagas)
--   frame    marco, plintos y metal           river  río de luz del divisor central
--   env      suelo del entorno                stone  torres y escalones
--   material material de mesa y torres (nombre de Enum.Material)
--   light    iluminación local (ambiente, sol, atmósfera, bloom)

local Skins = {}

Skins.Default = "Ruinas"
Skins.Order = { "Ruinas", "Circuito", "Templo" }

Skins.Data = {
	Ruinas = {
		rival = { 232, 128, 90 }, rivalDark = { 154, 74, 48 },
		ally = { 74, 159, 216 }, allyDark = { 42, 95, 154 },
		floor = { 159, 174, 122 }, tile = { 233, 224, 184 }, tileDark = { 196, 184, 134 },
		edge = { 138, 122, 74 }, glow = { 255, 233, 160 }, frame = { 184, 148, 74 }, river = { 127, 209, 232 },
		env = { 79, 127, 74 }, stone = { 190, 182, 140 }, material = "Sandstone",
		light = {
			ambient = { 150, 152, 138 }, outdoor = { 172, 176, 160 }, brightness = 2.4, clockTime = 13, exposure = 0.1,
			shiftTop = { 255, 244, 214 }, atmosphere = { 205, 222, 196 }, decay = { 150, 170, 130 }, density = 0.18,
			bloom = 0.25,
		},
	},
	Circuito = {
		rival = { 255, 107, 74 }, rivalDark = { 138, 42, 26 },
		ally = { 74, 208, 255 }, allyDark = { 18, 106, 154 },
		floor = { 20, 52, 61 }, tile = { 31, 77, 89 }, tileDark = { 18, 51, 60 },
		edge = { 47, 208, 224 }, glow = { 127, 243, 255 }, frame = { 42, 124, 136 }, river = { 255, 164, 58 },
		env = { 8, 40, 48 }, stone = { 36, 84, 96 }, material = "Slate",
		light = {
			ambient = { 80, 110, 118 }, outdoor = { 96, 128, 136 }, brightness = 2, clockTime = 13, exposure = 0,
			shiftTop = { 200, 240, 255 }, atmosphere = { 40, 90, 100 }, decay = { 14, 40, 50 }, density = 0.22,
			bloom = 0.45,
		},
	},
	Templo = {
		rival = { 255, 95, 122 }, rivalDark = { 138, 31, 58 },
		ally = { 106, 168, 255 }, allyDark = { 42, 79, 160 },
		floor = { 61, 51, 88 }, tile = { 82, 70, 116 }, tileDark = { 50, 42, 78 },
		edge = { 216, 174, 92 }, glow = { 255, 217, 138 }, frame = { 216, 174, 92 }, river = { 182, 107, 255 },
		env = { 30, 22, 54 }, stone = { 70, 60, 100 }, material = "Slate",
		light = {
			ambient = { 96, 86, 126 }, outdoor = { 112, 102, 144 }, brightness = 2, clockTime = 14, exposure = 0,
			shiftTop = { 255, 214, 160 }, atmosphere = { 70, 56, 110 }, decay = { 30, 24, 60 }, density = 0.25,
			bloom = 0.4,
		},
	},
}

-- Campos de color que toda skin debe tener (los comprueba tests/Skins.spec.luau)
Skins.COLOR_KEYS = { "rival", "rivalDark", "ally", "allyDark", "floor", "tile", "tileDark", "edge", "glow", "frame",
	"river", "env", "stone" }

-- Skin por nombre; si no existe, la predeterminada
function Skins.get(name)
	return Skins.Data[name] or Skins.Data[Skins.Default]
end

-- { r, g, b } -> Color3
function Skins.rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Mismo color con otro brillo (k = 1 igual, 0.45 = al 45 %). k > 1 aclara sin pasar de 255.
-- shadeRgb es pura ({ r, g, b } -> { r, g, b }); shade devuelve Color3.
function Skins.shadeRgb(c, k)
	return {
		math.min(255, math.floor(c[1] * k + 0.5)),
		math.min(255, math.floor(c[2] * k + 0.5)),
		math.min(255, math.floor(c[3] * k + 0.5)),
	}
end

function Skins.shade(c, k)
	return Skins.rgb(Skins.shadeRgb(c, k))
end

-- Color de bando: "Self" = azul (tú) · "Enemy" = rojo/coral (rival)
function Skins.side(skin, side)
	return side == "Self" and skin.ally or skin.rival
end

return Skins
