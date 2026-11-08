local Overlay = {}

function Overlay.create(parent, theme, widgets, remotes, onReturn)
	local frame = widgets.new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35, Visible = false, ZIndex = 30 }, parent)
	local text = widgets.label(frame, "", { Size = UDim2.new(0.6, 0, 0.12, 0), Position = UDim2.new(0.2, 0, 0.35, 0),
		ZIndex = 31, Font = Enum.Font.GothamBlack })
	local reason = widgets.label(frame, "", { Size = UDim2.new(0.6, 0, 0.06, 0), Position = UDim2.new(0.2, 0, 0.48, 0),
		ZIndex = 31, TextColor3 = theme.dim })
	widgets.button(frame, "Volver al menú", theme.btn, function()
		remotes.Lobby:FireServer({ type = "Leave" })
		frame.Visible = false
		onReturn()
	end, { Size = UDim2.new(0.2, 0, 0.07, 0), Position = UDim2.new(0.4, 0, 0.57, 0), ZIndex = 31 })
	return frame, text, reason
end

return Overlay
