--!nonstrict
-- AEVUM · Servicio de partidas (v1.3.0).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("AEVUM")
local Cards = require(Shared:WaitForChild("CardDatabase"))
local Config = require(Shared:WaitForChild("Config"))
local Match = require(script.Parent.Match)
local BotBrain = require(script.Parent.BotBrain)
local Validator = require(script.Parent.Validator)
local RateLimiter = require(script.Parent.RateLimiter)
local EventLog = require(script.Parent.EventLog)
local KillSwitch = require(script.Parent.KillSwitch)
local Inventory = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ServerConfig = require(script.Parent.ServerConfig)


local MatchService = {}
local remotes
local records = {}
local playerRec = {}
local queue = {}
-- Dev tools: no consumen rate limit (solo accesibles en Studio).
local DEV_ACTIONS = { DebugPause = true }

-- ===== Pause (Opción D: clock inyectable, NO toca Match.luau) =====
-- makePausableClock devuelve (nowFn, state). Mientras state.paused == true,
-- nowFn() devuelve el acumulado y no avanza (aunque el wall-clock real sí).
-- Esto evita que isExpired/isStale disparen al despausar.
local function makePausableClock()
	local state = { paused = false, accum = 0, lastReal = os.clock() }
	local function now()
		local real = os.clock()
		if state.paused then
			state.lastReal = real
			return state.accum
		end
		state.accum += real - state.lastReal
		state.lastReal = real
		return state.accum
	end
	return now, state
end

local function notice(player, text)
	if player and player.Parent then remotes.Notice:FireClient(player, text) end
end
local function push(rec)
	for i, seat in ipairs(rec.seats) do
		if seat.player and seat.player.Parent then
			local view = rec.match:getView(i)
			view.paused = rec.paused or false
			remotes.State:FireClient(seat.player, view)
		end
	end
end
local function closeRec(rec)
	if rec.closed then return end
	rec.closed = true
	records[rec] = nil
	for _, seat in ipairs(rec.seats) do
		if seat.player and playerRec[seat.player] == rec then playerRec[seat.player] = nil end
	end
end

local afterChange
local scheduleBot

scheduleBot = function(rec)
	local m = rec.match
	local w = m.waiting
	if m.over or not w then return end
	if rec.paused then return end
	if not rec.seats[w.player].bot then return end
	rec.botToken = (rec.botToken or 0) + 1
	local token = rec.botToken
	task.delay(ServerConfig.Bot.ThinkTime, function()
		if rec.closed or rec.paused or rec.botToken ~= token or m.over or m.waiting ~= w then return end
		local ok, act = pcall(BotBrain.decide, m:getView(w.player), Cards.Data, Config.Match)
		local accepted = ok and m:submit(w.player, act)
		if not accepted then m:timeout() end
		afterChange(rec)
	end)
end

afterChange = function(rec)
	if rec.closed then return end
	push(rec)
	local m = rec.match
	if m.over then
		if not rec.endLogged then
			rec.endLogged = true
			EventLog.record("MatchEnded", 0, { id = rec.id, winner = m.winner or 0, reason = m.reason, turns = m.turn })
			for i, seat in ipairs(rec.seats) do
				if seat.player then
					local won = (m.winner == i)
					PlayerDataService.recordMatch(seat.player, won)
				end
			end
			task.delay(ServerConfig.ResultLingerSeconds, function() closeRec(rec) end)
		end
		return
	end
	scheduleBot(rec)
end

local function setPausedForRec(rec, v)
	if rec.closed then return end
	rec.paused = v
	rec.clockState.paused = v
	if not v then scheduleBot(rec) end
	push(rec)
	EventLog.record("PauseToggled", 0, { id = rec.id, paused = v })
end

local nextId = 0
local function startMatch(a, b)
	local humans = { a, b or false }

	-- (v1.3.0) Validar TODOS los mazos antes de tocar estado.
	-- Si uno falla, notificar a ambos, re-encolar al válido y salir sin limbo.
	local decks, invalid = {}, {}
	for i = 1, 2 do
		local pl = humans[i]
		if pl then
			local deck, err = Inventory.getValidatedDeck(pl)
			if deck then decks[i] = deck else invalid[i] = err or "mazo inválido" end
		end
	end
	local anyInvalid = false
	for _ in pairs(invalid) do anyInvalid = true break end
	if anyInvalid then
		for i = 1, 2 do
			local pl = humans[i]
			if pl then
				if invalid[i] then
					notice(pl, "Mazo inválido: " .. tostring(invalid[i]))
				else
					-- Este jugador está OK, pero el otro falló.
					local otherPl = humans[3 - i]
					if otherPl then
						notice(pl, "El rival no tiene un mazo válido. Volviendo a la cola…")
						if not table.find(queue, pl) then table.insert(queue, pl) end
					end
					-- Si otherPl es false/nil (bot), no re-encolar (PlayBot).
				end
			end
		end
		return false
	end

	local seats, plist = {}, {}
	for i = 1, 2 do
		local pl = humans[i]
		if pl then
			seats[i] = { player = pl, bot = false }
			plist[i] = { id = pl.UserId, name = pl.DisplayName, deck = decks[i] }
		else
			seats[i] = { bot = true }
			plist[i] = { id = 0, name = "Bot", deck = Inventory.buildTestDeck(), isBot = true }
		end
	end
	nextId += 1
	local rec = { id = nextId, seats = seats, seatOf = {} }
	-- Pause: cada partida tiene su propio clock pausable.
	local clock, clockState = makePausableClock()
	rec.clock = clock
	rec.clockState = clockState
	rec.paused = false
	rec.match = Match.new({ cfg = Config.Match, cards = Cards.Data, players = plist, clock = clock })
	for i, seat in ipairs(seats) do
		if seat.player then
			rec.seatOf[seat.player] = i
			playerRec[seat.player] = rec
		end
	end
	records[rec] = true
	EventLog.record("MatchStarted", a.UserId, { id = rec.id, vsBot = b == nil, opponent = b and b.UserId or 0 })
	rec.match:start()
	afterChange(rec)
	return true
