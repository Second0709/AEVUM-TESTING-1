--!nonstrict
-- AEVUM · Tablero 3D: arena (v1.3.0)
-- Construye UNA sola vez la arena según la skin (Config.Client.Skin). No conoce el estado de la partida:
-- solo geometría. Las cartas las pone Board3D.
--
-- Diseño (ver docs/PLAN_TABLERO_3D.md §4 y docs/referencia/aevum_tablero_v2.html):
--   · El detalle vive en el ENTORNO (4 torres, pedestal de mazo, pozo de cementerio, luciérnagas); el
--     suelo de juego es liso y de poco contraste para que las cartas destaquen.
--   · Baldosas grabadas de UNA pieza por casilla: el grabado (octágono en Banca, círculo en Combate,
--     línea del color del bando) se dibuja en un SurfaceGui sobre la placa.
--   · Divisor central: río de luz animado con el disco de turno encima (mitad roja = rival, azul = tú).
--   · Barrera baja y translúcida detrás de cada Banca y un surco barrera → cristal por donde irán los pulsos.
--   · Todo objeto redondo usa disc(), que activa Shape = Cylinder (error ya cometido: ver plan §9).
--   · Las caras con SurfaceGui usan la misma orientación determinista que las cartas (CardView.faceRotation).
-- Presupuesto: <= ~130 partes (tests/smoke lo comprueba).

local Lighting = game:GetService("Lighting")

local Layout = require(script.Parent.Layout)
local Skins = require(script.Parent.Skins)
local CardView = require(script.Parent.CardView)

local BoardBuilder = {}

local SLOTS = 5
local CYL = CFrame.Angles(0, 0, math.pi / 2) -- un cilindro de Roblox tiene el eje en X: lo giramos para que mire hacia arriba
-- Un cubo con un vértice hacia arriba (punta de cristal): lleva (1,1,1) a +Y
local TIP = CFrame.Angles(-math.atan(math.sqrt(2)), -math.pi / 4, 0)
local SIDES = { "Self", "Enemy" }

-- Colores de bando de una skin: Self = azul (tú) · Enemy = rojo/coral (rival)
function BoardBuilder.palette(skinName)
	local skin = Skins.get(skinName)
	return { Self = Skins.rgb(skin.ally), Enemy = Skins.rgb(skin.rival) }
end

