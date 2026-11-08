--!nonstrict
-- AEVUM · Base de datos de cartas (v1.3.0)
-- kinds: Damage | Heal | Shield | Destroy | ReduceCost | ReduceAtk | ReduceMaxHp | Dispel | Stun | Reflect
-- onDeath: ReduceAtk | ReduceMaxHp | AreaDamage

local Cards = {}

Cards.Order = { "APRENDIZ", "CENTINELA", "CAZADOR", "GUARDIAN", "TITAN", "HEROE",
	"GOLPE", "RAYO", "BARRERA", "EMBOSCADA",
	"ESPORA", "DESBASTE", "GROTO", "CORROSION",
	"CURACION", "INFUSION", "DISIPACION",
	"ESPEJO", "LIANA", "ASALTANTE" }

Cards.Data = {
	APRENDIZ = { id = "APRENDIZ", name = "Aprendiz del Spawn", type = "Creature", cost = 1, atk = 1, hp = 2,
		legendary = false, art = "rbxassetid://125379581550088", text = "Criatura básica. Evoluciona a Héroe del Spawn." },
	CENTINELA = { id = "CENTINELA", name = "Centinela del Vacío", type = "Creature", cost = 2, atk = 2, hp = 2,
		legendary = false, art = "rbxassetid://125379581550088", text = "Criatura de bajo costo." },
	CAZADOR = { id = "CAZADOR", name = "Cazador de Glitches", type = "Creature", cost = 3, atk = 3, hp = 2,
		legendary = false, art = "rbxassetid://125379581550088", text = "Atacante frágil de alto daño." },
	GUARDIAN = { id = "GUARDIAN", name = "Guardián de la Torre", type = "Creature", cost = 3, atk = 1, hp = 5,
		legendary = false, art = "rbxassetid://125379581550088", text = "Criatura muy resistente." },
	TITAN = { id = "TITAN", name = "Titán Corrupto", type = "Creature", cost = 5, atk = 5, hp = 4,
		legendary = false, art = "rbxassetid://125379581550088", text = "Gran poder de ataque." },
	HEROE = { id = "HEROE", name = "Héroe del Spawn", type = "Creature", cost = 2, atk = 3, hp = 4,
		evolveFrom = "APRENDIZ", evolveCost = 2, legendary = false, art = "rbxassetid://125379581550088",
		text = "Evolución: solo se juega evolucionando a Aprendiz del Spawn." },
	GOLPE = { id = "GOLPE", name = "Golpe Certero", type = "Spell", cost = 2, speed = "Slow",
		effect = { kind = "Damage", amount = 3, targets = { "EnemyCombat", "EnemyBench" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Lento. 3 de daño a una criatura." },
	RAYO = { id = "RAYO", name = "Rayo del Servidor", type = "Spell", cost = 3, speed = "Slow",
		effect = { kind = "Damage", amount = 3, targets = { "EnemyAvatar" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Lento. 3 de daño al Avatar enemigo." },
	BARRERA = { id = "BARRERA", name = "Barrera Espectral", type = "Spell", cost = 2, speed = "Fast",
		effect = { kind = "Shield", amount = 3, targets = { "SelfCombat", "SelfAvatar" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Rápido. Previene hasta 3 de daño a una criatura propia o a tu Avatar este turno." },
	EMBOSCADA = { id = "EMBOSCADA", name = "Emboscada", type = "Spell", cost = 3, speed = "Fast",
		effect = { kind = "Destroy", maxAtk = 3, targets = { "EnemyAttacker" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Rápido. Destruye a un atacante con ATAQUE 3 o menos." },
	ESPORA = { id = "ESPORA", name = "Espora Viviente", type = "Creature", cost = 2, atk = 1, hp = 3,
		legendary = false, art = "rbxassetid://125379581550088",
		onDeath = { kind = "ReduceAtk", amount = 1, duration = 2 },
		text = "Al morir en combate, reduce el ATAQUE del atacante o defensor en 1 durante 2 turnos." },
	DESBASTE = { id = "DESBASTE", name = "Desbaste", type = "Spell", cost = 2, speed = "Slow",
		effect = { kind = "ReduceAtk", amount = 1, duration = 2, targets = { "EnemyCombat", "EnemyBench" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Lento. Reduce el ATAQUE de una criatura enemiga en 1 durante 2 turnos." },
	GROTO = { id = "GROTO", name = "Defensor del Groto", type = "Creature", cost = 5, atk = 2, hp = 4,
		legendary = false, art = "rbxassetid://125379581550088",
		aura = { kind = "ReduceMaxHp", amount = 1 },
		text = "Mientras esté en la Zona de Combate, todas las criaturas enemigas en combate tienen -1 de VIDA MÁXIMA (nunca por debajo de 1 de vida actual)." },
	CORROSION = { id = "CORROSION", name = "Corrosión", type = "Spell", cost = 2, speed = "Slow",
		effect = { kind = "ReduceMaxHp", amount = 1, duration = 2, targets = { "EnemyCombat", "EnemyBench" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Lento. Reduce la VIDA MÁXIMA de una criatura enemiga en 1 durante 2 turnos (nunca por debajo de 1 de vida actual)." },
	CURACION = { id = "CURACION", name = "Curación", type = "Spell", cost = 2, speed = "Slow",
		effect = { kind = "Heal", amount = 2, targets = { "SelfCombat", "SelfBench", "SelfAvatar" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Lento. Cura 2 puntos de daño a una criatura propia o 2 de vida a tu Avatar." },
	INFUSION = { id = "INFUSION", name = "Infusión", type = "Spell", cost = 2, speed = "Slow",
		effect = { kind = "ReduceCost", amount = 1, targets = { "SelfHand" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Lento. Reduce en 1 el costo de una carta de tu mano (mínimo 1, §3)." },
	DISIPACION = { id = "DISIPACION", name = "Disipación", type = "Spell", cost = 2, speed = "Fast",
		effect = { kind = "Dispel", targets = { "SelfCombat", "SelfBench" } },
		legendary = false, art = "rbxassetid://125379581550088", text = "Rápido. Quita todos los efectos negativos (ATK/VIDA MÁXIMA reducidos) de una criatura propia." },
	ESPEJO = { id = "ESPEJO", name = "Espejo Clarividente", type = "Spell", cost = 5, speed = "Fast",
		effect = { kind = "Reflect", duration = 1, targets = { "EnemyCombat", "EnemyAvatar" } },
		legendary = false, art = "rbxassetid://125379581550088",
		text = "Rápido. Selecciona al enemigo a responder: este turno, el daño de esa criatura al atacar (o del jugador del Avatar marcado) se desvía directamente a su propio Avatar." },
	LIANA = { id = "LIANA", name = "Liana Salvaje", type = "Spell", cost = 1, speed = "Fast",
		effect = { kind = "Stun", duration = 1, targets = { "EnemyCombat" } },
		legendary = false, art = "rbxassetid://125379581550088",
		text = "Rápido. Aturde a la criatura enemiga seleccionada: durante este turno no podrá atacar." },
	ASALTANTE = { id = "ASALTANTE", name = "Asaltante Malware", type = "Creature", cost = 4, atk = 2, hp = 4,
		legendary = false, art = "rbxassetid://125379581550088",
		onDeath = { kind = "AreaDamage", amount = 1 },
		text = "Al morir, inflige 1 de daño a todas las criaturas rivales en la Zona de Combate." },
}

local KINDS = { Damage = true, Heal = true, Shield = true, Destroy = true,
	ReduceCost = true, ReduceAtk = true, ReduceMaxHp = true, Dispel = true,
	Stun = true, Reflect = true }

local function isValidDeathKind(k)
	return k == "ReduceAtk" or k == "ReduceMaxHp" or k == "AreaDamage"
end

function Cards.validate(maxCost)
	local n = 0
	for id, c in pairs(Cards.Data) do
		n += 1
		assert(c.id == id, id .. ": id no coincide con la clave")
		assert(c.type == "Creature" or c.type == "Spell", id .. ": type inválido")
		assert(type(c.cost) == "number" and c.cost >= 1 and c.cost <= maxCost, id .. ": costo fuera de rango")
		if c.type == "Creature" then
			assert(c.atk and c.hp and c.hp >= 1, id .. ": criatura sin atk/hp")
			if c.evolveFrom then
				assert(Cards.Data[c.evolveFrom], id .. ": evolveFrom no existe")
				assert(c.evolveCost and c.evolveCost >= 1 and c.evolveCost <= maxCost, id .. ": evolveCost fuera de rango")
			end
			if c.onDeath then
				assert(isValidDeathKind(c.onDeath.kind), id .. ": onDeath.kind inválido")
				assert(type(c.onDeath.amount) == "number" and c.onDeath.amount >= 1, id .. ": onDeath.amount inválido")
			end
			if c.aura then
				assert(c.aura.kind == "ReduceMaxHp", id .. ": aura.kind inválido")
				assert(type(c.aura.amount) == "number" and c.aura.amount >= 1, id .. ": aura.amount inválido")
			end
		else
			assert(c.speed == "Slow" or c.speed == "Fast", id .. ": speed inválido")
			assert(c.effect and c.effect.targets and #c.effect.targets > 0, id .. ": hechizo sin effect.targets")
			assert(KINDS[c.effect.kind], id .. ": effect.kind desconocido")
			if c.effect.duration ~= nil then
				assert(type(c.effect.duration) == "number" and c.effect.duration >= 1, id .. ": effect.duration inválido")
			end
			if c.effect.kind == "Stun" or c.effect.kind == "Reflect" then
				assert(c.effect.duration, id .. ": " .. c.effect.kind .. " requiere duration")
			end
		end
	end
	assert(#Cards.Order == n, "Cards.Order y Cards.Data tienen tamaños distintos")
	return true
end

return Cards
