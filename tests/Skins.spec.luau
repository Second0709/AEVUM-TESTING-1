-- Prueba de las skins de arena (datos puros).
local Skins = require("../src/StarterPlayerScripts/AEVUM/UI3D/Skins")

local function expect(c, m) if not c then error(m, 2) end end
local function isRgb(c)
	if type(c) ~= "table" or #c ~= 3 then return false end
	for i = 1, 3 do
		if type(c[i]) ~= "number" or c[i] < 0 or c[i] > 255 then return false end
	end
	return true
end
local function lum(c) return 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3] end

expect(Skins.Data[Skins.Default] ~= nil, "la skin predeterminada existe")
expect(Skins.Default == "Ruinas", "Ruinas es la skin con la que se empieza")
expect(#Skins.Order == 3, "tres skins: Ruinas, Circuito, Templo")

for _, name in ipairs(Skins.Order) do
	local s = Skins.Data[name]
	expect(s ~= nil, name .. " definida")
	for _, k in ipairs(Skins.COLOR_KEYS) do
		expect(isRgb(s[k]), name .. "." .. k .. " debe ser { r, g, b } entre 0 y 255")
	end
	expect(type(s.material) == "string", name .. ".material")
	local l = s.light
	expect(l and isRgb(l.ambient) and isRgb(l.outdoor) and isRgb(l.shiftTop) and isRgb(l.atmosphere) and isRgb(l.decay), name .. ".light: colores")
	expect(type(l.brightness) == "number" and l.clockTime >= 10 and l.clockTime <= 15, name .. ": sol alto (no rasante)")
	-- Bandos distinguibles: el rival tira a rojo y el jugador a azul
	expect(s.rival[1] > s.rival[3], name .. ": el rival es rojo/coral")
	expect(s.ally[3] > s.ally[1], name .. ": el jugador es azul")
	-- Las baldosas deben contrastar con el grabado (si no, no se ve el dibujo)
	expect(math.abs(lum(s.tile) - lum(s.edge)) > 40, name .. ": el grabado se distingue de la baldosa")
end

-- Ruinas es la luminosa: más clara que las otras dos (la queja principal fue lo oscuro)
expect(lum(Skins.Data.Ruinas.tile) > lum(Skins.Data.Circuito.tile) and lum(Skins.Data.Ruinas.tile) > lum(Skins.Data.Templo.tile), "Ruinas es la más clara")
expect(Skins.Data.Ruinas.light.brightness >= 2.2, "Ruinas ilumina fuerte")

-- Utilidades
expect(Skins.get("nada") == Skins.Data.Ruinas, "una skin desconocida cae a la predeterminada")
expect(Skins.side(Skins.Data.Ruinas, "Self") == Skins.Data.Ruinas.ally and Skins.side(Skins.Data.Ruinas, "Enemy") == Skins.Data.Ruinas.rival, "Self = azul, Enemy = rojo")
local c = Skins.shadeRgb({ 200, 100, 50 }, 0.45)
expect(c[1] == 90 and c[2] == 45 and c[3] == 23, "shade al 45 %")
expect(Skins.shadeRgb({ 200, 100, 50 }, 2)[1] == 255, "shade no pasa de 255")
print("Skins.spec OK")
