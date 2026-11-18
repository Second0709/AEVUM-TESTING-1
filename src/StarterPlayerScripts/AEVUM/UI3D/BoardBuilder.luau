--!nonstrict
-- AEVUM · Tablero 3D: templo estático (v1.3.0)
-- Construye UNA sola vez la mesa de piedra y oro con surcos y glifos de neón.
-- No conoce el estado de la partida: solo geometría. Las cartas las pone Board3D (Fase 2).

local Lighting = game:GetService("Lighting")

local Layout = require(script.Parent.Layout)

local BoardBuilder = {}

local PAL = {
	stone = Color3.fromRGB(40, 38, 48),
	tier2 = Color3.fromRGB(28, 26, 34),
	tier3 = Color3.fromRGB(21, 20, 27),
	floor = Color3.fromRGB(13, 12, 18),
	slot = Color3.fromRGB(30, 29, 38),
	gold = Color3.fromRGB(176, 138, 66),
	glyph = Color3.fromRGB(255, 196, 110), -- neón neutro (ámbar)
	Self = Color3.fromRGB(77, 225, 255), -- cian = jugador
	Enemy = Color3.fromRGB(255, 90, 170), -- rosa = rival
}
BoardBuilder.Palette = PAL

local SLOTS = 5
local CYL = CFrame.Angles(0, 0, math.pi / 2) -- un cilindro de Roblox tiene el eje en X: lo giramos para que mire hacia arriba

