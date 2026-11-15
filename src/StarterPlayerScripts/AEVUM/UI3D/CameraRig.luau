--!nonstrict
-- AEVUM · Tablero 3D: cámara adaptable (v1.3.0)
-- Cámara Scriptable fija sobre el lado del jugador local (+Z), inclinada hacia la mesa.
-- La distancia se recalcula con la proporción de pantalla, así sirve en móvil y PC.

local Layout = require(script.Parent.Layout)

local CameraRig = {}

CameraRig.FOV = 45 -- FOV vertical (grados)
CameraRig.PITCH = 58 -- inclinación bajo el horizonte (grados)

-- Toma el control de la cámara apuntando a `center` (Vector3).
-- Devuelve una función `stop` que la devuelve a como estaba.
function CameraRig.start(center)
	local camera = workspace.CurrentCamera
	while not camera do
		task.wait()
		camera = workspace.CurrentCamera
	end
	local previous = { type = camera.CameraType, fov = camera.FieldOfView, cframe = camera.CFrame }
	local conns = {}

	local function apply()
		camera = workspace.CurrentCamera
		if not camera then return end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = CameraRig.FOV
		local size = camera.ViewportSize
		local fit = Layout.cameraFit(size.X / math.max(size.Y, 1), CameraRig.FOV, CameraRig.PITCH)
		local pitch = math.rad(CameraRig.PITCH)
		local forward = Vector3.new(0, -math.sin(pitch), -math.cos(pitch)) -- hacia -Z y hacia abajo
		local position = center - forward * fit.distance
		-- Bajamos la mirada `shift` para que la mesa quede centrada en el hueco que dejan los paneles 2D
		camera.CFrame = CFrame.lookAt(position, center) * CFrame.Angles(-fit.shift, 0, 0)
	end

	local function watch()
		for _, c in ipairs(conns) do c:Disconnect() end
		conns = {}
		if not camera then return end
		conns[#conns + 1] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		-- Si algo (otro script, el reaparecer) cambia el tipo de cámara, lo volvemos a forzar
		conns[#conns + 1] = camera:GetPropertyChangedSignal("CameraType"):Connect(function()
			if camera.CameraType ~= Enum.CameraType.Scriptable then apply() end
		end)
	end

	apply()
	watch()
	local camConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		apply()
		watch()
	end)

	return function()
		camConn:Disconnect()
		for _, c in ipairs(conns) do c:Disconnect() end
		if camera then
			camera.CameraType = previous.type
			camera.FieldOfView = previous.fov
			camera.CFrame = previous.cframe
		end
	end
end

return CameraRig
