--!nonstrict
-- AEVUM · Servicio central de inventario (v1.0).

local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("AEVUM")
local Cards = require(Shared:WaitForChild("CardDatabase"))
local Config = require(Shared:WaitForChild("Config"))
local ServerConfig = require(script.Parent.ServerConfig)

local Inventory = {}

function Inventory.buildTestDeck()
	local deck = {}
	for _, id in ipairs(Cards.Order) do
		local c = Cards.Data[id]
		local copies = c.legendary and Config.Match.MaxLegendaryCopies or Config.Match.MaxCopies
		for _ = 1, copies do deck[#deck + 1] = id end
	end
	return deck
end

local testProvider = {
	getCollection = function(_player)
		local col = {}
		for _, id in ipairs(Cards.Order) do col[id] = 99 end
		return col
	end,
	getDeck = function(_player) return Inventory.buildTestDeck() end,
}
local provider = testProvider

function Inventory.setProvider(p) provider = p end

function Inventory.validateDeck(player, deck)
	if type(deck) ~= "table" then return false, "mazo inválido" end
	if ServerConfig.TestMode then
		if #deck < 10 then return false, "el mazo de prueba debe tener al menos 10 cartas" end
		if #deck > 60 then return false, "el mazo de prueba no puede tener más de 60 cartas" end
	else
		if #deck ~= Config.Match.DeckSize then
			return false, ("el mazo debe tener exactamente %d cartas"):format(Config.Match.DeckSize)
		end
	end
	local owned = provider.getCollection(player)
	local used = {}
	for _, id in ipairs(deck) do
		local c = Cards.Data[id]
		if not c then return false, "carta inexistente: " .. tostring(id) end
		used[id] = (used[id] or 0) + 1
		local limit = c.legendary and Config.Match.MaxLegendaryCopies or Config.Match.MaxCopies
		if used[id] > limit then return false, ("demasiadas copias de %s"):format(c.name) end
		if used[id] > (owned[id] or 0) then return false, ("no posees suficientes copias de %s"):format(c.name) end
	end
	return true
end

function Inventory.getValidatedDeck(player)
	local deck = provider.getDeck(player)
	local ok, err = Inventory.validateDeck(player, deck)
	if not ok then return nil, err end
	return deck
end

return Inventory
