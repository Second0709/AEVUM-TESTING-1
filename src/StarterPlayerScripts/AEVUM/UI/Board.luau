local Board = {}
local ROW_TITLES = { "BANCA RIVAL (boca abajo)", "COMBATE RIVAL", "TU COMBATE", "TU BANCA" }
local SLOT = UDim2.new(0.185, 0, 1, 0)

function Board.create(ctx)
	local function boardRow(order, title)
		local row = ctx.new("Frame", { Size = UDim2.new(1, 0, 0.245, 0), BackgroundColor3 = ctx.theme.panel, LayoutOrder = order }, ctx.parent)
		ctx.new("TextLabel", { Size = UDim2.new(1, 0, 0.14, 0), BackgroundTransparency = 1, Text = title, TextColor3 = ctx.theme.dim,
			Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }, row)
		local slots = ctx.new("Frame", { Position = UDim2.new(0, 0, 0.14, 0), Size = UDim2.new(1, 0, 0.86, 0), BackgroundTransparency = 1 }, row)
		ctx.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center }, slots)
		return slots
	end

	return function()
		local state = ctx.getState()
		local view = state.view
		ctx.clear(ctx.parent)
		local me, opp = view.me, view.opp
		local atkSet = {}
		if view.attack then for _, a in ipairs(view.attack.attackers) do atkSet[a] = true end end
		local blockerSet = {}
		for a, b in pairs(state.blockPairs) do blockerSet[b] = a end
		for _, b in ipairs(view.attack and view.attack.blocks or {}) do blockerSet[b.blocker] = b.attacker end
		local r1 = boardRow(1, ROW_TITLES[1])
		for s, inst in ipairs(opp.bench) do
			if inst then
				local target = ctx.isTarget("Enemy", "Bench", s, inst.uid)
				ctx.cardBtn(r1, SLOT, "Carta\nboca abajo", ctx.theme.faceDown,
					function() ctx.onOppBench(s, inst) end, target and ctx.theme.tgt or nil)
			else
				ctx.cardBtn(r1, SLOT, "—", ctx.theme.empty)
			end
		end
		local r2 = boardRow(2, ROW_TITLES[2])
		for s, inst in ipairs(opp.combat) do
			if inst then
				local tag = atkSet[inst.uid] and "ATACA" or (blockerSet[inst.uid] and "BLOQUEA") or nil
				local target = ctx.isTarget("Enemy", "Combat", s, inst.uid)
				local stroke = target and ctx.theme.tgt or (atkSet[inst.uid] and ctx.theme.atk) or nil
				if view.waiting and view.waiting.kind == "Block" and view.waiting.player == view.you and state.blockPick and atkSet[inst.uid] then
					stroke = ctx.theme.sel
				end
				ctx.cardBtn(r2, SLOT, ctx.cardText(inst.cardId, inst, tag), ctx.theme.card,
					function() ctx.onOppCombat(s, inst) end, stroke, ctx.cards[inst.cardId].art)
			else
				ctx.cardBtn(r2, SLOT, "—", ctx.theme.empty)
			end
		end
		local r3 = boardRow(3, ROW_TITLES[3])
		for s, inst in ipairs(me.combat) do
			if inst then
				local tag = (state.attackSel[inst.uid] and "→ ATACARÁ") or (atkSet[inst.uid] and "ATACA")
					or (blockerSet[inst.uid] and "BLOQUEA") or nil
				local stroke
				if ctx.isTarget("Self", "Combat", s, inst.uid) then stroke = ctx.theme.tgt
				elseif state.attackSel[inst.uid] or state.blockPick == inst.uid or (state.sel and state.sel.uid == inst.uid) then stroke = ctx.theme.sel end
				ctx.cardBtn(r3, SLOT, ctx.cardText(inst.cardId, inst, tag), ctx.theme.card,
					function() ctx.onMyCombat(s, inst) end, stroke, ctx.cards[inst.cardId].art)
			else
				ctx.cardBtn(r3, SLOT, "—", ctx.theme.empty)
			end
		end
		local r4 = boardRow(4, ROW_TITLES[4])
		for s, inst in ipairs(me.bench) do
			if inst then
				local card = ctx.cards[inst.cardId]
				local tag = inst.prepared and "[lista]" or "[en preparación]"
				if state.attackSel[inst.uid] then tag = "→ ATACARÁ" end
				if state.blockPick == inst.uid then tag = "→ bloqueará" end
				if blockerSet[inst.uid] then tag = "BLOQUEA" end
				local stroke
				if ctx.isTarget("Self", "Bench", s, inst.uid) then stroke = ctx.theme.tgt
				elseif state.attackSel[inst.uid] or state.blockPick == inst.uid or (state.sel and state.sel.uid == inst.uid) then stroke = ctx.theme.sel
				elseif ctx.activatableAt(s) then stroke = Color3.fromRGB(120, 170, 255) end
				ctx.cardBtn(r4, SLOT, ctx.cardText(inst.cardId, inst, tag),
					card.type == "Spell" and Color3.fromRGB(60, 70, 110) or ctx.theme.card,
					function() ctx.onMyBench(s, inst) end, stroke, card.art)
			else
				ctx.cardBtn(r4, SLOT, "—", ctx.theme.empty)
			end
		end
	end
end

return Board
