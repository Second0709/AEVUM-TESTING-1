--!nonstrict
-- AEVUM · Motor de partida (v1.3.0, autoridad total del SERVIDOR)
-- v1.3.0: Groto stackea (auras de ReduceMaxHp sin límite por damage).
-- Spell kills no disparan ReduceAtk/ReduceMaxHp (solo AreaDamage).
-- ReduceMaxHp clampea damage cuando dejaría a la criatura sin vida.
-- ReduceAtk/ReduceMaxHp en bench: no-op (no hay pareja). AreaDamage en bench: sí.

local Match = {}
Match.__index = Match

local function other(i) return 3 - i end

local TARGET_MAP = {
	SelfAvatar = { "Self", "Avatar" }, EnemyAvatar = { "Enemy", "Avatar" },
	SelfCombat = { "Self", "Combat" }, EnemyCombat = { "Enemy", "Combat" },
	SelfBench = { "Self", "Bench" }, EnemyBench = { "Enemy", "Bench" },
	EnemyAttacker = { "Enemy", "Combat" },
	SelfHand = { "Self", "Hand" },
}

local function findIn(zone, uid)
	for slot, inst in ipairs(zone) do
		if inst and inst.uid == uid then return inst, slot end
	end
	return nil, nil
end
local function firstFree(zone)
	for slot, inst in ipairs(zone) do if not inst then return slot end end
	return nil
end
local function countUsed(zone)
	local n = 0
	for _, inst in ipairs(zone) do if inst then n += 1 end end
	return n
end

