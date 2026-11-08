--!nonstrict
-- AEVUM · Cliente (v1.3.0, sin KillRotation, con Stun/Reflect visuales)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = RS:WaitForChild("AEVUM")
local Cards = require(Shared:WaitForChild("CardDatabase")).Data
local Remotes = Shared:WaitForChild("Remotes")
local SoundCfg = require(Shared:WaitForChild("Config")).Sounds

local UI = script.Parent:WaitForChild("UI")
local C = require(UI:WaitForChild("Theme"))
local Widgets = require(UI:WaitForChild("Widgets"))
local BoardUI = require(UI:WaitForChild("Board"))
local HandUI = require(UI:WaitForChild("Hand"))
local LeftPanelUI = require(UI:WaitForChild("LeftPanel"))
local RightPanelUI = require(UI:WaitForChild("RightPanel"))
local LobbyUI = require(UI:WaitForChild("Lobby"))
local PauseUI = require(UI:WaitForChild("Pause"))
local BannerUI = require(UI:WaitForChild("Banner"))
local OverlayUI = require(UI:WaitForChild("Overlay"))
local new, clear = Widgets.new, Widgets.clear
local label, button = Widgets.label, Widgets.button
local playSound = require(UI:WaitForChild("Sounds")).create(SoundCfg)

local gui = new("ScreenGui", { Name = "AevumGui", ResetOnSpawn = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

local lobby, lobbyStatus = LobbyUI.create(gui, C, Widgets, Remotes)

local gameFrame = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.bg, Visible = false }, gui)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(30, 16, 66), C.bg), Rotation = 90 }, gameFrame)
local stars = Random.new(7)
for _ = 1, 70 do
	local size = stars:NextInteger(1, 3)
	new("Frame", { Size = UDim2.fromOffset(size, size), Position = UDim2.fromScale(stars:NextNumber(), stars:NextNumber()),
		BackgroundColor3 = C.text, BackgroundTransparency = stars:NextNumber(0.1, 0.7), BorderSizePixel = 0 }, gameFrame)
end

local topBar = new("TextLabel", { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0.065, 0),
	BackgroundColor3 = Color3.fromRGB(13, 18, 48), BackgroundTransparency = 0.12, TextColor3 = Color3.fromRGB(77, 225, 255),
	Font = Enum.Font.GothamBold, TextScaled = true, Text = "", ZIndex = 2 }, gameFrame)
new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 8 }, topBar)
new("UIStroke", { Color = Color3.fromRGB(42, 53, 104), Thickness = 1 }, topBar)

local left = new("Frame", { Position = UDim2.new(0.012, 0, 0.08, 0), Size = UDim2.new(0.13, 0, 0.91, 0),
	BackgroundColor3 = Color3.fromRGB(13, 18, 48), BackgroundTransparency = 0.12 }, gameFrame)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, left)
new("UIStroke", { Color = Color3.fromRGB(42, 53, 104), Thickness = 1.5 }, left)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, left)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6) }, left)

local board = new("Frame", { Position = UDim2.new(0.15, 0, 0.08, 0), Size = UDim2.new(0.68, 0, 0.68, 0),
	BackgroundTransparency = 1 }, gameFrame)
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, board)

local handFrame = new("Frame", { Position = UDim2.new(0.15, 0, 0.78, 0), Size = UDim2.new(0.68, 0, 0.21, 0),
	BackgroundColor3 = Color3.fromRGB(13, 18, 48), BackgroundTransparency = 0.12 }, gameFrame)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, handFrame)
new("UIStroke", { Color = Color3.fromRGB(42, 53, 104), Thickness = 1.5 }, handFrame)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
	VerticalAlignment = Enum.VerticalAlignment.Center }, handFrame)
new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, handFrame)

