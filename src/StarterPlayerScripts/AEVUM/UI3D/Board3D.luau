--!nonstrict
-- AEVUM · Tablero 3D: reconciliador (v1.3.0)
-- Misma forma que UI/Board.luau: Board3D.create(ctx) devuelve la función de render.
-- Compara el `view` nuevo con el anterior POR UID y decide qué animación toca:
--   mano → Banca · Banca → Combate (con volteo si se revela) · evolución · robar del mazo ·
--   tablero → mano · tablero/mano → cementerio.
-- Los `events` del servidor no se usan: el uid de cada carta ya dice de dónde viene y a dónde va.
--
-- Las cartas de tu Banca se ven boca arriba para ti; las del rival, boca abajo hasta que atacan.
-- Tu mano sigue siendo 2D: las cartas 3D salen y llegan a la posición del botón de la mano.
--
-- ctx:
--   origin, quality, skin (nombre de Skins; Config.Client.Skin), cards (CardDatabase.Data), theme
--   handRect(uid) -> centro, tamaño del botón de esa carta en la mano (en píxeles) o nil
--   isTarget(side, zone, slot, uid) · activatableAt(slot)
--   onMyBench / onMyCombat / onOppBench / onOppCombat (slot, inst) · onSlot(side, zone, index)
--   onAvatar(side) · onMiss() · requestRender()
--
-- Devuelve: render(state), show(), hide(), api { isHandHidden(uid), reset(), debug() }

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BoardBuilder = require(script.Parent.BoardBuilder)
local CameraRig = require(script.Parent.CameraRig)
local CardView = require(script.Parent.CardView)
local Input3D = require(script.Parent.Input3D)
local Layout = require(script.Parent.Layout)
local Motion = require(script.Parent.Motion)
local Skins = require(script.Parent.Skins)

local Board3D = {}

local DEFAULT_ORIGIN = Vector3.new(0, 500, 0) -- lejos de cualquier Baseplate del lugar
local N = 5 -- casillas por zona
local BLUE = Color3.fromRGB(120, 170, 255)
local ATK_TAG = Color3.fromRGB(150, 40, 40)
local BLOCK_TAG = Color3.fromRGB(40, 80, 150)
local SIDES = { "Self", "Enemy" }

