--!nonstrict
-- AEVUM · Tablero 3D: reconciliador (v1.3.0)
-- Misma forma que UI/Board.luau: Board3D.create(ctx) devuelve la función de render.
-- Fase 1: solo escena estática + cámara. `render` aún no dibuja cartas (Fase 2).
--
-- ctx (todo opcional):
--   origin  Vector3  centro de la mesa en el Workspace (por defecto muy por encima del mapa)
--   quality "High" | "Low"
--
-- Devuelve: render(state), show(), hide()

local TweenService = game:GetService("TweenService")

local BoardBuilder = require(script.Parent.BoardBuilder)
local CameraRig = require(script.Parent.CameraRig)

local Board3D = {}

local DEFAULT_ORIGIN = Vector3.new(0, 500, 0) -- lejos de cualquier Baseplate del lugar

function Board3D.create(ctx)
	ctx = ctx or {}
	local origin = ctx.origin or DEFAULT_ORIGIN
	local quality = ctx.quality or "High"

	local scene -- { folder, glow, refs } (se construye una sola vez)
	local stopCamera, restoreLighting
	local pulses = {}
	local visible = false

	local function show()
		if visible then return end
		visible = true
		if not scene then scene = BoardBuilder.build(origin, quality) end
		scene.folder.Parent = workspace
		restoreLighting = BoardBuilder.applyLighting(quality)
		stopCamera = CameraRig.start(origin)
		-- Brillo suave de los glifos (se omite en calidad baja)
		if quality ~= "Low" then
			local info = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			for _, p in ipairs(scene.glow) do
				local tween = TweenService:Create(p, info, { Transparency = 0.45 })
				tween:Play()
				pulses[#pulses + 1] = tween
			end
		end
	end

	local function hide()
		if not visible then return end
		visible = false
		for _, tween in ipairs(pulses) do tween:Cancel() end
		pulses = {}
		if scene then
			for _, p in ipairs(scene.glow) do p.Transparency = p.Name:find("Cristal") and 0.1 or 0 end
			scene.folder.Parent = nil
		end
		if stopCamera then stopCamera() stopCamera = nil end
		if restoreLighting then restoreLighting() restoreLighting = nil end
	end

	-- Fase 2: aquí se compara state.view con lo que hay en escena (por uid)
	local function render(state)
		if not visible then return end
	end

	return render, show, hide
end

return Board3D