local right = new("ScrollingFrame", { Position = UDim2.new(0.835, 0, 0.08, 0), Size = UDim2.new(0.153, 0, 0.91, 0),
	BackgroundColor3 = Color3.fromRGB(13, 18, 48), BackgroundTransparency = 0.12, BorderSizePixel = 0,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	ScrollBarImageColor3 = Color3.fromRGB(77, 225, 255) }, gameFrame)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, right)
new("UIStroke", { Color = Color3.fromRGB(42, 53, 104), Thickness = 1.5 }, right)
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, right)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7),
	PaddingBottom = UDim.new(0, 8) }, right)

local toast = new("TextLabel", { Size = UDim2.new(0.4, 0, 0, 34), Position = UDim2.new(0.3, 0, 0.07, 0), BackgroundColor3 = Color3.fromRGB(120, 40, 40),
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextScaled = true, Visible = false, ZIndex = 20, Text = "" }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, toast)
-- Botón de debug pause (solo visible si ServerConfig.DebugPause == true)
local pauseBtn = PauseUI.create(gui, C, Widgets, Remotes)

local shownTurn = nil
local lastEventId = 0
local hideBanner, showBanner = BannerUI.create(gameFrame, new, TweenService)
local overlay, overText, overReason = OverlayUI.create(gui, C, Widgets, Remotes, function()
	hideBanner()
	shownTurn = nil
	lastEventId = 0
	gameFrame.Visible = false
	lobby.Visible = true
	pauseBtn.Visible = false
	lobbyStatus.Text = ""
end)

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

local function getPanelState()
	return {
		view = view, sel = sel, inspect = inspect, targetMode = targetMode,
		attackSel = attackSel, blockPick = blockPick, blockPairs = blockPairs,
	}
end

local renderBoard = BoardUI.create({
	parent = board, new = new, clear = clear, theme = C, cards = Cards, cardBtn = cardBtn, cardText = cardText,
	isTarget = isTarget, activatableAt = activatableAt,
	onOppBench = onOppBench, onOppCombat = onOppCombat, onMyCombat = onMyCombat, onMyBench = onMyBench,
	getState = getPanelState,
})
local renderHand = HandUI.create({
	parent = handFrame, clear = clear, theme = C, cards = Cards, cardBtn = cardBtn, cardText = cardText,
	isTarget = isTarget, onHand = onHand, getState = getPanelState,
})

local renderLeft = LeftPanelUI.create({
	parent = left, new = new, clear = clear, label = label, theme = C, cardBtn = cardBtn,
	isTarget = isTarget, tryTarget = tryTarget, render = function() render() end,
	getView = function() return view end,
})

local renderRight = RightPanelUI.create({
	parent = right, new = new, clear = clear, button = button, label = label, theme = C, cards = Cards,
	activatableAt = activatableAt, send = send, startSpell = startSpell, startEvolve = startEvolve,
	tryTarget = tryTarget,
	getState = getPanelState,
})

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
	pauseBtn.Visible = Remotes:GetAttribute("DebugPause") == true
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
	-- Debug pause: reflejar estado en el botón (si está visible)
	if pauseBtn.Visible then
		pauseBtn.Text = view.paused and "REANUDAR" or "PAUSAR"
		pauseBtn.BackgroundColor3 = view.paused and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(200, 60, 60)
	end
	if view.over then topBar.Text = "Partida terminada" return end
	if view.paused then
		topBar.Text = ("PAUSADO · Turno %d · El reloj está detenido"):format(view.turn)
		return
	end
	local w = view.waiting
	local left = math.max(0, math.ceil(w.timeLeft - (os.clock() - recvAt)))
	local who = (w.player == view.you) and "TU PRIORIDAD" or "PRIORIDAD DEL RIVAL"
	local owner = view.attackerIdx == view.you and "TU TURNO" or "TURNO RIVAL"
	local phase = view.attackOpen and "" or " · Apertura: sin ataque"
	topBar.Text = ("Turno %d · %s%s · %s · %ds"):format(view.turn, owner, phase, who, left)
end)