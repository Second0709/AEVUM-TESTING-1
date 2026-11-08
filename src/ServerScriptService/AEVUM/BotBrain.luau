--!nonstrict
-- AEVUM · Bot sencillo (v1.3.0, evita atacar con criaturas aturdidas).

local BotBrain = {}

local function isAttacker(view, inst)
	if not inst or not inst.attacking then return false end
	for _, uid in ipairs(view.attack and view.attack.attackers or {}) do
		if uid == inst.uid then return true end
	end
	return false
end

local function isIncomingTarget(view, target)
	if not view.attack or view.waiting.kind ~= "FastWindow" or target.side ~= "Self" then return false end
	if target.zone == "Avatar" then
		if view.you == view.attackerIdx then return false end
		local blocked = {}
		for _, pair in ipairs(view.attack.blocks or {}) do blocked[pair.attacker] = true end
		for _, uid in ipairs(view.attack.attackers) do
			if not blocked[uid] then return true end
		end
		return false
	end
	if target.zone ~= "Combat" then return false end
	local inst = view.me.combat[target.slot]
	if not inst then return false end
	for _, pair in ipairs(view.attack.blocks or {}) do
		local incomingUid = view.you == view.attackerIdx and pair.attacker or pair.blocker
		if incomingUid == inst.uid then return true end
	end
	return false
end

local function chooseFast(view, cards)
	local me = view.me
	for _, wantedKind in ipairs({ "Destroy", "Stun", "Dispel", "Shield", "Reflect" }) do
		for _, spell in ipairs(view.activatable or {}) do
			local inst = me.bench[spell.slot]
			local card = inst and cards[inst.cardId]
			if card and card.effect.kind == wantedKind then
				for _, target in ipairs(spell.targets) do
					if wantedKind == "Destroy" or wantedKind == "Stun" then
						local enemy = target.zone == "Combat" and view.opp.combat[target.slot]
						if view.attack and target.side == "Enemy" and isAttacker(view, enemy) then
							return { type = "ActivateFast", slot = spell.slot, target = target }
						end
					elseif wantedKind == "Dispel" then
						local ally = target.side == "Self" and view.me[target.zone:lower()][target.slot]
						local base = ally and cards[ally.cardId]
						if base and ((base.atk and ally.atk < base.atk)
							or (base.hp and ally.maxHp < base.hp)) then
							return { type = "ActivateFast", slot = spell.slot, target = target }
						end
					elseif wantedKind == "Shield" and isIncomingTarget(view, target) then
						return { type = "ActivateFast", slot = spell.slot, target = target }
					elseif wantedKind == "Reflect" then
						-- (v1.3.2) El Espejo se lanza sobre el enemigo atacante seleccionado
						if view.attack and view.waiting.kind == "FastWindow" and target.side == "Enemy"
							and target.zone == "Combat" and isAttacker(view, view.opp.combat[target.slot]) then
							return { type = "ActivateFast", slot = spell.slot, target = target }
						end
					end
				end
			end
		end
	end
	return nil
end

function BotBrain.decide(view, cards, cfg)
	local kind = view.waiting.kind
	local me = view.me

	if kind == "Response" or kind == "AttackResponse" or kind == "FastWindow" then
		return chooseFast(view, cards) or { type = "Pass" }

	elseif kind == "AttackEvolve" then
		if view.evolveOpen and me.evolutions < cfg.EvolutionsPerTurn then
			for _, form in ipairs(me.hand) do
				local card = cards[form.cardId]
				if card.evolveFrom and form.cost <= me.energy then
					for _, inst in ipairs(me.combat) do
						if inst and inst.cardId == card.evolveFrom then
							return { type = "Evolve", form = form.uid, target = inst.uid }
						end
					end
				end
			end
		end
		return { type = "Continue" }

	elseif kind == "Actions" then
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
