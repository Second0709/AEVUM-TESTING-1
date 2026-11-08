local RightPanel = {}

local HINTS = {
	Actions = "Tu prioridad: juega una carta, activa un hechizo lento, evoluciona o pasa.",
	Response = "El rival declaró algo. Puedes responder con UN hechizo rápido o pasar.",
	AttackDeclare = "Elige tus atacantes (toca tus criaturas) y declara el ataque.",
	AttackEvolve = "Puedes evolucionar una criatura antes de continuar.",
	AttackResponse = "Te atacan. Puedes responder con UN hechizo rápido.",
	Block = "Toca una criatura tuya y luego el atacante rival al que bloquea.",
	FastWindow = "Ventana de hechizos rápidos (uno por jugador).",
	Discard = "Tienes más de 8 cartas: elige una de la mano para descartar.",
}

function RightPanel.create(ctx)
	return function()
		local state = ctx.getState()
		local view = state.view
		ctx.clear(ctx.parent)
		ctx.parent.CanvasPosition = Vector2.new(0, 0)
		local order = 0
		local function playerStatus(title, data, accent, side)
			order += 1
			local panel = ctx.new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Color3.fromRGB(20, 27, 62),
				BackgroundTransparency = 0.1, LayoutOrder = order }, ctx.parent)
			ctx.new("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
			ctx.new("UIStroke", { Color = accent, Thickness = 1.2 }, panel)
			local reflect = data.reflect and " · REFLEJO" or ""
			local shield = (data.shield or 0) > 0 and (" · Escudo " .. data.shield) or ""
			local name = ctx.label(panel, title .. " · " .. data.name, {
				Position = UDim2.new(0.06, 0, 0.08, 0), Size = UDim2.new(0.88, 0, 0, 20),
				TextColor3 = accent, Font = Enum.Font.GothamBold,
			})
			name.TextXAlignment = Enum.TextXAlignment.Left
			local health = ctx.label(panel, ("VIDA %d%s%s"):format(data.hp, shield, reflect), {
				Position = UDim2.new(0.06, 0, 0.42, 0), Size = UDim2.new(0.88, 0, 0, 22),
				TextColor3 = Color3.fromRGB(234, 240, 255),
			})
			health.TextXAlignment = Enum.TextXAlignment.Left

			order += 1
			local energy = ctx.new("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.fromRGB(20, 27, 62),
				BackgroundTransparency = 0.1, LayoutOrder = order }, ctx.parent)
			ctx.new("UICorner", { CornerRadius = UDim.new(0, 10) }, energy)
			ctx.new("UIStroke", { Color = Color3.fromRGB(42, 53, 104), Thickness = 1 }, energy)
			ctx.label(energy, ("ENERGÍA %d/%d · RESERVA %d"):format(data.energy, data.maxEnergy, data.reserve), {
				Position = UDim2.new(0.05, 0, 0.04, 0), Size = UDim2.new(0.9, 0, 0, 22),
				TextColor3 = Color3.fromRGB(143, 156, 196), Font = Enum.Font.GothamBold,
			})
			for i = 1, 8 do
				local isReserve = i > 6 and i - 6 <= data.reserve
				local filled = i <= data.energy or isReserve
				local orb = ctx.new("Frame", {
					Size = UDim2.new(0.14, 0, 0.24, 0), Position = UDim2.new(0.08 + ((i - 1) % 4) * 0.22, 0,
						0.39 + math.floor((i - 1) / 4) * 0.3, 0),
					BackgroundColor3 = isReserve and Color3.fromRGB(155, 107, 255) or Color3.fromRGB(255, 209, 102),
					BackgroundTransparency = filled and 0 or 0.88, BorderSizePixel = 0,
				}, energy)
				ctx.new("UIAspectRatioConstraint", { AspectRatio = 1 }, orb)
				ctx.new("UICorner", { CornerRadius = UDim.new(1, 0) }, orb)
				if isReserve then ctx.new("UIStroke", { Color = Color3.fromRGB(155, 107, 255), Thickness = 1 }, orb) end
			end
			-- Avatar como objetivo de hechizo: resaltar y hacerlo clickeable
			local tm = state.targetMode
			if tm and tm.kind == "spell" and side then
				for _, t in ipairs(tm.targets) do
					if t.side == side and t.zone == "Avatar" then
						local avBtn = ctx.new("TextButton", { Size = UDim2.new(1, 0, 1, 0),
							BackgroundTransparency = 1, Text = "", ZIndex = 5 }, panel)
						ctx.new("UIStroke", { Color = ctx.theme.tgt, Thickness = 3 }, avBtn)
						avBtn.Activated:Connect(function()
							ctx.tryTarget(side, "Avatar", 0, nil)
						end)
						break
					end
				end
			end
		end
		playerStatus("RIVAL", view.opp, Color3.fromRGB(255, 107, 214), "Enemy")
		playerStatus("TÚ", view.me, Color3.fromRGB(77, 225, 255), "Self")

		order += 1
		local function add(text, color, fn)
			order += 1
			local button = ctx.button(ctx.parent, text, color, fn)
			button.LayoutOrder = order
			return button
		end
		local function evolveControl(handInst, handCard)
			if not (handInst and handCard and handCard.evolveFrom) then return end
			if view.evolveOpen then
				add("Evolucionar…", ctx.theme.btn, function() ctx.startEvolve(handInst) end)
			else
				order += 1
				ctx.label(ctx.parent, "Las evoluciones se desbloquean en el turno 3.", {
					LayoutOrder = order, TextColor3 = ctx.theme.dim, Size = UDim2.new(1, 0, 0, 36),
				})
			end
		end
		local kind = view.waiting and view.waiting.kind or ""
		local isMine = view.waiting and view.waiting.player == view.you
		local hint = isMine and (HINTS[kind] or "") or "Esperando al rival…"
		if kind == "Actions" and isMine and not view.evolveOpen then
			hint = "Tu prioridad: juega una carta, activa un hechizo lento o pasa."
		end
		if state.targetMode then hint = "Elige un objetivo resaltado en verde (o toca otra cosa para cancelar)." end
		local header = ctx.label(ctx.parent, hint, { Size = UDim2.new(1, 0, 0, 70), LayoutOrder = order,
			TextColor3 = Color3.fromRGB(77, 225, 255) })
		header.TextScaled = false
		header.TextSize = 14
		order += 1

		if isMine and not state.targetMode then
			local handInst, handCard
			if state.sel and state.sel.zone == "hand" then
				for _, inst in ipairs(view.me.hand) do
					if inst.uid == state.sel.uid then handInst = inst end
				end
			end
			if handInst then handCard = ctx.cards[handInst.cardId] end

			if kind == "Actions" then
				if handInst and handCard and not handCard.evolveFrom then
					add("Jugar carta a la Banca", ctx.theme.btn, function() ctx.send({ type = "PlayCard", uid = handInst.uid }) end)
				end
				evolveControl(handInst, handCard)
				if state.sel and state.sel.zone == "bench" and ctx.activatableAt(state.sel.slot) then
					add("Activar hechizo lento…", ctx.theme.btn, function() ctx.startSpell("ActivateSlow", state.sel.slot) end)
				end
				add("Pasar prioridad", ctx.theme.btnOff, function() ctx.send({ type = "Pass" }) end)
			elseif kind == "Response" or kind == "AttackResponse" or kind == "FastWindow" then
				if state.sel and state.sel.zone == "bench" and ctx.activatableAt(state.sel.slot) then
					add("Activar hechizo rápido…", ctx.theme.btn, function() ctx.startSpell("ActivateFast", state.sel.slot) end)
				end
				add("No responder (pasar)", ctx.theme.btnOff, function() ctx.send({ type = "Pass" }) end)
			elseif kind == "AttackDeclare" then
				local n = 0
				local uids = {}
				for uid in pairs(state.attackSel) do n += 1 uids[#uids + 1] = uid end
				if n > 0 then add(("Declarar ataque (%d)"):format(n), ctx.theme.atk, function() ctx.send({ type = "DeclareAttack", attackers = uids }) end) end
				add("No atacar este turno", ctx.theme.btnOff, function() ctx.send({ type = "SkipAttack" }) end)
			elseif kind == "AttackEvolve" then
				evolveControl(handInst, handCard)
				add("Continuar el ataque", ctx.theme.btn, function() ctx.send({ type = "Continue" }) end)
			elseif kind == "Block" then
				local blocks, n = {}, 0
				for attacker, blocker in pairs(state.blockPairs) do
					n += 1
					blocks[#blocks + 1] = { attacker = attacker, blocker = blocker }
				end
				add(("Confirmar bloqueos (%d)"):format(n), ctx.theme.btn, function() ctx.send({ type = "AssignBlocks", blocks = blocks }) end)
				if view.attack.mode == "emergent" then
					order += 1
					ctx.label(ctx.parent, "Bloqueo emergente: máx. 2 criaturas de tu Banca.", {
						LayoutOrder = order, TextColor3 = ctx.theme.dim, Size = UDim2.new(1, 0, 0, 36),
					})
				end
			elseif kind == "Discard" then
				if handInst then add("Descartar esta carta", ctx.theme.atk, function() ctx.send({ type = "Discard", uid = handInst.uid }) end) end
			end
		end

		if state.inspect and ctx.cards[state.inspect] then
			local card = ctx.cards[state.inspect]
			local details = ctx.label(ctx.parent, ("%s\n%s\n%s"):format(card.name,
				card.type == "Creature" and "Criatura" or ("Hechizo " .. (card.speed == "Fast" and "rápido" or "lento")), card.text),
				{ Size = UDim2.new(1, 0, 0, 110), LayoutOrder = 50, TextColor3 = ctx.theme.dim })
			details.TextScaled = false
			details.TextSize = 13
			details.TextYAlignment = Enum.TextYAlignment.Top
		end
	end
end

return RightPanel
