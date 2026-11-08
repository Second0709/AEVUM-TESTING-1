local Banner = {}

function Banner.create(parent, new, tweenService)
	local token = 0
	local tweens = {}
	local frame = new("Frame", { Position = UDim2.new(0.2, 0, 0.06, 0), Size = UDim2.new(0.6, 0, 0.94, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 15, Active = true }, parent)
	local title = new("TextLabel", { Position = UDim2.new(0, 0, 0.36, 0), Size = UDim2.new(1, 0, 0.18, 0),
		BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack,
		TextScaled = true, Text = "", ZIndex = 16 }, frame)
	new("UITextSizeConstraint", { MaxTextSize = 72, MinTextSize = 16 }, title)
	local subtitle = new("TextLabel", { Position = UDim2.new(0, 0, 0.55, 0), Size = UDim2.new(1, 0, 0.06, 0),
		BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(220, 225, 240), Font = Enum.Font.Gotham,
		TextScaled = true, Text = "", ZIndex = 16 }, frame)
	new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 10 }, subtitle)

	local function hide()
		token += 1
		for _, tween in ipairs(tweens) do tween:Cancel() end
		tweens = {}
		frame.Visible = false
	end

	local function show(view)
		hide()
		local currentToken = token
		local mineTurn = view.attackerIdx == view.you
		frame.BackgroundColor3 = mineTurn and Color3.fromRGB(18, 48, 105) or Color3.fromRGB(95, 26, 32)
		title.Text = mineTurn and "Tu turno" or "Turno rival"
		if not view.attackOpen then subtitle.Text = ("Turno %d · Apertura: sin ataques ni evoluciones"):format(view.turn)
		elseif mineTurn then subtitle.Text = ("Turno %d · Atacas este turno"):format(view.turn)
		else subtitle.Text = ("Turno %d · El rival ataca este turno"):format(view.turn) end
		frame.BackgroundTransparency = 0.05
		title.TextTransparency = 0
		subtitle.TextTransparency = 0.15
		frame.Visible = true
		task.delay(1.1, function()
			if currentToken ~= token then return end
			local info = TweenInfo.new(0.35)
			tweens = {
				tweenService:Create(frame, info, { BackgroundTransparency = 1 }),
				tweenService:Create(title, info, { TextTransparency = 1 }),
				tweenService:Create(subtitle, info, { TextTransparency = 1 }),
			}
			for _, tween in ipairs(tweens) do tween:Play() end
			task.delay(0.35, function() if currentToken == token then frame.Visible = false end end)
		end)
	end

	return hide, show
end

return Banner
