--!nonstrict
-- AEVUM · Cliente (v1.1, sin KillRotation, con Stun/Reflect visuales)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local Shared = RS:WaitForChild("AEVUM")
local Cards = require(Shared:WaitForChild("CardDatabase")).Data
local Remotes = Shared:WaitForChild("Remotes")
local SoundCfg = require(Shared:WaitForChild("Config")).Sounds

local sounds = {}
local toPreload = {}
for _, name in ipairs({ "Select", "Deselect", "BlockKill", "Overkill" }) do
	local id = SoundCfg[name]
	if type(id) == "string" and id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "Aevum_" .. name
		s.SoundId = id
		s.Volume = SoundCfg.Volume or 0.6
		s.Parent = SoundService
		sounds[name] = s
		toPreload[#toPreload + 1] = s
	end
end
if #toPreload > 0 then task.spawn(function() pcall(ContentProvider.PreloadAsync, ContentProvider, toPreload) end) end

local function playSound(name)
	local s = sounds[name]
	if not s then return end
	s.TimePosition = 0
	s:Play()
end

local C = {
	bg = Color3.fromRGB(18, 20, 30), panel = Color3.fromRGB(28, 31, 46), card = Color3.fromRGB(46, 50, 72),
	faceDown = Color3.fromRGB(70, 48, 90), empty = Color3.fromRGB(30, 33, 48), text = Color3.fromRGB(235, 235, 245),
	dim = Color3.fromRGB(150, 155, 175), sel = Color3.fromRGB(250, 210, 70), tgt = Color3.fromRGB(80, 220, 120),
	atk = Color3.fromRGB(240, 90, 90), btn = Color3.fromRGB(70, 110, 200), btnOff = Color3.fromRGB(60, 62, 80),
}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function clear(frame)
	for _, ch in ipairs(frame:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
end
local function label(parent, text, props)
	local p = { Text = text, BackgroundTransparency = 1, TextColor3 = C.text, Font = Enum.Font.Gotham,
		TextScaled = true, TextWrapped = true, Size = UDim2.new(1, 0, 0, 20) }
	for k, v in pairs(props or {}) do p[k] = v end
	local l = new("TextLabel", p, parent)
	new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 8 }, l)
	return l
end
local function button(parent, text, color, onClick, props)
	local p = { Text = text, BackgroundColor3 = color, TextColor3 = C.text, Font = Enum.Font.GothamBold,
		TextScaled = true, TextWrapped = true, AutoButtonColor = true, Size = UDim2.new(1, 0, 0, 36) }
	for k, v in pairs(props or {}) do p[k] = v end
	local b = new("TextButton", p, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 }, b)
	if onClick then b.Activated:Connect(onClick) end
	return b
end

local gui = new("ScreenGui", { Name = "AevumGui", ResetOnSpawn = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

local lobby = new("Frame", { Size = UDim2.new(0, 420, 0, 320), Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.panel }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, lobby)
new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder }, lobby)
new("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }, lobby)
label(lobby, "AEVUM", { Size = UDim2.new(1, 0, 0, 50), Font = Enum.Font.GothamBlack, LayoutOrder = 1 })
label(lobby, "v1.1 · 20 cartas", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = C.dim, LayoutOrder = 2 })
local lobbyStatus = label(lobby, "", { Size = UDim2.new(1, 0, 0, 28), TextColor3 = C.sel, LayoutOrder = 3 })
local botBtn = button(lobby, "Jugar contra el Bot", C.btn, function()
	Remotes.Lobby:FireServer({ type = "PlayBot" })
end, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 48) })
button(lobby, "Buscar rival (2 jugadores)", C.btn, function()
	Remotes.Lobby:FireServer({ type = "Queue" })
end, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 48) })
button(lobby, "Cancelar búsqueda", C.btnOff, function()
	Remotes.Lobby:FireServer({ type = "Leave" })
	lobbyStatus.Text = ""
end, { LayoutOrder = 6 })
botBtn.Visible = Remotes:GetAttribute("BotAvailable") == true

