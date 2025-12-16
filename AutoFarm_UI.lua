-- =========================================================
-- FILE 1/4: StarterPlayerScripts/AutoFarm_UI.lua  (LocalScript)
-- ToRungHub UI + continuous save + hop persistence (TeleportData)
-- =========================================================

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TeleportService = game:GetService('TeleportService')
local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local plr = Players.LocalPlayer

local HUB_NAME = 'ToRungHub'
local TELEPORT_KEY = 'ToRungHubCfgV1'
local SESSION_ATTR = 'ToRungHubCfgJson'
local REMOTE_NAME = 'ToRungHubControl'

local DEFAULT = {
	v = 1,
	ui = {
		visible = true,
		minimized = false,
		locked = false,
		tab = 'Home',
		opacity = 0.18, -- 0..0.6 (higher = more see-through)
		pos = { xScale = 0, xOffset = 18, yScale = 0.35, yOffset = 0 },
	},
	autofarm = {
		Enabled = false,
		BossOnly = false,
		Radius = 3000,
		FollowDist = 6,
		AttackCD = 0.2,
	},
}

local MAX_DEPTH, MAX_KEYS = 4, 256

local function clamp(n, a, b)
	return math.max(a, math.min(b, n))
end

local function deepCopy(v, depth)
	depth = depth or 0
	if depth > MAX_DEPTH then return nil end
	if typeof(v) ~= 'table' then return v end
	local out, n = {}, 0
	for k, vv in pairs(v) do
		n += 1
		if n > MAX_KEYS then break end
		out[deepCopy(k, depth + 1)] = deepCopy(vv, depth + 1)
	end
	return out
end

local function sanitize(v, depth)
	depth = depth or 0
	if depth > MAX_DEPTH then return nil end

	local t = typeof(v)
	if t == 'boolean' or t == 'number' or t == 'string' then return v end
	if t ~= 'table' then return nil end

	local out, n = {}, 0
	for k, vv in pairs(v) do
		n += 1
		if n > MAX_KEYS then break end
		local kt = typeof(k)
		if kt == 'string' or kt == 'number' then
			local sv = sanitize(vv, depth + 1)
			if sv ~= nil then out[k] = sv end
		end
	end
	return out
end

local function getPlayerGui()
	return plr:FindFirstChildOfClass('PlayerGui')
end

local function udim2FromTbl(t)
	if typeof(t) ~= 'table' then return nil end
	local xs, xo = tonumber(t.xScale), tonumber(t.xOffset)
	local ys, yo = tonumber(t.yScale), tonumber(t.yOffset)
	if not (xs and xo and ys and yo) then return nil end
	return UDim2.new(xs, xo, ys, yo)
end

local function tblFromUdim2(u)
	return { xScale = u.X.Scale, xOffset = u.X.Offset, yScale = u.Y.Scale, yOffset = u.Y.Offset }
end

local function safeEncode(t)
	local ok, res = pcall(function() return HttpService:JSONEncode(t) end)
	return ok, ok and res or ''
end

local function safeDecode(s)
	local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
	return ok, res
end

-- =========================
-- Config manager
-- =========================
local Cfg = {}
Cfg.__index = Cfg

function Cfg.new(defaultCfg)
	local self = setmetatable({}, Cfg)
	self._cfg = sanitize(defaultCfg, 0) or {}
	self._saveToken = 0
	self._lastJson = ''
	self._remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	return self
end

function Cfg:Get()
	return deepCopy(self._cfg, 0) or {}
end

function Cfg:Set(t)
	self._cfg = sanitize(t, 0) or {}
end

function Cfg:_saveSession()
	local pg = getPlayerGui()
	if not pg then return end
	local ok, json = safeEncode(self._cfg)
	if not ok or json == self._lastJson then return end
	self._lastJson = json
	pg:SetAttribute(SESSION_ATTR, json)
end

function Cfg:_loadTeleportData()
	local ok, joinData = pcall(function() return plr:GetJoinData() end)
	if not ok or typeof(joinData) ~= 'table' then return nil end
	local td = joinData.TeleportData
	if typeof(td) ~= 'table' then return nil end
	local payload = td[TELEPORT_KEY]
	if typeof(payload) ~= 'table' then return nil end
	return sanitize(payload, 0)
end

