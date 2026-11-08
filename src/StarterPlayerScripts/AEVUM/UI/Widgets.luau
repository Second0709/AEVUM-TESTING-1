local C = require(script.Parent.Theme)

local Widgets = {}

function Widgets.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

function Widgets.clear(frame)
	for _, ch in ipairs(frame:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") and not ch:IsA("UICorner")
			and not ch:IsA("UIStroke") and not ch:IsA("UIGradient") then
			ch:Destroy()
		end
	end
end

function Widgets.label(parent, text, props)
	local p = { Text = text, BackgroundTransparency = 1, TextColor3 = C.text, Font = Enum.Font.Gotham,
		TextScaled = true, TextWrapped = true, Size = UDim2.new(1, 0, 0, 20) }
	for k, v in pairs(props or {}) do p[k] = v end
	local l = Widgets.new("TextLabel", p, parent)
	Widgets.new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 8 }, l)
	return l
end

function Widgets.button(parent, text, color, onClick, props)
	local p = { Text = text, BackgroundColor3 = color, TextColor3 = C.text, Font = Enum.Font.GothamBold,
		TextScaled = true, TextWrapped = true, AutoButtonColor = true, Size = UDim2.new(1, 0, 0, 36) }
	for k, v in pairs(props or {}) do p[k] = v end
	local b = Widgets.new("TextButton", p, parent)
	Widgets.new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	Widgets.new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 }, b)
	if onClick then b.Activated:Connect(onClick) end
	return b
end

return Widgets
