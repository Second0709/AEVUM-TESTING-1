local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Sounds = {}

function Sounds.create(soundCfg)
	local sounds = {}
	local toPreload = {}
	for _, name in ipairs({ "Select", "Deselect", "BlockKill", "Overkill" }) do
		local id = soundCfg[name]
		if type(id) == "string" and id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = "Aevum_" .. name
			sound.SoundId = id
			sound.Volume = soundCfg.Volume or 0.6
			sound.Parent = SoundService
			sounds[name] = sound
			toPreload[#toPreload + 1] = sound
		end
	end
	if #toPreload > 0 then task.spawn(function() pcall(ContentProvider.PreloadAsync, ContentProvider, toPreload) end) end

	return function(name)
		local sound = sounds[name]
		if not sound then return end
		sound.TimePosition = 0
		sound:Play()
	end
end

return Sounds
