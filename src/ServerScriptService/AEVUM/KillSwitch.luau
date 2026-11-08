--!nonstrict
-- AEVUM · Interruptores de emergencia (v1.3.0).

local DataStoreService = game:GetService("DataStoreService")
local ServerConfig = require(script.Parent.ServerConfig)
local EventLog = require(script.Parent.EventLog)

local KillSwitch = {}
local flags = table.clone(ServerConfig.KillSwitches)
local started = false

function KillSwitch.isEnabled(name) return flags[name] ~= false end

local function poll(store)
	local ok, data = pcall(function() return store:GetAsync("flags") end)
	if ok and type(data) == "table" then
		for name, default in pairs(ServerConfig.KillSwitches) do
			if type(data[name]) == "boolean" and data[name] ~= flags[name] then
				flags[name] = data[name]
				EventLog.record("KillSwitchChanged", 0, { name = name, value = data[name] })
			end
		end
	end
end

function KillSwitch.start()
	if started then return end
	started = true
	local okStore, store = pcall(function() return DataStoreService:GetDataStore(ServerConfig.KillSwitchDataStore) end)
	if not okStore then return end
	task.spawn(function()
		while true do poll(store) task.wait(ServerConfig.KillSwitchPollSeconds) end
	end)
end

return KillSwitch
