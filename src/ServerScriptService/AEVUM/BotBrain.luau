--!nonstrict
-- AEVUM · Bot sencillo (v1.3.0, evita atacar con criaturas aturdidas).

local BotBrain = {}

function BotBrain.decide(view, cards, cfg)
	local kind = view.waiting.kind
	local me = view.me

	if kind == "Actions" then
		local best, bestCost
		local free = false
		for _, inst in ipairs(me.bench) do if not inst then free = true end end
		if free then
			for _, h in ipairs(me.hand) do
				local c = cards[h.cardId]
				local cost = h.cost or c.cost
				if c.type == "Creature" and not c.evolveFrom and cost <= me.energy then
					if not best or cost > bestCost then best = h; bestCost = cost end
				end
			end
		end
		if best then return { type = "PlayCard", uid = best.uid } end
		return { type = "Pass" }

	elseif kind == "AttackDeclare" then
		local uids, freeCombat = {}, cfg.CombatSlots
		for _, inst in ipairs(me.combat) do
			if inst and not inst.stunned then
				uids[#uids + 1] = inst.uid
				freeCombat -= 1
			end
		end
		for _, inst in ipairs(me.bench) do
			if inst and inst.prepared and not inst.stunned and cards[inst.cardId].type == "Creature" and freeCombat > 0 then
				uids[#uids + 1] = inst.uid
				freeCombat -= 1
			end
		end
		if #uids == 0 then return { type = "SkipAttack" } end
		return { type = "DeclareAttack", attackers = uids }

	elseif kind == "AttackEvolve" then
		return { type = "Continue" }

	elseif kind == "Block" then
		local pool = {}
		if view.attack.mode == "regular" then
			for _, inst in ipairs(me.combat) do if inst then pool[#pool + 1] = inst.uid end end
		else
			for _, inst in ipairs(me.bench) do
				if inst and inst.prepared and cards[inst.cardId].type == "Creature" and #pool < cfg.MaxEmergentBlockers then
					pool[#pool + 1] = inst.uid
				end
			end
		end
		local blocks = {}
		for i, auid in ipairs(view.attack.attackers) do
			if pool[i] then blocks[#blocks + 1] = { attacker = auid, blocker = pool[i] } end
		end
		return { type = "AssignBlocks", blocks = blocks }

	elseif kind == "Discard" then
		return { type = "Discard", uid = me.hand[#me.hand].uid }
	end
	return { type = "Pass" }
end

return BotBrain