-- Construye el templo. origin: Vector3 del centro de la mesa. quality: "High" | "Low".
-- Devuelve { folder, glow, refs }:
--   glow: partes de neón que pueden pulsar (solo calidad alta)
--   refs: partes con nombre que usarán las fases siguientes (casillas, cristales, orbe)
function BoardBuilder.build(origin, quality)
	local high = quality ~= "Low"
	local folder = Instance.new("Folder")
	folder.Name = "AevumBoard3D"
	local glow = {}
	local refs = { slots = {}, vitals = {}, decks = {}, graveyards = {}, hit = {}, markers = {}, vitalHit = {} }

	-- Crea una pieza anclada. pos es relativa al centro de la mesa.
	local function part(name, size, pos, color, material, opts)
		opts = opts or {}
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = opts.query == true -- decorado: no estorba al raycast; solo las zonas táctiles lo activan
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.Slate
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = high and math.max(size.X, size.Y, size.Z) >= 2 and (opts.transparency or 0) < 1
		if opts.transparency then p.Transparency = opts.transparency end
		if opts.shape then p.Shape = opts.shape end
		p.CFrame = CFrame.new(origin + pos) * (opts.rot or CFrame.new())
		if opts.glow then glow[#glow + 1] = p end
		p.Parent = folder
		return p
	end

	local function light(parent, color, range, brightness)
		if not high then return end
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Shadows = false
		l.Parent = parent
	end

	local half = Layout.halfExtents()
	local hx, hz = half.x, half.z

	-- ── Suelo y escalones (ziggurat) ───────────────────────────────────────
	part("Suelo", Vector3.new(600, 1, 600), Vector3.new(0, -5, 0), PAL.floor, Enum.Material.Basalt)
	part("Escalon3", Vector3.new(hx * 2 + 12, 1.5, hz * 2 + 12), Vector3.new(0, -3.75, 0), PAL.tier3, Enum.Material.Basalt)
	part("Escalon2", Vector3.new(hx * 2 + 6, 1.5, hz * 2 + 6), Vector3.new(0, -2.25, 0), PAL.tier2, Enum.Material.Basalt)
	part("Mesa", Vector3.new(hx * 2, 1.5, hz * 2), Vector3.new(0, -0.75, 0), PAL.stone, Enum.Material.Slate)

	-- ── Marco de oro envejecido ────────────────────────────────────────────
	local METAL = Enum.Material.Metal
	part("MarcoN", Vector3.new(hx * 2 + 1.6, 0.5, 0.8), Vector3.new(0, 0.25, -(hz + 0.4)), PAL.gold, METAL)
	part("MarcoS", Vector3.new(hx * 2 + 1.6, 0.5, 0.8), Vector3.new(0, 0.25, hz + 0.4), PAL.gold, METAL)
	part("MarcoW", Vector3.new(0.8, 0.5, hz * 2), Vector3.new(-(hx + 0.4), 0.25, 0), PAL.gold, METAL)
	part("MarcoE", Vector3.new(0.8, 0.5, hz * 2), Vector3.new(hx + 0.4, 0.25, 0), PAL.gold, METAL)

	-- ── Nicho rectangular: placa oscura + 4 bordes de oro + franja de neón ──
	-- stripDz: desplazamiento en Z de la franja de neón respecto al centro del nicho.
	local function socket(name, cx, cz, color, stripDz)
		local W, D = 4.8, 6.4
		local base = part(name, Vector3.new(4.5, 0.1, 6.1), Vector3.new(cx, 0.05, cz), PAL.slot, Enum.Material.Basalt)
		part(name .. "_BordeN", Vector3.new(W, 0.25, 0.3), Vector3.new(cx, 0.125, cz - D / 2 + 0.15), PAL.gold, METAL)
		part(name .. "_BordeS", Vector3.new(W, 0.25, 0.3), Vector3.new(cx, 0.125, cz + D / 2 - 0.15), PAL.gold, METAL)
		part(name .. "_BordeW", Vector3.new(0.3, 0.25, D - 0.6), Vector3.new(cx - W / 2 + 0.15, 0.125, cz), PAL.gold, METAL)
		part(name .. "_BordeE", Vector3.new(0.3, 0.25, D - 0.6), Vector3.new(cx + W / 2 - 0.15, 0.125, cz), PAL.gold, METAL)
		part(name .. "_Glifo", Vector3.new(3, 0.06, 0.16), Vector3.new(cx, 0.12, cz + stripDz), color, Enum.Material.Neon)
		return base
	end

	-- ── Casillas de Combate y Banca (ambos bandos) ─────────────────────────
	for _, side in ipairs({ "Self", "Enemy" }) do
		local sgn = side == "Self" and 1 or -1
		for _, zone in ipairs({ "Combat", "Bench" }) do
			-- Combate: la franja mira al centro. Banca: mira al borde exterior.
			local dz = (zone == "Combat" and -sgn or sgn) * 2.7
			for i = 1, SLOTS do
				local p = Layout.slot(side, zone, i, SLOTS)
				local name = ("Casilla_%s_%s_%d"):format(side, zone, i)
				local key = ("%s:%s:%d"):format(side, zone, i)
				refs.slots[key] = socket(name, p.x, p.z, PAL[side], dz)
				-- Zona táctil invisible, más generosa que la carta (dedos en móvil)
				local hit = part("Zona_" .. name, Vector3.new(5, 0.3, 6.6), Vector3.new(p.x, 0.2, p.z), PAL.slot, nil,
					{ transparency = 1, query = true })
				hit:SetAttribute("Kind", "slot")
				hit:SetAttribute("Side", side)
				hit:SetAttribute("Zone", zone)
				hit:SetAttribute("Index", i)
				refs.hit[key] = hit
				-- Marcador de casilla: se enciende para "puedes colocar aquí" / "aquí irá el atacante"
				refs.markers[key] = part("Marcador_" .. name, Vector3.new(4.3, 0.04, 5.9), Vector3.new(p.x, 0.17, p.z),
					PAL.glyph, Enum.Material.Neon, { transparency = 1 })
			end
		end
	end

	-- ── Surcos tipo circuito ───────────────────────────────────────────────
	local NEON = Enum.Material.Neon
	-- Franja central: surco horizontal a ambos lados del orbe, con nodos
	for _, sx in ipairs({ -1, 1 }) do
		local len = hx - 2 - 2.6
		part("Surco", Vector3.new(len, 0.05, 0.14), Vector3.new(sx * (2.6 + len / 2), 0.03, 0), PAL.glyph, NEON, { glow = true })
		for _, nx in ipairs({ 6, 11, 16 }) do
			part("Nodo", Vector3.new(0.5, 0.1, 0.5), Vector3.new(sx * nx, 0.05, 0), PAL.glyph, NEON, { glow = true })
		end
		for _, sz in ipairs({ -1, 1 }) do
			part("SurcoFino", Vector3.new(5.6, 0.05, 0.1), Vector3.new(sx * 6.2, 0.03, sz * 1.3), PAL.glyph, NEON)
		end
	end
	-- Surcos de cada bando entre Combate y Banca: enlazan el cristal con las filas
	local channelZ = (Layout.ROW_COMBAT + 3.2 + Layout.ROW_BENCH - 3.2) / 2
	local x0, x1 = -(Layout.SIDE_X - 2), Layout.slotX(SLOTS, SLOTS) + 2.4
	for _, side in ipairs({ "Self", "Enemy" }) do
		local sgn = side == "Self" and 1 or -1
		part("Canal_" .. side, Vector3.new(x1 - x0, 0.05, 0.14), Vector3.new((x0 + x1) / 2, 0.03, sgn * channelZ), PAL[side], NEON)
	end

	-- ── Orbe central (sobre un sello de dos anillos) ───────────────────────
	part("SelloAnillo", Vector3.new(0.06, 4.4, 4.4), Vector3.new(0, 0.04, 0), PAL.glyph, NEON, { rot = CYL, glow = true })
	part("SelloBase", Vector3.new(0.06, 4.0, 4.0), Vector3.new(0, 0.07, 0), PAL.slot, Enum.Material.Basalt, { rot = CYL })
	part("SelloRuna", Vector3.new(0.06, 2.8, 2.8), Vector3.new(0, 0.1, 0), PAL.glyph, NEON, { rot = CYL, glow = true })
	part("SelloNucleo", Vector3.new(0.06, 2.4, 2.4), Vector3.new(0, 0.13, 0), PAL.slot, Enum.Material.Basalt, { rot = CYL })
	local orb = part("Orbe", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, Layout.ORB_Y, 0), PAL.glyph, NEON,
		{ shape = Enum.PartType.Ball, glow = true })
	light(orb, PAL.glyph, 18, 1.4)
	refs.orb = orb

	-- ── Columna lateral: cristal de vida, mazo y cementerio de cada bando ──
	for _, side in ipairs({ "Self", "Enemy" }) do
		local sgn = side == "Self" and 1 or -1
		local color = PAL[side]

		local v = Layout.vital(side)
		part("CristalBase_" .. side, Vector3.new(0.4, 4.4, 4.4), Vector3.new(v.x, 0.2, v.z), PAL.gold, METAL, { rot = CYL })
		part("CristalNucleo_" .. side, Vector3.new(0.34, 3.8, 3.8), Vector3.new(v.x, 0.17, v.z), PAL.slot, Enum.Material.Basalt, { rot = CYL })
		local crystal = part("Cristal_" .. side, Vector3.new(1.6, 1.6, 1.6), Vector3.new(v.x, 2.6, v.z), color, NEON,
			{ transparency = 0.1, rot = CFrame.Angles(math.rad(45), math.rad(45), 0), glow = true })
		light(crystal, color, 12, 1.2)
		refs.vitals[side] = crystal
		local vhit = part("ZonaCristal_" .. side, Vector3.new(5, 5, 5), Vector3.new(v.x, 2.6, v.z), PAL.slot, nil,
			{ transparency = 1, query = true })
		vhit:SetAttribute("Kind", "avatar")
		vhit:SetAttribute("Side", side)
		refs.vitalHit[side] = vhit

		local d = Layout.deck(side)
		socket("Mazo_" .. side, d.x, d.z, color, sgn * 2.7)
		refs.decks[side] = part("MazoPila_" .. side, Vector3.new(4, 0.5, 5.6), Vector3.new(d.x, 0.4, d.z),
			Color3.fromRGB(46, 40, 62), METAL)

		local g = Layout.graveyard(side)
		refs.graveyards[side] = socket("Cementerio_" .. side, g.x, g.z, color, -sgn * 2.7)
	end

	-- ── Pilares con brasero en las cuatro esquinas ─────────────────────────
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local px, pz = sx * (hx + 1.2), sz * (hz + 1.2)
			local color = sz == 1 and PAL.Self or PAL.Enemy
			part("Pilar", Vector3.new(1.8, 6.5, 1.8), Vector3.new(px, 1.75, pz), PAL.tier2, Enum.Material.Basalt)
			part("PilarCapitel", Vector3.new(2.4, 0.4, 2.4), Vector3.new(px, 5.2, pz), PAL.gold, METAL)
			local flame = part("PilarLlama", Vector3.new(1, 1, 1), Vector3.new(px, 6, pz), color, NEON,
				{ shape = Enum.PartType.Ball, glow = true })
			light(flame, color, 14, 1)
		end
	end

	return { folder = folder, glow = glow, refs = refs }
