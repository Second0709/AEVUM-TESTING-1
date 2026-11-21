--!nonstrict
-- Tarjeta de turno emergente (sustituye a UI/Banner).
-- Entra deslizándose desde el borde derecho, se queda ~2 s y se va. NO bloquea toques (Active = false):
-- el Banner anterior cubría casi toda la pantalla con Active = true y se tragaba los toques.
local TurnCard = {}

TurnCard.REST_X = 0.825 -- borde derecho de la tarjeta en reposo: justo a la izquierda de la columna derecha (empieza en 0.835)
TurnCard.TOP_Y = 0.09 -- parte alta de la zona del tablero
TurnCard.SLIDE = 0.3 -- segundos de entrada y de salida
TurnCard.TOTAL = 2.0 -- segundos desde que aparece hasta que desaparece

-- Lógica pura (se prueba sin Roblox). attackerIdx == you → es mi turno; attackOpen → ya se puede atacar.
function TurnCard.texts(view)
	local mine = view.attackerIdx == view.you
	local title = mine and "Tu turno" or "Turno enemigo"
	local sub = nil
	if view.attackOpen then sub = mine and "¡Al ataque!" or "¡A defender!" end
	return { mine = mine, title = title, sub = sub, full = sub and (title .. " " .. sub) or title }
end

function TurnCard.create(parent, new, tweenService)
	local token = 0
	local tweens = {}
	local offX = 1.4 -- fuera de pantalla por la derecha
	local frame = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(offX, 0, TurnCard.TOP_Y, 0),
		Size = UDim2.new(0.2, 0, 0.1, 0), BackgroundColor3 = Color3.fromRGB(18, 48, 105), BackgroundTransparency = 0.08,
		Visible = false, ZIndex = 15, Active = false }, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
	new("UISizeConstraint", { MinSize = Vector2.new(150, 44), MaxSize = Vector2.new(340, 96) }, frame)
	local stroke = new("UIStroke", { Color = Color3.fromRGB(110, 170, 255), Thickness = 2 }, frame)
	local title = new("TextLabel", { Position = UDim2.new(0.06, 0, 0, 0), Size = UDim2.new(0.88, 0, 1, 0),
		BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack,
		TextScaled = true, Text = "", ZIndex = 16, Active = false }, frame)
	new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 10 }, title)
	local subtitle = new("TextLabel", { Position = UDim2.new(0.06, 0, 0.55, 0), Size = UDim2.new(0.88, 0, 0.36, 0),
		BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 232, 160), Font = Enum.Font.GothamBold,
		TextScaled = true, Text = "", ZIndex = 16, Active = false }, frame)
	new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 8 }, subtitle)

	local function hide()
		token += 1
		for _, tween in ipairs(tweens) do tween:Cancel() end
		tweens = {}
		frame.Visible = false
	end

	local function slideTo(x)
		local tween = tweenService:Create(frame, TweenInfo.new(TurnCard.SLIDE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(x, 0, TurnCard.TOP_Y, 0) })
		tweens[#tweens + 1] = tween
		tween:Play()
	end

	local function show(view)
		hide()
		local current = token
		local t = TurnCard.texts(view)
		-- azul = tú, rojo coral = rival
		frame.BackgroundColor3 = t.mine and Color3.fromRGB(18, 48, 105) or Color3.fromRGB(122, 34, 44)
		stroke.Color = t.mine and Color3.fromRGB(110, 170, 255) or Color3.fromRGB(255, 125, 112)
		title.Text = t.title
		subtitle.Text = t.sub or ""
		subtitle.Visible = t.sub ~= nil
		title.Size = t.sub and UDim2.new(0.88, 0, 0.5, 0) or UDim2.new(0.88, 0, 1, 0)
		frame.Position = UDim2.new(offX, 0, TurnCard.TOP_Y, 0)
		frame.Visible = true
		slideTo(TurnCard.REST_X)
		task.delay(TurnCard.TOTAL - TurnCard.SLIDE, function()
			if current ~= token then return end
			slideTo(offX)
		end)
		task.delay(TurnCard.TOTAL, function()
			if current == token then frame.Visible = false end
		end)
	end

	return hide, show, frame
end

return TurnCard