function Cfg:_loadSession()
	local pg = getPlayerGui()
	if not pg then return nil end
	local json = pg:GetAttribute(SESSION_ATTR)
	if typeof(json) ~= 'string' or #json == 0 then return nil end
	local ok, decoded = safeDecode(json)
	if not ok or typeof(decoded) ~= 'table' then return nil end
	return sanitize(decoded, 0)
end

function Cfg:LoadInitial()
	local a = self:_loadTeleportData()
	if a then
		self._cfg = a
		self:_saveSession()
		return
	end

	local b = self:_loadSession()
	if b then
		self._cfg = b
		return
	end

	self._cfg = sanitize(DEFAULT, 0) or {}
	self:_saveSession()
end

function Cfg:GetTeleportData()
	return { [TELEPORT_KEY] = self:Get() }
end

function Cfg:SaveDebounced(onStatus)
	self._saveToken += 1
	local token = self._saveToken
	if onStatus then onStatus('Saving…') end

	task.delay(0.2, function()
		if token ~= self._saveToken then return end
		self:_saveSession()

		local remote = self._remote
		if remote and remote:IsA('RemoteEvent') then
			remote:FireServer('Config', self:Get())
		end

		if onStatus then
			onStatus('Saved')
			task.delay(0.9, function() onStatus('') end)
		end
	end)
end

function Cfg:SaveImmediate(onStatus)
	self._saveToken += 1
	self:_saveSession()

	local remote = self._remote
	if remote and remote:IsA('RemoteEvent') then
		remote:FireServer('Config', self:Get())
	end

	if onStatus then
		onStatus('Saved')
		task.delay(0.9, function() onStatus('') end)
	end
end

function Cfg:Teleport(placeId, jobId)
	local data = self:GetTeleportData()
	if typeof(jobId) == 'string' and #jobId > 0 then
		TeleportService:TeleportToPlaceInstance(placeId, jobId, plr, data)
	else
		TeleportService:Teleport(placeId, plr, data)
	end
end

local cfg = Cfg.new(DEFAULT)
cfg:LoadInitial()

-- =========================
-- UI builder
-- =========================
local pg = getPlayerGui() or plr:WaitForChild('PlayerGui')

local existing = pg:FindFirstChild(HUB_NAME)
if existing then existing:Destroy() end

local uiCfg = cfg:Get().ui or {}
local opacity = clamp(tonumber(uiCfg.opacity) or DEFAULT.ui.opacity, 0, 0.6)

local gui = Instance.new('ScreenGui')
gui.Name = HUB_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = pg

local shadow = Instance.new('Frame')
shadow.Name = 'Shadow'
shadow.Parent = gui
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.68
shadow.BorderSizePixel = 0
shadow.ZIndex = 0

local shadowCorner = Instance.new('UICorner')
shadowCorner.CornerRadius = UDim.new(0, 14)
shadowCorner.Parent = shadow

local main = Instance.new('Frame')
main.Name = 'Main'
main.Parent = gui
main.Size = UDim2.fromOffset(520, 360)
main.Position = udim2FromTbl(uiCfg.pos) or UDim2.new(0, 18, 0.35, 0)
main.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
main.BackgroundTransparency = opacity
main.BorderSizePixel = 0
main.Active = true
main.ZIndex = 2

local mainCorner = Instance.new('UICorner')
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local mainStroke = Instance.new('UIStroke')
mainStroke.Parent = main
mainStroke.Thickness = 1
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Transparency = 0.84

local top = Instance.new('Frame')
top.Name = 'Top'
top.Parent = main
top.Size = UDim2.new(1, 0, 0, 36)
top.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
top.BackgroundTransparency = opacity
top.BorderSizePixel = 0

local topCorner = Instance.new('UICorner')
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = top

