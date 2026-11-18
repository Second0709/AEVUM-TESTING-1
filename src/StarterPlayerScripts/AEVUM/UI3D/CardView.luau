--!nonstrict
-- AEVUM · Carta 3D (v1.3.0)
-- Una carta es un Model reutilizable (pool): cuerpo de oro, cara frontal con SurfaceGui (arte,
-- nombre, costo, ATK/VIDA, estado), reverso con glifo y un anillo de resalte.
-- La carta se orienta con el estado de Motion: { x, y, z, flip, tilt, scale }.
--   Frente = cara superior (+Y). flip = pi la deja boca abajo (se ve el reverso).
-- Convención de SurfaceGui: en la cara Top el "arriba" del texto apunta a -Z, que es el sentido
-- en que lee el jugador local (cámara en +Z). Si en Studio el texto saliera al revés,
-- cambia CardView.FRONT_ROTATION a 180.

local Motion = require(script.Parent.Motion)
local Layout = require(script.Parent.Layout)

local CardView = {}

CardView.FRONT_ROTATION = 0

local GOLD = Color3.fromRGB(176, 138, 66)
local CANVAS = Vector2.new(370, 530) -- píxeles de la cara (relación = cara 3.7 x 5.3 studs)

local COLORS = {
	creature = Color3.fromRGB(34, 44, 78),
	spell = Color3.fromRGB(70, 42, 96),
	atk = Color3.fromRGB(176, 52, 52),
	hp = Color3.fromRGB(46, 130, 78),
	cost = Color3.fromRGB(214, 170, 78),
	dark = Color3.fromRGB(14, 16, 30),
	text = Color3.fromRGB(240, 240, 250),
	good = Color3.fromRGB(120, 230, 140),
	bad = Color3.fromRGB(255, 120, 110),
	Self = Color3.fromRGB(77, 225, 255),
	Enemy = Color3.fromRGB(255, 90, 170),
}

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function cardPart(name, size, pos, color, material, parent)
	return mk("Part", {
		Name = name, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = true, CastShadow = false,
		Size = size, Color = color, Material = material, TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth, CFrame = CFrame.new(pos),
	}, parent)
end

local function label(parent, props)
	local base = { BackgroundTransparency = 1, TextColor3 = COLORS.text, Font = Enum.Font.GothamBold, TextScaled = true,
		TextWrapped = true, Text = "" }
	for k, v in pairs(props) do base[k] = v end
	return mk("TextLabel", base, parent)
end

