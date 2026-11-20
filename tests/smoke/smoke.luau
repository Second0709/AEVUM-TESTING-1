local S = require("./_stubs")
local V3, renderSteppedFns, flushDeferred = S.V3, S.renderSteppedFns, S.flushDeferred
local Cards = require("./CardDatabase").Data
local Board3D = require("./Board3D")

local function expect(c, m) if not c then error(m, 2) end end

-- 0) cara mínima: pocas instancias por carta y solo arte + ATK + VIDA (hechizo: franja propia)
do
	local CardView = require("./CardView")
	local pool = CardView.newPool(S.Instance.new("Folder"), Cards, "High")
	local probe = pool.acquire()
	local count = #probe.model:GetDescendants() + 1
	print("instancias por carta:", count)
	expect(count <= 24, "una carta 3D debe tener <= 24 instancias (hoy " .. count .. ")")
	expect(probe.ui.name == nil and probe.ui.cost == nil, "la carta no lleva nombre ni costo")
	CardView.setContent(probe, Cards, "TITAN", { atk = 5, maxHp = 4, damage = 1, uid = 1 })
	expect(probe.ui.atk.Text == "5" and probe.ui.hp.Text == "3", "ATK y VIDA actuales en la carta")
	expect(probe.ui.atkBadge.Visible and probe.ui.hpBadge.Visible and not probe.ui.spell.Visible, "criatura: insignias, sin franja de hechizo")
	CardView.setContent(probe, Cards, "GOLPE", nil)
	expect(not probe.ui.atkBadge.Visible and probe.ui.spell.Visible, "hechizo: franja propia, sin insignias")
	pool.release(probe)
end

-- 0b) detalle grande de carta (panel derecho): ATK/VIDA actuales, sigue la evolución por uid, plantilla si ya no está
do
	local CardDetail = require("./CardDetail")
	local parent = S.Instance.new("Frame")
	parent.AbsoluteSize = S.V3(300, 900, 0)
	local function new(class, props, p)
		local o = S.Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		o.Parent = p
		return o
	end
	local ctx = { new = new, cards = Cards, theme = { text = 1, sel = 2 } }
	local function texts(frame)
		local out = {}
		for _, d in ipairs(frame:GetDescendants()) do
			if d.Text then out[d.Name] = d.Text end
		end
		return out
	end
	local view = { me = { hand = {}, bench = { false, false, false, false, false }, combat = { { uid = 5, cardId = "TITAN", atk = 7, maxHp = 4, damage = 1, shield = 2 } } },
		opp = { bench = {}, combat = {} } }
	local f = CardDetail.draw(ctx, parent, { view = view, inspect = "TITAN", inspectUid = 5 }, 50)
	local tx = texts(f)
	expect(tx.Nombre == Cards.TITAN.name and tx.Ataque == "ATK 7" and tx.Vida == "VIDA 3/4", "detalle: ATK/VIDA actuales de la instancia")
	expect(tx.Texto:find("ESCUDO 2") ~= nil, "detalle: estados de la criatura")
	view.me.combat[1] = { uid = 5, cardId = "HEROE", atk = 3, maxHp = 4, damage = 0 }
	tx = texts(CardDetail.draw(ctx, parent, { view = view, inspect = "APRENDIZ", inspectUid = 5 }, 50))
	expect(tx.Nombre == Cards.HEROE.name, "detalle: tras evolucionar manda la forma actual (mismo uid)")
	view.me.combat[1] = false
	tx = texts(CardDetail.draw(ctx, parent, { view = view, inspect = "GOLPE", inspectUid = 99 }, 50))
	expect(tx.Nombre == Cards.GOLPE.name and tx.Ataque == nil, "detalle: sin instancia viva muestra la plantilla (hechizo sin ATK/VIDA)")
	expect(CardDetail.draw(ctx, parent, { view = view }, 50) == nil, "detalle: sin carta elegida no dibuja nada")
end