local gameFrame = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.bg, Visible = false }, gui)

local topBar = new("TextLabel", { Size = UDim2.new(1, 0, 0.06, 0), BackgroundColor3 = C.panel, TextColor3 = C.text,
	Font = Enum.Font.GothamBold, TextScaled = true, Text = "" }, gameFrame)
new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 8 }, topBar)

local left = new("Frame", { Position = UDim2.new(0, 0, 0.06, 0), Size = UDim2.new(0.2, 0, 0.94, 0), BackgroundColor3 = C.panel }, gameFrame)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, left)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, left)

local board = new("Frame", { Position = UDim2.new(0.2, 0, 0.06, 0), Size = UDim2.new(0.6, 0, 0.62, 0), BackgroundTransparency = 1 }, gameFrame)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, board)

local handFrame = new("Frame", { Position = UDim2.new(0.2, 0, 0.68, 0), Size = UDim2.new(0.6, 0, 0.32, 0), BackgroundColor3 = C.panel }, gameFrame)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
	VerticalAlignment = Enum.VerticalAlignment.Center }, handFrame)
new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, handFrame)

local right = new("Frame", { Position = UDim2.new(0.8, 0, 0.06, 0), Size = UDim2.new(0.2, 0, 0.94, 0), BackgroundColor3 = C.panel }, gameFrame)
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, right)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, right)

local toast = new("TextLabel", { Size = UDim2.new(0.4, 0, 0, 34), Position = UDim2.new(0.3, 0, 0.07, 0), BackgroundColor3 = Color3.fromRGB(120, 40, 40),
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextScaled = true, Visible = false, ZIndex = 20, Text = "" }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, toast)

local shownTurn = nil
local lastEventId = 0
local bannerToken = 0
local bannerTweens = {}
local banner = new("Frame", { Position = UDim2.new(0.2, 0, 0.06, 0), Size = UDim2.new(0.6, 0, 0.94, 0), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, Visible = false, ZIndex = 15, Active = true }, gameFrame)
local bannerTitle = new("TextLabel", { Position = UDim2.new(0, 0, 0.36, 0), Size = UDim2.new(1, 0, 0.18, 0), BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextScaled = true, Text = "", ZIndex = 16 }, banner)
new("UITextSizeConstraint", { MaxTextSize = 72, MinTextSize = 16 }, bannerTitle)
local bannerSub = new("TextLabel", { Position = UDim2.new(0, 0, 0.55, 0), Size = UDim2.new(1, 0, 0.06, 0), BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(220, 225, 240), Font = Enum.Font.Gotham, TextScaled = true, Text = "", ZIndex = 16 }, banner)
new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 10 }, bannerSub)

local function hideBanner()
	bannerToken += 1
	for _, tw in ipairs(bannerTweens) do tw:Cancel() end
	bannerTweens = {}
	banner.Visible = false
end
local function showBanner(v)
	hideBanner()
	local t = bannerToken
	local mineTurn = v.attackerIdx == v.you
	banner.BackgroundColor3 = mineTurn and Color3.fromRGB(18, 48, 105) or Color3.fromRGB(95, 26, 32)
	bannerTitle.Text = mineTurn and "Tu turno" or "Turno rival"
	if not v.attackOpen then bannerSub.Text = ("Turno %d · Apertura: sin ataques ni evoluciones"):format(v.turn)
	elseif mineTurn then bannerSub.Text = ("Turno %d · Atacas este turno"):format(v.turn)
	else bannerSub.Text = ("Turno %d · El rival ataca este turno"):format(v.turn) end
	banner.BackgroundTransparency = 0.05
	bannerTitle.TextTransparency = 0
	bannerSub.TextTransparency = 0.15
	banner.Visible = true
	task.delay(1.1, function()
		if t ~= bannerToken then return end
		local info = TweenInfo.new(0.35)
		bannerTweens = {
			TweenService:Create(banner, info, { BackgroundTransparency = 1 }),
			TweenService:Create(bannerTitle, info, { TextTransparency = 1 }),
			TweenService:Create(bannerSub, info, { TextTransparency = 1 }),
		}
		for _, tw in ipairs(bannerTweens) do tw:Play() end
		task.delay(0.35, function() if t == bannerToken then banner.Visible = false end end)
	end)
