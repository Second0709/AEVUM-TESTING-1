local Pause = {}

function Pause.create(parent, theme, widgets, remotes)
	local button = widgets.new("TextButton", {
		Size = UDim2.new(0, 140, 0, 40),
		Position = UDim2.new(1, -150, 0, 10),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		TextColor3 = theme.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Text = "PAUSAR",
		Visible = false,
		ZIndex = 50,
		AutoButtonColor = true,
	}, parent)
	widgets.new("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
	widgets.new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 8 }, button)
	button.Activated:Connect(function()
		remotes.Lobby:FireServer({ type = "DebugPause" })
	end)
	return button
end

return Pause