-- 0c) arena: presupuesto de partes, redondos con Shape = Cylinder, zonas táctiles justas, calidad baja más ligera
do
	local BoardBuilder = require("./BoardBuilder")
	local function census(quality)
		local sc = BoardBuilder.build(S.V3(0, 0, 0), quality, "Ruinas")
		local c = { parts = 0, lights = 0, query = {}, sc = sc }
		for _, d in ipairs(sc.folder:GetDescendants()) do
			if d.ClassName == "Part" then
				c.parts += 1
				if d.CanQuery then c.query[#c.query + 1] = d end
			elseif d.ClassName == "PointLight" then
				c.lights += 1
			end
		end
		return c
	end
	local hi, lo = census("High"), census("Low")
	print("partes de la arena:", hi.parts, "(alta) /", lo.parts, "(baja) · luces:", hi.lights, "/", lo.lights)
	expect(hi.parts <= 130, "la arena debe tener <= 130 partes (hoy " .. hi.parts .. ")")
	expect(lo.parts < hi.parts and lo.lights == 0 and #lo.sc.anim.fireflies == 0 and lo.sc.anim.river == nil and #lo.sc.glow == 0,
		"calidad baja: sin luces, luciérnagas, río animado ni brillos")
	expect(hi.lights <= 6, "como mucho una luz por torre y por cristal")
	expect(#hi.sc.refs.discs == 19, "los redondos se crean con disc()")
	for _, p in ipairs(hi.sc.refs.discs) do
		expect(p.Shape == S.Enum.PartType.Cylinder, "toda pieza redonda debe tener Shape = Cylinder: " .. p.Name)
	end
	-- Zonas táctiles: 20 casillas + 2 cristales, finas y sin solaparse con las vecinas
	expect(#hi.query == 22, "solo 22 piezas consultables por raycast (20 casillas + 2 cristales), hay " .. #hi.query)
	for _, p in ipairs(hi.query) do
		if p:GetAttribute("Kind") == "slot" then
			expect(p.Size.X < 5 and p.Size.Y <= 0.2, "la zona de casilla es fina y no pisa a la vecina: " .. p.Name)
		else
			expect(p:GetAttribute("Kind") == "avatar" and p.Size.Y <= 4, "la zona del cristal es ajustada")
		end
	end
	for _, d in ipairs(hi.sc.folder:GetDescendants()) do
		local n = d.Name or ""
		expect(not (n:find("Canal") or n:find("Orbe") or n:find("Nodo")), "sin restos de neón del diseño anterior: " .. n)
	end
	-- Mazo: la pila crece con las cartas que quedan
	hi.sc.refs.setDeck("Self", 30)
	expect(hi.sc.refs.decks.Self.Size.Y > 1, "la pila del mazo crece con las cartas")
	expect(hi.sc.refs.markers["Self:Bench:3"] ~= nil and hi.sc.refs.hit["Enemy:Combat:1"] ~= nil, "marcadores y zonas por casilla")
	-- Disco de turno: círculo (Frame + UICorner) con degradado de corte duro; sin CanvasGroup (no recortó en Studio)
	local dcol = {}
	for _, d in ipairs(hi.sc.folder:GetDescendants()) do
		expect(d.ClassName ~= "CanvasGroup", "sin CanvasGroup en la arena")
		if d.Name == "DiscoCirculo" then dcol = d:GetChildren() end
	end
	local hasCorner, hasGrad = false, false
	for _, c in ipairs(dcol) do
		hasCorner = hasCorner or c.ClassName == "UICorner"
		hasGrad = hasGrad or c.ClassName == "UIGradient"
	end
	expect(hasCorner and hasGrad, "el disco es un círculo redondeado con degradado")
	local RED, BLUE2 = { 200, 40, 40 }, { 40, 80, 200 }
	hi.sc.refs.disc.set("Enemy", RED)
	hi.sc.refs.disc.set("Self", BLUE2)
	local kp = hi.sc.refs.disc.gradient.Color.Keypoints
	expect(#kp == 4 and kp[1].Value == RED and kp[2].Value == RED and kp[3].Value == BLUE2 and kp[4].Value == BLUE2,
		"disco: arriba el color del rival, abajo el tuyo, con corte en el centro")
	expect(kp[2].Time < kp[3].Time, "los tiempos del corte no se repiten")
	-- Skins: las tres construyen
	for _, name in ipairs({ "Ruinas", "Circuito", "Templo" }) do
		expect(BoardBuilder.build(S.V3(0, 0, 0), "High", name).refs.disc ~= nil, "la skin " .. name .. " construye la arena")
	end
end

local handRects = {}
local render, show, hide, api = Board3D.create({
	cards = Cards, theme = { sel = 1, tgt = 2, atk = 3 },
	handRect = function(uid) return V3(300 + uid * 50, 900, 0), V3(140, 200, 0) end,
	isTarget = function() return false end, activatableAt = function() return nil end,
	onMyBench = function() end, onMyCombat = function() end, onOppBench = function() end, onOppCombat = function() end,
	onSlot = function() end, onAvatar = function() end, requestRender = function() end,
})
show()
local step = renderSteppedFns[1]
local function run(seconds)
	for _ = 1, math.floor(seconds * 60) do step(1 / 60) flushDeferred() end
end

local function mineInst(uid, cardId, extra)
	local t = { uid = uid, cardId = cardId, damage = 0, prepared = true, atk = Cards[cardId].atk, maxHp = Cards[cardId].hp, shield = 0 }
	for k, v in pairs(extra or {}) do t[k] = v end
	return t
end
local function emptyZone() return { false, false, false, false, false } end
local function mkView(o)
	return {
		you = 1, turn = o.turn or 3, attackerIdx = 1, over = false,
		waiting = { player = 1, kind = o.kind or "Actions", timeLeft = 30 },
		me = { hp = 20, shield = 0, deck = o.deck or 30, hand = o.hand or {}, bench = o.bench or emptyZone(), combat = o.combat or emptyZone(), graveyard = o.grave or {} },
		opp = { hp = 20, shield = 0, deck = o.odeck or 30, hand = o.ohand or 5, bench = o.obench or emptyZone(), combat = o.ocombat or emptyZone(), graveyard = o.ograve or {} },
	}
end
local function state(view, extra)
	local s = { view = view, blockPairs = {}, attackSel = {}, blockPick = nil, sel = nil, targetMode = nil }
	for k, v in pairs(extra or {}) do s[k] = v end
	return s
end
local function hnd(uid, cardId) return { uid = uid, cardId = cardId, cost = Cards[cardId].cost } end

-- 1) primer estado: todo aparece sin animar
render(state(mkView({ hand = { hnd(1, "APRENDIZ"), hnd(2, "CENTINELA"), hnd(3, "GOLPE") } })))
expect(api.debug().live == 0 and api.debug().flyers == 0, "primer estado vacío")

-- 1b) disco de turno: brilla la mitad de quien ataca (view.attackerIdx); sin atacante al terminar
expect(api.discAttacker() == "Self", "disco: ataco yo (attackerIdx == you)")
do
	local v = mkView({})
	v.attackerIdx = 2
	render(state(v))
	expect(api.discAttacker() == "Enemy", "disco: ataca el rival")
	v.over = true
	render(state(v))
	expect(api.discAttacker() == nil, "disco: partida terminada, sin atacante")
	local v2 = mkView({ hand = { hnd(1, "APRENDIZ"), hnd(2, "CENTINELA"), hnd(3, "GOLPE") } })
	render(state(v2)) -- vuelve al estado del escenario 1 (mismos uid): sin vuelos
end

-- 2) juego uid 1 a la Banca (casilla 2): sale de la mano
local bench = emptyZone() bench[2] = mineInst(1, "APRENDIZ", { prepared = false })
render(state(mkView({ hand = { hnd(2, "CENTINELA"), hnd(3, "GOLPE") }, bench = bench })))
expect(api.debug().live == 1, "la carta jugada aparece en el tablero")
run(1.5)
expect(api.debug().flyers == 0, "sin vuelos pendientes tras jugar")