end

local overlay = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
	Visible = false, ZIndex = 30 }, gui)
local overText = label(overlay, "", { Size = UDim2.new(0.6, 0, 0.12, 0), Position = UDim2.new(0.2, 0, 0.35, 0), ZIndex = 31, Font = Enum.Font.GothamBlack })
local overReason = label(overlay, "", { Size = UDim2.new(0.6, 0, 0.06, 0), Position = UDim2.new(0.2, 0, 0.48, 0), ZIndex = 31, TextColor3 = C.dim })
button(overlay, "Volver al menú", C.btn, function()
	Remotes.Lobby:FireServer({ type = "Leave" })
	overlay.Visible = false
	hideBanner()
	shownTurn = nil
	lastEventId = 0
	gameFrame.Visible = false
	lobby.Visible = true
	lobbyStatus.Text = ""
end, { Size = UDim2.new(0.2, 0, 0.07, 0), Position = UDim2.new(0.4, 0, 0.57, 0), ZIndex = 31 })

local view, recvAt = nil, 0
local sel = nil
local inspect = nil
local targetMode = nil
local attackSel = {}
local blockPick = nil
local blockPairs = {}
local lastKey = ""

local render

local function send(action)
	Remotes.Action:FireServer(action)
	sel, targetMode = nil, nil
end
local function mine() return view and view.waiting and view.waiting.player == view.you end
local function kind() return view and view.waiting and view.waiting.kind or "" end
local function activatableAt(slot)
	for _, a in ipairs(view.activatable or {}) do if a.slot == slot then return a end end
end

local function cardText(cid, inst, tag)
	local c = Cards[cid]
	local t
	if c.type == "Creature" then
		local maxHp = (inst and inst.maxHp) or c.hp
		local atk = (inst and inst.atk) or c.atk
		local hp = math.max(0, maxHp - ((inst and inst.damage) or 0))
		local displayCost = (inst and inst.cost) or (c.evolveFrom and c.evolveCost or c.cost)
		local costLabel = c.evolveFrom and ("Evol. " .. displayCost) or ("Costo " .. displayCost)
		t = ("%s\nATK %d · VIDA %d/%d\n%s"):format(c.name, atk, hp, maxHp, costLabel)
	else
		local displayCost = (inst and inst.cost) or c.cost
		t = ("%s\n%s · Costo %d"):format(c.name, c.speed == "Fast" and "Rápido" or "Lento", displayCost)
	end
	if inst and inst.shield and inst.shield > 0 then t = t .. "\nESCUDO " .. inst.shield end
	if inst and inst.stunned then t = t .. "\n[ATURDIDA]" end
	if inst and inst.reflect then t = t .. "\n[REFLEJO]" end
	if tag then t = t .. "\n" .. tag end
	return t
end

