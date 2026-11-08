--!nonstrict
-- AEVUM · Servicio de datos de jugador (v1.3.0)
-- Requiere ServerScriptService.AEVUM.Vendor.ProfileStore

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("AEVUM")
local Cards = require(Shared:WaitForChild("CardDatabase"))
local ServerConfig = require(script.Parent.ServerConfig)
local EventLog = require(script.Parent.EventLog)
local Inventory = require(script.Parent.InventoryService)
local ProfileSchema = require(script.Parent.ProfileSchema)

local PlayerDataService = {}

local PROFILE_VERSION = 2

local function buildStarterDeck()
	return Inventory.buildStarterDeck()
end

local function buildStarterCollection()
	return Inventory.buildStarterCollection()
end

local function newProfile()
	return {
		Version = PROFILE_VERSION,
		Collection = buildStarterCollection(),
		Deck = buildStarterDeck(),
		Stats = { Wins = 0, Losses = 0, Matches = 0 },
		LastLogin = 0,
	}
end

local profiles = {}
local started = false

local testProvider = {
	getCollection = function(player)
		local profile = profiles[player]
		if profile then return table.clone(profile.Data.Collection) end
		return Inventory.buildStarterCollection()
	end,
	getDeck = function(player)
		local profile = profiles[player]
		return profile and table.clone(profile.Data.Deck) or buildStarterDeck()
	end,
}

local ProfileStoreLib = nil
local Store = nil

local function onProfileLoaded(player, profile)
	ProfileSchema.migrate(profile.Data, PROFILE_VERSION, {
		Collection = buildStarterCollection(),
		Deck = buildStarterDeck(),
	})
	profile.Data.LastLogin = os.time()
end

local function startTestMode()
	local function onPlayerAdded(player)
		if profiles[player] then return end
		local profile = { Data = newProfile() }
		function profile:IsActive() return profiles[player] == self end
		profiles[player] = profile
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player) profiles[player] = nil end)
	for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end
end

local realProvider = {
	getCollection = function(player)
		local p = profiles[player]
		if not p then return {} end
		return table.clone(p.Data.Collection)
	end,
	getDeck = function(player)
		local p = profiles[player]
		if not p then return {} end
		return table.clone(p.Data.Deck)
	end,
}

function PlayerDataService.start()
	if started then return false end
	started = true
	if ServerConfig.TestMode then
		startTestMode()
		print("[AEVUM] PlayerDataService: TestMode ON (sin persistencia)")
		return true
	end

	local ok, mod = pcall(function()
		return require(script.Parent.Vendor.ProfileStore)
	end)
	if not ok or not mod then
		warn("[AEVUM] ProfileStore no encontrado en ServerScriptService.AEVUM.Vendor.ProfileStore")
		warn("[AEVUM] Fallback a TestMode.")
		ServerConfig.TestMode = true
		startTestMode()
		return true
	end
	ProfileStoreLib = mod

	Store = ProfileStoreLib.New("AEVUM_PlayerData_v1", newProfile())

	if RunService:IsStudio() then
		Store = Store.Mock
		print("[AEVUM] PlayerDataService: ProfileStore MOCK activo (Studio, sin API)")
	end

	ProfileStoreLib.OnError:Connect(function(message, store_name, profile_key)
		warn(("[AEVUM] ProfileStore error: %s (store: %s; key: %s)"):format(message, store_name, profile_key))
	end)
	ProfileStoreLib.OnCriticalToggle:Connect(function(is_critical)
		warn("[AEVUM] ProfileStore estado crítico: " .. tostring(is_critical))
	end)

	local function onPlayerAdded(player)
		local okL, profile = pcall(function()
			return Store:StartSessionAsync("Player_" .. player.UserId, {
				Cancel = function() return not player.Parent end,
			})
		end)

		if not okL then
			warn(("[AEVUM] StartSessionAsync falló para %s: %s"):format(player.Name, tostring(profile)))
			if player.Parent then
				player:Kick("No se pudo cargar tu perfil (error). Intenta de nuevo.")
			end
			return
		end

		if not profile then
			warn(("[AEVUM] StartSessionAsync devolvió nil para %s"):format(player.Name))
			if player.Parent then
				player:Kick("No se pudo cargar tu perfil (nil). Intenta de nuevo.")
			end
			return
		end

		if type(profile) ~= "table" or type(profile.IsActive) ~= "function" or type(profile.EndSession) ~= "function" then
			warn("[AEVUM] El objeto devuelto NO es un Profile válido.")
			if player.Parent then
				player:Kick("Perfil inválido. Contacta al desarrollador.")
			end
			return
		end

		if not player.Parent then
			profile:EndSession()
			return
		end

		profile:AddUserId(player.UserId)
		onProfileLoaded(player, profile)
		profile:Reconcile()
		profile.OnSessionEnd:Connect(function()
			profiles[player] = nil
			if player.Parent then
				player:Kick("Tu perfil fue liberado. Reconéctate.")
			end
		end)
		profiles[player] = profile
		EventLog.record("ProfileLoaded", player.UserId, {})
	end

	local function onPlayerRemoving(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
			profiles[player] = nil
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	print("[AEVUM] PlayerDataService: ProfileStore activo")
end

function PlayerDataService.getProvider()
	if ServerConfig.TestMode then
		return testProvider
	else
		return realProvider
	end
end

function PlayerDataService.isLoaded(player)
	return profiles[player] ~= nil
end

function PlayerDataService.setDeck(player, deck)
	local p = profiles[player]
	if not p or not p:IsActive() then return false, "perfil no cargado" end
	local ok, err = Inventory.validateDeck(player, deck)
	if not ok then return false, err end
	p.Data.Deck = table.clone(deck)
	return true
end

function PlayerDataService.addCards(player, cards)
	local p = profiles[player]
	if not p or not p:IsActive() then return false, "perfil no cargado" end
	if type(cards) ~= "table" then return false, "entrada inválida" end
	for cardId, n in pairs(cards) do
		if not Cards.Data[cardId] then return false, "carta inexistente: " .. tostring(cardId) end
		if type(n) ~= "number" or n ~= n or n % 1 ~= 0 or n <= 0 then
			return false, "cantidad inválida para " .. tostring(cardId)
		end
	end
	for cardId, n in pairs(cards) do
		p.Data.Collection[cardId] = (p.Data.Collection[cardId] or 0) + n
	end
	return true
end

function PlayerDataService.recordMatch(player, won)
	local p = profiles[player]
	if not p or not p:IsActive() then return end
	p.Data.Stats.Matches = (p.Data.Stats.Matches or 0) + 1
	if won then
		p.Data.Stats.Wins = (p.Data.Stats.Wins or 0) + 1
	else
		p.Data.Stats.Losses = (p.Data.Stats.Losses or 0) + 1
	end
end

function PlayerDataService.getStats(player)
	local p = profiles[player]
	if not p then return nil end
	return table.clone(p.Data.Stats)
end

return PlayerDataService
