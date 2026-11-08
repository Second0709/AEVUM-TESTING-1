local LeftPanel = {}

function LeftPanel.create(ctx)
	return function()
		local view = ctx.getView()
		ctx.clear(ctx.parent)

		local heading = ctx.label(ctx.parent, "REGISTRO", {
			Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(77, 225, 255),
		})
		heading.TextScaled = true

		local function pilePanel(title, data, accent, order)
			local panel = ctx.new("Frame", {
				Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = Color3.fromRGB(20, 27, 62),
				BackgroundTransparency = 0.1, LayoutOrder = order,
			}, ctx.parent)
			ctx.new("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
			ctx.new("UIStroke", { Color = accent, Thickness = 1.2 }, panel)
			ctx.label(panel, title, {
				Position = UDim2.new(0.06, 0, 0.08, 0), Size = UDim2.new(0.88, 0, 0, 20),
				TextColor3 = accent, Font = Enum.Font.GothamBold,
			})
			ctx.label(panel, ("Mazo  %d\nCementerio  %d"):format(data.deck, #data.graveyard), {
				Position = UDim2.new(0.06, 0, 0.35, 0), Size = UDim2.new(0.88, 0, 0.55, 0),
				TextColor3 = Color3.fromRGB(234, 240, 255), TextXAlignment = Enum.TextXAlignment.Left,
			})
		end

		pilePanel("RIVAL", view.opp, Color3.fromRGB(255, 107, 214), 2)
		pilePanel("TÚ", view.me, Color3.fromRGB(77, 225, 255), 3)

		ctx.label(ctx.parent, "EVENTOS", {
			Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 4, Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(143, 156, 196),
		})
		local log = ctx.label(ctx.parent, table.concat(view.log, "\n"), {
			Size = UDim2.new(1, 0, 0, 260), LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(143, 156, 196),
			TextScaled = false, TextSize = 12,
		})
		log.TextTruncate = Enum.TextTruncate.None
	end
end

return LeftPanel