local function cardBtn(parent, size, text, bg, onClick, stroke, artId)
	local hasArt = type(artId) == "string" and artId ~= ""
	local b = new("TextButton", { Size = size, BackgroundColor3 = bg, TextColor3 = C.text, Font = Enum.Font.Gotham,
		TextScaled = true, TextWrapped = true, Text = hasArt and "" or text, AutoButtonColor = onClick ~= nil }, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 7 }, b)
	if hasArt then
		new("ImageLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = artId,
			ScaleType = Enum.ScaleType.Crop, ZIndex = 1 }, b)
		local overlay = new("Frame", { Size = UDim2.new(1, 0, 0.42, 0), Position = UDim2.new(0, 0, 0.58, 0),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2 }, b)
		local tl = new("TextLabel", { Size = UDim2.new(1, -6, 1, -4), Position = UDim2.new(0, 3, 0, 2),
			BackgroundTransparency = 1, Text = text, TextColor3 = C.text, Font = Enum.Font.Gotham,
			TextScaled = true, TextWrapped = true, ZIndex = 3 }, overlay)
		new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 6 }, tl)
	end
	if stroke then
		if stroke == C.sel then
			-- Glow pulsante: tres anillos concéntricos externos con opacidad decreciente
			local function ring(pad, thickness, trans)
				local r = new("Frame", { Size = UDim2.new(1, pad * 2, 1, pad * 2),
					Position = UDim2.new(0, -pad, 0, -pad), BackgroundTransparency = 1,
					BorderSizePixel = 0, ZIndex = 6 }, b)
				new("UICorner", { CornerRadius = UDim.new(0, 6 + pad) }, r)
				return new("UIStroke", { Color = stroke, Thickness = thickness, Transparency = trans }, r)
			end
			local s1 = ring(2, 2, 0.10)
			local s2 = ring(3, 3, 0.55)
			local s3 = ring(4, 4, 0.80)
			local info = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			TweenService:Create(s1, info, { Transparency = 0.55 }):Play()
			TweenService:Create(s2, info, { Transparency = 0.85 }):Play()
			TweenService:Create(s3, info, { Transparency = 0.95 }):Play()
		else
			new("UIStroke", { Color = stroke, Thickness = 3, ZIndex = 4 }, b)
		end
	end
	if onClick then b.Activated:Connect(onClick) end
	return b
end

local function isTarget(side, zone, slot, uid)
	if not targetMode then return false end
	if targetMode.kind == "spell" then
		for _, t in ipairs(targetMode.targets) do
			if t.side == side and t.zone == zone and t.slot == slot then return true end
		end
	elseif targetMode.kind == "evolve" then
		return side == "Self" and zone == "Combat" and uid ~= nil and targetMode.valid[uid] == true
	end
	return false
end

local function tryTarget(side, zone, slot, uid)
	if not targetMode then return false end
	if isTarget(side, zone, slot, uid) then
		if targetMode.kind == "spell" then
			send({ type = targetMode.action, slot = targetMode.slot, target = { side = side, zone = zone, slot = slot } })
		else
			send({ type = "Evolve", form = targetMode.form, target = uid })
		end
	else
		targetMode = nil
		playSound("Deselect")
		render()
	end
	return true
end

local function onHand(inst, index)
	if tryTarget("Self", "Hand", index, inst.uid) then return end
	targetMode = nil
	if sel and sel.zone == "hand" and sel.uid == inst.uid then
		sel = nil
		playSound("Deselect")
	else
		sel = { zone = "hand", uid = inst.uid }
		playSound("Select")
	end
	inspect = inst.cardId
	render()
end

local function toggleSel(zone, inst, slot)
	if sel and sel.zone == zone and sel.uid == inst.uid then
		sel = nil
		playSound("Deselect")
	else
		sel = { zone = zone, uid = inst.uid, slot = slot }
		playSound("Select")
	end
end

local function pickBlocker(uid)
	if blockPick == uid then
		blockPick = nil
		playSound("Deselect")
	else
		blockPick = uid
		playSound("Select")
	end
end

local function toggleAttacker(inst)
	if inst.stunned then return end
	local on = not attackSel[inst.uid]
	attackSel[inst.uid] = on or nil
	playSound(on and "Select" or "Deselect")
	render()
end

local function onMyBench(slot, inst)
	if tryTarget("Self", "Bench", slot, inst.uid) then return end
	inspect = inst.cardId
	if kind() == "AttackDeclare" and mine() then
		if inst.prepared and Cards[inst.cardId].type == "Creature" then toggleAttacker(inst) end
		return
	end
	if kind() == "Block" and mine() and view.attack.mode == "emergent" then
		if inst.prepared and Cards[inst.cardId].type == "Creature" then pickBlocker(inst.uid) end
		render()
		return
	end
	toggleSel("bench", inst, slot)
	render()
