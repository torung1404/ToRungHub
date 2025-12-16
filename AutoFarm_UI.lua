--// =========================================================
--// FILE: AutoFarm_UI.lua   (LEGIT TEMPLATE: ToRungHub UI + hop persistence)
--// Purpose: Client UI framework + continuous config save + hop server keep config.
--// Notes:
--//  - Persists across server-hop/teleport (TeleportData)
--//  - Persists within same session (PlayerGui Attribute)
--//  - Does NOT persist after leaving the game (true out/in) without DataStore/backend
--// =========================================================

--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer

-- =========================
-- Config (edit keys freely)
-- =========================
local CONFIG_KEY = "ToRungHubCfgV1"
local SESSION_ATTR = "ToRungHubCfgJson"

local DEFAULT_CONFIG = {
	v = 1,
	ui = {
		visible = true,
		minimized = false,
		locked = false,
		tab = "Home",
		pos = { xScale = 0, xOffset = 18, yScale = 0.35, yOffset = 0 },
		opacity = 0.16, -- 0..0.6
	},
	toggles = {
		Enabled = false, -- "start"
		OptionA = false,
		OptionB = true,
		OptionC = false,
	},
	sliders = {
		Radius = 3000,
		Speed = 50,
	},
}

local MAX_DEPTH = 4
local MAX_KEYS = 256

local function deepCopy(v: any, depth: number?): any
	depth = depth or 0
	if depth > MAX_DEPTH then
		return nil
	end
	if typeof(v) ~= "table" then
		return v
	end
	local out = {}
	local n = 0
	for k, vv in pairs(v) do
		n += 1
		if n > MAX_KEYS then
			break
		end
		out[deepCopy(k, depth + 1)] = deepCopy(vv, depth + 1)
	end
	return out
end

local function sanitize(v: any, depth: number?): any
	depth = depth or 0
	if depth > MAX_DEPTH then
		return nil
	end
	local t = typeof(v)
	if t == "boolean" or t == "number" or t == "string" then
		return v
	end
	if t ~= "table" then
		return nil
	end
	local out = {}
	local n = 0
	for k, vv in pairs(v) do
		n += 1
		if n > MAX_KEYS then
			break
		end
		local kt = typeof(k)
		if kt == "string" or kt == "number" then
			local sv = sanitize(vv, depth + 1)
			if sv ~= nil then
				out[k] = sv
			end
		end
	end
	return out
end

local function getPlayerGui(): PlayerGui?
	return LOCAL_PLAYER:FindFirstChildOfClass("PlayerGui")
end

local function safeJsonEncode(t: any): (boolean, string)
	local ok, res = pcall(function()
		return HttpService:JSONEncode(t)
	end)
	return ok, ok and res or ""
end

local function safeJsonDecode(s: string): (boolean, any)
	local ok, res = pcall(function()
		return HttpService:JSONDecode(s)
	end)
	return ok, res
end

-- =========================
-- Config Manager (client-only)
-- =========================
local Config = {}
Config.__index = Config

function Config.new(defaultCfg: table)
	local self = setmetatable({}, Config)
	self._cfg = sanitize(defaultCfg, 0) or {}
	self._saveToken = 0
	self._lastSavedJson = ""
	return self
end

function Config:Get(): table
	return deepCopy(self._cfg, 0) or {}
end

function Config:Set(newCfg: table)
	self._cfg = sanitize(newCfg, 0) or {}
end

function Config:_saveToSessionAttr(payload: table)
	local pg = getPlayerGui()
	if not pg then
		return
	end
	local ok, json = safeJsonEncode(payload)
	if not ok then
		return
	end
	if json == self._lastSavedJson then
		return
	end
	self._lastSavedJson = json
	pg:SetAttribute(SESSION_ATTR, json)
end