local title = Instance.new('TextLabel')
title.Parent = top
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(1, -220, 1, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Text = HUB_NAME

local statusLbl = Instance.new('TextLabel')
statusLbl.Parent = top
statusLbl.BackgroundTransparency = 1
statusLbl.Position = UDim2.new(1, -240, 0, 0)
statusLbl.Size = UDim2.fromOffset(120, 36)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Right
statusLbl.TextColor3 = Color3.fromRGB(175, 175, 175)
statusLbl.Text = ''

local function setStatus(s) statusLbl.Text = s or '' end

local function mkTopBtn(txt, right)
	local b = Instance.new('TextButton')
	b.Parent = top
	b.Size = UDim2.fromOffset(36, 36)
	b.Position = UDim2.new(1, -right, 0, 0)
	b.BackgroundTransparency = 1
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = Color3.fromRGB(235, 235, 235)
	b.Text = txt
	return b
end

local btnMin = mkTopBtn('–', 72)
local btnClose = mkTopBtn('×', 36)
local btnLock = mkTopBtn('🔓', 108)

local body = Instance.new('Frame')
body.Parent = main
body.Position = UDim2.new(0, 0, 0, 36)
body.Size = UDim2.new(1, 0, 1, -36)
body.BackgroundTransparency = 1

local sidebar = Instance.new('Frame')
sidebar.Parent = body
sidebar.Size = UDim2.fromOffset(150, 324)
sidebar.Position = UDim2.fromOffset(0, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
sidebar.BackgroundTransparency = opacity
sidebar.BorderSizePixel = 0

local sideStroke = Instance.new('UIStroke')
sideStroke.Parent = sidebar
sideStroke.Thickness = 1
sideStroke.Color = Color3.fromRGB(255, 255, 255)
sideStroke.Transparency = 0.92

local sidePad = Instance.new('UIPadding')
sidePad.Parent = sidebar
sidePad.PaddingTop = UDim.new(0, 10)
sidePad.PaddingLeft = UDim.new(0, 10)
sidePad.PaddingRight = UDim.new(0, 10)

local sideList = Instance.new('UIListLayout')
sideList.Parent = sidebar
sideList.Padding = UDim.new(0, 8)
sideList.SortOrder = Enum.SortOrder.LayoutOrder

local pagesHost = Instance.new('Frame')
pagesHost.Parent = body
pagesHost.Position = UDim2.fromOffset(150, 0)
pagesHost.Size = UDim2.new(1, -150, 1, 0)
pagesHost.BackgroundTransparency = 1

local pagesPad = Instance.new('UIPadding')
pagesPad.Parent = pagesHost
pagesPad.PaddingTop = UDim.new(0, 10)
pagesPad.PaddingLeft = UDim.new(0, 10)
pagesPad.PaddingRight = UDim.new(0, 10)
pagesPad.PaddingBottom = UDim.new(0, 10)

local function mkPage(name)
	local p = Instance.new('ScrollingFrame')
	p.Name = name
	p.Parent = pagesHost
	p.Size = UDim2.new(1, 0, 1, 0)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = 4
	p.Visible = false
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.CanvasSize = UDim2.new(0, 0, 0, 0)

	local layout = Instance.new('UIListLayout')
	layout.Parent = p
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	return p
end

local pageHome = mkPage('Home')
local pageAuto = mkPage('AutoFarm')
local pageTeleport = mkPage('Teleport')
local pageSettings = mkPage('Settings')

local tabButtons = {}
local tabs = {
	Home = pageHome,
	AutoFarm = pageAuto,
	Teleport = pageTeleport,
	Settings = pageSettings,
}

local function mkTabButton(name)
	local b = Instance.new('TextButton')
	b.Parent = sidebar
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	b.BackgroundTransparency = opacity
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextColor3 = Color3.fromRGB(170, 170, 170)
	b.Text = '  ' .. name

	local cr = Instance.new('UICorner')
	cr.CornerRadius = UDim.new(0, 10)
	cr.Parent = b

	tabButtons[name] = b
	return b
end

local function setTab(name)
	for tabName, page in pairs(tabs) do
		page.Visible = (tabName == name)
		local b = tabButtons[tabName]
		if b then
			b.TextColor3 = (tabName == name) and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(170, 170, 170)
		end
	end
	local c = cfg:Get()
	c.ui = c.ui or {}
	c.ui.tab = name
	cfg:Set(c)
	cfg:SaveDebounced(setStatus)
end

for _, name in ipairs({ 'Home', 'AutoFarm', 'Teleport', 'Settings' }) do
	mkTabButton(name).MouseButton1Click:Connect(function()
		setTab(name)
	end)
end

local function mkHeader(parent, text)
	local t = Instance.new('TextLabel')
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

local function mkNote(parent, text)
	local t = Instance.new('TextLabel')
	t.Parent = parent
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 34)
	t.Font = Enum.Font.Gotham
	t.TextSize = 12
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Color3.fromRGB(175, 175, 175)
	t.Text = text
	return t
end

local function mkRow(parent, height)
	local row = Instance.new('Frame')
	row.Parent = parent
	row.Size = UDim2.new(1, 0, 0, height or 42)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	row.BackgroundTransparency = opacity
	row.BorderSizePixel = 0

	local cr = Instance.new('UICorner')
	cr.CornerRadius = UDim.new(0, 10)
	cr.Parent = row

	local st = Instance.new('UIStroke')
	st.Parent = row
	st.Thickness = 1
	st.Color = Color3.fromRGB(255, 255, 255)
	st.Transparency = 0.94

	return row
end

local function mkToggle(parent, label, getFn, setFn)
	local row = mkRow(parent, 42)

	local txt = Instance.new('TextLabel')
	txt.Parent = row
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromOffset(12, 0)
	txt.Size = UDim2.new(1, -90, 1, 0)
	txt.Font = Enum.Font.Gotham
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(225, 225, 225)
	txt.Text = label

	local btn = Instance.new('TextButton')
	btn.Parent = row
	btn.Size = UDim2.fromOffset(58, 24)
	btn.Position = UDim2.new(1, -70, 0.5, -12)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	btn.BackgroundTransparency = opacity
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12

	local cr = Instance.new('UICorner')
	cr.CornerRadius = UDim.new(0, 999)
	cr.Parent = btn

	local function refresh()
		local on = (getFn() == true)
		btn.Text = on and 'ON' or 'OFF'
		btn.TextColor3 = on and Color3.fromRGB(140, 255, 140) or Color3.fromRGB(255, 170, 170)
	end

	btn.MouseButton1Click:Connect(function()
		setFn(not getFn())
		refresh()
		cfg:SaveDebounced(setStatus)
	end)

	refresh()
	return refresh
end

local function mkSlider(parent, label, minV, maxV, step, getFn, setFn)
	local row = mkRow(parent, 54)

	local txt = Instance.new('TextLabel')
	txt.Parent = row
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromOffset(12, 6)
	txt.Size = UDim2.new(1, -120, 0, 16)
	txt.Font = Enum.Font.Gotham
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(225, 225, 225)
	txt.Text = label

	local valueLbl = Instance.new('TextLabel')
	valueLbl.Parent = row
	valueLbl.BackgroundTransparency = 1
	valueLbl.Position = UDim2.new(1, -110, 6, 0)
	valueLbl.Size = UDim2.fromOffset(96, 16)
	valueLbl.Font = Enum.Font.Gotham
	valueLbl.TextSize = 12
	valueLbl.TextXAlignment = Enum.TextXAlignment.Right
	valueLbl.TextColor3 = Color3.fromRGB(175, 175, 175)

	local bar = Instance.new('Frame')
	bar.Parent = row
	bar.Position = UDim2.fromOffset(12, 32)
	bar.Size = UDim2.new(1, -24, 0, 10)
	bar.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
	bar.BackgroundTransparency = opacity
	bar.BorderSizePixel = 0

	local barCr = Instance.new('UICorner')
	barCr.CornerRadius = UDim.new(0, 999)
	barCr.Parent = bar

	local fill = Instance.new('Frame')
	fill.Parent = bar
	fill.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	fill.BackgroundTransparency = 0.45
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0, 0, 1, 0)

	local fillCr = Instance.new('UICorner')
	fillCr.CornerRadius = UDim.new(0, 999)
	fillCr.Parent = fill

	local dragging = false

	local function snap(v)
		local s = math.max(1e-9, step or 1)
		return math.floor((v / s) + 0.5) * s
	end

	local function setFromAlpha(a)
		a = clamp(a, 0, 1)
		local v = minV + (maxV - minV) * a
		v = clamp(snap(v), minV, maxV)
		setFn(v)
	end

	local function refresh()
		local v = tonumber(getFn()) or minV
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
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local x = input.Position.X
			local bx = bar.AbsolutePosition.X
			local bw = math.max(1, bar.AbsoluteSize.X)
			setFromAlpha((x - bx) / bw)
			refresh()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			cfg:SaveDebounced(setStatus)
		end
	end)

	refresh()
	return refresh
