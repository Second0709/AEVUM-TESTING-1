local Hand = {}

-- ctx.register(uid, instancia)  guarda el botón (o su hueco) para que el tablero 3D sepa dónde está cada carta.
-- ctx.isHidden(uid)             true mientras la carta 3D todavía está volando hacia la mano: se deja un hueco.
function Hand.create(ctx)
	return function()
		local state = ctx.getState()
		ctx.clear(ctx.parent)
		for idx, inst in ipairs(state.view.me.hand) do
			local widget
			if ctx.isHidden and ctx.isHidden(inst.uid) then
				-- Hueco transparente del mismo tamaño. Se llama "TextButton" para conservar el orden del UIListLayout
				-- (se ordena por nombre: un "Frame" se colaría delante de los botones).
				widget = Instance.new("Frame")
				widget.Name = "TextButton"
				widget.Size = UDim2.new(0.105, 0, 1, 0)
				widget.BackgroundTransparency = 1
				widget.Parent = ctx.parent
			else
				local stroke
				if ctx.isTarget("Self", "Hand", idx, inst.uid) then stroke = ctx.theme.tgt
				elseif state.sel and state.sel.uid == inst.uid then stroke = ctx.theme.sel end
				widget = ctx.cardBtn(ctx.parent, UDim2.new(0.105, 0, 1, 0), ctx.cardText(inst.cardId, inst), ctx.theme.card,
					function() ctx.onHand(inst, idx) end, stroke, ctx.cards[inst.cardId].art)
			end
			if ctx.register then ctx.register(inst.uid, widget) end
		end
	end
end

return Hand
