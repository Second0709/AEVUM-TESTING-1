local Hand = {}

function Hand.create(ctx)
	return function()
		local state = ctx.getState()
		ctx.clear(ctx.parent)
		for idx, inst in ipairs(state.view.me.hand) do
			local stroke
			if ctx.isTarget("Self", "Hand", idx, inst.uid) then stroke = ctx.theme.tgt
			elseif state.sel and state.sel.uid == inst.uid then stroke = ctx.theme.sel end
			ctx.cardBtn(ctx.parent, UDim2.new(0.105, 0, 1, 0), ctx.cardText(inst.cardId, inst), ctx.theme.card,
				function() ctx.onHand(inst, idx) end, stroke, ctx.cards[inst.cardId].art)
		end
	end
end

return Hand
