local LeftPanel = {}

function LeftPanel.create(ctx)
	local function makeSword(parent)
		local box = ctx.new("Frame", { Size = UDim2.new(0, 36, 0, 36), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1, Rotation = 45, ZIndex = 6 }, parent)
		local function part(x, y, w, h, color, radius)
			local frame = ctx.new("Frame", { Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h),
				BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 6 }, box)
			if radius then ctx.new("UICorner", { CornerRadius = UDim.new(0, radius) }, frame) end
		end
		part(15, 0, 6, 22, Color3.fromRGB(225, 230, 245), 3)
		part(17, 3, 2, 17, Color3.fromRGB(150, 160, 190))
		part(9, 22, 18, 4, Color3.fromRGB(240, 190, 60), 2)
		part(16, 26, 4, 6, Color3.fromRGB(120, 80, 50))
		part(14, 32, 8, 3, Color3.fromRGB(240, 190, 60), 1)
	end

	return function()
		local view = ctx.getView()
		ctx.clear(ctx.parent)
		local me, opp = view.me, view.opp
		local function avatar(side, data, order)
			local target = ctx.isTarget(side, "Avatar", 0, nil)
			local who = side == "Self" and ("TÚ · " .. data.name) or ("RIVAL · " .. data.name)
			local isAttacker = view.attackOpen and ((side == "Self") == (view.attackerIdx == view.you))
			local wrap = ctx.new("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1, LayoutOrder = order }, ctx.parent)
			local reflectTag = data.reflect and " · REFLEJO" or ""
			ctx.cardBtn(wrap, UDim2.new(0.8, -2, 1, 0), ("%s\nVIDA %d" .. ((data.shield or 0) > 0 and (" · ESCUDO " .. data.shield) or "") .. reflectTag .. "\nEnergía %d/%d · Reserva %d\nMazo %d · Mano %s"):format(
				who, data.hp, data.energy, data.maxEnergy, data.reserve, data.deck,
				tostring(type(data.hand) == "table" and #data.hand or data.hand)),
				ctx.theme.card, function() if not ctx.tryTarget(side, "Avatar", 0, nil) then ctx.render() end end,
				target and ctx.theme.tgt or (isAttacker and ctx.theme.atk or nil))
			if isAttacker then
				local box = ctx.new("Frame", { Position = UDim2.new(0.8, 0, 0, 0), Size = UDim2.new(0.2, 0, 1, 0), BackgroundTransparency = 1 }, wrap)
				makeSword(box)
			end
		end
		avatar("Enemy", opp, 1)
		avatar("Self", me, 3)
		local log = ctx.label(ctx.parent, table.concat(view.log, "\n"), { Size = UDim2.new(1, 0, 1, -170), LayoutOrder = 4,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = ctx.theme.dim,
			TextScaled = false, TextSize = 12 })
		log.TextTruncate = Enum.TextTruncate.None
	end
end

return LeftPanel
