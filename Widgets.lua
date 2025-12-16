--// =========================================================
--// File: ReplicatedStorage/ToRungHub/Widgets.lua
--// =========================================================
--!strict

local TweenService = game:GetService("TweenService")

local Widgets = {}

export type Theme = {
	Radius: number,
	TextSize: number,
	TextSizeSmall: number,
	Font: Enum.Font,
	FontTitle: Enum.Font,
	Colors: {
		Bg: Color3,
		Panel: Color3,
		Panel2: Color3,
		Stroke: Color3,
		Text: Color3,
		Muted: Color3,
		Accent: Color3,
		Good: Color3,
		Bad: Color3,
	},
	Transparency: {
		Window: number,
		Panel: number,
		Topbar: number,
		Stroke: number,
		Shadow: number,
	},
}

local function mk<T>(className: string, props: any, parent: Instance?): T
	local inst = Instance.new(className) :: any
	for k, v in pairs(props or {}) do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst :: T
end

local function corner(parent: Instance, radiusPx: number)
	mk("UICorner", { CornerRadius = UDim.new(0, radiusPx) }, parent)
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number?)
	mk("UIStroke", {
		Color = color,
		Transparency = transparency,
		Thickness = thickness or 1,
	}, parent)
end

local function tween(obj: Instance, goal: any, t: number)
	TweenService:Create(obj, TweenInfo.new(t), goal):Play()
end

function Widgets.SoftShadow(parent: Instance, theme: Theme, pad: number)
	-- Faux "blur border": gradients around a slightly larger frame (no BlurEffect)
	local shadow = mk("Frame", {
		Name = "SoftShadow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, pad * 2, 1, pad * 2),
		Position = UDim2.fromOffset(-pad, -pad),
		ZIndex = (parent :: any).ZIndex - 1,
	}, parent)

	local function edge(name: string, size: UDim2, pos: UDim2, rot: number)
		local f = mk("Frame", {
			Name = name,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = size,
			Position = pos,
			BorderSizePixel = 0,
		}, shadow)

		local g = mk("UIGradient", {
			Rotation = rot,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, theme.Transparency.Shadow),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, f)

		return f, g
	end

	edge("Top", UDim2.new(1, 0, 0, pad), UDim2.fromOffset(0, 0), 90)
	edge("Bottom", UDim2.new(1, 0, 0, pad), UDim2.new(0, 0, 1, -pad), -90)
	edge("Left", UDim2.new(0, pad, 1, 0), UDim2.fromOffset(0, 0), 0)
	edge("Right", UDim2.new(0, pad, 1, 0), UDim2.new(1, -pad, 0, 0), 180)

	return shadow
end

function Widgets.Header(parent: Instance, theme: Theme, text: string)
	local lbl = mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = theme.FontTitle,
		TextSize = theme.TextSize,
		TextColor3 = theme.Colors.Text,
		Text = text,
	}, parent)
	return lbl
end

function Widgets.Note(parent: Instance, theme: Theme, text: string)
	local lbl = mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Font = theme.Font,
		TextSize = theme.TextSizeSmall,
		TextColor3 = theme.Colors.Muted,
		Text = text,
	}, parent)
	return lbl
end

function Widgets.Row(parent: Instance, theme: Theme, height: number)
	local r = mk("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = theme.Colors.Panel2,
		BackgroundTransparency = theme.Transparency.Panel,
		BorderSizePixel = 0,
	}, parent)
	corner(r, theme.Radius)
	stroke(r, theme.Colors.Stroke, 0.92, 1)
	return r
end

function Widgets.Toggle(parent: Instance, theme: Theme, label: string, getFn: () -> boolean, setFn: (boolean) -> ())
	local r = Widgets.Row(parent, theme, 44)

	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -100, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = theme.Font,
		TextSize = theme.TextSize,
		TextColor3 = theme.Colors.Text,
		Text = label,
	}, r)

	local btn = mk("TextButton", {
		Size = UDim2.fromOffset(60, 26),
		Position = UDim2.new(1, -72, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = theme.Colors.Panel,
		BackgroundTransparency = theme.Transparency.Panel,
		BorderSizePixel = 0,
	}, r)
	corner(btn, 999)
	stroke(btn, theme.Colors.Stroke, 0.92, 1)

	local knob = mk("Frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = theme.Colors.Accent,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, btn)
	corner(knob, 999)

	local function refresh()
		local on = getFn()
		if on then
			tween(knob, { Position = UDim2.fromOffset(36, 2) }, 0.12)
			tween(btn, { BackgroundTransparency = 0.12 }, 0.12)
		else
			tween(knob, { Position = UDim2.fromOffset(2, 2) }, 0.12)
			tween(btn, { BackgroundTransparency = theme.Transparency.Panel }, 0.12)
		end
	end

	btn.Activated:Connect(function()
		setFn(not getFn())
		refresh()
	end)

	refresh()
	return refresh
end

function Widgets.Slider(parent: Instance, theme: Theme, label: string, minV: number, maxV: number, getFn: () -> number, setFn: (number) -> ())
	local r = Widgets.Row(parent, theme, 56)

	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -120, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = theme.Font,
		TextSize = theme.TextSize,
		TextColor3 = theme.Colors.Text,
		Text = label,
	}, r)

	local valLbl = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -110, 6, 0),
		Size = UDim2.fromOffset(96, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = theme.Font,
		TextSize = theme.TextSize,
		TextColor3 = theme.Colors.Muted,
		Text = "",
	}, r)

	local bar = mk("Frame", {
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 10),
		BackgroundColor3 = theme.Colors.Panel,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, r)
	corner(bar, 999)

	local fill = mk("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Colors.Accent,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, bar)
	corner(fill, 999)

	local knob = mk("Frame", {
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = theme.Colors.Accent,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
	}, bar)
	corner(knob, 999)

	local dragging = false

	local function setFromX(x: number)
		local a = bar.AbsolutePosition.X
		local w = math.max(1, bar.AbsoluteSize.X)
		local t = math.clamp((x - a) / w, 0, 1)
		local v = minV + (maxV - minV) * t
		setFn(v)
	end

	local function refresh()
		local v = getFn()
		local t = 0
		if maxV > minV then
			t = math.clamp((v - minV) / (maxV - minV), 0, 1)
		end
		fill.Size = UDim2.fromScale(t, 1)
		knob.Position = UDim2.new(t, 0, 0.5, 0)
		valLbl.Text = tostring(math.floor(v + 0.5))
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
			refresh()
		end
	end)

	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
			refresh()
		end
	end)

	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	refresh()
	return refresh
end

function Widgets.Button(parent: Instance, theme: Theme, label: string, text: string, onClick: () -> ())
	local r = Widgets.Row(parent, theme, 44)

	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -140, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = theme.Font,
		TextSize = theme.TextSize,
		TextColor3 = theme.Colors.Text,
		Text = label,
	}, r)

	local btn = mk("TextButton", {
		Size = UDim2.fromOffset(120, 26),
		Position = UDim2.new(1, -132, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		AutoButtonColor = false,
		Text = text,
		Font = theme.FontTitle,
		TextSize = theme.TextSize,
		TextColor3 = theme.Colors.Text,
		BackgroundColor3 = theme.Colors.Panel,
		BackgroundTransparency = theme.Transparency.Panel,
		BorderSizePixel = 0,
	}, r)
	corner(btn, 10)
	stroke(btn, theme.Colors.Stroke, 0.9, 1)

	btn.Activated:Connect(function()
		onClick()
	end)

	return btn
end

return Widgets
