--!nonstrict
-- AEVUM · Carta 3D (v1.3.0)
-- Una carta es un Model reutilizable (pool): cuerpo de oro, cara frontal mínima con SurfaceGui
-- (arte a todo el alto + ATK abajo a la izquierda + VIDA abajo a la derecha + etiqueta corta de estado),
-- reverso con rombo del color del bando y un anillo de resalte. Sin nombre, costo ni descripción:
-- eso se ve en el detalle al tocar (UI/CardDetail).
-- La carta se orienta con el estado de Motion: { x, y, z, flip, tilt, scale }.
--   Frente = cara superior (+Y). flip = pi la deja boca abajo (se ve el reverso).
--
-- ORIENTACIÓN DETERMINISTA de las caras. Las caras viven en piezas finas con Size (ancho, alto, grosor)
-- y el SurfaceGui va en la cara Front/Back, cuya orientación es conocida (no la cara Top):
--   Front: normal -Z, "arriba" del lienzo = +Y de la pieza, "derecha" = -X de la pieza.
-- Giramos la pieza con Ry(FACE_YAW) * Rx(90°):
--   Rx(90°): la normal pasa de -Z a +Y (mira al cielo) y el "arriba" pasa de +Y a +Z.
--   Ry(180°): el "arriba" pasa a -Z (lo que lee la cámara en +Z) y la "derecha" a +X.
-- Resultado: texto derecho y sin espejo para el jugador local, tanto en tus cartas como en las
-- reveladas del rival (ninguna carta recibe giro por bando: todas leen hacia +Z).
-- El reverso (cara Back) usa el mismo giro: su normal pasa a -Y y, con flip = pi, queda arriba.
-- Si en Studio el texto saliera al revés, cambia CardView.FACE_YAW a 0 (antes de crear el pool).

local Motion = require(script.Parent.Motion)
local Layout = require(script.Parent.Layout)

local CardView = {}

CardView.FACE_YAW = math.pi

local GOLD = Color3.fromRGB(176, 138, 66)
local CANVAS = Vector2.new(370, 530) -- píxeles de la cara (relación = cara física 3.7 x 5.3 studs)

local COLORS = {
	creature = Color3.fromRGB(34, 44, 78),
	spell = Color3.fromRGB(110, 70, 150),
	atk = Color3.fromRGB(217, 96, 63), -- ATK normal
	hp = Color3.fromRGB(63, 154, 95), -- VIDA normal
	better = Color3.fromRGB(214, 160, 40), -- por encima de la base (mejora)
	worse = Color3.fromRGB(122, 48, 56), -- por debajo de la base / dañada
	dark = Color3.fromRGB(14, 16, 30),
	text = Color3.fromRGB(240, 240, 250),
	Self = Color3.fromRGB(77, 225, 255),
	Enemy = Color3.fromRGB(255, 90, 170),
}

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function cardPart(name, size, cframe, color, material, parent)
	return mk("Part", {
		Name = name, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = true, CastShadow = false,
		Size = size, Color = color, Material = material, TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth, CFrame = cframe,
	}, parent)
end

-- Insignia de estadística: recuadro de color con el número enorme (lo importante a distancia)
local function badge(parent, name, x, color)
	local f = mk("Frame", { Name = name, Position = UDim2.fromOffset(x, 404), Size = UDim2.fromOffset(150, 118),
		BackgroundColor3 = color, BorderSizePixel = 6, BorderColor3 = Color3.fromRGB(255, 255, 255),
		BorderMode = Enum.BorderMode.Inset, ZIndex = 3 }, parent)
	local v = mk("TextLabel", { Name = "Valor", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		TextColor3 = COLORS.text, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "", ZIndex = 4,
		TextStrokeTransparency = 0.2, TextStrokeColor3 = COLORS.dark }, f)
	return f, v
end