end

local function onMyCombat(slot, inst)
	if tryTarget("Self", "Combat", slot, inst.uid) then return end
	inspect = inst.cardId
	if kind() == "AttackDeclare" and mine() then toggleAttacker(inst) return end
	if kind() == "Block" and mine() and view.attack.mode == "regular" then pickBlocker(inst.uid) render() return end
	toggleSel("combat", inst, slot)
	render()
end

local function onOppCombat(slot, inst)
	if tryTarget("Enemy", "Combat", slot, inst.uid) then return end
	inspect = inst.cardId
	if kind() == "Block" and mine() and blockPick then
		local isAttacker = false
		for _, a in ipairs(view.attack.attackers) do if a == inst.uid then isAttacker = true end end
		if isAttacker then
			for a, b in pairs(blockPairs) do if b == blockPick then blockPairs[a] = nil end end
			blockPairs[inst.uid] = blockPick
			blockPick = nil
		end
	end
	render()
end

local function onOppBench(slot, inst)
	if tryTarget("Enemy", "Bench", slot, inst.uid) then return end
	render()
end

local function startSpell(action, slot)
	local a = activatableAt(slot)
	if not a then return end
	targetMode = { kind = "spell", action = action, slot = slot, targets = a.targets }
	render()
end

local function startEvolve(formInst)
	local base = Cards[formInst.cardId].evolveFrom
	local valid, any = {}, false
	for _, inst in ipairs(view.me.combat) do
		if inst and inst.cardId == base then valid[inst.uid] = true any = true end
	end
	if not any then
		toast.Text = "Necesitas esa criatura base en tu Zona de Combate"
		toast.Visible = true
		task.delay(2.5, function() toast.Visible = false end)
		return
	end
	targetMode = { kind = "evolve", form = formInst.uid, valid = valid }
	render()
end

local ROW_TITLES = { "BANCA RIVAL (boca abajo)", "COMBATE RIVAL", "TU COMBATE", "TU BANCA" }
local function boardRow(order, title)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0.245, 0), BackgroundColor3 = C.panel, LayoutOrder = order }, board)
	new("TextLabel", { Size = UDim2.new(1, 0, 0.14, 0), BackgroundTransparency = 1, Text = title, TextColor3 = C.dim,
		Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }, row)
	local slots = new("Frame", { Position = UDim2.new(0, 0, 0.14, 0), Size = UDim2.new(1, 0, 0.86, 0), BackgroundTransparency = 1 }, row)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center }, slots)
	return slots
end
local SLOT = UDim2.new(0.185, 0, 1, 0)