function Board3D.create(ctx)
	ctx = ctx or {}
	local origin = ctx.origin or DEFAULT_ORIGIN
	local quality = ctx.quality or "High"
	local skinName = ctx.skin or Skins.Default
	local cardsDb = ctx.cards
	local theme = ctx.theme

	local scene, cardsFolder, pool
	local stopCamera, restoreLighting, stepConn, disconnectInput
	local pulses = {}
	local visible = false

	local live = {} -- uid -> carta 3D que está en una casilla
	local flyers = {} -- carta 3D -> true (vuelos que terminan fuera del tablero: se liberan solas)
	local hidden = {} -- uid de mano -> true mientras su carta 3D todavía está llegando
	local prev = nil -- snapshot del view anterior
	local activeMarkers = {} -- clave de casilla -> true
	local labels = {}
	local discAttacker = nil -- "Self" | "Enemy" | nil: quién tiene el derecho de ataque (view.attackerIdx)
	local discDirty = true

	-- ══════════════ Posiciones y destinos ══════════════

	-- Estado de reposo de una carta en su casilla (se evalúa "en vivo": cambia al seleccionarla)
	local function restOf(card)
		local p = Layout.slot(card.side, card.zone, card.slot, N)
		local lifted = card.selected == true
		return {
			x = p.x, y = Layout.CARD_Y + (lifted and Layout.SEL_LIFT or 0), z = p.z,
			flip = card.faceUp and 0 or math.pi, tilt = lifted and math.rad(12) or 0, scale = 1,
		}
	end

	-- Un punto de la pantalla -> estado 3D de una carta que "mira a la cámara" con ese tamaño aparente
	local function screenState(center, pixelWidth, flip)
		local cam = workspace.CurrentCamera
		local vs = cam.ViewportSize
		local tanHalf = math.tan(math.rad(cam.FieldOfView) / 2)
		local d = (Layout.CARD.w * vs.Y) / (2 * tanHalf * math.max(pixelWidth, 20))
		d = math.clamp(d, 8, 120)
		local ray = cam:ViewportPointToRay(center.X, center.Y)
		local w = ray.Origin + ray.Direction * d
		return {
			x = w.X - origin.X, y = w.Y - origin.Y, z = w.Z - origin.Z,
			tilt = math.rad(90 - CameraRig.PITCH), flip = flip or 0, scale = 1,
		}
	end

	-- Dónde está (o estaba) la carta de la mano, en coordenadas 3D. Sin botón: abajo al centro.
	local function handTarget(uid)
		local center, size
		if ctx.handRect then center, size = ctx.handRect(uid) end
		if not center then
			local vs = workspace.CurrentCamera.ViewportSize
			center, size = Vector2.new(vs.X * 0.49, vs.Y * 0.9), Vector2.new(vs.X * 0.07, 0)
		end
		return screenState(center, size.X, 0)
	end

	-- La mano del rival es solo un número: sus cartas salen/entran por el borde superior
	local function oppHandTarget()
		local vs = workspace.CurrentCamera.ViewportSize
		return screenState(Vector2.new(vs.X * 0.49, vs.Y * 0.02), vs.X * 0.05, math.pi)
	end

	local function deckStart(side)
		local t = Layout.deckTop(side)
		return { x = t.x, y = t.y, z = t.z, flip = math.pi, tilt = 0, scale = 0.9 }
	end

	local function assign(s, t)
		s.x, s.y, s.z = t.x or 0, t.y or 0, t.z or 0
		s.flip, s.tilt, s.scale = t.flip or 0, t.tilt or 0, t.scale or 1
	end

	local function settle(card, dur)
		return { dur = dur or 0.2, to = function() return restOf(card) end, ease = "backOut" }
	end

	local function later(fn)
		task.defer(fn)
	end

	-- ══════════════ Cartas ══════════════

	local function newCard(uid, e, start)
		local card = pool.acquire()
		card.uid = uid
		card.side, card.zone, card.slot = e.side, e.zone, e.slot
		card.faceUp = not e.faceDown
		card.inst = e.inst
		card.phase = (uid * 0.737) % 6.28
		card.model:SetAttribute("Uid", uid)
		CardView.setSide(card, e.side)
		if e.cardId then CardView.setContent(card, cardsDb, e.cardId, e.inst) end
		assign(card.s, start or restOf(card))
		live[uid] = card
		return card
	end

	-- Carta temporal (sin casilla) para vuelos de/hacia mano, mazo y cementerio
	local function newFlyer(side, cardId, inst, start, faceUp)
		local card = pool.acquire()
		card.model:SetAttribute("Uid", nil)
		card.side = side
		card.faceUp = faceUp
		CardView.setSide(card, side)
		if cardId then CardView.setContent(card, cardsDb, cardId, inst) end
		assign(card.s, start)
		flyers[card] = true
		return card
	end

	local function endFlyer(card)
		flyers[card] = nil
		pool.release(card)
	end

	-- Entrada a una casilla desde `start` (mano, borde del rival o mazo)
	local function playIn(card, delay)
		Motion.play(card.track, {
			{ delay = delay or 0, dur = 0.55, arc = 3, ease = "quadInOut",
				to = function() local r = restOf(card) r.y += 0.7 return r end },
			settle(card),
		})
	end

	-- Banca → Combate. Si la carta se revela (rival), se alza y se voltea antes de avanzar.
	local function advance(card, e)
		local wantUp = not e.faceDown
		local flipNeeded = card.faceUp ~= wantUp
		card.zone, card.slot = e.zone, e.slot
		if flipNeeded then
			if e.cardId then CardView.setContent(card, cardsDb, e.cardId, e.inst) end
			card.faceUp = wantUp
		end
		Motion.play(card.track, {
			{ dur = flipNeeded and 0.42 or 0.22, ease = "quadOut",
				to = { y = Layout.HOVER_Y, flip = flipNeeded and (wantUp and 0 or math.pi) or nil } },
			{ dur = 0.5, arc = 1.2, ease = "quadInOut",
				to = function() local r = restOf(card) r.y += 0.5 return r end },
			settle(card),
		})
	end

	-- Volteo en su sitio (por ejemplo, una carta boca abajo que se revela sin cambiar de zona)
	local function flipInPlace(card, e)
		local wantUp = not e.faceDown
		if e.cardId then CardView.setContent(card, cardsDb, e.cardId, e.inst) end
		card.faceUp = wantUp
		Motion.play(card.track, {
			{ dur = 0.4, ease = "quadOut", to = { y = Layout.HOVER_Y, flip = wantUp and 0 or math.pi } },
			settle(card, 0.25),
		})
	end

	local function slide(card, e)
		card.slot = e.slot
		Motion.play(card.track, {
			{ dur = 0.35, arc = 0.8, ease = "quadInOut", to = function() return restOf(card) end },
			settle(card, 0.15),
		})
	end

	-- Evolución: la misma carta cambia de forma (mismo uid, otro cardId)
	local function evolveBump(card, e)
		CardView.setContent(card, cardsDb, e.cardId, e.inst)
		Motion.play(card.track, {
			{ dur = 0.15, ease = "quadOut", to = function() local r = restOf(card) r.y += 1 r.scale = 1.25 return r end },
			{ dur = 0.3, ease = "backOut", to = function() return restOf(card) end },
		})
	end

	-- Tablero → mano. mine: la carta llega a tu mano 2D (se oculta su botón hasta que aterriza).
	local function toHand(card, uid, mine)
		if mine then hidden[uid] = true end
		flyers[card] = true
		live[uid] = nil
		card.model:SetAttribute("Uid", nil)
		Motion.play(card.track, {
			{ dur = 0.18, ease = "quadOut", to = { y = Layout.HOVER_Y, flip = mine and 0 or math.pi } },
			{ dur = 0.55, arc = 2, ease = "quadInOut",
				to = function() return mine and handTarget(uid) or oppHandTarget() end,
				onEnd = function()
					endFlyer(card)
					if mine then
						hidden[uid] = nil
						if ctx.requestRender then later(ctx.requestRender) end
					end
				end },
		})
	end

	-- Cualquier carta (ya sea del tablero o un vuelo) → cementerio de `side`, mostrándose boca arriba
	local function toGraveyard(card, side, cardId)
		if cardId and card.cardId ~= cardId then CardView.setContent(card, cardsDb, cardId, nil) end
		card.faceUp = true
		flyers[card] = true
		if card.uid then live[card.uid] = nil end
		card.model:SetAttribute("Uid", nil)
		local drop = Layout.graveDrop(side)
		Motion.play(card.track, {
			{ dur = 0.3, ease = "quadOut", to = { y = Layout.HOVER_Y - 0.6, flip = 0, tilt = 0 } },
			{ dur = 0.55, arc = 1.5, ease = "quadInOut", to = { x = drop.x, y = drop.y + 1.2, z = drop.z, scale = 0.6 } },
			{ dur = 0.15, ease = "quadInOut", to = { y = drop.y, scale = 0.05 }, onEnd = function() endFlyer(card) end },
		})
	end

	-- Carta de evolución: vuela hasta la criatura que evoluciona y se funde con ella
	local function toEvolveTarget(card, slot)
		local p = Layout.slot("Self", "Combat", slot, N)
		flyers[card] = true
		Motion.play(card.track, {
			{ dur = 0.2, ease = "quadOut", to = { y = Layout.HOVER_Y } },
			{ dur = 0.5, arc = 1.5, ease = "quadInOut", to = { x = p.x, y = Layout.CARD_Y + 0.8, z = p.z, scale = 0.5, tilt = 0 } },
			{ dur = 0.15, ease = "quadInOut", to = { scale = 0.05 }, onEnd = function() endFlyer(card) end },
		})
	end

	local function vanish(card)
		if card.uid then live[card.uid] = nil end
		card.model:SetAttribute("Uid", nil)
		flyers[card] = true
		Motion.play(card.track, {
			{ dur = 0.25, ease = "quadInOut", to = { scale = 0.05, y = Layout.CARD_Y + 1 }, onEnd = function() endFlyer(card) end },
		})
	end

	-- Robo propio: del mazo a tu mano 2D
	local function drawMine(uid, handInst, delay)
		local card = newFlyer("Self", handInst.cardId, handInst, deckStart("Self"), false)
		hidden[uid] = true
		Motion.play(card.track, {
			{ delay = delay, dur = 0.22, ease = "quadOut", to = { y = Layout.HOVER_Y, flip = 0, scale = 1 } },
			{ dur = 0.5, arc = 1.5, ease = "quadInOut", to = function() return handTarget(uid) end,
				onEnd = function()
					endFlyer(card)
					hidden[uid] = nil
					if ctx.requestRender then later(ctx.requestRender) end
				end },
		})
	end

	-- Robo del rival: del mazo rival a su borde (su mano es un número)
	local function drawOpp(delay)
		local card = newFlyer("Enemy", nil, nil, deckStart("Enemy"), false)
		Motion.play(card.track, {
			{ delay = delay, dur = 0.22, ease = "quadOut", to = { y = Layout.HOVER_Y, scale = 1 } },
			{ dur = 0.5, arc = 1.5, ease = "quadInOut", to = function() return oppHandTarget() end,
				onEnd = function() endFlyer(card) end },
		})
	end

	-- ══════════════ Snapshot y diferencias ══════════════

	local ORDER = { { "Self", "Bench" }, { "Self", "Combat" }, { "Enemy", "Bench" }, { "Enemy", "Combat" } }

	local function snapshot(view)
		local players = { Self = view.me, Enemy = view.opp }
		local snap = {
			turn = view.turn, you = view.you, hand = {}, handOrder = {}, board = {}, order = {},
			oppHand = view.opp.hand, deck = { Self = view.me.deck, Enemy = view.opp.deck },
			grave = { Self = {}, Enemy = {} },
		}
		for _, h in ipairs(view.me.hand) do
			snap.hand[h.uid] = h
			snap.handOrder[#snap.handOrder + 1] = h
		end
		for _, pair in ipairs(ORDER) do
			local side, zone = pair[1], pair[2]
			local pl = players[side]
			local list = zone == "Bench" and pl.bench or pl.combat
			for i = 1, N do
				local inst = list[i]
				if inst then
					local e = { uid = inst.uid, side = side, zone = zone, slot = i, cardId = inst.cardId,
						faceDown = inst.faceDown == true, inst = inst }
					snap.board[inst.uid] = e
					snap.order[#snap.order + 1] = e
				end
			end
		end
		for _, side in ipairs(SIDES) do
			for i, id in ipairs(players[side].graveyard) do snap.grave[side][i] = id end
		end
		return snap
	end

	local function resetCards()
		for _, card in pairs(live) do pool.release(card) end
		live = {}
		for card in pairs(flyers) do pool.release(card) end
		flyers = {}
		hidden = {}
		prev = nil
	end

	-- Primer estado (o partida nueva): todo aparece ya colocado, sin animar
	local function populate(cur)
		for _, e in ipairs(cur.order) do newCard(e.uid, e, nil) end
	end

	local function reconcile(cur)
		local p = prev

		-- Entradas nuevas del cementerio de cada bando (la lista es de cardId, no de uid)
		local newGrave = { Self = {}, Enemy = {} }
		for _, side in ipairs(SIDES) do
			for i = #p.grave[side] + 1, #cur.grave[side] do
				table.insert(newGrave[side], cur.grave[side][i])
			end
		end
		local function takeGrave(side, cardId)
			local list = newGrave[side]
			for i, id in ipairs(list) do
				if id == cardId then table.remove(list, i) return id end
			end
			return nil
		end

		-- A) Cartas que están en el tablero ahora
		local entering = { Self = 0, Enemy = 0 }
		for _, e in ipairs(cur.order) do
			local card = live[e.uid]
			if not card then
				local start
				if e.side == "Self" then
					start = p.hand[e.uid] and handTarget(e.uid) or deckStart("Self")
				else
					start = oppHandTarget()
				end
				card = newCard(e.uid, e, start)
				playIn(card, entering[e.side] * 0.14)
				entering[e.side] += 1
			else
				local zoneChanged = card.zone ~= e.zone
				local faceChanged = card.faceUp == e.faceDown
				card.inst = e.inst
				if zoneChanged then
					advance(card, e)
				elseif faceChanged then
					flipInPlace(card, e)
				elseif card.slot ~= e.slot then
					slide(card, e)
				elseif e.cardId and card.cardId and e.cardId ~= card.cardId then
					evolveBump(card, e)
				end
			end
		end

		-- B) Cartas que estaban en el tablero y ya no: a la mano, al cementerio o desaparecen
		local gone = {}
		for uid, card in pairs(live) do
			if not cur.board[uid] then gone[#gone + 1] = card end
		end
		table.sort(gone, function(a, b) return a.uid < b.uid end)
		local unknown = { Self = {}, Enemy = {} }
		for _, card in ipairs(gone) do
			if card.side == "Self" and cur.hand[card.uid] then
				toHand(card, card.uid, true)
			elseif card.cardId and takeGrave(card.side, card.cardId) then
				toGraveyard(card, card.side, card.cardId)
			elseif card.cardId == nil or not card.faceUp then
				table.insert(unknown[card.side], card) -- carta boca abajo del rival: su identidad la dirá el cementerio
			elseif card.side == "Enemy" then
				toHand(card, card.uid, false)
			else
				vanish(card)
			end
		end
		for _, side in ipairs(SIDES) do
			for _, card in ipairs(unknown[side]) do
				local id = table.remove(newGrave[side], 1)
				if id then toGraveyard(card, side, id)
				elseif side == "Enemy" then toHand(card, card.uid, false)
				else vanish(card) end
			end
		end

		-- C) Cartas de TU mano que se usaron sin quedar en el tablero: evolución o cementerio
		local claimed = {}
		for uid, inst in pairs(p.hand) do
			if not cur.hand[uid] and not cur.board[uid] then
				local target
				for _, e in ipairs(cur.order) do
					local before = p.board[e.uid]
					if e.side == "Self" and e.zone == "Combat" and e.cardId == inst.cardId and before
						and before.cardId ~= inst.cardId and not claimed[e.uid] then
						target = e
						claimed[e.uid] = true
						break
					end
				end
				local fly = newFlyer("Self", inst.cardId, inst, handTarget(uid), true)
				if target then
					toEvolveTarget(fly, target.slot)
				elseif takeGrave("Self", inst.cardId) then
					toGraveyard(fly, "Self", inst.cardId)
				else
					endFlyer(fly)
				end
			end
		end

		-- D) Robos propios: uids nuevos en tu mano que no vienen del tablero
		local k = 0
		for _, h in ipairs(cur.handOrder) do
			if not p.hand[h.uid] and not p.board[h.uid] then
				drawMine(h.uid, h, k * 0.18)
				k += 1
			end
		end

		-- E) Robos del rival (su mano es un número: usamos lo que baja su mazo)
		local oppDraws = math.min(4, p.deck.Enemy - cur.deck.Enemy)
		for i = 1, oppDraws do drawOpp((i - 1) * 0.18) end

		-- F) Entradas de cementerio del rival que nadie reclamó: salieron de su mano (descarte / evolución fallida)
		for _, id in ipairs(newGrave.Enemy) do
			local fly = newFlyer("Enemy", id, nil, oppHandTarget(), true)
			toGraveyard(fly, "Enemy", id)
		end
	end

	-- ══════════════ Resaltes, marcadores y contadores ══════════════

	-- Medallón de vida pequeño sobre el plinto del cristal y contadores discretos sobre mazo y cementerio.
	-- Nada de letreros gigantes ni AlwaysOnTop: no tapan la mesa (error ya cometido, plan §9).
	local function ensureLabels()
		if labels.ready or not scene then return end
		labels.ready = true
		local function billboard(adornee, offset, w, h)
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(w, h)
			bb.StudsOffset = offset
			bb.AlwaysOnTop = false
			bb.LightInfluence = 0
			bb.Adornee = adornee
			bb.Parent = adornee
			return bb
		end
		local function text(parent, props)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextStrokeTransparency = 0.35
			l.Text = ""
			for k, v in pairs(props) do l[k] = v end
			l.Parent = parent
			return l
		end
		local frameColor = Skins.rgb(scene.skin.frame)
		for _, side in ipairs(SIDES) do
			local color = scene.palette[side]
			-- Medallón: círculo oscuro con el número de vida (+ escudo en pequeño)
			local bb = billboard(scene.refs.plinth[side], Vector3.new(0, 1.1, 2.2), 46, 46)
			local medal = Instance.new("Frame")
			medal.Size = UDim2.fromScale(1, 1)
			medal.BackgroundColor3 = Color3.fromRGB(20, 18, 34)
			medal.BorderSizePixel = 0
			medal.Parent = bb
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = medal
			local stroke = Instance.new("UIStroke")
			stroke.Color = frameColor
			stroke.Thickness = 3
			stroke.Parent = medal
			labels["hp" .. side] = text(medal, { Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 255, 255) })
			labels["shield" .. side] = text(bb, { Position = UDim2.new(1, -2, 0, -6), Size = UDim2.fromOffset(26, 16),
				TextColor3 = Color3.fromRGB(150, 210, 255), Visible = false })
			-- Contadores sobre las pilas
			labels["deck" .. side] = text(billboard(scene.refs.decks[side], Vector3.new(0, 1.5, 0), 40, 18), { Size = UDim2.fromScale(1, 1), TextColor3 = color })
			labels["grave" .. side] = text(billboard(scene.refs.graveyards[side], Vector3.new(0, 1.3, 0), 40, 18), { Size = UDim2.fromScale(1, 1),
				TextColor3 = Color3.fromRGB(235, 235, 245) })
		end
	end

	local function setMarker(key, color)
		local m = scene.refs.markers[key]
		if m then
			m.Color = color
			activeMarkers[key] = true
		end
	end

	local function refreshVisuals(state, cur)
		local view = state.view
		local waiting = view.waiting
		local mine = waiting ~= nil and waiting.player == view.you
		local kind = waiting and waiting.kind or ""

		local atkSet, blockerSet = {}, {}
		if view.attack then for _, a in ipairs(view.attack.attackers) do atkSet[a] = true end end
		for a, b in pairs(state.blockPairs or {}) do blockerSet[b] = a end
		for _, b in ipairs(view.attack and view.attack.blocks or {}) do blockerSet[b.blocker] = b.attacker end
		local attackSel = state.attackSel or {}
		local sel = state.sel

		for uid, card in pairs(live) do
			local e = cur.board[uid]
			if e then
				local inst = e.inst
				card.inst = inst
				if card.faceUp and e.cardId then CardView.setContent(card, cardsDb, e.cardId, inst) end

				local tag, stroke
				if e.side == "Self" and e.zone == "Combat" then
					tag = (attackSel[uid] and "→ ATACARÁ") or (atkSet[uid] and "ATACA") or (blockerSet[uid] and "BLOQUEA") or nil
					if ctx.isTarget("Self", "Combat", e.slot, uid) then stroke = theme.tgt
					elseif attackSel[uid] or state.blockPick == uid or (sel and sel.uid == uid) then stroke = theme.sel end
				elseif e.side == "Self" then
					tag = inst.prepared and "[lista]" or "[en preparación]"
					if attackSel[uid] then tag = "→ ATACARÁ" end
					if state.blockPick == uid then tag = "→ bloqueará" end
					if blockerSet[uid] then tag = "BLOQUEA" end
					if ctx.isTarget("Self", "Bench", e.slot, uid) then stroke = theme.tgt
					elseif attackSel[uid] or state.blockPick == uid or (sel and sel.uid == uid) then stroke = theme.sel
					elseif ctx.activatableAt(e.slot) then stroke = BLUE end
				elseif e.zone == "Combat" then
					tag = (atkSet[uid] and "ATACA") or (blockerSet[uid] and "BLOQUEA") or nil
					stroke = ctx.isTarget("Enemy", "Combat", e.slot, uid) and theme.tgt or (atkSet[uid] and theme.atk) or nil
					if kind == "Block" and mine and state.blockPick and atkSet[uid] then stroke = theme.sel end
				else
					stroke = ctx.isTarget("Enemy", "Bench", e.slot, uid) and theme.tgt or nil
				end

				-- Estados de la criatura (solo si es visible)
				local status = {}
				if card.faceUp then
					if (inst.shield or 0) > 0 then table.insert(status, "ESCUDO " .. inst.shield) end
					if inst.stunned then table.insert(status, "ATURDIDA") end
					if inst.reflect then table.insert(status, "REFLEJO") end
				end
				local text = tag or ""
				if #status > 0 then text = (text ~= "" and (text .. " · ") or "") .. table.concat(status, " · ") end
				local tagColor
				if tag and tag:find("ATAC") then tagColor = ATK_TAG
				elseif tag and (tag:find("BLOQUE") or tag:find("bloque")) then tagColor = BLOCK_TAG end
				CardView.setTag(card, text, tagColor)
				CardView.setRing(card, stroke)

				-- Seleccionada = levantada
				local raised = (sel and sel.uid == uid and sel.zone ~= "hand") or attackSel[uid] == true or state.blockPick == uid
				if raised ~= card.selected then
					card.selected = raised
					if not card.track.active then
						Motion.play(card.track, { { dur = 0.15, ease = "quadOut", to = function() return restOf(card) end } })
					end
				end
			end
		end

		-- Marcadores de casilla
		for key in pairs(activeMarkers) do scene.refs.markers[key].Transparency = 1 end
		activeMarkers = {}
		if mine and kind == "Actions" and not state.targetMode and sel and sel.zone == "hand" then
			local h = cur.hand[sel.uid]
			if h and not (cardsDb[h.cardId] and cardsDb[h.cardId].evolveFrom) then
				for i = 1, N do
					if not view.me.bench[i] then setMarker(("Self:Bench:%d"):format(i), theme.tgt) end
				end
			end
		end
		if mine and kind == "AttackDeclare" then
			local n = 0
			for uid in pairs(attackSel) do
				local e = cur.board[uid]
				if e and e.side == "Self" and e.zone == "Bench" then n += 1 end
			end
			-- Los atacantes de la Banca entran de izquierda a derecha en las primeras casillas libres de Combate
			for _, slot in ipairs(Layout.freeSlots(view.me.combat, n, N)) do
				setMarker(("Self:Combat:%d"):format(slot), theme.atk)
			end
		end

		-- Cristales de vida (objetivo "Avatar"), medallón, contadores y pila del mazo
		ensureLabels()
		for _, side in ipairs(SIDES) do
			local pl = side == "Self" and view.me or view.opp
			local color = ctx.isTarget(side, "Avatar", 0, nil) and theme.tgt or scene.palette[side]
			for _, p in ipairs(scene.refs.vitalGem[side]) do p.Color = color end
			labels["hp" .. side].Text = tostring(pl.hp)
			local shield = pl.shield or 0
			labels["shield" .. side].Visible = shield > 0
			labels["shield" .. side].Text = "+" .. shield
			labels["deck" .. side].Text = tostring(pl.deck)
			labels["grave" .. side].Text = tostring(#pl.graveyard)
			scene.refs.setDeck(side, pl.deck)
		end

		-- Disco de turno: brilla la mitad de quien tiene el derecho de ataque (view.attackerIdx)
		local attacker = nil
		if view.attackerIdx and not view.over then attacker = (view.attackerIdx == view.you) and "Self" or "Enemy" end
		discAttacker = attacker
		discDirty = true
	end

	-- Brillo de las mitades del disco: la de quien ataca brilla y pulsa; la otra baja a ~45 %.
	-- Sin atacante (partida terminada): las dos a un brillo neutro.
	local function updateDisc(t)
		if not scene then return end
		local pulsing = discAttacker ~= nil and quality ~= "Low"
		if not (discDirty or pulsing) then return end
		discDirty = false
		for _, side in ipairs(SIDES) do
			local k
			if discAttacker == nil then k = 0.8
			elseif discAttacker == side then k = pulsing and (1.05 + 0.2 * math.sin(t * 4.4)) or 1.1
			else k = 0.45 end
			scene.refs.disc.set(side, Skins.shade(Skins.side(scene.skin, side), k))
		end
	end

	-- ══════════════ Entrada ══════════════

	local function handleHit(instance)
		local model = instance:FindFirstAncestorOfClass("Model")
		local uid = model and model:GetAttribute("Uid")
		if uid then
			local card = live[uid]
			if card and card.inst then
				if card.side == "Self" then
					if card.zone == "Combat" then ctx.onMyCombat(card.slot, card.inst) else ctx.onMyBench(card.slot, card.inst) end
				else
					if card.zone == "Combat" then ctx.onOppCombat(card.slot, card.inst) else ctx.onOppBench(card.slot, card.inst) end
				end
				return
			end
		end
		local kind = instance:GetAttribute("Kind")
		if kind == "slot" then
			ctx.onSlot(instance:GetAttribute("Side"), instance:GetAttribute("Zone"), instance:GetAttribute("Index"))
		elseif kind == "avatar" then
			ctx.onAvatar(instance:GetAttribute("Side"))
		elseif ctx.onMiss then
			ctx.onMiss()
		end
	end

	-- ══════════════ Ciclo de vida ══════════════

	local function step(dt)
		local t = os.clock()
		for _, card in pairs(live) do
			local active = Motion.step(card.track, dt)
			local bob = 0
			if quality ~= "Low" then
				card.bob = active and math.max(0, card.bob - dt * 4) or math.min(1, card.bob + dt * 2)
				bob = 0.08 * card.bob * math.sin(t * 1.6 + card.phase)
			end
			CardView.apply(card, origin, bob)
		end
		for card in pairs(flyers) do
			Motion.step(card.track, dt)
			if flyers[card] then CardView.apply(card, origin, 0) end -- onEnd puede haberla liberado ya
		end
		updateDisc(t)
		if quality ~= "Low" and scene then
			local river = scene.anim.river
			if river then
				for i, f in ipairs(river.frames) do f.Position = UDim2.fromScale(((i - 1) / river.n + t * 0.1) % 1, 0) end
			end
			for _, f in ipairs(scene.anim.fireflies) do
				local ph = (t * 0.18 + f.phase) % 1
				f.part.Position = origin + Vector3.new(f.x + math.sin(t + f.phase * 6) * 0.6, 0.8 + ph * 3.2, f.z)
				f.part.Transparency = 1 - math.sin(math.pi * ph) * 0.75
			end
		end
		if next(activeMarkers) then
			local a = 0.5 + 0.15 * math.sin(t * 4)
			for key in pairs(activeMarkers) do scene.refs.markers[key].Transparency = a end
		end
	end

	local function show()
		if visible then return end
		visible = true
		if not scene then
			CardView.setSkin(Skins.get(skinName)) -- colores de bando del reverso (antes de crear cartas)
			scene = BoardBuilder.build(origin, quality, skinName)
			cardsFolder = Instance.new("Folder")
			cardsFolder.Name = "Cartas"
			cardsFolder.Parent = scene.folder
			pool = CardView.newPool(cardsFolder, cardsDb, quality)
		end
		scene.folder.Parent = workspace
		restoreLighting = BoardBuilder.applyLighting(quality, skinName)
		stopCamera = CameraRig.start(origin)
		stepConn = RunService.RenderStepped:Connect(step)
		disconnectInput = Input3D.connect({
			getFilter = function() return { scene.folder } end,
			onHit = handleHit,
			onMiss = ctx.onMiss,
		})
		if quality ~= "Low" then
			local info = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			for _, p in ipairs(scene.glow) do
				local tween = TweenService:Create(p, info, { Transparency = math.min(0.9, scene.glowBase[p] + 0.35) })
				tween:Play()
				pulses[#pulses + 1] = tween
			end
		end
	end

	local function hide()
		if not visible then return end
		visible = false
		if stepConn then stepConn:Disconnect() stepConn = nil end
		if disconnectInput then disconnectInput() disconnectInput = nil end
		for _, tween in ipairs(pulses) do tween:Cancel() end
		pulses = {}
		resetCards()
		if scene then
			for _, p in ipairs(scene.glow) do p.Transparency = scene.glowBase[p] end
			scene.folder.Parent = nil
		end
		if stopCamera then stopCamera() stopCamera = nil end
		if restoreLighting then restoreLighting() restoreLighting = nil end
	end

	local function render(state)
		if not visible or not pool then return end
		local view = state.view
		local cur = snapshot(view)
		if not prev or view.turn < prev.turn or view.you ~= prev.you then
			resetCards()
			populate(cur)
		else
			reconcile(cur)
		end
		prev = cur
		refreshVisuals(state, cur)
	end

	local api = {
		isHandHidden = function(uid) return hidden[uid] == true end,
		reset = resetCards,
		discAttacker = function() return discAttacker end,
		debug = function()
			local n, f, h = 0, 0, 0
			for _ in pairs(live) do n += 1 end
			for _ in pairs(flyers) do f += 1 end
			for _ in pairs(hidden) do h += 1 end
			return { live = n, flyers = f, hidden = h }
		end,
	}
	return render, show, hide, api
end

return Board3D