-- Construye la arena. origin: Vector3 del centro de la mesa. quality: "High" | "Low". skinName: ver Skins.
-- Devuelve { folder, glow, glowBase, refs, anim, palette, skin }:
--   glow: partes de neón que pueden pulsar (solo calidad alta) · glowBase[parte] = su transparencia en reposo
--   refs: partes con nombre que usan las fases siguientes (zonas táctiles, cristales, mazos, disco…)
--   anim: elementos que se animan cada fotograma (río, luciérnagas)
function BoardBuilder.build(origin, quality, skinName)
	local high = quality ~= "Low"
	local skin = Skins.get(skinName)
	local rgb, shade = Skins.rgb, Skins.shade
	local face = CardView.faceRotation() -- misma orientación determinista que las cartas
	local material = Enum.Material[skin.material] or Enum.Material.Slate
	local METAL, NEON, SMOOTH = Enum.Material.Metal, Enum.Material.Neon, Enum.Material.SmoothPlastic

	local folder = Instance.new("Folder")
	folder.Name = "AevumBoard3D"
	local glow, glowBase = {}, {}
	local anim = { river = nil, fireflies = {} }
	local refs = {
		slots = {}, hit = {}, markers = {}, vitals = {}, vitalGem = {}, vitalHit = {}, decks = {}, deckTops = {}, graveyards = {},
		barriers = {}, grooves = {}, discs = {}, disc = nil,
	}
	local palette = BoardBuilder.palette(skinName)

	-- Crea una pieza anclada. pos es relativa al centro de la mesa.
	-- opts: transparency, shape, rot (CFrame), glow (pulsa), query (zona táctil), shadow (proyecta sombra)
	local function part(name, size, pos, color, mat, opts)
		opts = opts or {}
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = opts.query == true -- decorado: no estorba al raycast; solo las zonas táctiles lo activan
		p.Size = size
		p.Color = color
		p.Material = mat or material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = high and opts.shadow == true
		if opts.transparency then p.Transparency = opts.transparency end
		if opts.shape then p.Shape = opts.shape end
		p.CFrame = CFrame.new(origin + pos) * (opts.rot or CFrame.new())
		if opts.glow and high then
			glow[#glow + 1] = p
			glowBase[p] = opts.transparency or 0
		end
		p.Parent = folder
		return p
	end

	-- Pieza redonda con el eje hacia arriba. SIEMPRE activa Shape = Cylinder (si no, sale cuadrada).
	local function disc(name, diameter, height, pos, color, mat, opts)
		opts = opts or {}
		opts.shape = Enum.PartType.Cylinder
		opts.rot = CYL
		local p = part(name, Vector3.new(height, diameter, diameter), pos, color, mat, opts)
		refs.discs[#refs.discs + 1] = p
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

	-- SurfaceGui en la cara Front/Back de una pieza fina girada con `face` (orientación conocida)
	local function surface(p, faceId, w, h, lightInfluence)
		local g = Instance.new("SurfaceGui")
		g.Face = faceId
		g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		g.CanvasSize = Vector2.new(w, h)
		g.LightInfluence = lightInfluence or 0
		g.AlwaysOnTop = false
		g.Parent = p
		return g
	end

	local function frame(parent, props)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		for k, v in pairs(props) do f[k] = v end
		f.Parent = parent
		return f
	end

	-- Barra centrada en (x, y) del lienzo, de largo `len` y grosor `th`, girada `deg` grados
	local function bar(parent, x, y, len, th, deg, color)
		return frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(len, th), Rotation = deg, BackgroundColor3 = color })
	end

	local function ring(parent, diameter, thickness, color)
		local f = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(diameter, diameter), BackgroundTransparency = 1 })
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness
		s.Parent = f
		return f
	end

	local half = Layout.halfExtents()
	local hx, hz = half.x, half.z
	local edgeColor = rgb(skin.edge)

	-- ── Entorno y mesa: superficies lisas, de poco contraste ───────────────
	part("Suelo", Vector3.new(400, 1, 400), Vector3.new(0, -2.9, 0), rgb(skin.env), SMOOTH)
	part("Escalon", Vector3.new(hx * 2 + 4, 1.2, hz * 2 + 4), Vector3.new(0, -1.8, 0), rgb(skin.stone), material)
	part("Mesa", Vector3.new(hx * 2, 1.2, hz * 2), Vector3.new(0, -0.6, 0), rgb(skin.floor), material)

	-- ── Marco ──────────────────────────────────────────────────────────────
	local frameColor = rgb(skin.frame)
	part("MarcoN", Vector3.new(hx * 2 + 1.6, 0.5, 0.8), Vector3.new(0, 0.25, -(hz + 0.4)), frameColor, METAL)
	part("MarcoS", Vector3.new(hx * 2 + 1.6, 0.5, 0.8), Vector3.new(0, 0.25, hz + 0.4), frameColor, METAL)
	part("MarcoW", Vector3.new(0.8, 0.5, hz * 2), Vector3.new(-(hx + 0.4), 0.25, 0), frameColor, METAL)
	part("MarcoE", Vector3.new(0.8, 0.5, hz * 2), Vector3.new(hx + 0.4, 0.25, 0), frameColor, METAL)

	-- ── Baldosas grabadas: UNA pieza por casilla + zona táctil que a la vez hace de marcador ──
	local tileColor = rgb(skin.tile)
	for _, side in ipairs(SIDES) do
		local sgn = side == "Self" and 1 or -1
		local sideColor = palette[side]
		for _, zone in ipairs({ "Combat", "Bench" }) do
			for i = 1, SLOTS do
				local p = Layout.slot(side, zone, i, SLOTS)
				local name = ("Casilla_%s_%s_%d"):format(side, zone, i)
				local key = ("%s:%s:%d"):format(side, zone, i)

				-- Placa fina (ancho, alto, grosor) girada: su cara Front mira al cielo con el "arriba" hacia -Z
				local plate = part(name, Vector3.new(4.5, 6.1, 0.1), Vector3.new(p.x, 0.05, p.z), tileColor, SMOOTH, { rot = face })
				local g = surface(plate, Enum.NormalId.Front, 450, 610, 0.5)
				if zone == "Bench" then
					-- Octágono: 8 barras sobre el contorno (apotema 150 px, lado = 2·a·tan(22.5°))
					local a = 150
					local len = 2 * a * math.tan(math.pi / 8) + 8
					for k = 0, 7 do
						local phi = k * math.pi / 4
						bar(g, 225 + a * math.cos(phi), 305 + a * math.sin(phi), len, 8, math.deg(phi) + 90, edgeColor)
					end
				else
					ring(g, 300, 8, edgeColor) -- círculo doble en Combate
					ring(g, 224, 3, edgeColor)
				end
				-- Línea del color del bando, en el borde que mira a su dueño
				bar(g, 225, sgn == 1 and 574 or 36, 270, 10, 0, sideColor)
				refs.slots[key] = plate

				-- Zona táctil generosa (dedos en móvil), por debajo de las cartas. También es el marcador de
				-- casilla: Board3D la enciende ("puedes colocar aquí" / "aquí irá el atacante").
				local hit = part("Zona_" .. name, Vector3.new(4.9, 0.12, 6.5), Vector3.new(p.x, 0.16, p.z), rgb(skin.glow), NEON,
					{ transparency = 1, query = true })
				hit:SetAttribute("Kind", "slot")
				hit:SetAttribute("Side", side)
				hit:SetAttribute("Zone", zone)
				hit:SetAttribute("Index", i)
				refs.hit[key] = hit
				refs.markers[key] = hit
			end
		end
	end

	-- ── Divisor central: río de luz animado ────────────────────────────────
	local river = part("Rio", Vector3.new(hx * 2, 2.2, 0.08), Vector3.new(0, 0.04, 0), rgb(skin.river), SMOOTH,
		{ rot = face, transparency = 0.2 })
	local rg = surface(river, Enum.NormalId.Front, 1216, 70, 0)
	if high then
		local stripes, n = {}, 12
		for i = 1, n do
			stripes[i] = frame(rg, { Size = UDim2.fromOffset(40, 70), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.6 })
		end
		anim.river = { frames = stripes, n = n }
	end
	for _, sz in ipairs({ -1, 1 }) do
		part("OrillaRio", Vector3.new(hx * 2, 0.14, 0.18), Vector3.new(0, 0.07, sz * 1.2), frameColor, METAL)
	end

	-- ── Disco de turno: círculo partido, mitad superior roja (rival) e inferior azul (tú) ──
	-- El círculo es un Frame con UICorner (la misma técnica de los anillos de las baldosas) y las dos mitades son
	-- un UIGradient de corte duro. CanvasGroup + UICorner no recortó en Studio (salían esquinas): no usarlo.
	local dr = Layout.DISC_R
	disc("DiscoBase", dr * 2 + 0.4, 0.16, Vector3.new(0, 0.12, 0), frameColor, METAL, { shadow = true })
	local holder = part("DiscoCara", Vector3.new(dr * 2, dr * 2, 0.02), Vector3.new(0, 0.215, 0), Color3.fromRGB(255, 255, 255),
		SMOOTH, { rot = face, transparency = 1 })
	local dg = surface(holder, Enum.NormalId.Front, 400, 400, 0)
	local circle = frame(dg, { Name = "DiscoCirculo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.94), BackgroundColor3 = Color3.fromRGB(255, 255, 255) }) -- 0.94: deja sitio al borde
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = circle
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90 -- de arriba (rival) a abajo (tú)
	grad.Parent = circle
	local cs = Instance.new("UIStroke")
	cs.Color = Color3.fromRGB(255, 255, 255)
	cs.Thickness = 8
	cs.Parent = circle
	frame(circle, { Name = "DiscoLinea", Position = UDim2.new(0, 0, 0.5, -3), Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
	local dot = frame(circle, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(56, 56), BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
	local halves = { Enemy = palette.Enemy, Self = palette.Self }
	local function paintDisc()
		local e, m = halves.Enemy, halves.Self
		-- corte duro en 0.5 (los tiempos no se repiten por si Roblox los exige estrictos)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, e), ColorSequenceKeypoint.new(0.5, e),
			ColorSequenceKeypoint.new(0.501, m), ColorSequenceKeypoint.new(1, m),
		})
	end
	paintDisc()
	refs.disc = {
		gradient = grad,
		set = function(side, color) -- color de la mitad "Enemy" (arriba) o "Self" (abajo)
			halves[side] = color
			paintDisc()
		end,
	}

	-- ── Columna lateral: cristal de vida, mazo y cementerio de cada bando ──
	for _, side in ipairs(SIDES) do
		local sgn = side == "Self" and 1 or -1
		local color = palette[side]

		-- Cristal facetado: fuste de 8 caras (dos bloques a 0° y 45°) con una punta de cubo arriba y abajo
		local v = Layout.vital(side)
		disc("CristalPlinto_" .. side, 3.6, 0.7, Vector3.new(v.x, 0.35, v.z), frameColor, METAL, { shadow = true })
		disc("CristalAro_" .. side, 3.9, 0.06, Vector3.new(v.x, 0.03, v.z), color, NEON, { glow = true, transparency = 0.3 })
		local shaft = part("Cristal_" .. side, Vector3.new(1.2, 1.5, 1.2), Vector3.new(v.x, 2.5, v.z), color, NEON,
			{ transparency = 0.12, glow = true, shadow = true })
		local shaft2 = part("CristalB_" .. side, Vector3.new(1.2, 1.5, 1.2), Vector3.new(v.x, 2.5, v.z), color, NEON,
			{ transparency = 0.12, glow = true, rot = CFrame.Angles(0, math.pi / 4, 0) })
		local tipLo = part("CristalPuntaB_" .. side, Vector3.new(0.95, 0.95, 0.95), Vector3.new(v.x, 1.55, v.z), color, NEON,
			{ transparency = 0.12, glow = true, rot = TIP })
		local tipHi = part("CristalPuntaA_" .. side, Vector3.new(0.95, 0.95, 0.95), Vector3.new(v.x, 3.45, v.z), color, NEON,
			{ transparency = 0.12, glow = true, rot = TIP })
		light(shaft, color, 12, 1)
		refs.vitals[side] = shaft
		refs.vitalGem[side] = { shaft, shaft2, tipLo, tipHi }
		-- Zona táctil del avatar: ajustada al cristal, para no tapar lo que hay detrás
		local vhit = part("ZonaCristal_" .. side, Vector3.new(4.2, 4, 4.2), Vector3.new(v.x, 2.2, v.z), color, nil,
			{ transparency = 1, query = true })
		vhit:SetAttribute("Kind", "avatar")
		vhit:SetAttribute("Side", side)
		refs.vitalHit[side] = vhit

		-- Muesca grabada (misma placa que las casillas): marco redondeado, el cementerio con doble marco,
		-- y la línea del color del bando en el borde que mira a su dueño.
		local function notch(name, pos, double)
			local plate = part(name, Vector3.new(4.5, 6.1, 0.1), Vector3.new(pos.x, 0.05, pos.z), tileColor, SMOOTH, { rot = face })
			local ng = surface(plate, Enum.NormalId.Front, 450, 610, 0.5)
			local function outline(inset, thickness)
				local f = frame(ng, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(450 - inset * 2, 610 - inset * 2), BackgroundTransparency = 1 })
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, 28)
				c.Parent = f
				local st = Instance.new("UIStroke")
				st.Color = edgeColor
				st.Thickness = thickness
				st.Parent = f
			end
			outline(40, 8)
			if double then outline(90, 3) end
			bar(ng, 225, sgn == 1 and 574 or 36, 270, 10, 0, sideColor)
			return plate
		end

		-- Mazo = muesca + pila de cartas que crece, con un reverso real encima
		local d = Layout.deck(side)
		notch("MuescaMazo_" .. side, d, false)
		local stack = part("MazoPila_" .. side, Vector3.new(3.9, 0.3, 5.5), Vector3.new(d.x, 0.25, d.z), Color3.fromRGB(34, 28, 50), SMOOTH,
			{ shadow = true })
		local top = part("MazoReverso_" .. side, Vector3.new(3.9, 5.5, 0.02), Vector3.new(d.x, 0.41, d.z), Color3.fromRGB(34, 28, 50), SMOOTH,
			{ rot = face })
		local tg = surface(top, Enum.NormalId.Front, 390, 550, 0)
		local broot = frame(tg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(34, 28, 50) })
		local function diamond(size, col)
			frame(broot, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size),
				Rotation = 45, BackgroundColor3 = col })
		end
		diamond(210, Color3.fromRGB(212, 175, 85))
		diamond(176, Color3.fromRGB(20, 18, 34))
		diamond(90, color)
		refs.decks[side] = stack
		refs.deckTops[side] = top

		-- Cementerio = muesca con doble marco + pila de descartes que crece (apagada: sin cartas es solo la muesca)
		local g = Layout.graveyard(side)
		notch("MuescaCementerio_" .. side, g, true)
		refs.graveyards[side] = part("CementerioPila_" .. side, Vector3.new(3.9, 0.1, 5.5), Vector3.new(g.x, 0.15, g.z),
			shade(skin.frame, 0.55), SMOOTH, { shadow = true, transparency = 1 })

		-- Barrera baja y translúcida detrás de la Banca (aloja las grietas del Parche 3) + surco hasta el cristal
		local bz = Layout.barrierZ(side)
		local halfW = Layout.BARRIER_HALF_W
		local panel = part("Barrera_" .. side, Vector3.new(halfW * 2, 1, 0.5), Vector3.new(0, 0.5, bz), rgb(skin[side == "Self" and "allyDark" or "rivalDark"]), SMOOTH,
			{ transparency = 0.45 })
		-- Cara +Z (la que ve la cámara): franjas verticales del color del bando
		local bg = surface(panel, Enum.NormalId.Back, 1000, 40, 0)
		for i = 0, 23 do
			frame(bg, { Position = UDim2.fromOffset(i * 41.6 + 14, 0), Size = UDim2.fromOffset(8, 40), BackgroundColor3 = color,
				BackgroundTransparency = 0.25 })
		end
		part("BarreraRiel_" .. side, Vector3.new(halfW * 2 + 0.6, 0.14, 0.9), Vector3.new(0, 1.07, bz), frameColor, METAL, { shadow = true })
		refs.barriers[side] = panel

		local gz = bz + sgn * 0.55 -- el surco corre justo detrás del panel
		local x0, x1 = v.x, halfW
		local h = part("Surco_" .. side .. "_H", Vector3.new(x1 - x0, 0.06, 0.14), Vector3.new((x0 + x1) / 2, 0.03, gz), color, NEON,
			{ glow = true, transparency = 0.3 })
		local z0, z1 = gz, v.z
		local vtc = part("Surco_" .. side .. "_V", Vector3.new(0.14, 0.06, math.abs(z1 - z0)), Vector3.new(v.x, 0.03, (z0 + z1) / 2), color, NEON,
			{ glow = true, transparency = 0.3 })
		refs.grooves[side] = { h, vtc }
	end

	-- Las pilas crecen con las cartas que quedan (mazo: 40 cartas ≈ 1.5 studs) y el reverso sube con ellas
	function refs.setDeck(side, count)
		local st = refs.decks[side]
		local d = Layout.deck(side)
		local h = math.clamp(0.1 + (count or 0) * 0.035, 0.1, 1.6)
		st.Size = Vector3.new(3.9, h, 5.5)
		st.CFrame = CFrame.new(origin + Vector3.new(d.x, 0.1 + h / 2, d.z))
		refs.deckTops[side].CFrame = CFrame.new(origin + Vector3.new(d.x, 0.1 + h + 0.011, d.z)) * face
	end

	-- Pila de descartes: invisible sin cartas; con cartas crece (cada una ≈ 0.08 studs, tope 1.2)
	function refs.setGrave(side, count)
		local pile = refs.graveyards[side]
		local g = Layout.graveyard(side)
		local n = count or 0
		local h = math.clamp(0.1 + n * 0.08, 0.1, 1.2)
		pile.Transparency = n > 0 and 0 or 1
		pile.Size = Vector3.new(3.9, h, 5.5)
		pile.CFrame = CFrame.new(origin + Vector3.new(g.x, 0.1 + h / 2, g.z))
	end

	-- ── Torres en las cuatro esquinas (una sola luz cada una) ──────────────
	local stoneColor = rgb(skin.stone)
	local glowColor = rgb(skin.glow)
	for _, c in ipairs(Layout.corners()) do
		local tag = (c.x < 0 and "W" or "E") .. (c.z < 0 and "N" or "S")
		-- Fuste poligonal: tres bloques girados 0°, 30° y 60° (silueta de 12 lados)
		for k = 0, 2 do
			part("Torre_" .. tag .. k, Vector3.new(2, 3.2, 2), Vector3.new(c.x, 1.6, c.z), stoneColor, nil,
				{ rot = CFrame.Angles(0, math.rad(k * 30), 0), shadow = k == 0 })
		end
		disc("TorreCapitel_" .. tag, 2.8, 0.3, Vector3.new(c.x, 3.35, c.z), frameColor, METAL)
		local flame = part("TorreLlama_" .. tag, Vector3.new(0.9, 0.9, 0.9), Vector3.new(c.x, 4.05, c.z), glowColor, NEON,
			{ shape = Enum.PartType.Ball, glow = true })
		light(flame, glowColor, 14, 0.8)
	end

	-- ── Luciérnagas (solo calidad alta): puntos de luz que suben y se desvanecen fuera de la mesa ──
	if high then
		for i = 1, 8 do
			local a = i * 0.785 + 0.3
			local bx = (hx + 4 + (i % 3) * 1.6) * math.cos(a)
			local bz = (hz + 3 + (i % 2) * 2.2) * math.sin(a)
			local f = part("Luciernaga" .. i, Vector3.new(0.35, 0.35, 0.35), Vector3.new(bx, 1, bz), glowColor, NEON,
				{ shape = Enum.PartType.Ball, transparency = 1 })
			anim.fireflies[#anim.fireflies + 1] = { part = f, x = bx, z = bz, phase = i * 0.37 }
		end
	end

	return { folder = folder, glow = glow, glowBase = glowBase, refs = refs, anim = anim, palette = palette, skin = skin }
end

-- Iluminación clara y local (solo afecta a este cliente): ambiente alto, sol alto (no rasante),
-- bloom suave y atmósfera ligera. Devuelve una función que restaura todo lo que cambió.
function BoardBuilder.applyLighting(quality, skinName)
	local high = quality ~= "Low"
	local L = Skins.get(skinName).light
	local saved = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		ColorShift_Top = Lighting.ColorShift_Top,
		GlobalShadows = Lighting.GlobalShadows,
		ExposureCompensation = Lighting.ExposureCompensation,
	}

	-- Desactivar los efectos de post-procesado y atmósfera preexistentes del mapa
	-- (Bloom, SunRays, DepthOfField, etc.) para que no se acumulen con los de AEVUM.
		-- Se restauran al salir del tablero.
	local disabled = {}
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("PostEffect") then
			disabled[#disabled + 1] = { effect = e, wasEnabled = e.Enabled }
			e.Enabled = false
		elseif e:IsA("Atmosphere") then
			-- Atmosphere no tiene propiedad Enabled: se aparta y se vuelve a montar al restaurar.
			disabled[#disabled + 1] = { effect = e, parent = e.Parent }
			e.Parent = nil
		end
	end

	Lighting.Ambient = Skins.rgb(L.ambient)
	Lighting.OutdoorAmbient = Skins.rgb(L.outdoor)
	Lighting.Brightness = L.brightness
	Lighting.ClockTime = L.clockTime -- sol alto: sombras cortas, sin luz rasante
	Lighting.ColorShift_Top = Skins.rgb(L.shiftTop)
	Lighting.GlobalShadows = high
	Lighting.ExposureCompensation = L.exposure

	local extras = {}
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "AevumAtmosphere"
	atmosphere.Density = L.density
	atmosphere.Offset = 0
	atmosphere.Color = Skins.rgb(L.atmosphere)
	atmosphere.Decay = Skins.rgb(L.decay)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting
	extras[#extras + 1] = atmosphere

	if high then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "AevumBloom"
		bloom.Intensity = L.bloom
		bloom.Size = 20
		bloom.Threshold = 1.1
		bloom.Parent = Lighting
		extras[#extras + 1] = bloom
	end

	return function()
		for k, v in pairs(saved) do Lighting[k] = v end
		for _, e in ipairs(extras) do e:Destroy() end
		-- Reactivar los efectos del mapa que se desactivaron al entrar.
		for _, entry in ipairs(disabled) do
			local e = entry.effect
			if e.Parent == nil and entry.parent then
				e.Parent = entry.parent -- Atmosphere apartada: volver a montarla.
			elseif entry.wasEnabled ~= nil then
				e.Enabled = entry.wasEnabled -- PostEffect: restaurar su estado previo.
			end
		end
	end
end

return BoardBuilder