-- 3) el rival coloca una carta boca abajo en su Banca (casilla 3)
local obench = emptyZone() obench[3] = { uid = 100, faceDown = true }
render(state(mkView({ hand = { hnd(2, "CENTINELA"), hnd(3, "GOLPE") }, bench = bench, obench = obench, ohand = 4 })))
expect(api.debug().live == 2, "la carta boca abajo del rival aparece")
run(1.5)

-- 4) robo propio y del rival
render(state(mkView({ hand = { hnd(2, "CENTINELA"), hnd(3, "GOLPE"), hnd(4, "TITAN") }, bench = bench, obench = obench, ohand = 5, deck = 29, odeck = 29 })))
local d = api.debug()
expect(d.flyers == 2 and d.hidden == 1 and api.isHandHidden(4), "robos: 2 vuelos y la carta 4 oculta en la mano 2D")
run(2)
d = api.debug()
expect(d.flyers == 0 and d.hidden == 0, "los robos terminan y la mano deja de estar oculta")

-- 5) avance: mi uid 1 Banca->Combate; la carta del rival se revela y pasa a Combate
local combat = emptyZone() combat[1] = mineInst(1, "APRENDIZ")
local ocombat = emptyZone() ocombat[1] = { uid = 100, cardId = "CAZADOR", damage = 0, atk = 3, maxHp = 2, shield = 0 }
local hand5 = { hnd(2, "CENTINELA"), hnd(3, "GOLPE"), hnd(4, "TITAN") }
render(state(mkView({ hand = hand5, combat = combat, ocombat = ocombat, ohand = 5, deck = 29, odeck = 29, kind = "AttackDeclare" })))
expect(api.debug().live == 2 and api.debug().flyers == 0, "avance: sin cartas nuevas ni vuelos")
run(1.5)