end

local function mkTextBox(parent, label, placeholder)
	local row = mkRow(parent, 42)

	local txt = Instance.new('TextLabel')
	txt.Parent = row
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromOffset(12, 0)
	txt.Size = UDim2.new(1, -220, 1, 0)
	txt.Font = Enum.Font.Gotham
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(225, 225, 225)
	txt.Text = label

	local box = Instance.new('TextBox')
	box.Parent = row
	box.Size = UDim2.fromOffset(200, 24)
	box.Position = UDim2.new(1, -212, 0.5, -12)
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	box.BackgroundTransparency = opacity
	box.BorderSizePixel = 0
	box.Font = Enum.Font.Gotham
	box.TextSize = 12
	box.TextColor3 = Color3.fromRGB(235, 235, 235)
	box.PlaceholderText = placeholder
	box.Text = ''

	local cr = Instance.new('UICorner')
	cr.CornerRadius = UDim.new(0, 8)
	cr.Parent = box

	return box
end

local function mkButton(parent, label, text, onClick)
	local row = mkRow(parent, 42)

	local txt = Instance.new('TextLabel')
	txt.Parent = row
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromOffset(12, 0)
	txt.Size = UDim2.new(1, -160, 1, 0)
	txt.Font = Enum.Font.Gotham
	txt.TextSize = 12
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextColor3 = Color3.fromRGB(225, 225, 225)
	txt.Text = label

	local btn = Instance.new('TextButton')
	btn.Parent = row
	btn.Size = UDim2.fromOffset(120, 24)
	btn.Position = UDim2.new(1, -132, 0.5, -12)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	btn.BackgroundTransparency = opacity
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(235, 235, 235)
	btn.Text = text

	local cr = Instance.new('UICorner')
	cr.CornerRadius = UDim.new(0, 999)
	cr.Parent = btn

	btn.MouseButton1Click:Connect(function()
		onClick()
		cfg:SaveDebounced(setStatus)
	end)

	return btn