end

-- Atmósfera oscura de templo. Solo afecta a este cliente.
-- Devuelve una función que restaura todo lo que cambió.
function BoardBuilder.applyLighting(quality)
	local high = quality ~= "Low"
	local saved = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		ColorShift_Top = Lighting.ColorShift_Top,
		GlobalShadows = Lighting.GlobalShadows,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	Lighting.Ambient = Color3.fromRGB(52, 48, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 56, 84)
	Lighting.Brightness = 2
	Lighting.ClockTime = 16.5 -- sol bajo: luz rasante que marca el relieve de la piedra
	Lighting.ColorShift_Top = Color3.fromRGB(255, 205, 150)
	Lighting.GlobalShadows = high
	Lighting.ExposureCompensation = 0

	local extras = {}
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "AevumAtmosphere"
	atmosphere.Density = 0.25
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(34, 28, 56)
	atmosphere.Decay = Color3.fromRGB(14, 12, 28)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting
	extras[#extras + 1] = atmosphere

	if high then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "AevumBloom"
		bloom.Intensity = 0.5
		bloom.Size = 24
		bloom.Threshold = 1
		bloom.Parent = Lighting
		extras[#extras + 1] = bloom
	end

	return function()
		for k, v in pairs(saved) do Lighting[k] = v end
		for _, e in ipairs(extras) do e:Destroy() end
	end
end

return BoardBuilder
