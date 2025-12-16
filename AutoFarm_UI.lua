local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local plr = Players.LocalPlayer

local REMOTE_NAME = 'TorungHub_AutoFarmRE'
local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME) :: RemoteEvent

local THEME = {
  -- Keep colors moderate; avoid neon. (Roblox Color3 only, no external assets.)
  Bg = Color3.fromRGB(18, 18, 22),
  Panel = Color3.fromRGB(24, 24, 30),
  PanelSoft = Color3.fromRGB(30, 30, 38),
  Text = Color3.fromRGB(235, 235, 245),
  TextDim = Color3.fromRGB(170, 170, 185),
  Accent = Color3.fromRGB(120, 180, 255),
  Danger = Color3.fromRGB(255, 120, 120),
}

local function make(className: string, props: { [string]: any }?, children: { Instance }?)
  local inst = Instance.new(className)
  if props then
    for k, v in pairs(props) do
      (inst :: any)[k] = v
    end
  end
  if children then
    for _, c in ipairs(children) do
      c.Parent = inst
    end
  end
  return inst
end

local function bindHover(btn: GuiButton, on: () -> (), off: () -> ())
  btn.MouseEnter:Connect(on)
  btn.MouseLeave:Connect(off)
end

local function formatBool(v: any): string
  return (v == true) and 'ON' or 'OFF'
end

local gui = make('ScreenGui', {
  Name = 'TorungHubUI',
  ResetOnSpawn = false,
  IgnoreGuiInset = true,
})

local root = make('Frame', {
  Name = 'Root',
  AnchorPoint = Vector2.new(0.5, 0.5),
  Position = UDim2.fromScale(0.5, 0.5),
  Size = UDim2.fromOffset(520, 300),
  BackgroundTransparency = 1,
}, {
  make('UISizeConstraint', { MinSize = Vector2.new(420, 260), MaxSize = Vector2.new(900, 600) }),
})

-- Soft border effect (no full-screen blur): layered strokes/glow
local glowOuter = make('Frame', {
  Name = 'GlowOuter',
  Size = UDim2.fromScale(1, 1),
  BackgroundTransparency = 1,
}, {
  make('UICorner', { CornerRadius = UDim.new(0, 18) }),
  make('UIStroke', { Thickness = 10, Transparency = 0.92, Color = THEME.Accent }),
})

local glowMid = make('Frame', {
  Name = 'GlowMid',
  Size = UDim2.fromScale(1, 1),
  BackgroundTransparency = 1,
}, {
  make('UICorner', { CornerRadius = UDim.new(0, 18) }),
  make('UIStroke', { Thickness = 6, Transparency = 0.90, Color = THEME.Accent }),
})

