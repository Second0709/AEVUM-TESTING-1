--!nonstrict
-- AEVUM · Arranque del servidor (v1.0).

local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("AEVUM")
local Config = require(Shared:WaitForChild("Config"))
local Cards = require(Shared:WaitForChild("CardDatabase"))
local ServerConfig = require(script.Parent.ServerConfig)
local KillSwitch = require(script.Parent.KillSwitch)
local MatchService = require(script.Parent.MatchService)
local InventoryService = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)

Cards.validate(Config.Match.MaxEnergy)

PlayerDataService.start()
InventoryService.setProvider(PlayerDataService.getProvider())

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({ "Action", "Lobby", "State", "Notice" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
remotes:SetAttribute("BotAvailable", ServerConfig.Bot.Enabled)
remotes:SetAttribute("DebugPause", ServerConfig.DebugPause)  -- (nuevo)
remotes.Parent = Shared

KillSwitch.start()
MatchService.start(remotes)
print("[AEVUM] Servidor listo v1.0. TestMode =", ServerConfig.TestMode)