function Config:SaveDebounced(onStatus: ((string) -> ())?)
	self._saveToken += 1
	local token = self._saveToken
	if onStatus then
		onStatus("Saving…")
	end

	task.delay(0.2, function()
		if token ~= self._saveToken then
			return
		end
		self:_saveToSessionAttr(self._cfg)
		if onStatus then
			onStatus("Saved")
			task.delay(1.0, function()
				onStatus("")
			end)
		end
	end)
end

function Config:LoadInitial()
	-- 1) TeleportData (hop server / teleport)
	do
		local ok, joinData = pcall(function()
			return LOCAL_PLAYER:GetJoinData()
		end)
		if ok and typeof(joinData) == "table" and typeof(joinData.TeleportData) == "table" then
			local td = joinData.TeleportData
			local payload = td[CONFIG_KEY]
			if typeof(payload) == "table" then
				local s = sanitize(payload, 0)
				if s then
					self._cfg = s
					self:_saveToSessionAttr(self._cfg)
					return
				end
			end
		end
	end

	-- 2) Session attribute (same session survive UI reload/respawn)
	do
		local pg = getPlayerGui()
		if pg then
			local json = pg:GetAttribute(SESSION_ATTR)
			if typeof(json) == "string" and #json > 0 then
				local ok, decoded = safeJsonDecode(json)
				if ok and typeof(decoded) == "table" then
					local s = sanitize(decoded, 0)
					if s then
						self._cfg = s
						return
					end
				end
			end
		end
	end

	-- 3) Default
	self._cfg = sanitize(DEFAULT_CONFIG, 0) or {}
	self:_saveToSessionAttr(self._cfg)
end

function Config:GetTeleportData(): table
	return {
		[CONFIG_KEY] = self:Get(),
	}
end

function Config:Teleport(placeId: number, jobId: string?)
	local td = self:GetTeleportData()
	if typeof(jobId) == "string" and #jobId > 0 then
		TeleportService:TeleportToPlaceInstance(placeId, jobId, LOCAL_PLAYER, td)
	else
		TeleportService:Teleport(placeId, LOCAL_PLAYER, td)
	end
end

local cfg = Config.new(DEFAULT_CONFIG)
cfg:LoadInitial()

-- =========================
-- UI Helpers
-- =========================
local function udim2FromTbl(t: any): UDim2?
	if typeof(t) ~= "table" then
		return nil
	end
	local xs = tonumber(t.xScale)
	local xo = tonumber(t.xOffset)
	local ys = tonumber(t.yScale)
	local yo = tonumber(t.yOffset)
	if not (xs and xo and ys and yo) then
		return nil
	end
	return UDim2.new(xs, xo, ys, yo)
end

local function tblFromUdim2(u: UDim2): table
	return {
		xScale = u.X.Scale,
		xOffset = u.X.Offset,
		yScale = u.Y.Scale,
		yOffset = u.Y.Offset,
	}
end

local function clamp(n: number, a: number, b: number): number
	return math.max(a, math.min(b, n))
end

local function themeOpacity(): number
	local c = cfg:Get()
	local op = tonumber(((c.ui or {}).opacity)) or DEFAULT_CONFIG.ui.opacity
	return clamp(op, 0, 0.6)
end

-- =========================
-- Build UI (ToRungHub style)
-- =========================
local playerGui = getPlayerGui() or LOCAL_PLAYER:WaitForChild("PlayerGui")

-- ensure only 1 instance
local old = playerGui:FindFirstChild("ToRungHub")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ToRungHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Parent = gui
main.Size = UDim2.fromOffset(460, 320)
main.Position = udim2FromTbl((cfg:Get().ui or {}).pos) or UDim2.new(0, 18, 0.35, 0)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
main.BackgroundTransparency = themeOpacity()
main.BorderSizePixel = 0
main.Active = true

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Parent = main
stroke.Thickness = 1
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 0.82

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Parent = gui
shadow.Size = main.Size
shadow.Position = main.Position + UDim2.fromOffset(6, 6)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.65
shadow.BorderSizePixel = 0
shadow.ZIndex = main.ZIndex - 1

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 14)
shadowCorner.Parent = shadow