end

local function removeFromQueue(player)
	local i = table.find(queue, player)
	if i then table.remove(queue, i) end
end

local function leave(player)
	removeFromQueue(player)
	local rec = playerRec[player]
	if not rec then return end
	local seat = rec.seatOf[player]
	if not rec.match.over then
		rec.match:forfeit(seat)
		EventLog.record("Forfeit", player.UserId, { id = rec.id })
		afterChange(rec)
	end
	playerRec[player] = nil
	rec.seats[seat].player = nil
	local anyHuman = false
	for _, s in ipairs(rec.seats) do if s.player then anyHuman = true end end
	if not anyHuman then closeRec(rec) end
end

local function onLobby(player, payload)
	local req = Validator.lobby(payload)
	if not req then return end

	-- Dev tools (DebugPause): sin rate limit, solo en Studio.
	if DEV_ACTIONS[req.type] then
		if req.type == "DebugPause" then
			if not ServerConfig.DebugPause then return end
			if not RunService:IsStudio() then return end
			local rec = playerRec[player]
			if not rec or rec.closed then return end
			setPausedForRec(rec, not rec.paused)
		end
		return
	end

	local ok, kick = RateLimiter.check(player)
	if not ok then
		if kick then player:Kick("Demasiadas peticiones.") end
		return
	end

	if req.type == "Leave" then leave(player) return end
	if playerRec[player] and not playerRec[player].match.over then return end
	if playerRec[player] then leave(player) end
	if not KillSwitch.isEnabled("Queue") or not KillSwitch.isEnabled("Matches") then
		notice(player, "Las partidas están desactivadas temporalmente.")
		return
	end
	if req.type == "PlayBot" then
		if not ServerConfig.Bot.Enabled then return end
		removeFromQueue(player)
		startMatch(player, nil)
	elseif req.type == "Queue" then
		if table.find(queue, player) then return end
		local rival = table.remove(queue, 1)
		if rival and rival.Parent then startMatch(rival, player)
		else
			table.insert(queue, player)
			notice(player, "Buscando rival…")
		end
	end
end

local function onAction(player, payload)
	local ok, kick = RateLimiter.check(player)
	if not ok then
		if kick then
			EventLog.record("KickedForSpam", player.UserId, {})
			player:Kick("Demasiadas peticiones.")
		end
		return
	end
	if not KillSwitch.isEnabled("Matches") then return end
	local clean, why = Validator.action(payload)
	if not clean then
		EventLog.record("InvalidPayload", player.UserId, { reason = why })
		return
	end
	local rec = playerRec[player]
	if not rec or rec.closed then return end
	if rec.paused then
		notice(player, "Partida pausada. Reanudá para seguir jugando.")
		return
	end
	local seat = rec.seatOf[player]
	local accepted, err = rec.match:submit(seat, clean)
	if accepted then
		EventLog.record("Action", player.UserId, { id = rec.id, type = clean.type, turn = rec.match.turn })
		afterChange(rec)
	else
		EventLog.record("ActionRejected", player.UserId, { id = rec.id, type = clean.type, why = err })
		notice(player, err or "Acción no válida")
		remotes.State:FireClient(player, rec.match:getView(seat))
	end
end

function MatchService.start(remotesFolder)
	remotes = remotesFolder
	remotes.Action.OnServerEvent:Connect(onAction)
	remotes.Lobby.OnServerEvent:Connect(onLobby)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		RateLimiter.forget(player)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for rec in pairs(records) do
				-- (pause) si la partida está pausada, no chequear timeouts.
				if not rec.closed and not rec.paused then
					if rec.match:isStale() then
						rec.match:staleFinish()
						afterChange(rec)
					elseif rec.match:isExpired() then
						rec.match:timeout()
						afterChange(rec)
					end
				end
			end
		end
	end)
end

return MatchService