local ProfileSchema = {}

function ProfileSchema.migrate(data, currentVersion, defaults)
	local version = data.Version or 0
	if version < 1 then
		if type(data.Collection) ~= "table" or next(data.Collection) == nil then
			data.Collection = table.clone(defaults.Collection)
		end
		if type(data.Deck) ~= "table" or #data.Deck == 0 then
			data.Deck = table.clone(defaults.Deck)
		end
	end
	if version < currentVersion then
		data.Version = currentVersion
	end
end

return ProfileSchema
