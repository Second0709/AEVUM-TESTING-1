--!nonstrict
-- AEVUM · Detalle grande de carta (v1.3.0)
-- Carta vertical (5:7) con nombre, costo, arte, ATK/VIDA y texto. Se dibuja en el panel derecho,
-- fijo junto al tablero: no tapa nada mientras eliges objetivos. Se alimenta de `state.inspect`
-- (cardId) y `state.inspectUid` (uid de la instancia, para mostrar ATK/VIDA actuales).
-- Sirve igual con el tablero 2D y con el 3D. Las cartas boca abajo del rival no llaman a esto.

local CardDetail = {}

local RATIO = 7 / 5 -- alto / ancho de la carta
local ATK_COLOR = Color3.fromRGB(217, 96, 63)
local HP_COLOR = Color3.fromRGB(63, 154, 95)
local DARK = Color3.fromRGB(14, 16, 30)

-- Busca la instancia viva por uid en las zonas visibles del view (la propia mano incluida)
local function findInst(view, uid)
	if not view or not uid then return nil end
	local function scan(list)
		for i = 1, #list do
			local inst = list[i]
			if inst and inst.uid == uid then return inst end
		end
		for _, inst in pairs(list) do
			if type(inst) == "table" and inst.uid == uid then return inst end
		end
		return nil
	end
	return scan(view.me.hand) or scan(view.me.bench) or scan(view.me.combat)
		or scan(view.opp.bench) or scan(view.opp.combat)
end

-- Cuántas filas de texto caben: el texto de la carta puede ser largo
local function statusLines(inst)
	local out = {}
	if inst then
		if (inst.shield or 0) > 0 then out[#out + 1] = "ESCUDO " .. inst.shield end
		if inst.stunned then out[#out + 1] = "ATURDIDA" end
		if inst.reflect then out[#out + 1] = "REFLEJO" end
	end
	return out
end

-- Dibuja el detalle dentro de `parent` (con UIListLayout). ctx: { new, cards, theme }
function CardDetail.draw(ctx, parent, state, order)
	local inst = findInst(state.view, state.inspectUid)
	local cardId = (inst and inst.cardId) or state.inspect -- si evolucionó, manda la forma actual
	local c = cardId and ctx.cards[cardId]
	if not c then return nil end
	local isCreature = c.type == "Creature"

	local width = math.max(100, parent.AbsoluteSize.X - 14)
	local frame = ctx.new("Frame", { Name = "DetalleCarta", LayoutOrder = order, BackgroundColor3 = Color3.fromRGB(34, 44, 78),
		Size = UDim2.new(1, 0, 0, math.floor(width * RATIO)), BorderSizePixel = 0 }, parent)
	ctx.new("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
	ctx.new("UIStroke", { Color = Color3.fromRGB(176, 138, 66), Thickness = 3 }, frame)

	ctx.new("TextLabel", { Name = "Nombre", Position = UDim2.fromScale(0.04, 0.015), Size = UDim2.fromScale(0.92, 0.1),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = ctx.theme.text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = c.name }, frame)
	local art = ctx.new("ImageLabel", { Name = "Arte", Position = UDim2.fromScale(0.04, 0.125), Size = UDim2.fromScale(0.92, 0.36),
		BackgroundColor3 = DARK, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop,
		Image = type(c.art) == "string" and c.art or "" }, frame)
	ctx.new("UICorner", { CornerRadius = UDim.new(0, 6) }, art)

	local cost = (inst and inst.cost) or (c.evolveFrom and c.evolveCost or c.cost)
	local kind = isCreature and "Criatura" or ("Hechizo " .. (c.speed == "Fast" and "rápido" or "lento"))
	local costText = c.evolveFrom and ("Evolución " .. cost) or ("Costo " .. cost)
	ctx.new("TextLabel", { Name = "Tipo", Position = UDim2.fromScale(0.04, 0.495), Size = UDim2.fromScale(0.92, 0.06),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = ctx.theme.sel,
		TextXAlignment = Enum.TextXAlignment.Left, Text = costText .. " · " .. kind }, frame)

	local body = c.text or ""
	local status = statusLines(inst)
	if #status > 0 then body = body .. "\n" .. table.concat(status, " · ") end
	local text = ctx.new("TextLabel", { Name = "Texto", Position = UDim2.fromScale(0.04, 0.565), Size = UDim2.fromScale(0.92, 0.27),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextScaled = true, TextWrapped = true, TextColor3 = ctx.theme.text,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = body }, frame)
	ctx.new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, text)

	if isCreature then
		local maxHp = (inst and inst.maxHp) or c.hp
		local atk = (inst and inst.atk) or c.atk
		local hp = math.max(0, maxHp - ((inst and inst.damage) or 0))
		local function stat(name, x, color, value)
			local b = ctx.new("TextLabel", { Name = name, Position = UDim2.fromScale(x, 0.86), Size = UDim2.fromScale(0.44, 0.12),
				BackgroundColor3 = color, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255), Text = tostring(value) }, frame)
			ctx.new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
			ctx.new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2 }, b)
		end
		stat("Ataque", 0.04, ATK_COLOR, "ATK " .. atk)
		stat("Vida", 0.52, HP_COLOR, "VIDA " .. hp .. "/" .. maxHp)
	end
	return frame
end

return CardDetail
