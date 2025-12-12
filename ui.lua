-- ========================================================
-- file: ui.lua
-- ========================================================
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local UI = {}

local function createScreenGui()
  local existing = CoreGui:FindFirstChild("ToRungHubUI")
  if existing then
    existing:Destroy()
  end

  local sg = Instance.new("ScreenGui")
  sg.Name = "ToRungHubUI"
  sg.ResetOnSpawn = false
  sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
  sg.Parent = CoreGui

  return sg
end

local function createMainFrame(parent)
  local frame = Instance.new("Frame")
  frame.Name = "MainFrame"
  frame.Size = UDim2.new(0, 400, 0, 280)
  frame.Position = UDim2.new(0, 40, 0, 100)
  frame.BackgroundColor3 = Color3.fromRGB(4, 7, 20)
  frame.BorderSizePixel = 0
  frame.Parent = parent

  local corner = Instance.new("UICorner")
  corner.CornerRadius = UDim.new(0, 12)
  corner.Parent = frame

  local stroke = Instance.new("UIStroke")
  stroke.Color = Color3.fromRGB(37, 99, 235)
  stroke.Thickness = 1
  stroke.Transparency = 0.25
  stroke.Parent = frame

  local padding = Instance.new("UIPadding")
  padding.PaddingLeft = UDim.new(0, 10)
  padding.PaddingRight = UDim.new(0, 10)
  padding.PaddingTop = UDim.new(0, 10)
  padding.PaddingBottom = UDim.new(0, 10)
  padding.Parent = frame

  return frame
end

local function createHeader(parent, text)
  local title = Instance.new("TextLabel")
  title.Name = "Title"
  title.Size = UDim2.new(1, -80, 0, 24)
  title.Position = UDim2.new(0, 0, 0, 0)
  title.BackgroundTransparency = 1
  title.Font = Enum.Font.GothamBold
  title.TextSize = 18
  title.TextColor3 = Color3.fromRGB(248, 250, 252)
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Text = text or "ToRungHub • Anime Fruit"
  title.Parent = parent

  local status = Instance.new("TextLabel")
  status.Name = "StatusLabel"
  status.AnchorPoint = Vector2.new(1, 0)
  status.Position = UDim2.new(1, 0, 0, 0)
  status.Size = UDim2.new(0, 80, 0, 24)
  status.BackgroundTransparency = 1
  status.Font = Enum.Font.Gotham
  status.TextSize = 12
  status.TextColor3 = Color3.fromRGB(148, 163, 184)
  status.TextXAlignment = Enum.TextXAlignment.Right
  status.Text = "STOPPED"
  status.Parent = parent

  local line = Instance.new("Frame")
  line.Size = UDim2.new(1, 0, 0, 1)
  line.Position = UDim2.new(0, 0, 0, 26)
  line.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
  line.BorderSizePixel = 0
  line.Parent = parent

  return status
end

local function createStats(parent)
  local stats = Instance.new("TextLabel")
  stats.Name = "StatsLabel"
  stats.Size = UDim2.new(1, 0, 0, 20)
  stats.Position = UDim2.new(0, 0, 0, 30)
  stats.BackgroundTransparency = 1
  stats.Font = Enum.Font.Code
  stats.TextSize = 13
  stats.TextColor3 = Color3.fromRGB(148, 163, 184)
  stats.TextXAlignment = Enum.TextXAlignment.Left
  stats.Text = "Kills: 0 | Boss: 0 | Chest: 0 | Time: 00:00"
  stats.Parent = parent

  return stats
end

local function createButton(parent, labelText)
  local button = Instance.new("TextButton")
  button.Size = UDim2.new(1, 0, 0, 24)
  button.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
  button.BorderSizePixel = 0
  button.AutoButtonColor = false
  button.Font = Enum.Font.Gotham
  button.TextSize = 13
  button.TextColor3 = Color3.fromRGB(209, 213, 219)
  button.TextXAlignment = Enum.TextXAlignment.Left
  button.Text = labelText
  button.Parent = parent

  local corner = Instance.new("UICorner")
  corner.CornerRadius = UDim.new(0, 6)
  corner.Parent = button

  local stroke = Instance.new("UIStroke")
  stroke.Color = Color3.fromRGB(31, 41, 55)
  stroke.Thickness = 1
  stroke.Parent = button

  local onOff = Instance.new("TextLabel")
  onOff.Name = "ToggleLabel"
  onOff.AnchorPoint = Vector2.new(1, 0.5)
  onOff.Position = UDim2.new(1, -6, 0.5, 0)
  onOff.Size = UDim2.new(0, 50, 0, 16)
  onOff.BackgroundTransparency = 1
  onOff.Font = Enum.Font.GothamBold
  onOff.TextSize = 12
  onOff.TextColor3 = Color3.fromRGB(148, 163, 184)
  onOff.TextXAlignment = Enum.TextXAlignment.Right
  onOff.Text = "OFF"
  onOff.Parent = button

  return button, onOff
end

local function setToggleVisual(label, state)
  if state then
    label.Text = "ON"
    label.TextColor3 = Color3.fromRGB(52, 211, 153)
  else
    label.Text = "OFF"
    label.TextColor3 = Color3.fromRGB(148, 163, 184)
  end
end

function UI.init(CONFIG, state, callbacks)
  local sg = createScreenGui()
  local frame = createMainFrame(sg)
  local statusLabel = createHeader(frame)
  local statsLabel = createStats(frame)

  local list = Instance.new("Frame")
  list.Name = "Buttons"
  list.Size = UDim2.new(1, 0, 1, -70)
  list.Position = UDim2.new(0, 0, 0, 58)
  list.BackgroundTransparency = 1
  list.Parent = frame

  local layout = Instance.new("UIListLayout")
  layout.Padding = UDim.new(0, 6)
  layout.FillDirection = Enum.FillDirection.Vertical
  layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = list

  local buttons = {}

  local function makeToggle(label, key)
    local btn, lbl = createButton(list, label)
    setToggleVisual(lbl, CONFIG.features[key])

    btn.MouseButton1Click:Connect(function()
      local newState = not CONFIG.features[key]
      CONFIG.features[key] = newState
      setToggleVisual(lbl, newState)
      callbacks.onFeatureToggle(key, newState)
    end)

    buttons[key] = { button = btn, label = lbl }
  end

  makeToggle("Auto Farm (mobs)", "autoFarm")
  makeToggle("Auto Boss", "autoBoss")
  makeToggle("Auto Skill (1-4 + R)", "autoSkill")
  makeToggle("Auto Chest", "autoChest")
  makeToggle("Auto Xmas Chest", "autoXmasChest")
  makeToggle("Auto Dungeon", "autoDungeon")
  makeToggle("Auto Mugen", "autoMugen")
  makeToggle("Auto Hop Server", "autoHop")

  local info = {
    screenGui = sg,
    mainFrame = frame,
    statusLabel = statusLabel,
    statsLabel = statsLabel,
    buttons = buttons,
  }

  callbacks.onUiReady(info)

  return info
end

return UI