local panel = make('Frame', {
  Name = 'Panel',
  Size = UDim2.fromScale(1, 1),
  BackgroundColor3 = THEME.Panel,
  BackgroundTransparency = 0.12,
}, {
  make('UICorner', { CornerRadius = UDim.new(0, 18) }),
  make('UIStroke', { Thickness = 1, Transparency = 0.65, Color = THEME.PanelSoft }),
  make('UIPadding', { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
})

local topBar = make('Frame', {
  Name = 'TopBar',
  Size = UDim2.new(1, 0, 0, 42),
  BackgroundTransparency = 1,
}, {
  make('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
})

local title = make('TextLabel', {
  Name = 'Title',
  Size = UDim2.new(1, -120, 1, 0),
  BackgroundTransparency = 1,
  Text = 'Tờ Rung Hub • AutoFarm',
  Font = Enum.Font.GothamSemibold,
  TextSize = 18,
  TextColor3 = THEME.Text,
  TextXAlignment = Enum.TextXAlignment.Left,
})

local hideBtn = make('TextButton', {
  Name = 'HideBtn',
  Size = UDim2.fromOffset(90, 30),
  BackgroundColor3 = THEME.PanelSoft,
  BackgroundTransparency = 0.35,
  Text = 'Hide (RShift)',
  Font = Enum.Font.Gotham,
  TextSize = 12,
  TextColor3 = THEME.TextDim,
  AutoButtonColor = false,
}, {
  make('UICorner', { CornerRadius = UDim.new(0, 10) }),
  make('UIStroke', { Thickness = 1, Transparency = 0.75, Color = THEME.PanelSoft }),
})

bindHover(hideBtn,
  function() hideBtn.BackgroundTransparency = 0.20 end,
  function() hideBtn.BackgroundTransparency = 0.35 end
)

topBar.Parent = panel
title.Parent = topBar
hideBtn.Parent = topBar

local content = make('Frame', {
  Name = 'Content',
  Size = UDim2.new(1, 0, 1, -42),
  Position = UDim2.fromOffset(0, 42),
  BackgroundTransparency = 1,
}, {
  make('UIListLayout', { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
})

content.Parent = panel

local statusCard = make('Frame', {
  Name = 'StatusCard',
  Size = UDim2.new(1, 0, 0, 110),
  BackgroundColor3 = THEME.Bg,
  BackgroundTransparency = 0.30,
}, {
  make('UICorner', { CornerRadius = UDim.new(0, 14) }),
  make('UIStroke', { Thickness = 1, Transparency = 0.80, Color = THEME.PanelSoft }),
  make('UIPadding', { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
})

local statusLine = make('TextLabel', {
  Name = 'StatusLine',
  Size = UDim2.new(1, 0, 0, 22),
  BackgroundTransparency = 1,
  Text = 'Status: ...',
  Font = Enum.Font.Gotham,
  TextSize = 14,
  TextColor3 = THEME.Text,
  TextXAlignment = Enum.TextXAlignment.Left,
})

local targetLine = make('TextLabel', {
  Name = 'TargetLine',
  Size = UDim2.new(1, 0, 0, 22),
  BackgroundTransparency = 1,
  Text = 'Target: ...',
  Font = Enum.Font.Gotham,
  TextSize = 14,
  TextColor3 = THEME.TextDim,
  TextXAlignment = Enum.TextXAlignment.Left,
})

local timersLine = make('TextLabel', {
  Name = 'TimersLine',
  Size = UDim2.new(1, 0, 0, 22),
  BackgroundTransparency = 1,
  Text = 'Haki: 20s • Fruit: 8s',
  Font = Enum.Font.Gotham,
  TextSize = 13,
  TextColor3 = THEME.TextDim,
  TextXAlignment = Enum.TextXAlignment.Left,
})

local buttonRow = make('Frame', {
  Name = 'ButtonRow',
  Size = UDim2.new(1, 0, 0, 34),
  BackgroundTransparency = 1,
}, {
  make('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
})

local toggleBtn = make('TextButton', {
  Name = 'ToggleBtn',
  Size = UDim2.fromOffset(160, 34),
  BackgroundColor3 = THEME.Accent,
  BackgroundTransparency = 0.20,
  Text = 'Start: ...',
  Font = Enum.Font.GothamSemibold,
  TextSize = 14,
  TextColor3 = THEME.Text,
  AutoButtonColor = false,
}, {
  make('UICorner', { CornerRadius = UDim.new(0, 12) }),
})

local bossBtn = make('TextButton', {
  Name = 'BossBtn',
  Size = UDim2.fromOffset(160, 34),
  BackgroundColor3 = THEME.PanelSoft,
  BackgroundTransparency = 0.35,
  Text = 'Boss only: ...',
  Font = Enum.Font.GothamSemibold,
  TextSize = 14,
  TextColor3 = THEME.TextDim,
  AutoButtonColor = false,
}, {
  make('UICorner', { CornerRadius = UDim.new(0, 12) }),
  make('UIStroke', { Thickness = 1, Transparency = 0.75, Color = THEME.PanelSoft }),
})

local radiusBtn = make('TextButton', {
  Name = 'RadiusBtn',
  Size = UDim2.fromOffset(160, 34),
  BackgroundColor3 = THEME.PanelSoft,
  BackgroundTransparency = 0.35,
  Text = 'Radius: ...',
  Font = Enum.Font.GothamSemibold,
  TextSize = 14,
  TextColor3 = THEME.TextDim,
  AutoButtonColor = false,
}, {
  make('UICorner', { CornerRadius = UDim.new(0, 12) }),
  make('UIStroke', { Thickness = 1, Transparency = 0.75, Color = THEME.PanelSoft }),
})

toggleBtn.Parent = buttonRow
bossBtn.Parent = buttonRow
radiusBtn.Parent = buttonRow

statusLine.Parent = statusCard
targetLine.Parent = statusCard
timersLine.Parent = statusCard
buttonRow.Parent = statusCard
statusCard.Parent = content

-- Minimal radius cycling (no slider to keep CPU low)
local radiusOptions = { 500, 1200, 3000, 6000, 12000 }
local radiusIdx = 3

local function setEnabled(v: boolean)
  remote:FireServer('SET_ENABLED', v)
end

local function setBossOnly(v: boolean)
  remote:FireServer('SET_BOSS_ONLY', v)
end

local function setRadius(v: number)
  remote:FireServer('SET_RADIUS', v)
end

toggleBtn.MouseButton1Click:Connect(function()
  local enabled = plr:GetAttribute('TorungHub_Enabled') == true
  setEnabled(not enabled)
end)

bossBtn.MouseButton1Click:Connect(function()
  local bossOnly = plr:GetAttribute('TorungHub_BossOnly') == true
  setBossOnly(not bossOnly)
end)

radiusBtn.MouseButton1Click:Connect(function()
  radiusIdx += 1
  if radiusIdx > #radiusOptions then radiusIdx = 1 end
  setRadius(radiusOptions[radiusIdx])
end)

local visible = true
local function setVisible(v: boolean)
  visible = v
  root.Visible = v
end

hideBtn.MouseButton1Click:Connect(function()
  setVisible(not visible)
end)

UserInputService.InputBegan:Connect(function(input, gp)
  if gp then return end
  if input.KeyCode == Enum.KeyCode.RightShift then
    setVisible(not visible)
  end
end)

-- Dragging
do
  local dragging = false
  local dragStart: Vector2? = nil
  local startPos: UDim2? = nil

  topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = true
      dragStart = input.Position
      startPos = root.Position
    end
  end)

  topBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = false
      dragStart = nil
      startPos = nil
    end
  end)

  UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    if not dragStart or not startPos then return end

    local delta = input.Position - dragStart
    root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
  end)
end

-- Mount GUI
glowOuter.Parent = root
glowMid.Parent = root
panel.Parent = root

gui.Parent = plr:WaitForChild('PlayerGui')

-- Status loop (throttled)
local lastUi = 0.0
RunService.RenderStepped:Connect(function()
  local t = os.clock()
  if (t - lastUi) < 0.10 then return end
  lastUi = t

  local enabled = plr:GetAttribute('TorungHub_Enabled') == true
  local bossOnly = plr:GetAttribute('TorungHub_BossOnly') == true
  local radius = plr:GetAttribute('TorungHub_Radius')
  local status = plr:GetAttribute('TorungHub_Status') or '...'
  local target = plr:GetAttribute('TorungHub_Target') or ''

  toggleBtn.Text = 'Start: ' .. formatBool(enabled)
  toggleBtn.BackgroundColor3 = enabled and THEME.Accent or THEME.Danger
  toggleBtn.BackgroundTransparency = enabled and 0.20 or 0.35

  bossBtn.Text = 'Boss only: ' .. formatBool(bossOnly)
  radiusBtn.Text = 'Radius: ' .. tostring(radius or '...')

  statusLine.Text = 'Status: ' .. tostring(status)
  targetLine.Text = 'Target: ' .. ((target ~= '') and target or 'None')
end)