end

-- =========================
-- Page contents
-- =========================
mkHeader(pageHome, 'Overview')
mkNote(pageHome, 'UI gọn + save liên tục. Hop server sẽ giữ config qua TeleportData.\nOut game rồi vào lại: không thể giữ nếu không có DataStore/backend.')

mkHeader(pageAuto, 'AutoFarm Settings')
mkNote(pageAuto, 'Phần này chỉ là UI + config. Nếu bạn muốn “auto farm hợp lệ” trong game của bạn, dùng server script (file 3/4).')

local function getAF() return (cfg:Get().autofarm or {}) end
local function setAF(mutator)
	local c = cfg:Get()
	c.autofarm = c.autofarm or {}
	mutator(c.autofarm)
	cfg:Set(c)
end

mkToggle(pageAuto, 'Start (Enabled)', function() return getAF().Enabled == true end, function(v)
	setAF(function(a) a.Enabled = (v == true) end)
end)

mkToggle(pageAuto, 'Boss Only', function() return getAF().BossOnly == true end, function(v)
	setAF(function(a) a.BossOnly = (v == true) end)
end)

mkSlider(pageAuto, 'Radius', 0, 20000, 50, function()
	return tonumber(getAF().Radius) or DEFAULT.autofarm.Radius
end, function(v)
	setAF(function(a) a.Radius = v end)
end)

mkSlider(pageAuto, 'Follow Distance', 1, 40, 1, function()
	return tonumber(getAF().FollowDist) or DEFAULT.autofarm.FollowDist
end, function(v)
	setAF(function(a) a.FollowDist = v end)
end)

mkSlider(pageAuto, 'Attack CD', 0.05, 1.0, 0.05, function()
	return tonumber(getAF().AttackCD) or DEFAULT.autofarm.AttackCD
end, function(v)
	setAF(function(a) a.AttackCD = v end)
end)

mkHeader(pageTeleport, 'Teleport / Hop')
mkNote(pageTeleport, 'Muốn hop mà giữ config: phải teleport kèm TeleportData. Dùng ToRungHubTransport bridge hoặc nút dưới.')

local jobBox = mkTextBox(pageTeleport, 'JobId', 'Paste JobId here')

mkButton(pageTeleport, 'Rejoin (same place)', 'REJOIN', function()
	cfg:SaveImmediate(setStatus)
	cfg:Teleport(game.PlaceId, nil)
end)

mkButton(pageTeleport, 'Hop to JobId', 'HOP', function()
	local jobId = jobBox.Text
	if typeof(jobId) == 'string' and #jobId > 0 then
		cfg:SaveImmediate(setStatus)
		cfg:Teleport(game.PlaceId, jobId)
	end
end)

