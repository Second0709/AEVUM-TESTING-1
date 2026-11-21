--!nonstrict
-- Cronómetro pequeño arriba a la derecha (sustituye a la barra superior).
-- El tiempo es de QUIEN TIENE LA PRIORIDAD, no siempre del jugador:
--   tu prioridad → normal; en los últimos 5 s → rojo y pulsando
--   prioridad del rival → sigue contando, atenuado
--   pausa → símbolo de pausa · partida terminada → oculto
local Timer = {}

Timer.URGENT_AT = 5 -- segundos
Timer.RIGHT_X = 0.985
Timer.TOP_Y = 0.015

-- Lógica pura (se prueba sin Roblox). `recvAt` = instante (os.clock) en que llegó la vista.
function Timer.state(view, now, recvAt)
	if not view or view.over then return { mode = "hidden" } end
	if view.paused then return { mode = "paused" } end
	local w = view.waiting
	if not w or w.timeLeft == nil then return { mode = "hidden" } end
	local seconds = math.max(0, math.ceil(w.timeLeft - (now - recvAt)))
	local mine = w.player == view.you
	local mode = "normal"
	if not mine then mode = "dim"
	elseif seconds <= Timer.URGENT_AT then mode = "urgent" end
	return { mode = mode, seconds = seconds, mine = mine }
end

-- Devuelve la función `update(state, now)` que pinta el estado calculado por Timer.state.
function Timer.create(parent, new)
	local root = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(Timer.RIGHT_X, 0, Timer.TOP_Y, 0),
		Size = UDim2.new(0.07, 0, 0.055, 0), BackgroundColor3 = Color3.fromRGB(13, 18, 48), BackgroundTransparency = 0.15,
		Visible = false, ZIndex = 12, Active = false }, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, root)
	new("UISizeConstraint", { MinSize = Vector2.new(56, 30), MaxSize = Vector2.new(96, 46) }, root)
	local stroke = new("UIStroke", { Color = Color3.fromRGB(42, 53, 104), Thickness = 1.5 }, root)
	local scale = new("UIScale", { Scale = 1 }, root)
	local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
		TextScaled = true, Text = "", TextColor3 = Color3.fromRGB(77, 225, 255), ZIndex = 13, Active = false }, root)
	new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }, label)
	new("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0) }, label)
	-- símbolo de pausa: dos barras (un emoji o ⏸ puede no existir en la fuente)
	local bars = {}
	for i = 1, 2 do
		bars[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i == 1 and 0.42 or 0.58, 0.5),
			Size = UDim2.fromScale(0.09, 0.5), BackgroundColor3 = Color3.fromRGB(255, 214, 102), BorderSizePixel = 0,
			Visible = false, ZIndex = 13, Active = false }, root)
	end

	return function(st, now)
		if st.mode == "hidden" then root.Visible = false return end
		root.Visible = true
		local paused = st.mode == "paused"
		label.Visible = not paused
		for _, b in ipairs(bars) do b.Visible = paused end
		scale.Scale = 1
		root.BackgroundTransparency = 0.15
		stroke.Color = Color3.fromRGB(42, 53, 104)
		stroke.Transparency = 0
		label.TextTransparency = 0
		label.TextColor3 = Color3.fromRGB(77, 225, 255)
		if paused then return end
		label.Text = tostring(st.seconds)
		if st.mode == "dim" then
			root.BackgroundTransparency = 0.55
			stroke.Transparency = 0.6
			label.TextTransparency = 0.55
		elseif st.mode == "urgent" then
			label.TextColor3 = Color3.fromRGB(255, 92, 92)
			stroke.Color = Color3.fromRGB(255, 92, 92)
			scale.Scale = 1 + 0.1 * (0.5 + 0.5 * math.sin(now * 10))
		end
	end
end

return Timer
