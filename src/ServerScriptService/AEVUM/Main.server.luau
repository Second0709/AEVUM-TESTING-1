--!nonstrict
-- AEVUM · Arranque del servidor (v1.3.0).

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
-- (v1.3.0) DebugPause solo efectivo en Studio. Aunque el flag esté en true
-- en producción, el atributo viaja como false y el botón no se crea.
remotes:SetAttribute("DebugPause", ServerConfig.DebugPause and RunService:IsStudio())
remotes.Parent = Shared

KillSwitch.start()
MatchService.start(remotes)
print("[AEVUM] Servidor listo v1.3.0. TestMode =", ServerConfig.TestMode)