local function buildModel(quality)
	local W, D = Layout.CARD.w, Layout.CARD.d
	local model = Instance.new("Model")
	model.Name = "Carta"

	local body = cardPart("Cuerpo", Vector3.new(W, 0.22, D), Vector3.new(0, 0, 0), GOLD, Enum.Material.Metal, model)
	local front = cardPart("Frente", Vector3.new(W - 0.3, 0.02, D - 0.3), Vector3.new(0, 0.12, 0), COLORS.creature,
		Enum.Material.SmoothPlastic, model)
	local back = cardPart("Reverso", Vector3.new(W - 0.3, 0.02, D - 0.3), Vector3.new(0, -0.12, 0), Color3.fromRGB(34, 28, 50),
		Enum.Material.SmoothPlastic, model)
	model.PrimaryPart = body

	-- ── Cara frontal ──
	local fg = mk("SurfaceGui", { Name = "Cara", Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = CANVAS, LightInfluence = 0, Brightness = 1.15, AlwaysOnTop = false }, front)
	local root = mk("Frame", { Name = "Raiz", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.creature,
		BorderSizePixel = 0, Rotation = CardView.FRONT_ROTATION }, fg)
	local art = mk("ImageLabel", { Name = "Arte", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(350, 300),
		BackgroundColor3 = COLORS.dark, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, Image = "" }, root)
	local nameBar = mk("Frame", { Name = "NombreBarra", Position = UDim2.fromOffset(10, 262), Size = UDim2.fromOffset(350, 48),
		BackgroundColor3 = COLORS.dark, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, root)
	local nameLabel = label(nameBar, { Name = "Nombre", Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 1, -4) })
	mk("UITextSizeConstraint", { MaxTextSize = 34, MinTextSize = 14 }, nameLabel)
	local costBadge = mk("Frame", { Name = "Costo", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = COLORS.cost, BorderSizePixel = 0 }, root)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, costBadge)
	mk("UIStroke", { Color = COLORS.dark, Thickness = 4 }, costBadge)
	local costLabel = label(costBadge, { Name = "Valor", Size = UDim2.fromScale(1, 1), TextColor3 = COLORS.dark,
		Font = Enum.Font.GothamBlack })
	mk("UITextSizeConstraint", { MaxTextSize = 64, MinTextSize = 20 }, costLabel)

	local tagBar = mk("Frame", { Name = "EstadoBarra", Position = UDim2.fromOffset(10, 318), Size = UDim2.fromOffset(350, 54),
		BackgroundColor3 = COLORS.dark, BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false }, root)
	local tagLabel = label(tagBar, { Name = "Estado", Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 1, -4) })
	mk("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 14 }, tagLabel)

	local statRow = mk("Frame", { Name = "Stats", Position = UDim2.fromOffset(10, 384), Size = UDim2.fromOffset(350, 126),
		BackgroundTransparency = 1 }, root)
	local function badge(name, x, color, title)
		local f = mk("Frame", { Name = name, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(168, 126),
			BackgroundColor3 = color, BorderSizePixel = 0 }, statRow)
		mk("UICorner", { CornerRadius = UDim.new(0, 14) }, f)
		mk("UIStroke", { Color = COLORS.dark, Thickness = 4 }, f)
		label(f, { Name = "Titulo", Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 30), Text = title,
			TextColor3 = Color3.fromRGB(255, 235, 215) })
		local v = label(f, { Name = "Valor", Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -34),
			Font = Enum.Font.GothamBlack })
		mk("UITextSizeConstraint", { MaxTextSize = 100, MinTextSize = 30 }, v)
		return f, v
	end
	local atkBadge, atkValue = badge("Ataque", 0, COLORS.atk, "ATK")
	local hpBadge, hpValue = badge("Vida", 182, COLORS.hp, "VIDA")
	local spellLabel = label(statRow, { Name = "Hechizo", Size = UDim2.fromScale(1, 1), Visible = false,
		BackgroundTransparency = 0, BackgroundColor3 = COLORS.dark })
	mk("UICorner", { CornerRadius = UDim.new(0, 14) }, spellLabel)

	-- ── Reverso: marco de oro y rombo del color del bando ──
	local bg = mk("SurfaceGui", { Name = "Cara", Face = Enum.NormalId.Bottom, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = CANVAS, LightInfluence = 0, Brightness = 1.1 }, back)
	local broot = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(34, 28, 50), BorderSizePixel = 0 }, bg)
	mk("UIStroke", { Color = GOLD, Thickness = 10 }, broot)
	local outer = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(210, 210), Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0 }, broot)
	local inner = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(176, 176), Rotation = 45, BackgroundColor3 = Color3.fromRGB(20, 18, 34), BorderSizePixel = 0 }, broot)
	local core = mk("Frame", { Name = "Nucleo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(90, 90), Rotation = 45, BackgroundColor3 = COLORS.Self, BorderSizePixel = 0 }, broot)

	-- ── Anillo de resalte ──
	local ring = mk("SelectionBox", { Name = "Anillo", Adornee = body, LineThickness = 0.07, Visible = false,
		Color3 = COLORS.text, SurfaceColor3 = COLORS.text, SurfaceTransparency = 0.82 }, model)

	return {
		model = model, body = body, front = front, back = back, ring = ring, core = core,
		ui = { root = root, art = art, name = nameLabel, cost = costLabel, tagBar = tagBar, tag = tagLabel,
			atkBadge = atkBadge, atk = atkValue, hpBadge = hpBadge, hp = hpValue, spell = spellLabel },
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
function CardView.setContent(card, cardsDb, cardId, inst)
	local c = cardsDb[cardId]
	if not c then return end
	local atk, hp, maxHp, cost
	if c.type == "Creature" then
		maxHp = (inst and inst.maxHp) or c.hp
		atk = (inst and inst.atk) or c.atk
		hp = math.max(0, maxHp - ((inst and inst.damage) or 0))
	end
	cost = (inst and inst.cost) or (c.evolveFrom and c.evolveCost or c.cost)
	local key = table.concat({ cardId, tostring(atk), tostring(hp), tostring(maxHp), tostring(cost) }, "|")
	if card.contentKey == key then return end
	card.contentKey = key
	card.cardId = cardId

	local ui = card.ui
	local isCreature = c.type == "Creature"
	local base = isCreature and COLORS.creature or COLORS.spell
	ui.root.BackgroundColor3 = base
	card.front.Color = base
	ui.art.Image = type(c.art) == "string" and c.art or ""
	ui.name.Text = c.name
	ui.cost.Text = tostring(cost)
	ui.atkBadge.Visible = isCreature
	ui.hpBadge.Visible = isCreature
	ui.spell.Visible = not isCreature
	if isCreature then
		ui.atk.Text = tostring(atk)
		ui.atk.TextColor3 = (atk > c.atk) and COLORS.good or ((atk < c.atk) and COLORS.bad or COLORS.text)
		ui.hp.Text = tostring(hp)
		ui.hp.TextColor3 = (hp < maxHp) and COLORS.bad or ((maxHp > c.hp) and COLORS.good or COLORS.text)
	else
		ui.spell.Text = c.speed == "Fast" and "HECHIZO · RÁPIDO" or "HECHIZO · LENTO"
	end
end

-- Franja de estado ("ATACA", "[en preparación]", "ESCUDO 2"…). nil/"" la oculta.
function CardView.setTag(card, text, color)
	text = text or ""
	local key = text .. tostring(color)
	if card.tagKey == key then return end
	card.tagKey = key
	card.ui.tagBar.Visible = text ~= ""
	card.ui.tag.Text = text
	card.ui.tagBar.BackgroundColor3 = color or COLORS.dark
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
