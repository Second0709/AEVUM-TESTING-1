--!nonstrict
-- AEVUM · Registro de eventos (v1.0).

local HttpService = game:GetService("HttpService")
local ServerConfig = require(script.Parent.ServerConfig)

local EventLog = {}
local entries = {}
local MAX = 500

function EventLog.record(kind, userId, data)
	local e = { t = os.time(), kind = kind, userId = userId, server = game.JobId, data = data }
	table.insert(entries, e)
	if #entries > MAX then table.remove(entries, 1) end
	if ServerConfig.PrintLogs then
		local ok, json = pcall(HttpService.JSONEncode, HttpService, e)
		print("[AEVUM]", ok and json or kind)
	end
end

function EventLog.recent() return entries end

return EventLog
