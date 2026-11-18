--!nonstrict
-- AEVUM · Entrada 3D (v1.3.0)
-- Un solo sistema para ratón y pantalla táctil. Un "toque" es pulsar y soltar sin arrastrar
-- (más de TAP_SLOP píxeles se considera gesto y se ignora). La GUI 2D tiene prioridad:
-- si un botón consumió la pulsación (gameProcessed), no se lanza el rayo.
--
-- opts:
--   getFilter() -> { Instance }   lo único contra lo que se lanza el rayo (cartas y zonas táctiles)
--   onHit(instance)               se llama con la parte tocada
--   onMiss()                      se llama si el toque no dio a nada del tablero

local UserInputService = game:GetService("UserInputService")

local Input3D = {}

local TAP_SLOP = 14 -- píxeles
local RAY_LENGTH = 600

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Devuelve una función `disconnect`.
function Input3D.connect(opts)
	local starts = {} -- input -> posición inicial (solo pulsaciones que la GUI no consumió)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	local function cast(position)
		local camera = workspace.CurrentCamera
		if not camera then return nil end
		-- ScreenPointToRay ya descuenta el inset de la GUI, igual que input.Position
		local ray = camera:ScreenPointToRay(position.X, position.Y)
		params.FilterDescendantsInstances = opts.getFilter()
		local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
		return result and result.Instance or nil
	end

	local began = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isPointer(input) then return end
		starts[input] = Vector2.new(input.Position.X, input.Position.Y)
	end)

	local ended = UserInputService.InputEnded:Connect(function(input)
		local start = starts[input]
		if not start then return end
		starts[input] = nil
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if (pos - start).Magnitude > TAP_SLOP then return end
		local hit = cast(pos)
		if hit then
			opts.onHit(hit)
		elseif opts.onMiss then
			opts.onMiss()
		end
	end)

	return function()
		began:Disconnect()
		ended:Disconnect()
		starts = {}
	end
end

return Input3D