-- 6) marcadores: con ataque declarado y una criatura en Banca seleccionada para atacar
local bench6 = emptyZone() bench6[1] = mineInst(9, "CENTINELA")
render(state(mkView({ hand = hand5, bench = bench6, combat = combat, ocombat = ocombat, ohand = 5, deck = 29, odeck = 29, kind = "AttackDeclare" }),
	{ attackSel = { [9] = true } }))
run(1)

-- 7) muertes: la mía va al cementerio y la del rival también (cardId en la lista de cementerio)
render(state(mkView({ hand = hand5, bench = bench6, combat = emptyZone(), ocombat = emptyZone(), ohand = 5, deck = 29, odeck = 29,
	grave = { "APRENDIZ" }, ograve = { "CAZADOR" } })))
expect(api.debug().flyers == 2 and api.debug().live == 1, "dos cartas van al cementerio")
run(2)
expect(api.debug().flyers == 0, "los vuelos al cementerio terminan")

-- 8) devolver al tablero->mano: la carta 9 de mi Banca aparece en mi mano
render(state(mkView({ hand = { hnd(2, "CENTINELA"), hnd(3, "GOLPE"), hnd(4, "TITAN"), hnd(9, "CENTINELA") }, deck = 29, odeck = 29,
	grave = { "APRENDIZ" }, ograve = { "CAZADOR" }, ohand = 5 })))
expect(api.debug().flyers == 1 and api.isHandHidden(9), "devolución: vuelo hacia la mano y carta 9 oculta")
run(2)
expect(api.debug().flyers == 0 and not api.isHandHidden(9), "la devolución termina")

-- 9) evolución: Aprendiz en Combate + Héroe en mano -> misma carta cambia de forma y la carta de la mano se funde
local c9 = emptyZone() c9[2] = mineInst(7, "APRENDIZ")
local h9 = { hnd(8, "HEROE"), hnd(2, "CENTINELA") }
render(state(mkView({ hand = h9, combat = c9, deck = 29, odeck = 29, grave = { "APRENDIZ" }, ograve = { "CAZADOR" } })))
run(1.5)
local c9b = emptyZone() c9b[2] = mineInst(7, "HEROE")
render(state(mkView({ hand = { hnd(2, "CENTINELA") }, combat = c9b, deck = 29, odeck = 29, grave = { "APRENDIZ" }, ograve = { "CAZADOR" } })))
expect(api.debug().flyers == 1, "evolución: la carta de evolución vuela hacia la criatura")
run(2)
expect(api.debug().flyers == 0 and api.debug().live == 1, "evolución termina")

-- 10) partida nueva (turno menor) y reset: se limpia todo
render(state(mkView({ turn = 1, hand = { hnd(1, "APRENDIZ") } })))
expect(api.debug().live == 0 and api.debug().flyers == 0, "partida nueva limpia el tablero")
api.reset()
hide()
print("Board3D smoke OK")
