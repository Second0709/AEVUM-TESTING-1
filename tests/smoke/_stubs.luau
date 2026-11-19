-- Arnés de humo (solo desarrollo): simula lo mínimo de la API de Roblox y ejecuta los escenarios de Board3D.
local V3mt = {}
V3mt.__index = V3mt
local function V3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt) end
V3mt.__add = function(a, b) return V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return V3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return V3(a.X * b, a.Y * b, a.Z * b) end
	return V3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b) return V3(a.X / b, a.Y / b, a.Z / b) end
V3mt.__unm = function(a) return V3(-a.X, -a.Y, -a.Z) end
V3mt.Magnitude = nil
local Vector3 = { new = V3 }
local Vector2 = { new = function(x, y) return V3(x, y, 0) end }
local anyMt = {}
anyMt.__index = function(t, k) return setmetatable({}, anyMt) end
anyMt.__call = function() return setmetatable({}, anyMt) end
anyMt.__mul = function() return setmetatable({}, anyMt) end
local function any() return setmetatable({}, anyMt) end
local CFrame = setmetatable({ new = function() return any() end, Angles = function() return any() end, lookAt = function() return any() end }, anyMt)
local Color3 = { fromRGB = function(r, g, b) return { r, g, b } end, new = function() return {} end }
local UDim2 = { new = function() return {} end, fromOffset = function() return {} end, fromScale = function() return {} end }
local UDim = { new = function() return {} end }
local TweenInfo = { new = function() return {} end }
local Enum = setmetatable({}, { __index = function(_, a) return setmetatable({}, { __index = function(_, b) return a .. "." .. b end }) end })
local RaycastParams = { new = function() return {} end }

local deferred = {}
local task = { defer = function(f) deferred[#deferred + 1] = f end, wait = function() end }
local function flushDeferred()
	local d = deferred
	deferred = {}
	for _, f in ipairs(d) do f() end
end

local function signal()
	local s = { fns = {} }
	function s:Connect(f) table.insert(self.fns, f) return { Disconnect = function() end } end
	return s
end

local kids = setmetatable({}, { __mode = "k" }) -- padre -> lista de hijos (para contar instancias en las pruebas)
local function detach(o, parent)
	local list = parent and kids[parent]
	if not list then return end
	for i, c in ipairs(list) do
		if c == o then table.remove(list, i) return end
	end
end
local function descendants(o, out)
	for _, c in ipairs(kids[o] or {}) do
		out[#out + 1] = c
		descendants(c, out)
	end
	return out
end
local function newInstance(class)
	local props, attrs = { ClassName = class }, {}
	local o = {}
	setmetatable(o, {
		__index = function(_, k)
			if props[k] ~= nil then return props[k] end
			if k == "Destroy" then return function() detach(o, props.Parent) props.Parent = nil end end
			if k == "GetChildren" then return function() return table.clone(kids[o] or {}) end end
			if k == "GetDescendants" then return function() return descendants(o, {}) end end
			if k == "PivotTo" or k == "ScaleTo" then return function() end end
			if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
			if k == "GetAttribute" then return function(_, n) return attrs[n] end end
			if k == "FindFirstAncestorOfClass" then return function() return o end end
			if k == "GetPropertyChangedSignal" then return function() return signal() end end
			if k == "Play" or k == "Cancel" then return function() end end
			return nil
		end,
		__newindex = function(_, k, v)
			if k == "Parent" then
				detach(o, props.Parent)
				if v then
					kids[v] = kids[v] or {}
					table.insert(kids[v], o)
				end
			end
			props[k] = v
		end,
	})
	return o
end
local Instance = { new = newInstance }

local renderSteppedFns = {}
local camera = newInstance("Camera")
camera.ViewportSize = V3(1920, 1080, 0)
camera.FieldOfView = 45
camera.ScreenPointToRay = function() return { Origin = V3(0, 0, 0), Direction = V3(0, 0, -1) } end
camera.ViewportPointToRay = function(_, x, y) return { Origin = V3(0, 530, 80), Direction = V3((x - 960) / 3000, -0.8, -0.6) } end
local workspace = { CurrentCamera = camera, GetPropertyChangedSignal = function() return signal() end, Raycast = function() return nil end }
local services = {
	RunService = { RenderStepped = { Connect = function(_, f) renderSteppedFns[#renderSteppedFns + 1] = f return { Disconnect = function() end } end } },
	TweenService = { Create = function() return { Play = function() end, Cancel = function() end } end },
	Lighting = {},
	UserInputService = { InputBegan = signal(), InputEnded = signal() },
}
local game = { GetService = function(_, n) return services[n] end }
local modules = {}
local script = { Parent = setmetatable({}, { __index = function(_, name)
	if not modules[name] then modules[name] = require("./" .. name) end
	return modules[name]
end }) }


return { Vector3=Vector3, Vector2=Vector2, CFrame=CFrame, Color3=Color3, UDim2=UDim2, UDim=UDim, TweenInfo=TweenInfo, Enum=Enum, RaycastParams=RaycastParams, Instance=Instance, workspace=workspace, game=game, task=task, script=script, renderSteppedFns=renderSteppedFns, flushDeferred=flushDeferred, V3=V3 }