local function buildModel(quality)
	local W, D = Layout.CARD.w, Layout.CARD.d
	local model = Instance.new("Model")
	model.Name = "Carta"

	-- Giro que deja la normal de Front hacia +Y y el "arriba" del lienzo hacia -Z (ver cabecera)
	local face = CFrame.Angles(0, CardView.FACE_YAW, 0) * CFrame.Angles(math.pi / 2, 0, 0)

	local body = cardPart("Cuerpo", Vector3.new(W, 0.22, D), CFrame.new(0, 0, 0), GOLD, Enum.Material.Metal, model)
	-- Pieza fina (ancho, alto, grosor): al girarla, su "alto" queda a lo largo de Z de la carta
	local thin = Vector3.new(W - 0.3, D - 0.3, 0.02)
	local front = cardPart("Frente", thin, CFrame.new(0, 0.12, 0) * face, COLORS.creature, Enum.Material.SmoothPlastic, model)
	local back = cardPart("Reverso", thin, CFrame.new(0, -0.12, 0) * face, Color3.fromRGB(34, 28, 50),
		Enum.Material.SmoothPlastic, model)
	model.PrimaryPart = body

	-- ── Cara frontal mínima ──
	local fg = mk("SurfaceGui", { Name = "Cara", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = CANVAS, LightInfluence = 0, Brightness = 1.15, AlwaysOnTop = false }, front)
	local root = mk("Frame", { Name = "Raiz", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.creature,
		BorderSizePixel = 0 }, fg)
	local art = mk("ImageLabel", { Name = "Arte", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.dark,
		BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, Image = "", ZIndex = 1 }, root)
	local tag = mk("TextLabel", { Name = "Estado", Size = UDim2.fromOffset(370, 58), BackgroundColor3 = COLORS.dark,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, TextColor3 = COLORS.text, Font = Enum.Font.GothamBold,
		TextScaled = true, TextWrapped = false, Text = "", Visible = false, ZIndex = 5 }, root)
	local atkBadge, atkValue = badge(root, "Ataque", 8, COLORS.atk)
	local hpBadge, hpValue = badge(root, "Vida", 212, COLORS.hp)
	local spell = mk("TextLabel", { Name = "Hechizo", Position = UDim2.fromOffset(8, 440), Size = UDim2.fromOffset(354, 82),
		BackgroundColor3 = COLORS.spell, BorderSizePixel = 6, BorderColor3 = Color3.fromRGB(255, 255, 255),
		BorderMode = Enum.BorderMode.Inset, TextColor3 = COLORS.text, Font = Enum.Font.GothamBlack, TextScaled = true,
		Text = "", Visible = false, ZIndex = 3 }, root)

	-- ── Reverso: marco de oro y rombo del color del bando ──
	local bg = mk("SurfaceGui", { Name = "Cara", Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = CANVAS, LightInfluence = 0, Brightness = 1.1 }, back)
	local broot = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(34, 28, 50),
		BorderSizePixel = 14, BorderColor3 = GOLD, BorderMode = Enum.BorderMode.Inset }, bg)
	mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(210, 210), Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0 }, broot)
	mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(176, 176), Rotation = 45, BackgroundColor3 = Color3.fromRGB(20, 18, 34), BorderSizePixel = 0,
		ZIndex = 2 }, broot)
	local core = mk("Frame", { Name = "Nucleo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(90, 90), Rotation = 45, BackgroundColor3 = COLORS.Self, BorderSizePixel = 0, ZIndex = 3 }, broot)

	-- ── Anillo de resalte ──
	local ring = mk("SelectionBox", { Name = "Anillo", Adornee = body, LineThickness = 0.07, Visible = false,
		Color3 = COLORS.text, SurfaceColor3 = COLORS.text, SurfaceTransparency = 0.82 }, model)

	return {
		model = model, body = body, front = front, back = back, ring = ring, core = core,
		ui = { root = root, art = art, tag = tag, atkBadge = atkBadge, atk = atkValue, hpBadge = hpBadge, hp = hpValue,
			spell = spell },
	}
end

-- Crea un pool de cartas dentro de `folder` (Instance). cardsDb: CardDatabase.Data
function CardView.newPool(folder, cardsDb, quality)
	local pool = { free = {}, folder = folder, cards = cardsDb, quality = quality }

	function pool.acquire()
		local card = table.remove(pool.free)
		if not card then
			card = buildModel(quality)
			card.s = Motion.newState()
			card.track = Motion.newTrack(card.s)
		end
		card.uid = nil
		card.cardId = nil
		card.contentKey = nil
		card.tagKey = nil
		card.faceUp = true
		card.selected = false
		card.bob = 0
		card.appliedScale = 1
		card.model:ScaleTo(1)
		card.ring.Visible = false
		Motion.stop(card.track)
		card.model.Parent = folder
		return card
	end

	function pool.release(card)
		Motion.stop(card.track)
		card.ring.Visible = false
		card.model:SetAttribute("Uid", nil)
		card.model.Parent = nil
		table.insert(pool.free, card)
	end

	return pool
end

-- Estado de Motion -> posición en el mundo. origin: Vector3 del centro de la mesa.
function CardView.apply(card, origin, bobY)
	local s = card.s
	local cf = CFrame.new(origin.X + s.x, origin.Y + s.y + (bobY or 0), origin.Z + s.z)
		* CFrame.Angles(s.tilt, 0, 0) * CFrame.Angles(0, 0, s.flip)
	card.model:PivotTo(cf)
	if math.abs(s.scale - card.appliedScale) > 0.002 then
		card.appliedScale = s.scale
		card.model:ScaleTo(math.max(s.scale, 0.05))
	end
end

-- Color del núcleo del reverso (cian = jugador, rosa = rival)
function CardView.setSide(card, side)
	card.core.BackgroundColor3 = COLORS[side] or COLORS.Self
end

-- Contenido de la cara frontal. inst es la instancia del view (puede ser nil: solo plantilla de la carta).
-- Solo lo esencial: arte + ATK + VIDA (o "HECHIZO"). Nombre, costo y texto van en el detalle al tocar.
function CardView.setContent(card, cardsDb, cardId, inst)
	local c = cardsDb[cardId]
	if not c then return end
	local atk, hp, maxHp
	if c.type == "Creature" then
		maxHp = (inst and inst.maxHp) or c.hp
		atk = (inst and inst.atk) or c.atk
		hp = math.max(0, maxHp - ((inst and inst.damage) or 0))
	end
	local key = table.concat({ cardId, tostring(atk), tostring(hp), tostring(maxHp) }, "|")
	if card.contentKey == key then return end
	card.contentKey = key
	card.cardId = cardId

	local ui = card.ui
	local isCreature = c.type == "Creature"
	local base = isCreature and COLORS.creature or COLORS.spell
	ui.root.BackgroundColor3 = base
	card.front.Color = base
	ui.art.Image = type(c.art) == "string" and c.art or ""
	ui.atkBadge.Visible = isCreature
	ui.hpBadge.Visible = isCreature
	ui.spell.Visible = not isCreature
	if isCreature then
		ui.atk.Text = tostring(atk)
		ui.atkBadge.BackgroundColor3 = (atk > c.atk) and COLORS.better or ((atk < c.atk) and COLORS.worse or COLORS.atk)
		ui.hp.Text = tostring(hp)
		ui.hpBadge.BackgroundColor3 = (hp < maxHp) and COLORS.worse or ((maxHp > c.hp) and COLORS.better or COLORS.hp)
	else
		ui.spell.Text = c.speed == "Fast" and "HECHIZO · RÁPIDO" or "HECHIZO · LENTO"
	end
end

-- Etiqueta corta de estado ("ATACA", "BLOQUEA", "[lista]", "[en preparación]"…). nil/"" la oculta.
function CardView.setTag(card, text, color)
	text = text or ""
	local key = text .. tostring(color)
	if card.tagKey == key then return end
	card.tagKey = key
	card.ui.tag.Visible = text ~= ""
	card.ui.tag.Text = text
	card.ui.tag.BackgroundColor3 = color or COLORS.dark
end

-- Anillo de resalte (selección, objetivo, atacante…). nil lo apaga.
function CardView.setRing(card, color)
	if color then
		card.ring.Color3 = color
		card.ring.SurfaceColor3 = color
		card.ring.Visible = true
	else
		card.ring.Visible = false
	end
end

CardView.Colors = COLORS

return CardView