mkHeader(pageSettings, 'UI')
mkSlider(pageSettings, 'Opacity', 0, 0.6, 0.02, function()
	local c = cfg:Get()
	return clamp(tonumber((c.ui or {}).opacity) or DEFAULT.ui.opacity, 0, 0.6)
end, function(v)
	local c = cfg:Get()
	c.ui = c.ui or {}
	c.ui.opacity = v
	cfg:Set(c)

	opacity = v
	main.BackgroundTransparency = opacity
	top.BackgroundTransparency = opacity
	sidebar.BackgroundTransparency = opacity
end)

mkNote(pageSettings, 'Hotkey: RightShift (toggle UI). Drag trên topbar để kéo.')

-- =========================
-- Window controls + persistence of UI state
-- =========================
local minimized = (uiCfg.minimized == true)
local locked = (uiCfg.locked == true)

local normalSize = UDim2.fromOffset(520, 360)
local miniSize = UDim2.fromOffset(520, 36)

local floatBtn = Instance.new('TextButton')
floatBtn.Parent = gui
floatBtn.Size = UDim2.fromOffset(44, 44)
floatBtn.Position = UDim2.new(0, 12, 0, 12)
floatBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
floatBtn.BackgroundTransparency = 0.2
floatBtn.BorderSizePixel = 0
floatBtn.Font = Enum.Font.GothamBold
floatBtn.TextSize = 14
floatBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
floatBtn.Text = 'TR'
floatBtn.Visible = false
floatBtn.ZIndex = 10

local fbCr = Instance.new('UICorner')
fbCr.CornerRadius = UDim.new(0, 12)
fbCr.Parent = floatBtn

local function syncShadow()
	shadow.Size = main.Size
	shadow.Position = main.Position + UDim2.fromOffset(6, 6)
	shadow.Visible = main.Visible
end

local function saveUiState()
	local c = cfg:Get()
	c.ui = c.ui or {}
	c.ui.visible = (main.Visible == true)
	c.ui.minimized = minimized
	c.ui.locked = locked
	c.ui.pos = tblFromUdim2(main.Position)
	cfg:Set(c)
	cfg:SaveDebounced(setStatus)
end

local function applyMinimize(on)
	minimized = (on == true)
	body.Visible = not minimized
	main.Size = minimized and miniSize or normalSize
	btnMin.Text = minimized and '+' or '–'
	syncShadow()
	saveUiState()
end

local function applyVisible(on)
	main.Visible = (on == true)
	floatBtn.Visible = not main.Visible
	syncShadow()
	saveUiState()
end

local function applyLock(on)
	locked = (on == true)
	btnLock.Text = locked and '🔒' or '🔓'
	saveUiState()
end

btnClose.MouseButton1Click:Connect(function() applyVisible(false) end)
floatBtn.MouseButton1Click:Connect(function() applyVisible(true) end)
btnMin.MouseButton1Click:Connect(function() applyMinimize(not minimized) end)
btnLock.MouseButton1Click:Connect(function() applyLock(not locked) end)

local dragging, dragStart, startPos = false, nil, nil

top.InputBegan:Connect(function(input)
	if locked then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		syncShadow()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		dragStart, startPos = nil, nil
		saveUiState()
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		applyVisible(not main.Visible)
	end
end)

-- restore initial state
applyLock(locked)
applyMinimize(minimized)
applyVisible(uiCfg.visible ~= false)
setTab(tostring(uiCfg.tab or 'Home'))
syncShadow()

RunService.RenderStepped:Connect(syncShadow)

-- =========================
-- Bridge for your "hop file"
-- =========================
local transport = pg:FindFirstChild('ToRungHubTransport')
if transport then transport:Destroy() end

transport = Instance.new('BindableFunction')
transport.Name = 'ToRungHubTransport'
transport.Parent = pg

transport.OnInvoke = function(action, ...)
	if action == 'GetConfig' then
		return cfg:Get()
	end
	if action == 'SetConfig' then
		local t = ...
		if typeof(t) == 'table' then
			cfg:Set(t)
			cfg:SaveImmediate(setStatus)
			return true
		end
		return false
	end
	if action == 'GetTeleportData' then
		cfg:SaveImmediate(setStatus)
		return cfg:GetTeleportData()
	end
	if action == 'Teleport' then
		local placeId, jobId = ...
		if typeof(placeId) == 'number' then
			cfg:SaveImmediate(setStatus)
			cfg:Teleport(placeId, jobId)
			return true
		end
		return false
	end
	return nil
end
