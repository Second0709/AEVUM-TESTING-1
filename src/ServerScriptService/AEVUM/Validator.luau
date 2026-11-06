--!nonstrict
-- AEVUM · Módulo de validación (v1.0).

local Validator = {}
local MAX_INT = 1000000

local function isInt(v, min, max)
	return type(v) == "number" and v == math.floor(v) and v >= (min or 0) and v <= (max or MAX_INT)
end
local function target(t)
	if type(t) ~= "table" then return nil end
	if t.side ~= "Self" and t.side ~= "Enemy" then return nil end
	if t.zone ~= "Avatar" and t.zone ~= "Combat" and t.zone ~= "Bench" and t.zone ~= "Hand" then return nil end
	if not isInt(t.slot, 0, 10) then return nil end
	return { side = t.side, zone = t.zone, slot = t.slot }
end
local function intList(l, maxLen)
	if type(l) ~= "table" or #l > maxLen then return nil end
	local out = {}
	for i = 1, #l do
		if not isInt(l[i]) then return nil end
		out[i] = l[i]
	end
	return out
end

local ACTIONS = {
	Pass = function() return {} end,
	SkipAttack = function() return {} end,
	Continue = function() return {} end,
	PlayCard = function(p)
		if not isInt(p.uid) then return nil end
		if p.slot ~= nil and not isInt(p.slot, 1, 10) then return nil end
		return { uid = p.uid, slot = p.slot }
	end,
	ActivateSlow = function(p)
		local t = target(p.target)
		if not isInt(p.slot, 1, 10) or not t then return nil end
		return { slot = p.slot, target = t }
	end,
	ActivateFast = function(p)
		local t = target(p.target)
		if not isInt(p.slot, 1, 10) or not t then return nil end
		return { slot = p.slot, target = t }
	end,
	Evolve = function(p)
		if not isInt(p.form) or not isInt(p.target) then return nil end
		return { form = p.form, target = p.target }
	end,
	DeclareAttack = function(p)
		local l = intList(p.attackers, 10)
		if not l then return nil end
		return { attackers = l }
	end,
	AssignBlocks = function(p)
		if type(p.blocks) ~= "table" or #p.blocks > 10 then return nil end
		local out = {}
		for i = 1, #p.blocks do
			local b = p.blocks[i]
			if type(b) ~= "table" or not isInt(b.attacker) or not isInt(b.blocker) then return nil end
			out[i] = { attacker = b.attacker, blocker = b.blocker }
		end
		return { blocks = out }
	end,
	Discard = function(p)
		if not isInt(p.uid) then return nil end
		return { uid = p.uid }
	end,
}

function Validator.action(payload)
	if type(payload) ~= "table" then return nil, "payload no es tabla" end
	local t = payload.type
	if type(t) ~= "string" or #t > 24 then return nil, "tipo inválido" end
	local f = ACTIONS[t]
	if not f then return nil, "acción desconocida" end
	local clean = f(payload)
	if not clean then return nil, "campos inválidos" end
	clean.type = t
	return clean
end

local LOBBY = { PlayBot = true, Queue = true, Leave = true, DebugPause = true }
function Validator.lobby(payload)
	if type(payload) ~= "table" or type(payload.type) ~= "string" or not LOBBY[payload.type] then
		return nil, "petición de lobby inválida"
	end
	return { type = payload.type }
end

return Validator
