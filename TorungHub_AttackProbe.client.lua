-- file: StarterPlayerScripts/TorungHub_AttackProbe.client.lua
-- Purpose: Debug why "Attack" doesn't work by resolving the exact GUI instance and testing :Activate().

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

if RunService:IsServer() then
  return
end

local plr = Players.LocalPlayer
while not plr do
  Players.PlayerAdded:Wait()
  plr = Players.LocalPlayer
end

local function waitChild(parent: Instance, name: string, timeout: number?)
  local t = timeout or 10
  local inst = parent:FindFirstChild(name)
  if inst then return inst end
  return parent:WaitForChild(name, t)
end

local function resolveAttackCandidates()
  local pg = plr:WaitForChild('PlayerGui')

  local pcAction = pg:FindFirstChild('PCAction') or waitChild(pg, 'PCAction', 15)
  if not pcAction then
    return nil, nil, 'Missing PlayerGui.PCAction'
  end

  local bg = pcAction:FindFirstChild('Background') or waitChild(pcAction, 'Background', 10)
  if not bg then
    return nil, nil, 'Missing PlayerGui.PCAction.Background'
  end

  local attack = bg:FindFirstChild('Attack', true)
  local attackBg = bg:FindFirstChild('AttackBG', true)

  return attack, attackBg, nil
end

local function findClickable(inst: Instance?)
  if not inst then return nil end
  if inst:IsA('GuiButton') then return inst end
  local btn = inst:FindFirstChildWhichIsA('GuiButton', true)
  return btn
end

-- Minimal UI
local gui = Instance.new('ScreenGui')
gui.Name = 'TorungHub_AttackProbe'
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild('PlayerGui')

local frame = Instance.new('Frame')
frame.Parent = gui
frame.Size = UDim2.fromOffset(520, 170)
frame.Position = UDim2.fromOffset(20, 120)
frame.BackgroundTransparency = 0.15

local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local stroke = Instance.new('UIStroke')
stroke.Thickness = 1
stroke.Transparency = 0.6
stroke.Parent = frame

local title = Instance.new('TextLabel')
title.Parent = frame
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.fromOffset(10, 8)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamSemibold
title.TextSize = 16
title.Text = 'TorungHub Attack Probe (PCAction.Background.Attack / AttackBG)'

local status = Instance.new('TextLabel')
status.Parent = frame
status.BackgroundTransparency = 1
status.Size = UDim2.new(1, -16, 0, 70)
status.Position = UDim2.fromOffset(10, 40)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Font = Enum.Font.Code
status.TextSize = 13
status.TextWrapped = true
status.Text = 'Resolving...'

local testBtn = Instance.new('TextButton')
testBtn.Parent = frame
testBtn.Size = UDim2.fromOffset(160, 34)
testBtn.Position = UDim2.fromOffset(10, 125)
testBtn.Text = 'Test Activate'
testBtn.AutoButtonColor = true

local hideBtn = Instance.new('TextButton')
hideBtn.Parent = frame
hideBtn.Size = UDim2.fromOffset(120, 34)
hideBtn.Position = UDim2.fromOffset(180, 125)
hideBtn.Text = 'Hide/Show'

local cachedBtn: GuiButton? = nil

local function refresh()
  local attack, attackBg, err = resolveAttackCandidates()
  if err then
    cachedBtn = nil
    status.Text = ('ERROR: %s\n\nTip: PCAction UI phải tồn tại trong PlayerGui trước.'):format(err)
    return
  end

  local aBtn = findClickable(attack)
  local bgBtn = findClickable(attackBg)

  -- Prefer the real Attack button if clickable, else AttackBG
  cachedBtn = aBtn or bgBtn

  local function fmt(inst: Instance?, btn: GuiButton?)
    if not inst then return 'nil' end
    local path = inst:GetFullName()
    local t = inst.ClassName
    local ok = btn and ('clickable=' .. btn.ClassName) or 'clickable=nil'
    return string.format('%s (%s) | %s', path, t, ok)
  end

  status.Text =
    'Attack:\n  ' .. fmt(attack, aBtn) ..
    '\n\nAttackBG:\n  ' .. fmt(attackBg, bgBtn) ..
    '\n\nChosen clickable:\n  ' .. (cachedBtn and cachedBtn:GetFullName() or 'nil')
end

testBtn.MouseButton1Click:Connect(function()
  refresh()
  if not cachedBtn then
    status.Text = status.Text .. '\n\n[Test] No clickable GuiButton found.'
    return
  end

  local ok, err = pcall(function()
    cachedBtn:Activate()
  end)

  status.Text = status.Text .. '\n\n[Test] Activate(): ' .. (ok and 'OK' or ('FAILED: ' .. tostring(err)))
end)

hideBtn.MouseButton1Click:Connect(function()
  frame.Visible = not frame.Visible
end)

task.spawn(function()
  while gui.Parent do
    refresh()
    task.wait(1.0)
  end
end)