local top = Instance.new("Frame")
top.Name = "Topbar"
top.Parent = main
top.Size = UDim2.new(1, 0, 0, 34)
top.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
top.BackgroundTransparency = themeOpacity()
top.BorderSizePixel = 0

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = top

local title = Instance.new("TextLabel")
title.Parent = top
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(1, -160, 1, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.Text = "ToRungHub"

local saveLbl = Instance.new("TextLabel")
saveLbl.Parent = top
saveLbl.BackgroundTransparency = 1
saveLbl.Position = UDim2.new(1, -240, 0, 0)
saveLbl.Size = UDim2.fromOffset(120, 34)
saveLbl.Font = Enum.Font.Gotham
saveLbl.TextSize = 12
saveLbl.TextXAlignment = Enum.TextXAlignment.Right
saveLbl.TextColor3 = Color3.fromRGB(175, 175, 175)
saveLbl.Text = ""

local function setStatus(s: string)
	saveLbl.Text = s
end

local function mkTopBtn(text: string, xRight: number): TextButton
	local b = Instance.new("TextButton")
	b.Parent = top
	b.Size = UDim2.fromOffset(34, 34)
	b.Position = UDim2.new(1, -xRight, 0, 0)
	b.BackgroundTransparency = 1
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(230, 230, 230)
	b.Text = text
	return b
end

local btnClose = mkTopBtn("×", 34)
local btnMin = mkTopBtn("–", 68)
local btnLock = mkTopBtn("🔓", 102)

local body = Instance.new("Frame")
body.Parent = main
body.Position = UDim2.new(0, 0, 0, 34)
body.Size = UDim2.new(1, 0, 1, -34)
body.BackgroundTransparency = 1

local sidebar = Instance.new("Frame")
sidebar.Parent = body
sidebar.Size = UDim2.fromOffset(140, 286)
sidebar.Position = UDim2.fromOffset(0, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
sidebar.BackgroundTransparency = themeOpacity()
sidebar.BorderSizePixel = 0

local sideStroke = Instance.new("UIStroke")
sideStroke.Parent = sidebar
sideStroke.Thickness = 1
sideStroke.Color = Color3.fromRGB(255, 255, 255)
sideStroke.Transparency = 0.9

local sidePad = Instance.new("UIPadding")
sidePad.Parent = sidebar
sidePad.PaddingTop = UDim.new(0, 10)
sidePad.PaddingLeft = UDim.new(0, 10)
sidePad.PaddingRight = UDim.new(0, 10)

local sideList = Instance.new("UIListLayout")
sideList.Parent = sidebar
sideList.Padding = UDim.new(0, 8)
sideList.FillDirection = Enum.FillDirection.Vertical
sideList.SortOrder = Enum.SortOrder.LayoutOrder

local content = Instance.new("Frame")
content.Parent = body
content.Position = UDim2.fromOffset(140, 0)
content.Size = UDim2.new(1, -140, 1, 0)
content.BackgroundTransparency = 1

local pages = Instance.new("Frame")
pages.Parent = content
pages.Size = UDim2.new(1, -12, 1, -12)
pages.Position = UDim2.fromOffset(6, 6)
pages.BackgroundTransparency = 1

local function mkPage(name: string): ScrollingFrame
	local p = Instance.new("ScrollingFrame")
	p.Name = name
	p.Parent = pages
	p.Size = UDim2.new(1, 0, 1, 0)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = 4
	p.Visible = false
	p.CanvasSize = UDim2.new(0, 0, 0, 0)
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local layout = Instance.new("UIListLayout")
	layout.Parent = p
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local pad = Instance.new("UIPadding")
	pad.Parent = p
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)

	return p
end

local pageHome = mkPage("Home")
local pageSettings = mkPage("Settings")
local pageTeleport = mkPage("Teleport")

local function mkHeaderText(parent: Instance, text: string)
	local t = Instance.new("TextLabel")
	t.Parent = parent
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 18)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 13
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Color3.fromRGB(235, 235, 235)
	t.Text = text
	return t