local function renderBoard()
	clear(board)
	local me, opp = view.me, view.opp
	local atkSet = {}
	if view.attack then for _, a in ipairs(view.attack.attackers) do atkSet[a] = true end end
	local blockerSet = {}
	for a, b in pairs(blockPairs) do blockerSet[b] = a end
	for _, b in ipairs(view.attack and view.attack.blocks or {}) do blockerSet[b.blocker] = b.attacker end
	local r1 = boardRow(1, ROW_TITLES[1])
	for s, inst in ipairs(opp.bench) do
		if inst then
			local tgt = isTarget("Enemy", "Bench", s, inst.uid)
			cardBtn(r1, SLOT, "Carta\nboca abajo", C.faceDown, function() onOppBench(s, inst) end, tgt and C.tgt or nil)
		else cardBtn(r1, SLOT, "—", C.empty) end
	end
	local r2 = boardRow(2, ROW_TITLES[2])
	for s, inst in ipairs(opp.combat) do
		if inst then
			local tag = atkSet[inst.uid] and "ATACA" or (blockerSet[inst.uid] and "BLOQUEA") or nil
			local tgt = isTarget("Enemy", "Combat", s, inst.uid)
			local stroke = tgt and C.tgt or (atkSet[inst.uid] and C.atk) or nil
			if view.waiting and kind() == "Block" and mine() and blockPick and atkSet[inst.uid] then stroke = C.sel end
			cardBtn(r2, SLOT, cardText(inst.cardId, inst, tag), C.card, function() onOppCombat(s, inst) end, stroke, Cards[inst.cardId].art)
		else cardBtn(r2, SLOT, "—", C.empty) end
	end
	local r3 = boardRow(3, ROW_TITLES[3])
	for s, inst in ipairs(me.combat) do
		if inst then
			local tag = (attackSel[inst.uid] and "→ ATACARÁ") or (atkSet[inst.uid] and "ATACA") or (blockerSet[inst.uid] and "BLOQUEA") or nil
			local stroke
			if isTarget("Self", "Combat", s, inst.uid) then stroke = C.tgt
			elseif attackSel[inst.uid] or blockPick == inst.uid or (sel and sel.uid == inst.uid) then stroke = C.sel end
						cardBtn(r3, SLOT, cardText(inst.cardId, inst, tag), C.card, function() onMyCombat(s, inst) end, stroke, Cards[inst.cardId].art)
		else cardBtn(r3, SLOT, "—", C.empty) end
	end
	local r4 = boardRow(4, ROW_TITLES[4])
	for s, inst in ipairs(me.bench) do
		if inst then
			local c = Cards[inst.cardId]
			local tag = inst.prepared and "[lista]" or "[en preparación]"
			if attackSel[inst.uid] then tag = "→ ATACARÁ" end
			if blockPick == inst.uid then tag = "→ bloqueará" end
			if blockerSet[inst.uid] then tag = "BLOQUEA" end
			local stroke
			if isTarget("Self", "Bench", s, inst.uid) then stroke = C.tgt
			elseif attackSel[inst.uid] or blockPick == inst.uid or (sel and sel.uid == inst.uid) then stroke = C.sel
			elseif activatableAt(s) then stroke = Color3.fromRGB(120, 170, 255) end
			cardBtn(r4, SLOT, cardText(inst.cardId, inst, tag), c.type == "Spell" and Color3.fromRGB(60, 70, 110) or C.card,
				function() onMyBench(s, inst) end, stroke, c.art)
		else cardBtn(r4, SLOT, "—", C.empty) end
	end
end

local function renderHand()
	clear(handFrame)
	for idx, inst in ipairs(view.me.hand) do
		local stroke
		if isTarget("Self", "Hand", idx, inst.uid) then stroke = C.tgt
		elseif sel and sel.uid == inst.uid then stroke = C.sel end
				cardBtn(handFrame, UDim2.new(0.105, 0, 1, 0), cardText(inst.cardId, inst), C.card, function() onHand(inst, idx) end, stroke, Cards[inst.cardId].art)
	end
end

local function makeSword(parent)
	local box = new("Frame", { Size = UDim2.new(0, 36, 0, 36), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1, Rotation = 45, ZIndex = 6 }, parent)
	local function part(x, y, w, h, color, radius)
		local f = new("Frame", { Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 6 }, box)
		if radius then new("UICorner", { CornerRadius = UDim.new(0, radius) }, f) end
	end
	part(15, 0, 6, 22, Color3.fromRGB(225, 230, 245), 3)
	part(17, 3, 2, 17, Color3.fromRGB(150, 160, 190))
	part(9, 22, 18, 4, Color3.fromRGB(240, 190, 60), 2)
	part(16, 26, 4, 6, Color3.fromRGB(120, 80, 50))
	part(14, 32, 8, 3, Color3.fromRGB(240, 190, 60), 1)
	return box
end

