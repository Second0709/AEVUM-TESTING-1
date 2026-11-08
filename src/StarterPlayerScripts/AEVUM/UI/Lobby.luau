local Lobby = {}

function Lobby.create(parent, theme, widgets, remotes)
	local lobby = widgets.new("Frame", { Size = UDim2.new(0, 420, 0, 320), Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = theme.panel }, parent)
	widgets.new("UICorner", { CornerRadius = UDim.new(0, 12) }, lobby)
	widgets.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }, lobby)
	widgets.new("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }, lobby)
	widgets.label(lobby, "AEVUM", { Size = UDim2.new(1, 0, 0, 50), Font = Enum.Font.GothamBlack, LayoutOrder = 1 })
	widgets.label(lobby, "v1.3.0 · 20 cartas", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = theme.dim, LayoutOrder = 2 })
	local status = widgets.label(lobby, "", { Size = UDim2.new(1, 0, 0, 28), TextColor3 = theme.sel, LayoutOrder = 3 })
	local botButton = widgets.button(lobby, "Jugar contra el Bot", theme.btn, function()
		remotes.Lobby:FireServer({ type = "PlayBot" })
	end, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 48) })
	widgets.button(lobby, "Buscar rival (2 jugadores)", theme.btn, function()
		remotes.Lobby:FireServer({ type = "Queue" })
	end, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 48) })
	widgets.button(lobby, "Cancelar búsqueda", theme.btnOff, function()
		remotes.Lobby:FireServer({ type = "Leave" })
		status.Text = ""
	end, { LayoutOrder = 6 })
	botButton.Visible = remotes:GetAttribute("BotAvailable") == true
	return lobby, status
end

return Lobby