end

local function mkNote(parent: Instance, text: string)
	local t = Instance.new("TextLabel")
	t.Parent = parent
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 32)
	t.Font = Enum.Font.Gotham
	t.TextSize = 12
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Color3.fromRGB(170, 170, 170)
	t.Text = text
	return t
end

local function mkRow(parent: Instance)
	local row = Instance.new("Frame")
	row.Parent = parent
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	row.BackgroundTransparency = themeOpacity()
	row.BorderSizePixel = 0

	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 10)
	cr.Parent = row

	local st = Instance.new("UIStroke")
	st.Parent = row
	st.Thickness = 1
	st.Color = Color3.fromRGB(255, 255, 255)
	st.Transparency = 0.92

	return row
end

local function mkToggle(parent: Instance, label: string, getter: () -> boolean, setter: (boolean) -> ())
	local row = mkRow(parent)

	local txt = Instance.new("TextLabel")
	txt.Parent = row
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromOffset(12, 0)
	txt.Size = UDim2.new(1, -90, 1, 0)
	txt.Font = Enum.Font.Gotham
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(225, 225, 225)
	txt.Text = label

	local btn = Instance.new("TextButton")
	btn.Parent = row
	btn.Size = UDim2.fromOffset(58, 24)
	btn.Position = UDim2.new(1, -70, 0.5, -12)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	btn.BackgroundTransparency = themeOpacity()
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12

	local bcr = Instance.new("UICorner")
	bcr.CornerRadius = UDim.new(0, 999)
	bcr.Parent = btn

	local function refresh()
		local on = getter()
		btn.Text = on and "ON" or "OFF"
		btn.TextColor3 = on and Color3.fromRGB(140, 255, 140) or Color3.fromRGB(255, 170, 170)
	end

	btn.MouseButton1Click:Connect(function()
		setter(not getter())
		refresh()
		cfg:SaveDebounced(setStatus)
	end)

	refresh()
	return refresh
end

local function mkSlider(parent: Instance, label: string, minV: number, maxV: number, step: number, getter: () -> number, setter: (number) -> ())
	local row = mkRow(parent)
	row.Size = UDim2.new(1, 0, 0, 52)

	local txt = Instance.new("TextLabel")
	txt.Parent = row
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromOffset(12, 6)
	txt.Size = UDim2.new(1, -24, 0, 16)
	txt.Font = Enum.Font.Gotham
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(225, 225, 225)
	txt.Text = label

	local valueLbl = Instance.new("TextLabel")
	valueLbl.Parent = row
	valueLbl.BackgroundTransparency = 1
	valueLbl.Position = UDim2.new(1, -90, 6, 0)
	valueLbl.Size = UDim2.fromOffset(78, 16)
	valueLbl.Font = Enum.Font.Gotham
	valueLbl.TextSize = 12
	valueLbl.TextXAlignment = Enum.TextXAlignment.Right
	valueLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	valueLbl.Text = ""

	local bar = Instance.new("Frame")
	bar.Parent = row
	bar.Position = UDim2.fromOffset(12, 30)
	bar.Size = UDim2.new(1, -24, 0, 10)
	bar.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
	bar.BackgroundTransparency = themeOpacity()
	bar.BorderSizePixel = 0

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 999)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Parent = bar
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	fill.BackgroundTransparency = 0.45
	fill.BorderSizePixel = 0

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 999)
	fillCorner.Parent = fill

	local dragging = false

	local function snap(v: number): number
		local s = math.max(1e-9, step)
		return math.floor((v / s) + 0.5) * s
	end

	local function setFromAlpha(a: number)
		a = clamp(a, 0, 1)
		local val = minV + (maxV - minV) * a
		val = snap(val)
		val = clamp(val, minV, maxV)
		setter(val)
	end

	local function refresh()
		local v = getter()
		local a = (v - minV) / (maxV - minV)
		fill.Size = UDim2.new(clamp(a, 0, 1), 0, 1, 0)
		valueLbl.Text = tostring(v)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local x = input.Position.X
			local bx = bar.AbsolutePosition.X
			local bw = math.max(1, bar.AbsoluteSize.X)
			setFromAlpha((x - bx) / bw)
			refresh()
			cfg:SaveDebounced(setStatus)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local x = input.Position.X
			local bx = bar.AbsolutePosition.X
			local bw = math.max(1, bar.AbsoluteSize.X)
			setFromAlpha((x - bx) / bw)
			refresh()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			cfg:SaveDebounced(setStatus)
		end
	end)

	refresh()
	return refresh