local function renderLeft()
	clear(left)
	local me, opp = view.me, view.opp
	local function avatar(side, d, order)
		local tgt = isTarget(side, "Avatar", 0, nil)
		local who = side == "Self" and ("TÚ · " .. d.name) or ("RIVAL · " .. d.name)
		local isAttacker = view.attackOpen and ((side == "Self") == (view.attackerIdx == view.you))
		local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1, LayoutOrder = order }, left)
		local reflectTag = d.reflect and " · REFLEJO" or ""
		cardBtn(wrap, UDim2.new(0.8, -2, 1, 0), ("%s\nVIDA %d" .. ((d.shield or 0) > 0 and (" · ESCUDO " .. d.shield) or "") .. reflectTag .. "\nEnergía %d/%d · Reserva %d\nMazo %d · Mano %s"):format(
			who, d.hp, d.energy, d.maxEnergy, d.reserve, d.deck, tostring(type(d.hand) == "table" and #d.hand or d.hand)),
			C.card, function() if not tryTarget(side, "Avatar", 0, nil) then render() end end,
			tgt and C.tgt or (isAttacker and C.atk or nil))
		if isAttacker then
			local box = new("Frame", { Position = UDim2.new(0.8, 0, 0, 0), Size = UDim2.new(0.2, 0, 1, 0), BackgroundTransparency = 1 }, wrap)
			makeSword(box)
		end
	end
	avatar("Enemy", opp, 1)
	avatar("Self", me, 3)
	local lg = label(left, table.concat(view.log, "\n"), { Size = UDim2.new(1, 0, 1, -170), LayoutOrder = 4,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.dim, TextScaled = false, TextSize = 12 })
	lg.TextTruncate = Enum.TextTruncate.None
end

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

local function renderRight()
	clear(right)
	local order = 0
	local function add(text, color, fn)
		order += 1
		local b = button(right, text, color, fn)
		b.LayoutOrder = order
		return b
	end
	local function evolveControl(handInst, handCard)
		if not (handInst and handCard and handCard.evolveFrom) then return end
		if view.evolveOpen then
			add("Evolucionar…", C.btn, function() startEvolve(handInst) end)
		else
			order += 1
			label(right, "Las evoluciones se desbloquean en el turno 3.", { LayoutOrder = order, TextColor3 = C.dim, Size = UDim2.new(1, 0, 0, 36) })
			order += 1
		end
	end
	local k = kind()
	local isMine = mine()
	local hint = isMine and (HINTS[k] or "") or "Esperando al rival…"
	if k == "Actions" and isMine and not view.evolveOpen then
		hint = "Tu prioridad: juega una carta, activa un hechizo lento o pasa."
	end
	if targetMode then hint = "Elige un objetivo resaltado en verde (o toca otra cosa para cancelar)." end
	local h = label(right, hint, { Size = UDim2.new(1, 0, 0, 70), LayoutOrder = 0, TextColor3 = C.sel })
	h.TextScaled = false h.TextSize = 14

	if isMine and not targetMode then
		local handCard = sel and sel.zone == "hand" and Cards[(function() for _, i in ipairs(view.me.hand) do if i.uid == sel.uid then return i.cardId end end end)()] or nil
		local handInst
		if sel and sel.zone == "hand" then for _, i in ipairs(view.me.hand) do if i.uid == sel.uid then handInst = i end end end

		if k == "Actions" then
			if handInst and handCard and not handCard.evolveFrom then
				add("Jugar carta a la Banca", C.btn, function() send({ type = "PlayCard", uid = handInst.uid }) end)
			end
			evolveControl(handInst, handCard)
			if sel and sel.zone == "bench" and activatableAt(sel.slot) then
				add("Activar hechizo lento…", C.btn, function() startSpell("ActivateSlow", sel.slot) end)
			end
			add("Pasar prioridad", C.btnOff, function() send({ type = "Pass" }) end)
		elseif k == "Response" or k == "AttackResponse" or k == "FastWindow" then
			if sel and sel.zone == "bench" and activatableAt(sel.slot) then
				add("Activar hechizo rápido…", C.btn, function() startSpell("ActivateFast", sel.slot) end)
			end
			add("No responder (pasar)", C.btnOff, function() send({ type = "Pass" }) end)
		elseif k == "AttackDeclare" then
			local n = 0
			local uids = {}
			for uid in pairs(attackSel) do n += 1 uids[#uids + 1] = uid end
			if n > 0 then add(("Declarar ataque (%d)"):format(n), C.atk, function() send({ type = "DeclareAttack", attackers = uids }) end) end
			add("No atacar este turno", C.btnOff, function() send({ type = "SkipAttack" }) end)
		elseif k == "AttackEvolve" then
			evolveControl(handInst, handCard)
			add("Continuar el ataque", C.btn, function() send({ type = "Continue" }) end)
		elseif k == "Block" then
			local blocks, n = {}, 0
			for a, b in pairs(blockPairs) do n += 1 blocks[#blocks + 1] = { attacker = a, blocker = b } end
			add(("Confirmar bloqueos (%d)"):format(n), C.btn, function() send({ type = "AssignBlocks", blocks = blocks }) end)
			if view.attack.mode == "emergent" then
				label(right, "Bloqueo emergente: máx. 2 criaturas de tu Banca.", { LayoutOrder = order + 1, TextColor3 = C.dim, Size = UDim2.new(1, 0, 0, 36) })
			end
		elseif k == "Discard" then
			if handInst then add("Descartar esta carta", C.atk, function() send({ type = "Discard", uid = handInst.uid }) end) end
		end
	end

	if inspect and Cards[inspect] then
		local c = Cards[inspect]
		local d = label(right, ("%s\n%s\n%s"):format(c.name, c.type == "Creature" and "Criatura" or ("Hechizo " .. (c.speed == "Fast" and "rápido" or "lento")), c.text),
			{ Size = UDim2.new(1, 0, 0, 110), LayoutOrder = 50, TextColor3 = C.dim })
		d.TextScaled = false d.TextSize = 13 d.TextYAlignment = Enum.TextYAlignment.Top
	end
end

render = function()
	if not view then return end
	local key = view.turn .. (view.waiting and (view.waiting.kind .. view.waiting.player) or "end")
	if key ~= lastKey then
		lastKey = key
		sel, targetMode, attackSel, blockPick, blockPairs = nil, nil, {}, nil, {}
	end
	renderBoard()
	renderHand()
	renderLeft()
	renderRight()
end

Remotes.State.OnClientEvent:Connect(function(v)
	local firstState = (shownTurn == nil)
	for _, ev in ipairs(v.events or {}) do
		if ev.id > lastEventId then
			lastEventId = ev.id
			if not firstState and (ev.kind == "BlockKill" or ev.kind == "Overkill") then
				playSound(ev.kind)
			end
		end
	end
	view, recvAt = v, os.clock()
	lobby.Visible = false
	gameFrame.Visible = true
	render()
	if v.over then hideBanner()
	elseif v.turn ~= shownTurn then shownTurn = v.turn showBanner(v) end
	if v.over then
		overlay.Visible = true
		if v.winner == 0 then overText.Text = "EMPATE"
		elseif v.winner == v.you then overText.Text = "¡VICTORIA!" else overText.Text = "DERROTA" end
		overReason.Text = v.reason
	else overlay.Visible = false end
end)

local toastToken = 0
Remotes.Notice.OnClientEvent:Connect(function(text)
	lobbyStatus.Text = text
	toast.Text = text
	toast.Visible = gameFrame.Visible
	toastToken += 1
	local t = toastToken
	task.delay(3, function() if t == toastToken then toast.Visible = false end end)
end)

RunService.Heartbeat:Connect(function()
	if not view or not gameFrame.Visible then return end
	if view.over then topBar.Text = "Partida terminada" return end
	local w = view.waiting
	local left = math.max(0, math.ceil(w.timeLeft - (os.clock() - recvAt)))
	local who = (w.player == view.you) and "TU PRIORIDAD" or "PRIORIDAD DEL RIVAL"
	local owner = view.attackerIdx == view.you and "TU TURNO" or "TURNO RIVAL"
	local phase = view.attackOpen and "" or " · Apertura: sin ataque"
	topBar.Text = ("Turno %d · %s%s · %s · %ds"):format(view.turn, owner, phase, who, left)
end)