function Match.new(opts)
	local self = setmetatable({}, Match)
	self.cfg = opts.cfg
	self.cards = opts.cards
	self.clock = opts.clock or os.clock
	self.rand = opts.rand or math.random
	self.uidCounter = 0
	self.turn = 0
	self.logLines = {}
	self.players = {}
	self.over = false
	self.winner = nil
	self.reason = nil
	self.events = {}
	self.eventId = 0
	self.startedAt = self.clock()
	for i, p in ipairs(opts.players) do
		local P = {
			idx = i, id = p.id, name = p.name or ("Jugador " .. i), isBot = p.isBot or false,
			hp = self.cfg.AvatarHealth, maxEnergy = 0, energy = 0, reserve = 0, evolutions = 0,
			deck = {}, hand = {}, bench = {}, combat = {}, graveyard = {},
		}
		for s = 1, self.cfg.BenchSlots do P.bench[s] = false end
		for s = 1, self.cfg.CombatSlots do P.combat[s] = false end
		local ids = table.clone(p.deck)
		self:shuffle(ids)
		for _, cid in ipairs(ids) do P.deck[#P.deck + 1] = self:newInst(cid, i) end
		self.players[i] = P
	end
	self.first = self.rand(1, 2)
	return self
end

function Match:shuffle(t)
	for i = #t, 2, -1 do
		local j = self.rand(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function Match:newInst(cardId, ownerIdx)
	self.uidCounter += 1
	return { uid = self.uidCounter, cardId = cardId, playedTurn = 0, damage = 0, ownerIdx = ownerIdx }
end
function Match:say(text)
	table.insert(self.logLines, { turn = self.turn, text = text })
	if #self.logLines > 40 then table.remove(self.logLines, 1) end
end
function Match:nameOf(i) return self.players[i].name end
function Match:emit(kind, data)
	self.eventId += 1
	data = data or {}
	data.id = self.eventId
	data.kind = kind
	table.insert(self.events, data)
	if #self.events > 20 then table.remove(self.events, 1) end
end
function Match:setWaiting(player, kind)
	self.waiting = { player = player, kind = kind, deadline = self.clock() + self.cfg.ActionTimeSeconds }
end
function Match:finish(winner, reason)
	if self.over then return end
	self.over = true
	self.winner = winner
	self.reason = reason
	self.waiting = nil
	self:say(winner and ("Gana " .. self:nameOf(winner) .. ": " .. reason) or ("Empate: " .. reason))
end

function Match:effectiveAtk(inst)
	local c = self.cards[inst.cardId]
	local atk = c.atk or 0
	for _, m in ipairs(inst.atkModifiers or {}) do
		if m.expiresAtTurn == nil or self.turn < m.expiresAtTurn then atk += m.amount end
	end
	return math.max(0, atk)
end

function Match:effectiveMaxHp(inst)
	local c = self.cards[inst.cardId]
	local hp = c.hp or 0
	for _, m in ipairs(inst.hpModifiers or {}) do
		if m.expiresAtTurn == nil or self.turn < m.expiresAtTurn then hp += m.amount end
	end
	if inst.ownerIdx then
		local opp = self.players[other(inst.ownerIdx)]
		if opp then
			for _, oppInst in ipairs(opp.combat) do
				if oppInst then
					local oc = self.cards[oppInst.cardId]
					if oc.aura and oc.aura.kind == "ReduceMaxHp" then
						local candidate = hp - oc.aura.amount
						if candidate >= 1 then hp = candidate end  -- (v1.3.0) stackea auras
					end
				end
			end
		end
	end
	return math.max(1, hp)
end

-- (v1.3.0) Clampea damage en Combat para respetar maxHp efectivo (auras que stackean).
-- Llamar después de mover criaturas a Combat o de re-evaluar auras.
function Match:clampDamageIn(P)
	for _, inst in ipairs(P.combat) do
		if inst then
			local maxHp = self:effectiveMaxHp(inst)
			if inst.damage >= maxHp then
				inst.damage = math.max(0, maxHp - 1)
			end
		end
	end
end

function Match:clampAllDamage()
	for _, P in ipairs(self.players) do
		self:clampDamageIn(P)
	end
end

function Match:effectiveCost(inst)
	local c = self.cards[inst.cardId]
	local base = c.evolveFrom and (c.evolveCost or c.cost) or c.cost
	local reduction = 0
	for _, m in ipairs(inst.costModifiers or {}) do
		if m.expiresAtTurn == nil or self.turn < m.expiresAtTurn then
			reduction = math.max(reduction, m.amount)
		end
	end
	return self:costOf(base, reduction)
end

function Match:isStunned(inst)
	return inst and inst.stunUntilTurn and self.turn < inst.stunUntilTurn
end

function Match:triggerReflect(holder, damageDealt, sourceIdx)
	-- (v1.3.1) Espejo Clarividente: DESVÍA la totalidad del daño directo (hechizos o
	-- criaturas que ataquen) al Avatar del contrincante. El titular no recibe nada.
	-- Devuelve true si el daño fue desviado.
	if not holder or not holder.reflect then return false end
	if self.turn >= holder.reflect.expiresAtTurn then
		holder.reflect = nil
		return false
	end
	if damageDealt <= 0 then return false end
	local source = self.players[sourceIdx]
	if not source then return false end
	local actual = self:absorb(source, damageDealt)
	source.hp -= actual
	self:say(("¡Espejo Clarividente! El daño es desviado: %s recibe %d de daño directo en el Avatar."):format(source.name, actual))
	return true
end

function Match:drawInitial(P)
	local cfg = self.cfg
	local n = #P.deck
	if cfg.GuaranteeLowCostCreature and n > 0 then
		local function eligible(inst)
			local c = self.cards[inst.cardId]
			return c.type == "Creature" and not c.evolveFrom and c.cost <= cfg.LowCostMax
		end
		local topStart = math.max(1, n - cfg.StartingHand + 1)
		local has = false
		for k = topStart, n do if eligible(P.deck[k]) then has = true break end end
		if not has then
			local candidates = {}
			for k = 1, topStart - 1 do if eligible(P.deck[k]) then candidates[#candidates + 1] = k end end
			if #candidates > 0 then
				local pick = candidates[self.rand(1, #candidates)]
				P.deck[pick], P.deck[topStart] = P.deck[topStart], P.deck[pick]
			end
		end
	end
	for _ = 1, cfg.StartingHand do
		if #P.deck > 0 then table.insert(P.hand, table.remove(P.deck)) end
	end
end

function Match:start()
	for _, P in ipairs(self.players) do self:drawInitial(P) end
	self:say(self:nameOf(self.first) .. " es el primer jugador.")
	self:startTurn()
	self:autoAdvance()
end

function Match:startTurn()
	local cfg = self.cfg
	self.turn += 1
	self.attackerIdx = (self.turn % 2 == 1) and self.first or other(self.first)
	self.passes = 0
	self.pending = nil
	self.attack = nil
	self.fastStage = nil
	for _, P in ipairs(self.players) do
		P.maxEnergy = math.min(P.maxEnergy + 1, cfg.MaxEnergy)
		P.energy = P.maxEnergy
		P.evolutions = 0
	end
	local empty = {}
	for i, P in ipairs(self.players) do
		if #P.deck == 0 then empty[#empty + 1] = i
		else table.insert(P.hand, table.remove(P.deck)) end
	end
	if self.turn < cfg.FirstAttackTurn then
		self:say(("— Turno %d — turno de %s (apertura: sin ataques ni evoluciones)"):format(self.turn, self:nameOf(self.attackerIdx)))
	else
		self:say(("— Turno %d — ataca %s"):format(self.turn, self:nameOf(self.attackerIdx)))
	end
	if #empty == 2 then self:finish(nil, "ambos mazos vacíos al robar")
	elseif #empty == 1 then self:finish(other(empty[1]), "el rival no puede robar (mazo vacío)")
	else self:setWaiting(self.attackerIdx, "Actions") end
end

function Match:endTurn()
	local cfg = self.cfg
	for _, P in ipairs(self.players) do
		P.reserve = math.min(cfg.MaxReserve, P.reserve + P.energy)
		P.energy = 0
		P.shield = nil
		P.reflect = nil
		for _, zone in ipairs({ P.combat, P.bench }) do
			for _, inst in ipairs(zone) do
				if inst then
					inst.attacking = nil
					inst.emergent = nil
					inst.shield = nil
					inst.reflect = nil
				end
			end
		end
	end
	self.attack = nil
	self.pending = nil
	self.discardQueue = {}
	for _, i in ipairs({ self.attackerIdx, other(self.attackerIdx) }) do
		if #self.players[i].hand > cfg.HandLimit then table.insert(self.discardQueue, i) end
	end
	self:nextDiscardOrStart()
end

function Match:nextDiscardOrStart()
	while #self.discardQueue > 0 do
		local i = self.discardQueue[1]
		if #self.players[i].hand > self.cfg.HandLimit then
			self:setWaiting(i, "Discard")
			return
		end
		table.remove(self.discardQueue, 1)
	end
	self:startTurn()
end

function Match:costOf(base, reduction)
	reduction = math.min(reduction or 0, self.cfg.MaxCostReduction)
	return math.max(self.cfg.MinCost, base - reduction)
end

function Match:pay(P, cost, usesReserve)
	local avail = P.energy + (usesReserve and P.reserve or 0)
	if avail < cost then return false end
	if usesReserve then
		local r = math.min(P.reserve, cost)
		P.reserve -= r
		cost -= r
	end
	P.energy -= cost
	return true
end

function Match:enumerateTargets(idx, card, fromFast, excludeBenchSlot)
	local out = {}
	for _, name in ipairs(card.effect.targets) do
		local m = TARGET_MAP[name]
		if m then
			local side, zone = m[1], m[2]
			local ownerIdx = (side == "Self") and idx or other(idx)
			local P = self.players[ownerIdx]
			if zone == "Hand" then
				if side == "Self" then
					for i = 1, #P.hand do out[#out + 1] = { side = side, zone = zone, slot = i } end
				end
			elseif zone == "Avatar" then
				out[#out + 1] = { side = side, zone = zone, slot = 0 }
			else
				local list = (zone == "Combat") and P.combat or P.bench
				for s, inst in ipairs(list) do
					local okAttacker = true
					if name == "EnemyAttacker" then
						okAttacker = inst and inst.attacking and self.cards[inst.cardId].type == "Creature"
							and (card.effect.maxAtk == nil or self:effectiveAtk(inst) <= card.effect.maxAtk)
					end
					if inst and okAttacker then
						local blocked = fromFast and side == "Self" and inst.emergent
						local itself = zone == "Bench" and side == "Self" and s == excludeBenchSlot
						if not blocked and not itself then out[#out + 1] = { side = side, zone = zone, slot = s } end
					end
				end
			end
		end
	end
	return out
end

local function sameTarget(a, b)
	return a.side == b.side and a.zone == b.zone and a.slot == b.slot
end

function Match:absorb(holder, amount)
	local sh = holder.shield or 0
	if sh <= 0 or amount <= 0 then return amount end
	local used = math.min(sh, amount)
	holder.shield = sh - used
	return amount - used
end

function Match:isBlocking(inst)
	if not self.attack then return false end
	for _, buid in pairs(self.attack.blocks) do
		if buid == inst.uid then return true end
	end
	return false
end

function Match:destroy(ownerIdx, zoneName, slot)
	local P = self.players[ownerIdx]
	local zone = (zoneName == "Combat") and P.combat or P.bench
	local inst = zone[slot]
	if not inst then return end
	zone[slot] = false
	table.insert(P.graveyard, inst.cardId)
	for _, under in ipairs(inst.under or {}) do table.insert(P.graveyard, under) end
	self:say(("%s pierde %s (cementerio)."):format(P.name, self.cards[inst.cardId].name))
end

function Match:fireDeathTrigger(dead, opponent)
	local c = self.cards[dead.cardId]
	local trig = c and c.onDeath
	if not trig then return end
	if trig.kind == "ReduceAtk" then
		if not opponent then
			self:say(("%s muere sin objetivo para su efecto."):format(c.name))
			return
		end
		local m = { amount = -trig.amount, expiresAtTurn = trig.duration and (self.turn + trig.duration) or nil }
		opponent.atkModifiers = opponent.atkModifiers or {}
		table.insert(opponent.atkModifiers, m)
		self:say(("%s (al morir) reduce el ATAQUE de %s en %d%s."):format(
			c.name, self.cards[opponent.cardId].name, trig.amount,
			trig.duration and (" durante %d turno(s)"):format(trig.duration) or ""))
	elseif trig.kind == "ReduceMaxHp" then
		if not opponent then
			self:say(("%s muere sin objetivo para su efecto."):format(c.name))
			return
		end
		-- (fix) no "revivir" a una pareja que ya murió en el intercambio
		local oppMax = self:effectiveMaxHp(opponent)
		if opponent.damage >= oppMax then
			self:say(("%s (al morir) no puede reducir la VIDA MÁXIMA de %s: ya está sin vida."):format(
				c.name, self.cards[opponent.cardId].name))
			return
		end
		local newMax = math.max(1, oppMax - trig.amount)
		if newMax < oppMax then
			local m = { amount = -trig.amount, expiresAtTurn = trig.duration and (self.turn + trig.duration) or nil }
			opponent.hpModifiers = opponent.hpModifiers or {}
			table.insert(opponent.hpModifiers, m)
			local finalMax = self:effectiveMaxHp(opponent)
			if opponent.damage >= finalMax then
				opponent.damage = math.max(0, finalMax - 1)
			end
			self:say(("%s (al morir) reduce la VIDA MÁXIMA de %s en %d%s."):format(
				c.name, self.cards[opponent.cardId].name, trig.amount,
				trig.duration and (" durante %d turno(s)"):format(trig.duration) or ""))
		end
	elseif trig.kind == "AreaDamage" then
		local ownerIdx = dead.ownerIdx
		if not ownerIdx then return end
		local enemy = self.players[other(ownerIdx)]
		if not enemy then return end
		local hits = 0
		for _, inst in ipairs(enemy.combat) do
			if inst then
				local dmg = self:absorb(inst, trig.amount)
				inst.damage += dmg
				hits += 1
			end
		end
		self:say(("%s (al morir) inflige %d de daño a %d criatura(s) enemiga(s)."):format(c.name, trig.amount, hits))
	end
end

-- (v1.3.0) Un hechizo no es una entidad: ReduceAtk/ReduceMaxHp requieren par
-- del intercambio y no lo tienen → no-op con say. AreaDamage no necesita par →
-- sí se dispara (castiga al que destruyó, sea criatura o hechizo).
function Match:tryDeathFromEffect(ownerIdx, zoneName, slot, sourceIdx)
	local P = self.players[ownerIdx]
	local zone = (zoneName == "Combat") and P.combat or P.bench
	local inst = zone[slot]
	if not inst then return end
	local c = self.cards[inst.cardId]
	if not c.onDeath then return end

	if c.onDeath.kind == "AreaDamage" then
		self:fireDeathTrigger(inst, nil)
		-- Detectar muertes secundarias por AreaDamage (sin recursión).
		local enemy = self.players[other(ownerIdx)]
		if enemy then
			for eslot, einst in ipairs(enemy.combat) do
				if einst and einst.damage >= self:effectiveMaxHp(einst) then
					self:say(("%s muere por daño de área."):format(self.cards[einst.cardId].name))
					self:destroy(enemy.idx, "Combat", eslot)
				end
			end
		end
	else
		self:say(("%s muere por un hechizo: su efecto de muerte no se aplica."):format(c.name))
	end
end

function Match:checkAvatars()
	local d1, d2 = self.players[1].hp <= 0, self.players[2].hp <= 0
	if d1 and d2 then self:finish(nil, "ambos Avatares a 0 de vida")
	elseif d1 then self:finish(2, "el Avatar rival llegó a 0 de vida")
	elseif d2 then self:finish(1, "el Avatar rival llegó a 0 de vida") end
end

function Match:applyEffect(idx, card, t)
	local e = card.effect
	local ownerIdx = (t.side == "Self") and idx or other(idx)
	local P = self.players[ownerIdx]
	if t.zone == "Hand" then
		if e.kind == "ReduceCost" and t.side == "Self" then
			local handInst = P.hand[t.slot]
			if handInst then
				local m = { amount = e.amount, expiresAtTurn = e.duration and (self.turn + e.duration) or nil }
				handInst.costModifiers = handInst.costModifiers or {}
				table.insert(handInst.costModifiers, m)
				self:say(("%s reduce el coste de una carta en su mano en %d%s."):format(
					P.name, e.amount,
					e.duration and (" durante %d turno(s)"):format(e.duration) or " hasta jugarla"))
			end
		end
		return
	elseif t.zone == "Avatar" then
		if e.kind == "Damage" then
			if not self:triggerReflect(P, e.amount, idx) then
				local dmg = self:absorb(P, e.amount)
				P.hp -= dmg
				self:say(("%s recibe %d de daño en el Avatar%s."):format(P.name, dmg, dmg < e.amount and " (escudo)" or ""))
			end
		elseif e.kind == "Heal" then
			P.hp = math.min(self.cfg.AvatarHealth, P.hp + e.amount)
			self:say(("%s cura %d a su Avatar."):format(P.name, e.amount))
		elseif e.kind == "Shield" then
			P.shield = (P.shield or 0) + e.amount
			self:say(("%s protege a su Avatar (previene hasta %d)."):format(P.name, e.amount))
		elseif e.kind == "Reflect" then
			P.reflect = { expiresAtTurn = self.turn + (e.duration or 1) }
			self:say(("%s protege a su Avatar con un Espejo Clarividente."):format(P.name))
		end
	else
		local zone = (t.zone == "Combat") and P.combat or P.bench
		local inst = zone[t.slot]
		if inst then
			local c = self.cards[inst.cardId]
			if c.type == "Creature" then
				if e.kind == "Damage" then
					local fullLife = inst.damage == 0
					local dmg = 0
					if not self:triggerReflect(inst, e.amount, idx) then
						dmg = self:absorb(inst, e.amount)
						inst.damage += dmg
					end
					local effMax = self:effectiveMaxHp(inst)
					if inst.damage >= effMax then
						if fullLife and dmg > effMax and self:isBlocking(inst) then
							self.attack.spellOverkill = true
							self:say(("¡OVERKILL! %s aniquila a %s (%d de daño contra %d de vida)."):format(card.name, c.name, dmg, effMax))
						end
						-- (v1.3.0) onDeath también por hechizo
						self:tryDeathFromEffect(ownerIdx, t.zone, t.slot, idx)
						self:destroy(ownerIdx, t.zone, t.slot)
					end
				elseif e.kind == "Heal" then
					inst.damage = math.max(0, inst.damage - e.amount)
				elseif e.kind == "Shield" then
					inst.shield = (inst.shield or 0) + e.amount
					self:say(("%s protege a %s (previene hasta %d)."):format(P.name, c.name, e.amount))
				elseif e.kind == "Destroy" then
					-- (v1.3.0) onDeath también por Destroy
					self:tryDeathFromEffect(ownerIdx, t.zone, t.slot, idx)
					self:destroy(ownerIdx, t.zone, t.slot)
				elseif e.kind == "ReduceAtk" then
					local m = { amount = -e.amount, expiresAtTurn = e.duration and (self.turn + e.duration) or nil }
					inst.atkModifiers = inst.atkModifiers or {}
					table.insert(inst.atkModifiers, m)
					self:say(("%s reduce el ATAQUE de %s en %d%s."):format(
						P.name, c.name, e.amount,
						e.duration and (" durante %d turno(s)"):format(e.duration) or " (permanente)"))
				elseif e.kind == "ReduceMaxHp" then
					local currentMax = self:effectiveMaxHp(inst)
					local newMax = math.max(1, currentMax - e.amount)
					if newMax >= currentMax then
						self:say(("%s no puede reducir más la VIDA MÁXIMA de %s: ya está en el mínimo."):format(P.name, c.name))
					else
						local m = { amount = -e.amount, expiresAtTurn = e.duration and (self.turn + e.duration) or nil }
						inst.hpModifiers = inst.hpModifiers or {}
						table.insert(inst.hpModifiers, m)
						-- (fix) ReduceMaxHp nunca mata: si dejaría la criatura sin vida, clampear damage.
						local finalMax = self:effectiveMaxHp(inst)
						if inst.damage >= finalMax then
							inst.damage = math.max(0, finalMax - 1)
						end
						self:say(("%s reduce la VIDA MÁXIMA de %s en %d%s."):format(
							P.name, c.name, e.amount,
							e.duration and (" durante %d turno(s)"):format(e.duration) or " (permanente)"))
					end
				elseif e.kind == "Dispel" then
					local removed = 0
					if inst.atkModifiers then
						for i = #inst.atkModifiers, 1, -1 do
							if inst.atkModifiers[i].amount < 0 then table.remove(inst.atkModifiers, i) removed += 1 end
						end
					end
					if inst.hpModifiers then
						for i = #inst.hpModifiers, 1, -1 do
							if inst.hpModifiers[i].amount < 0 then table.remove(inst.hpModifiers, i) removed += 1 end
						end
					end
					self:say(("%s disipa %d efecto(s) negativo(s) de %s."):format(P.name, removed, c.name))
				elseif e.kind == "Stun" then
					inst.stunUntilTurn = self.turn + (e.duration or 1)
					self:say(("%s aturde a %s."):format(P.name, c.name))
				elseif e.kind == "Reflect" then
					inst.reflect = { expiresAtTurn = self.turn + (e.duration or 1) }
					self:say(("%s protege a %s con un Espejo Clarividente."):format(P.name, c.name))
				end
			end
		end
	end
	self:checkAvatars()
end

function Match:activateSpell(idx, slot, target, speed)
	local P = self.players[idx]
	local inst = P.bench[slot]
	if not inst then return false, "No hay carta en esa casilla" end
	local card = self.cards[inst.cardId]
	if card.type ~= "Spell" or card.speed ~= speed then return false, "Esa carta no se puede activar ahora" end
	if inst.playedTurn >= self.turn then return false, "El hechizo aún no está preparado" end
	if type(target) ~= "table" then return false, "Falta el objetivo" end
	local valid = false
	for _, t in ipairs(self:enumerateTargets(idx, card, speed == "Fast", slot)) do
		if sameTarget(t, target) then valid = true break end
	end
	if not valid then return false, "Objetivo no válido" end
	P.bench[slot] = false
	table.insert(P.graveyard, inst.cardId)
	self:say(("%s activa %s."):format(P.name, card.name))
	self:applyEffect(idx, card, target)
	return true
end

function Match:activatableSpells(idx, speed)
	local P = self.players[idx]
	local out = {}
	for slot, inst in ipairs(P.bench) do
		if inst and inst.playedTurn < self.turn then
			local c = self.cards[inst.cardId]
			if c.type == "Spell" and c.speed == speed then
				local targets = self:enumerateTargets(idx, c, speed == "Fast", slot)
				if #targets > 0 then out[#out + 1] = { slot = slot, speed = speed, targets = targets } end
			end
		end
	end
	return out
end

function Match:hasRelevantFast(idx)
	local P = self.players[idx]
	for _, a in ipairs(self:activatableSpells(idx, "Fast")) do
		local c = self.cards[P.bench[a.slot].cardId]
		if c.effect.kind ~= "Shield" or self.attack ~= nil then return true end
	end
	return false
end

function Match:canAct(idx)
	local P = self.players[idx]
	if firstFree(P.bench) then
		for _, h in ipairs(P.hand) do
			local c = self.cards[h.cardId]
			if not c.evolveFrom then
				local avail = P.energy + ((c.type == "Spell") and P.reserve or 0)
				if self:effectiveCost(h) <= avail then return true end
			end
		end
	end
	if #self:activatableSpells(idx, "Slow") > 0 then return true end
	return self:canEvolveNow(idx)
end

function Match:canEvolveNow(idx)
	local P = self.players[idx]
	if self.turn < self.cfg.FirstEvolveTurn or P.evolutions >= self.cfg.EvolutionsPerTurn then return false end
	for _, h in ipairs(P.hand) do
		local c = self.cards[h.cardId]
		if c.evolveFrom and P.energy >= self:effectiveCost(h) then
			for _, inst in ipairs(P.combat) do
				if inst and inst.cardId == c.evolveFrom then return true end
			end
		end
	end
	return false
end

function Match:possibleAttackers(idx)
	local P = self.players[idx]
	local list = {}
	for _, inst in ipairs(P.combat) do
		if inst and not self:isStunned(inst) then list[#list + 1] = inst end
	end
	if countUsed(P.combat) < self.cfg.CombatSlots then
		for _, inst in ipairs(P.bench) do
			if inst and inst.playedTurn < self.turn and not self:isStunned(inst)
				and self.cards[inst.cardId].type == "Creature" then
				list[#list + 1] = inst
			end
		end
	end
	return list
end

function Match:possibleBlockers(idx, mode)
	local P = self.players[idx]
	local list = {}
	if mode == "regular" then
		for _, inst in ipairs(P.combat) do if inst then list[#list + 1] = inst end end
	else
		for _, inst in ipairs(P.bench) do
			if inst and inst.playedTurn < self.turn and self.cards[inst.cardId].type == "Creature" then
				list[#list + 1] = inst
			end
		end
	end
	return list
end

function Match:openResponse()
	self:setWaiting(other(self.pending.player), "Response")
end

function Match:resolvePending()
	local p = self.pending
	self.pending = nil
	if not p then return end
	if p.kind == "Evolve" then
		local P = self.players[p.player]
		local target, slot = findIn(P.combat, p.targetUid)
		local formCard = self.cards[p.form.cardId]
		if target and target.cardId == formCard.evolveFrom then
			local oldName = self.cards[target.cardId].name
			target.under = target.under or {}
			table.insert(target.under, target.cardId)
			target.cardId = p.form.cardId
			target.damage = math.max(0, target.damage - self.cfg.EvolveHeal)
			self:say(("%s evoluciona %s → %s."):format(P.name, oldName, formCard.name))
			if target.damage >= self:effectiveMaxHp(target) then self:destroy(p.player, "Combat", slot) end
		else
			table.insert(P.graveyard, p.form.cardId)
			self:say("La evolución falla: el objetivo ya no está (el costo no se devuelve).")
		end
	end
	if self.over then return end
	if self.attack then self:toAttackResponse()
	else self.passes = 0 self:setWaiting(other(p.player), "Actions") end
end

function Match:toAttackResponse()
	self:setWaiting(other(self.attackerIdx), "AttackResponse")
end

function Match:proceedToBlocks()
	if self.over then return end
	local A = self.players[self.attackerIdx]
	local D = self.players[other(self.attackerIdx)]
	local alive, set = {}, {}
	for _, uid in ipairs(self.attack.attackers) do
		if findIn(A.combat, uid) then alive[#alive + 1] = uid set[uid] = true end
	end
	self.attack.attackers = alive
	self.attack.attackerSet = set
	if #alive == 0 then self:say("No quedan atacantes.") self:endTurn() return end
	self.attack.mode = (countUsed(D.combat) > 0) and "regular" or "emergent"
	self:setWaiting(other(self.attackerIdx), "Block")
end

function Match:fastStep()
	if self.over then return end
	if self.fastStage == 1 then
		self.fastStage = 2
		self:setWaiting(self.attackerIdx, "FastWindow")
	else
		self:resolveDamage()
	end
end

function Match:resolveDamage()
	local A = self.players[self.attackerIdx]
	local dIdx = other(self.attackerIdx)
	local D = self.players[dIdx]
	local avatarDmg = 0
	local exchanges = {}

	for _, auid in ipairs(self.attack.attackers) do
		local a = findIn(A.combat, auid)
		if a and not self:isStunned(a) then
			local buid = self.attack.blocks[auid]
			if buid then
				local b = findIn(D.combat, buid)
				if b then
					exchanges[#exchanges + 1] = {
						a = a, b = b,
						toA = self:absorb(a, self:effectiveAtk(b)),
						toB = self:absorb(b, self:effectiveAtk(a)),
						bRemaining = self:effectiveMaxHp(b) - b.damage,
						aBefore = a.damage,
						bBefore = b.damage,
					}
				end
			else
				avatarDmg += self:effectiveAtk(a)
			end
		end
	end

	for _, ex in ipairs(exchanges) do
		if not self:triggerReflect(ex.a, self:effectiveAtk(ex.b), dIdx) then
			ex.a.damage += ex.toA
		end
		if not self:triggerReflect(ex.b, self:effectiveAtk(ex.a), self.attackerIdx) then
			ex.b.damage += ex.toB
		end
	end

	self:checkAvatars()
	if self.over then return end

	local deadUid = {}
	for _, ex in ipairs(exchanges) do
		if ex.a.damage >= self:effectiveMaxHp(ex.a) then deadUid[ex.a.uid] = true end
		if ex.b.damage >= self:effectiveMaxHp(ex.b) then deadUid[ex.b.uid] = true end
	end

	for _, ex in ipairs(exchanges) do
		if deadUid[ex.a.uid] then self:fireDeathTrigger(ex.a, ex.b) end
		if deadUid[ex.b.uid] then self:fireDeathTrigger(ex.b, ex.a) end
	end

	for _, P in ipairs({ A, D }) do
		for _, inst in ipairs(P.combat) do
			if inst and not deadUid[inst.uid] and inst.damage >= self:effectiveMaxHp(inst) then
				deadUid[inst.uid] = true
				self:say(("%s muere por daño de área."):format(self.cards[inst.cardId].name))
			end
		end
	end

	local overkill = self.attack.spellOverkill == true
	local blockKill = false
	for _, ex in ipairs(exchanges) do
		local bHp = self:effectiveMaxHp(ex.b)
		local bFull = ex.bBefore == 0
		local aDead = deadUid[ex.a.uid]
		local bDead = deadUid[ex.b.uid]
		if bDead and bFull and ex.toB > bHp then
			overkill = true
			self:say(("¡OVERKILL! %s aniquila a %s (%d de daño contra %d de vida)."):format(
				self.cards[ex.a.cardId].name, self.cards[ex.b.cardId].name, ex.toB, bHp))
		elseif aDead or bDead then
			blockKill = true
		end
		if ex.b.emergent and bDead then
			avatarDmg += math.max(0, ex.toB - ex.bRemaining)
		end
	end

	for _, P in ipairs({ A, D }) do
		for slot, inst in ipairs(P.combat) do
			if inst and deadUid[inst.uid] then self:destroy(P.idx, "Combat", slot) end
		end
	end

	if overkill then self:emit("Overkill") elseif blockKill then self:emit("BlockKill") end

	if avatarDmg > 0 then
		if not self:triggerReflect(D, avatarDmg, self.attackerIdx) then
			avatarDmg = self:absorb(D, avatarDmg)
			D.hp -= avatarDmg
			self:say(("%s recibe %d de daño en el Avatar."):format(D.name, avatarDmg))
		end
	end
	self:checkAvatars()
	if not self.over then self:endTurn() end
end

local H = {}

local function pass(self, idx)
	self.passes += 1
	if self.passes >= 2 then
		if self.turn < self.cfg.FirstAttackTurn then self:endTurn()
		else self:setWaiting(self.attackerIdx, "AttackDeclare") end
	else
		self:setWaiting(other(idx), "Actions")
	end
	return true
end

local function playCard(self, idx, a)
	local P = self.players[idx]
	local inst, hi = findIn(P.hand, a.uid)
	if not inst then return false, "Esa carta no está en tu mano" end
	local card = self.cards[inst.cardId]
	if card.evolveFrom then return false, "Esa carta solo se juega evolucionando" end
	local slot = a.slot
	if slot then
		if slot < 1 or slot > self.cfg.BenchSlots or P.bench[slot] then return false, "Casilla de Banca no disponible" end
	else
		slot = firstFree(P.bench)
		if not slot then return false, "La Banca está llena" end
	end
	local isSpell = card.type == "Spell"
	if not self:pay(P, self:effectiveCost(inst), isSpell) then return false, "Energía insuficiente" end
	table.remove(P.hand, hi)
	inst.playedTurn = self.turn
	P.bench[slot] = inst
	self:say(("%s coloca una carta boca abajo en la Banca."):format(P.name))
	self.pending = { kind = "Place", player = idx, uid = inst.uid }
	self:openResponse()
	return true
end

local function activateSlow(self, idx, a)
	local ok, err = self:activateSpell(idx, a.slot, a.target, "Slow")
	if not ok then return false, err end
	if not self.over then self.passes = 0 self:setWaiting(other(idx), "Actions") end
	return true
end

local function evolve(self, idx, a)
	local P = self.players[idx]
	if self.turn < self.cfg.FirstEvolveTurn then return false, "No se puede evolucionar todavía" end
	if P.evolutions >= self.cfg.EvolutionsPerTurn then return false, "Ya evolucionaste este turno" end
	local form, fi = findIn(P.hand, a.form)
	if not form then return false, "Esa carta no está en tu mano" end
	local fc = self.cards[form.cardId]
	if not fc.evolveFrom then return false, "Esa carta no es una evolución" end
	local target = findIn(P.combat, a.target)
	if not target or target.cardId ~= fc.evolveFrom then return false, "Objetivo de evolución no válido" end
	if not self:pay(P, self:effectiveCost(form), false) then return false, "Energía insuficiente" end
	table.remove(P.hand, fi)
	P.evolutions += 1
	self.pending = { kind = "Evolve", player = idx, form = form, targetUid = target.uid }
	self:say(("%s declara una evolución."):format(P.name))
	self:openResponse()
	return true
end

H.Actions = { Pass = pass, PlayCard = playCard, ActivateSlow = activateSlow, Evolve = evolve }

H.Response = {
	Pass = function(self) self:resolvePending() return true end,
	ActivateFast = function(self, idx, a)
		local ok, err = self:activateSpell(idx, a.slot, a.target, "Fast")
		if not ok then return false, err end
		self:resolvePending()
		return true
	end,
}

H.AttackDeclare = {
	SkipAttack = function(self) self:endTurn() return true end,
	DeclareAttack = function(self, idx, a)
		local P = self.players[idx]
		local chosen, seen, fromBench = {}, {}, 0
		for _, uid in ipairs(a.attackers) do
			if seen[uid] then return false, "Atacante repetido" end
			seen[uid] = true
			local inst = findIn(P.combat, uid)
			if not inst then
				inst = findIn(P.bench, uid)
				if not inst or self.cards[inst.cardId].type ~= "Creature" or inst.playedTurn >= self.turn then
					return false, "Atacante no válido"
				end
				fromBench += 1
			end
			if self:isStunned(inst) then return false, "Esa criatura está aturdida y no puede atacar" end
			chosen[#chosen + 1] = inst
		end
		if #chosen == 0 then return false, "Elige al menos un atacante" end
		if countUsed(P.combat) + fromBench > self.cfg.CombatSlots then return false, "No hay espacio en la Zona de Combate" end
		local uids = {}
		for _, inst in ipairs(chosen) do
			local _, bslot = findIn(P.bench, inst.uid)
			if bslot then
				P.bench[bslot] = false
				P.combat[firstFree(P.combat)] = inst
				self:say(("%s revela %s en la Zona de Combate."):format(P.name, self.cards[inst.cardId].name))
			end
			inst.attacking = true
			uids[#uids + 1] = inst.uid
		end
		self.attack = { attackers = uids, blocks = {}, attackerSet = {} }
		for _, u in ipairs(uids) do self.attack.attackerSet[u] = true end
		self:say(("%s declara un ataque con %d criatura(s)."):format(P.name, #uids))
		self:clampAllDamage()  -- (v1.3.0) respetar auras de Groto al mover a Combat
		self:setWaiting(idx, "AttackEvolve")
		return true
	end,
}

H.AttackEvolve = {
	Evolve = evolve,
	Continue = function(self) self:toAttackResponse() return true end,
}

H.AttackResponse = {
	Pass = function(self) self:proceedToBlocks() return true end,
	ActivateFast = function(self, idx, a)
		local ok, err = self:activateSpell(idx, a.slot, a.target, "Fast")
		if not ok then return false, err end
		self:proceedToBlocks()
		return true
	end,
}

H.Block = {
	AssignBlocks = function(self, idx, a)
		local atk = self.attack
		local D = self.players[idx]
		local usedA, usedB, picked = {}, {}, {}
		local emergent = atk.mode == "emergent"
		if emergent and countUsed(D.combat) > 0 then
			return false, "El bloqueo emergente requiere Zona de Combate vacía"
		end
		for _, b in ipairs(a.blocks) do
			if not atk.attackerSet[b.attacker] or usedA[b.attacker] or usedB[b.blocker] then
				return false, "Bloqueo no válido"
			end
			usedA[b.attacker] = true
			usedB[b.blocker] = true
			local inst
			if emergent then
				inst = findIn(D.bench, b.blocker)
				if not inst or self.cards[inst.cardId].type ~= "Creature" or inst.playedTurn >= self.turn then
					return false, "Esa criatura de la Banca no puede bloquear"
				end
			else
				inst = findIn(D.combat, b.blocker)
				if not inst then return false, "Esa criatura no puede bloquear" end
			end
			picked[#picked + 1] = { attacker = b.attacker, inst = inst }
		end
		if emergent and #picked > self.cfg.MaxEmergentBlockers then return false, "Máximo 2 bloqueadores desde la Banca" end
		for _, p in ipairs(picked) do
			if emergent then
				local _, bslot = findIn(D.bench, p.inst.uid)
				D.bench[bslot] = false
				D.combat[firstFree(D.combat)] = p.inst
				p.inst.emergent = true
				self:say(("%s bloquea desde la Banca con %s."):format(D.name, self.cards[p.inst.cardId].name))
			end
			atk.blocks[p.attacker] = p.inst.uid
		end
		self:say(("%s asigna %d bloqueo(s)."):format(D.name, #picked))
		self:clampAllDamage()  -- (v1.3.0) respetar auras de HPredux
		self.fastStage = 1
		self:setWaiting(idx, "FastWindow")
		return true
	end,
}

H.FastWindow = {
	Pass = function(self) self:fastStep() return true end,
	ActivateFast = function(self, idx, a)
		local ok, err = self:activateSpell(idx, a.slot, a.target, "Fast")
		if not ok then return false, err end
		self:fastStep()
		return true
	end,
}

H.Discard = {
	Discard = function(self, idx, a)
		local P = self.players[idx]
		local inst, hi = findIn(P.hand, a.uid)
		if not inst then return false, "Esa carta no está en tu mano" end
		table.remove(P.hand, hi)
		table.insert(P.graveyard, inst.cardId)
		self:say(("%s descarta una carta."):format(P.name))
		self:nextDiscardOrStart()
		return true
	end,
}

function Match:dispatchRaw(idx, a)
	local w = self.waiting
	if not w then return false, "La partida terminó" end
	local group = H[w.kind]
	local fn = group and group[a.type]
	if not fn then return false, "Acción no permitida en este momento" end
	return fn(self, idx, a)
end

function Match:submit(idx, a)
	if self.over then return false, "La partida terminó" end
	if not self.waiting or self.waiting.player ~= idx then return false, "No es tu momento de actuar" end
	local ok, err = self:dispatchRaw(idx, a)
	if ok then self:autoAdvance() end
	return ok, err
end

function Match:defaultAction()
	local w = self.waiting
	local k = w.kind
	if k == "Actions" or k == "Response" or k == "AttackResponse" or k == "FastWindow" then return { type = "Pass" }
	elseif k == "AttackDeclare" then return { type = "SkipAttack" }
	elseif k == "AttackEvolve" then return { type = "Continue" }
	elseif k == "Block" then return { type = "AssignBlocks", blocks = {} }
	elseif k == "Discard" then
		local hand = self.players[w.player].hand
		return { type = "Discard", uid = hand[#hand].uid }
	end
	return { type = "Pass" }
end

function Match:canAutoSkip()
	local w = self.waiting
	local k = w.kind
	if k == "Response" or k == "AttackResponse" or k == "FastWindow" then
		return not self:hasRelevantFast(w.player)
	elseif k == "Actions" then
		return (self.cfg.AutoPassWhenNoActions == true) and not self:canAct(w.player)
	elseif k == "Block" then
		return #self:possibleBlockers(w.player, self.attack.mode) == 0
	elseif k == "AttackEvolve" then
		return not self:canEvolveNow(w.player)
	elseif k == "AttackDeclare" then
		return #self:possibleAttackers(w.player) == 0
	end
	return false
end

function Match:autoAdvance()
	local guard = 0
	while not self.over and self.waiting and guard < 400 do
		guard += 1
		if not (self.cfg.AutoSkipEmptyWindows and self:canAutoSkip()) then break end
		local w = self.waiting
		local ok = self:dispatchRaw(w.player, self:defaultAction())
		if not ok then break end
	end
end

function Match:isExpired()
	return not self.over and self.waiting ~= nil and self.clock() >= self.waiting.deadline
end

function Match:isStale()
	if self.over then return false end
	local max = self.cfg.MaxMatchSeconds
	if not max then return false end
	return self.clock() - self.startedAt >= max
end

function Match:timeout()
	if self.over or not self.waiting then return end
	local w = self.waiting
	self:say(("%s se quedó sin tiempo."):format(self:nameOf(w.player)))
	local ok = self:dispatchRaw(w.player, self:defaultAction())
	if ok then self:autoAdvance() end
end

function Match:forfeit(idx)
	self:finish(other(idx), "el rival abandonó la partida")
end

function Match:staleFinish()
	self:finish(nil, "la partida excedió el tiempo máximo")
end

function Match:getView(idx)
	local me, opp = self.players[idx], self.players[other(idx)]
	local function mine(inst)
		if not inst then return false end
		return { uid = inst.uid, cardId = inst.cardId, damage = inst.damage,
			prepared = inst.playedTurn < self.turn, attacking = inst.attacking or false, emergent = inst.emergent or false,
			shield = inst.shield or 0,
			atk = self:effectiveAtk(inst), maxHp = self:effectiveMaxHp(inst),
			stunned = self:isStunned(inst),
			reflect = (inst.reflect ~= nil and self.turn < inst.reflect.expiresAtTurn) or false }
	end
	local function theirsBench(inst)
		if not inst then return false end
		return { uid = inst.uid, faceDown = true }
	end
	local function theirsCombat(inst)
		if not inst then return false end
		return { uid = inst.uid, cardId = inst.cardId, damage = inst.damage,
			attacking = inst.attacking or false, emergent = inst.emergent or false, shield = inst.shield or 0,
			atk = self:effectiveAtk(inst), maxHp = self:effectiveMaxHp(inst),
			stunned = self:isStunned(inst),
			reflect = (inst.reflect ~= nil and self.turn < inst.reflect.expiresAtTurn) or false }
	end
	local function map(zone, f)
		local out = {}
		for i, inst in ipairs(zone) do out[i] = f(inst) end
		return out
	end
	local hand = {}
	for i, inst in ipairs(me.hand) do
		hand[i] = { uid = inst.uid, cardId = inst.cardId, cost = self:effectiveCost(inst) }
	end
	local view = {
		you = idx, turn = self.turn, attackerIdx = self.attackerIdx, over = self.over,
		attackOpen = self.turn >= self.cfg.FirstAttackTurn,
		evolveOpen = self.turn >= self.cfg.FirstEvolveTurn,
		winner = self.winner or 0, reason = self.reason or "",
		me = {
			name = me.name, hp = me.hp, shield = me.shield or 0, maxEnergy = me.maxEnergy, energy = me.energy, reserve = me.reserve,
			deck = #me.deck, hand = hand, bench = map(me.bench, mine), combat = map(me.combat, mine),
			graveyard = me.graveyard, evolutions = me.evolutions,
			reflect = (me.reflect ~= nil and self.turn < me.reflect.expiresAtTurn) or false,
		},
		opp = {
			name = opp.name, hp = opp.hp, shield = opp.shield or 0, maxEnergy = opp.maxEnergy, energy = opp.energy, reserve = opp.reserve,
			deck = #opp.deck, hand = #opp.hand, bench = map(opp.bench, theirsBench), combat = map(opp.combat, theirsCombat),
			graveyard = opp.graveyard,
			reflect = (opp.reflect ~= nil and self.turn < opp.reflect.expiresAtTurn) or false,
		},
		log = {},
	}
	local from = math.max(1, #self.logLines - 14)
	for i = from, #self.logLines do view.log[#view.log + 1] = self.logLines[i].text end
	if self.waiting then
		view.waiting = { player = self.waiting.player, kind = self.waiting.kind,
			timeLeft = math.max(0, self.waiting.deadline - self.clock()) }
		if self.waiting.player == idx then
			local k = self.waiting.kind
			local speed = (k == "Actions") and "Slow" or ((k == "Response" or k == "AttackResponse" or k == "FastWindow") and "Fast" or nil)
			view.activatable = speed and self:activatableSpells(idx, speed) or {}
		end
	end
	view.events = {}
	for i = math.max(1, #self.events - 7), #self.events do
		local e = self.events[i]
		view.events[#view.events + 1] = { id = e.id, kind = e.kind }
	end
	if self.pending then view.pending = { kind = self.pending.kind, player = self.pending.player } end
	if self.attack then
		local blocks = {}
		for a, b in pairs(self.attack.blocks) do blocks[#blocks + 1] = { attacker = a, blocker = b } end
		view.attack = { attackers = self.attack.attackers, blocks = blocks, mode = self.attack.mode or "" }
	end
	return view
end

return Match