end

local function mkButton(parent: Instance, label: string, text: string, onClick: () -> ())
	local row = mkRow(parent)

	local txt = Instance.new("TextLabel")
	txt.Parent = row
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromOffset(12, 0)
	txt.Size = UDim2.new(1, -140, 1, 0)
	txt.Font = Enum.Font.Gotham
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(225, 225, 225)
	txt.Text = label

	local btn = Instance.new("TextButton")
	btn.Parent = row
	btn.Size = UDim2.fromOffset(110, 24)
	btn.Position = UDim2.new(1, -122, 0.5, -12)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	btn.BackgroundTransparency = themeOpacity()
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(230, 230, 230)

	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 999)
	cr.Parent = btn

	btn.MouseButton1Click:Connect(function()
		onClick()
		cfg:SaveDebounced(setStatus)
	end)

	return btn
end

local function mkTextBox(parent: Instance, label: string, placeholder: string)
	local row = mkRow(parent)

	local txt = Instance.new("TextLabel")
	txt.Parent = row
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromOffset(12, 0)
	txt.Size = UDim2.new(1, -200, 1, 0)
	txt.Font = Enum.Font.Gotham
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(225, 225, 225)
	txt.Text = label

	local box = Instance.new("TextBox")
	box.Parent = row
	box.Size = UDim2.fromOffset(180, 24)
	box.Position = UDim2.new(1, -192, 0.5, -12)
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	box.BackgroundTransparency = themeOpacity()
	box.BorderSizePixel = 0
	box.Font = Enum.Font.Gotham
	box.TextSize = 12
	box.TextColor3 = Color3.fromRGB(230, 230, 230)
	box.PlaceholderText = placeholder
	box.Text = ""

	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 8)
	cr.Parent = box

	return box
end

-- Tabs
local tabButtons: { [string]: TextButton } = {}
local tabPages: { [string]: ScrollingFrame } = {
	Home = pageHome,
	Settings = pageSettings,
	Teleport = pageTeleport,
}

local function setTab(name: string)
	for tabName, page in pairs(tabPages) do
		page.Visible = (tabName == name)
		local b = tabButtons[tabName]
		if b then
			b.TextColor3 = (tabName == name) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170)
		end
	end

	local c = cfg:Get()
	c.ui = c.ui or {}
	c.ui.tab = name
	cfg:Set(c)
	cfg:SaveDebounced(setStatus)
end

local function mkTabButton(name: string)
	local b = Instance.new("TextButton")
	b.Parent = sidebar
	b.Size = UDim2.new(1, 0, 0, 32)
	b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	b.BackgroundTransparency = themeOpacity()
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextColor3 = Color3.fromRGB(170, 170, 170)
	b.Text = "  " .. name

	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 10)
	cr.Parent = b

	b.MouseButton1Click:Connect(function()
		setTab(name)
	end)

	tabButtons[name] = b
end

mkTabButton("Home")
mkTabButton("Settings")
mkTabButton("Teleport")

