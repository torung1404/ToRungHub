--// File: StarterPlayerScripts/ToRungHub/Client/UI.lua
--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)

local UI = {}
UI.__index = UI

type Callbacks = {
	onToggle: (key: string, value: boolean) -> (),
	onOption: (key: string, value: any) -> (),
	onAction: (key: string, value: any?) -> (),
}

local function mk(instType: string, props: {[string]: any}): Instance
	local inst = Instance.new(instType)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	return inst
end

local function addStroke(parent: Instance, color: Color3)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1
	s.Transparency = 0.35
	s.Parent = parent
	return s
end

local function addCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
	return c
end

function UI.new(callbacks: Callbacks)
	local self = setmetatable({}, UI)
	self.player = Players.LocalPlayer
	self.cb = callbacks
	self.opacity = Config.UI.DefaultOpacity
	self.minimized = false
	self:_build()
	return self
end

function UI:_build()
	local theme = Config.UI.Theme
	local gui = mk("ScreenGui", {
		Name = "ToRungHubUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
	})
	gui.Parent = self.player:WaitForChild("PlayerGui")

	local root = mk("Frame", {
		Name = "Root",
		Size = UDim2.fromOffset(560, 360),
		Position = UDim2.new(0, 40, 0, 80),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 1 - self.opacity,
	})
	addCorner(root, 14)
	addStroke(root, theme.Stroke)
	root.Parent = gui

	local header = mk("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = theme.Panel,
		BackgroundTransparency = 1 - self.opacity,
	})
	addCorner(header, 14)
	header.Parent = root

	local title = mk("TextLabel", {
		Size = UDim2.new(1, -140, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Text = "ToRungHub • Boss / Loot / QoL",
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamSemibold,
		TextSize = 16,
	})
	title.Parent = header

	local btnMin = mk("TextButton", {
		Size = UDim2.fromOffset(34, 28),
		Position = UDim2.new(1, -78, 0.5, -14),
		BackgroundColor3 = theme.Panel,
		BackgroundTransparency = 0.2,
		Text = "—",
		TextColor3 = theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
	})
	addCorner(btnMin, 10)
	addStroke(btnMin, theme.Stroke)
	btnMin.Parent = header

	local btnClose = mk("TextButton", {
		Size = UDim2.fromOffset(34, 28),
		Position = UDim2.new(1, -38, 0.5, -14),
		BackgroundColor3 = theme.Panel,
		BackgroundTransparency = 0.2,
		Text = "X",
		TextColor3 = theme.Bad,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	})
	addCorner(btnClose, 10)
	addStroke(btnClose, theme.Stroke)
	btnClose.Parent = header

	local body = mk("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -24, 1, -68),
		Position = UDim2.fromOffset(12, 56),
		BackgroundTransparency = 1,
	})
	body.Parent = root

	local left = mk("Frame", {
		Size = UDim2.new(0, 250, 1, 0),
		BackgroundColor3 = theme.Panel,
		BackgroundTransparency = 1 - self.opacity,
	})
	addCorner(left, 14)
	addStroke(left, theme.Stroke)
	left.Parent = body

	local right = mk("Frame", {
		Size = UDim2.new(1, -262, 1, 0),
		Position = UDim2.fromOffset(262, 0),
		BackgroundColor3 = theme.Panel,
		BackgroundTransparency = 1 - self.opacity,
	})
	addCorner(right, 14)
	addStroke(right, theme.Stroke)
	right.Parent = body

	local function mkToggle(y: number, label: string, key: string, default: boolean)
		local row = mk("Frame", {
			Size = UDim2.new(1, -18, 0, 42),
			Position = UDim2.fromOffset(9, y),
			BackgroundTransparency = 1,
		})
		row.Parent = left

		local text = mk("TextLabel", {
			Size = UDim2.new(1, -70, 1, 0),
			BackgroundTransparency = 1,
			Text = label,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			TextSize = 14,
		})
		text.Parent = row

		local btn = mk("TextButton", {
			Size = UDim2.fromOffset(56, 26),
			Position = UDim2.new(1, -56, 0.5, -13),
			BackgroundColor3 = default and theme.Good or theme.Panel,
			BackgroundTransparency = 0.15,
			Text = default and "ON" or "OFF",
			TextColor3 = default and Color3.fromRGB(10, 18, 10) or theme.Muted,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
		})
		addCorner(btn, 10)
		addStroke(btn, theme.Stroke)
		btn.Parent = row

		local on = default
		btn.MouseButton1Click:Connect(function()
			on = not on
			btn.Text = on and "ON" or "OFF"
			btn.BackgroundColor3 = on and theme.Good or theme.Panel
			btn.TextColor3 = on and Color3.fromRGB(10, 18, 10) or theme.Muted
			self.cb.onToggle(key, on)
		end)
	end

	mkToggle(12, "Enable FSM (J)", "enabled", false)
	mkToggle(62, "Auto Boss Farm", "autoBoss", Config.Boss.Enabled)
	mkToggle(112, "Auto Chest", "autoChest", Config.Chest.Enabled)
	mkToggle(162, "Auto Hop", "autoHop", Config.Hop.Enabled)
	mkToggle(212, "Auto Medi", "autoMedi", Config.QoL.AutoMediEnabled)
	mkToggle(262, "Use Skills 1-4", "useSkills", Config.Combat.UseSkills)

	local status = mk("TextLabel", {
		Name = "Status",
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Text = "State: Idle",
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
	})
	status.Parent = right

	local small = mk("TextLabel", {
		Name = "Small",
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 40),
		BackgroundTransparency = 1,
		Text = "Kills: 0 | Target: -",
		TextColor3 = theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 12,
	})
	small.Parent = right

	local hpLabel = mk("TextLabel", {
		Size = UDim2.new(0, 160, 0, 18),
		Position = UDim2.fromOffset(10, 72),
		BackgroundTransparency = 1,
		Text = "HP Threshold (%)",
		TextColor3 = theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 12,
	})
	hpLabel.Parent = right

	local hpBox = mk("TextBox", {
		Size = UDim2.new(0, 120, 0, 28),
		Position = UDim2.fromOffset(10, 94),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.15,
		Text = tostring(Config.QoL.HPThresholdPercent),
		TextColor3 = theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		ClearTextOnFocus = false,
	})
	addCorner(hpBox, 10)
	addStroke(hpBox, theme.Stroke)
	hpBox.Parent = right

	hpBox.FocusLost:Connect(function()
		local v = tonumber(hpBox.Text)
		if not v then return end
		self.cb.onOption("hpThreshold", v)
	end)

	local opacityLabel = mk("TextLabel", {
		Size = UDim2.new(0, 160, 0, 18),
		Position = UDim2.fromOffset(10, 136),
		BackgroundTransparency = 1,
		Text = "Opacity",
		TextColor3 = theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 12,
	})
	opacityLabel.Parent = right

	local opacityBox = mk("TextBox", {
		Size = UDim2.new(0, 120, 0, 28),
		Position = UDim2.fromOffset(10, 158),
		BackgroundColor3 = theme.Bg,
		BackgroundTransparency = 0.15,
		Text = tostring(self.opacity),
		TextColor3 = theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		ClearTextOnFocus = false,
	})
	addCorner(opacityBox, 10)
	addStroke(opacityBox, theme.Stroke)
	opacityBox.Parent = right

	opacityBox.FocusLost:Connect(function()
		local v = tonumber(opacityBox.Text)
		if not v then return end
		self.opacity = math.clamp(v, 0, 1)
		root.BackgroundTransparency = 1 - self.opacity
		header.BackgroundTransparency = 1 - self.opacity
		left.BackgroundTransparency = 1 - self.opacity
		right.BackgroundTransparency = 1 - self.opacity
	end)

	local minBtn = btnMin
	minBtn.MouseButton1Click:Connect(function()
		self.minimized = not self.minimized
		body.Visible = not self.minimized
	end)

	local closeBtn = btnClose
	closeBtn.MouseButton1Click:Connect(function()
		gui:Destroy()
	end)
end

return UI