-- Content
mkHeaderText(pageHome, "Quick")
mkNote(pageHome, "Bật/tắt option. Mọi thay đổi được lưu liên tục và sẽ giữ khi bạn hop server (TeleportData).")

local function cfgToggleGetter(k: string): () -> boolean
	return function()
		local c = cfg:Get()
		return ((c.toggles or {})[k] == true)
	end
end

local function cfgToggleSetter(k: string): (boolean) -> ()
	return function(v)
		local c = cfg:Get()
		c.toggles = c.toggles or {}
		c.toggles[k] = (v == true)
		cfg:Set(c)
	end
end

local function cfgSliderGetter(k: string): () -> number
	return function()
		local c = cfg:Get()
		local n = tonumber(((c.sliders or {})[k]))
		return n or DEFAULT_CONFIG.sliders[k]
	end
end

local function cfgSliderSetter(k: string): (number) -> ()
	return function(v)
		local c = cfg:Get()
		c.sliders = c.sliders or {}
		c.sliders[k] = v
		cfg:Set(c)
	end
end

mkToggle(pageHome, "Start (Enabled)", cfgToggleGetter("Enabled"), cfgToggleSetter("Enabled"))
mkToggle(pageHome, "Option A", cfgToggleGetter("OptionA"), cfgToggleSetter("OptionA"))
mkToggle(pageHome, "Option B", cfgToggleGetter("OptionB"), cfgToggleSetter("OptionB"))
mkToggle(pageHome, "Option C", cfgToggleGetter("OptionC"), cfgToggleSetter("OptionC"))

mkHeaderText(pageSettings, "Sliders")
mkNote(pageSettings, "Bạn có thể đổi tên/ý nghĩa slider theo game của bạn.")

mkSlider(pageSettings, "Radius", 0, 20000, 50, cfgSliderGetter("Radius"), cfgSliderSetter("Radius"))
mkSlider(pageSettings, "Speed", 0, 200, 1, cfgSliderGetter("Speed"), cfgSliderSetter("Speed"))

mkHeaderText(pageSettings, "UI")
mkSlider(pageSettings, "Opacity", 0, 0.6, 0.02, function()
	local c = cfg:Get()
	return tonumber(((c.ui or {}).opacity)) or DEFAULT_CONFIG.ui.opacity
end, function(v)
	local c = cfg:Get()
	c.ui = c.ui or {}
	c.ui.opacity = v
	cfg:Set(c)

	main.BackgroundTransparency = v
	top.BackgroundTransparency = v
	sidebar.BackgroundTransparency = v
end)

mkHeaderText(pageTeleport, "Hop / Teleport")
mkNote(pageTeleport, "Để giữ config khi hop, hãy teleport kèm TeleportData (script dưới có sẵn).")

local jobBox = mkTextBox(pageTeleport, "JobId", "Paste JobId here")

mkButton(pageTeleport, "Rejoin (same place)", "REJOIN", function()
	cfg:Teleport(game.PlaceId, nil)
end)

mkButton(pageTeleport, "Hop to JobId", "HOP", function()
	local jobId = jobBox.Text
	if typeof(jobId) == "string" and #jobId > 0 then
		cfg:Teleport(game.PlaceId, jobId)
	end
end)

-- Minimize/close/lock + hotkey
local minimized = false
local locked = false
local dragging = false
local dragStart: Vector2? = nil
local startPos: UDim2? = nil

local function applyMinimize(on: boolean)
	minimized = on
	body.Visible = not minimized
	main.Size = minimized and UDim2.fromOffset(460, 34) or UDim2.fromOffset(460, 320)
	shadow.Size = main.Size
	btnMin.Text = minimized and "+" or "–"

	local c = cfg:Get()
	c.ui = c.ui or {}
	c.ui.minimized = minimized
	cfg:Set(c)
	cfg:SaveDebounced(setStatus)
end

local function applyVisible(on: boolean)
	main.Visible = on
	shadow.Visible = on
	local c = cfg:Get()
	c.ui = c.ui or {}
	c.ui.visible = on
	cfg:Set(c)
	cfg:SaveDebounced(setStatus)
end

local function applyLock(on: boolean)
	locked = on
	btnLock.Text = locked and "🔒" or "🔓"
	local c = cfg:Get()
	c.ui = c.ui or {}
	c.ui.locked = locked
	cfg:Set(c)
	cfg:SaveDebounced(setStatus)
end

btnClose.MouseButton1Click:Connect(function()
	applyVisible(false)
end)

btnMin.MouseButton1Click:Connect(function()
	applyMinimize(not minimized)
end)

btnLock.MouseButton1Click:Connect(function()
	applyLock(not locked)
end)

top.InputBegan:Connect(function(input)
	if locked then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging or not dragStart or not startPos then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		main.Position = newPos
		shadow.Position = newPos + UDim2.fromOffset(6, 6)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not dragging then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		dragStart = nil
		startPos = nil

		local c = cfg:Get()
		c.ui = c.ui or {}
		c.ui.pos = tblFromUdim2(main.Position)
		cfg:Set(c)
		cfg:SaveDebounced(setStatus)
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		applyVisible(not main.Visible)
	end
end)

-- Restore UI state from config
do
	local c = cfg:Get()
	local uiState = c.ui or {}
	local p = udim2FromTbl(uiState.pos)
	if p then
		main.Position = p
		shadow.Position = p + UDim2.fromOffset(6, 6)
	end
	applyLock(uiState.locked == true)
	applyMinimize(uiState.minimized == true)
	applyVisible(uiState.visible ~= false)

	setTab(tostring(uiState.tab or "Home"))
end

-- Keep shadow always following (safety if other scripts change zindex/pos)
RunService.RenderStepped:Connect(function()
	if shadow.Parent ~= gui then
		shadow.Parent = gui
	end
	shadow.Position = main.Position + UDim2.fromOffset(6, 6)
	shadow.Visible = main.Visible
end)

-- =========================
-- Transport bridge for external hop scripts (client-side)
-- =========================
local bf = playerGui:FindFirstChild("ToRungHubTransport")
if bf then
	bf:Destroy()
end

bf = Instance.new("BindableFunction")
bf.Name = "ToRungHubTransport"
bf.Parent = playerGui

bf.OnInvoke = function(action: any, ...)
	if action == "GetConfig" then
		return cfg:Get()
	end
	if action == "SetConfig" then
		local t = ...
		if typeof(t) == "table" then
			cfg:Set(t)
			cfg:SaveDebounced(setStatus)
			return true
		end
		return false
	end
	if action == "GetTeleportData" then
		return cfg:GetTeleportData()
	end
	if action == "Teleport" then
		local placeId, jobId = ...
		if typeof(placeId) == "number" then
			cfg:Teleport(placeId, jobId)
			return true
		end
		return false
	end
	return nil
end


--// =========================================================
--// FILE: Hop_Example.lua  (Optional helper)
--// How to hop while preserving ToRungHub config
--// =========================================================
--[[
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")
local transport = pg:WaitForChild("ToRungHubTransport")

local jobId = "PASTE_JOB_ID"

-- Option 1: let UI teleport (already packs data)
transport:Invoke("Teleport", game.PlaceId, jobId)

-- Option 2: if your hop script teleports itself
local td = transport:Invoke("GetTeleportData")
TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, plr, td)
]]


--// =========================================================
--// FILE: README.md
--// =========================================================
--[[
# ToRungHub (client-only UI + hop persistence)

- Continuous save: every UI change updates PlayerGui Attribute (same session).
- Hop persistence: TeleportData keeps config across server-hop/teleport.
- True out/in persistence requires DataStore/backend (not included).

## How to load
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/torung1404/torunghub/refs/heads/main/AutoFarm_UI.lua"))()
