-- ========================================================
-- file: utils.lua
-- ========================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualInput = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Utils = {}
local CONFIG
local currentTween

local function jitter(base, percent)
  percent = percent or 0.15
  local delta = base * percent
  local offset = (math.random() * 2 - 1) * delta
  local value = base + offset
  if value < 0 then
    value = base * 0.5
  end
  return value
end

local function getCharacter()
  local char = LocalPlayer and LocalPlayer.Character
  if not char or not char.Parent then
    return nil
  end
  return char
end

local function getRoot(char)
  char = char or getCharacter()
  if not char then
    return nil
  end
  return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(char)
  char = char or getCharacter()
  if not char then
    return nil
  end
  return char:FindFirstChildOfClass("Humanoid")
end

local function isAlive()
  local hum = getHumanoid()
  return hum and hum.Health > 0
end

local function distance(a, b)
  return (a - b).Magnitude
end

local function matchName(list, name)
  if not list or #list == 0 then
    return true
  end
  local lower = string.lower(name)
  for _, pattern in ipairs(list) do
    local p = string.lower(tostring(pattern))
    if p ~= "" and string.find(lower, p, 1, true) then
      return true
    end
  end
  return false
end

local function matchChestName(name)
  if not CONFIG or not CONFIG.chestNames then
    return false
  end
  local lower = string.lower(name)
  for _, pattern in ipairs(CONFIG.chestNames) do
    local p = string.lower(pattern)
    if p ~= "" and string.find(lower, p, 1, true) then
      return true
    end
  end
  return false
end

local function getMonstersFolder()
  return Workspace:FindFirstChild("Monsters")
end

local function findNearestInFolder(folder, namesList, maxRange, pathKeyword)
  local char = getCharacter()
  local root = getRoot(char)
  if not char or not root or not folder then
    return nil, nil, nil
  end

  maxRange = maxRange or CONFIG.movement.maxTargetRange
  local origin = root.Position
  local bestModel, bestHum, bestRoot, bestDist

  for _, model in ipairs(folder:GetChildren()) do
    if model:IsA("Model") then
      if matchName(namesList, model.Name) then
        if not pathKeyword or string.find(string.lower(model:GetFullName()), string.lower(pathKeyword), 1, true) then
          local hum = model:FindFirstChildOfClass("Humanoid")
          local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
          if hum and hrp and hum.Health > 0 then
            local d = distance(origin, hrp.Position)
            if d <= maxRange and (not bestDist or d < bestDist) then
              bestModel, bestHum, bestRoot, bestDist = model, hum, hrp, d
            end
          end
        end
      end
    end
  end

  return bestModel, bestHum, bestRoot
end

local function findNearestMonster(list, maxRange, pathKeyword)
  local monstersFolder = getMonstersFolder()
  if not monstersFolder then
    return nil, nil, nil
  end
  return findNearestInFolder(monstersFolder, list, maxRange, pathKeyword)
end

local function findChestCandidate()
  local char = getCharacter()
  local root = getRoot(char)
  if not char or not root then
    return nil
  end

  local bestObj, bestDist
  for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("BasePart") or obj:IsA("Model") then
      if matchChestName(obj.Name) then
        local pos = obj.Position or (obj:IsA("Model") and obj:GetPivot().Position)
        if pos then
          local d = distance(root.Position, pos)
          if d <= CONFIG.movement.maxTargetRange and (not bestDist or d < bestDist) then
            bestObj, bestDist = obj, d
          end
        end
      end
    end
  end

  return bestObj
end

local function findChristmasChestCandidate()
  local char = getCharacter()
  local root = getRoot(char)
  if not char or not root then
    return nil
  end

  local zone = Workspace:FindFirstChild("ChristmasChestZone")
  if not zone then
    return nil
  end

  local bestObj, bestDist
  for _, obj in ipairs(zone:GetDescendants()) do
    if obj:IsA("BasePart") or obj:IsA("Model") then
      local lower = string.lower(obj.Name)
      if string.find(lower, "chest", 1, true) then
        local pos = obj.Position or (obj:IsA("Model") and obj:GetPivot().Position)
        if pos then
          local d = distance(root.Position, pos)
          if not bestDist or d < bestDist then
            bestObj, bestDist = obj, d
          end
        end
      end
    end
  end

  return bestObj
end

local function tweenToPosition(position)
  local root = getRoot()
  if not root then
    return
  end

  local offset = Vector3.new(0, CONFIG.movement.aboveOffsetY, 0)
  local targetPos = position + offset
  local origin = root.Position
  local dist = distance(origin, targetPos)
  local t = math.max(dist / CONFIG.movement.tweenSpeed, CONFIG.movement.minTweenTime)

  if currentTween then
    currentTween:Cancel()
  end

  local cf = CFrame.new(targetPos, position) * CFrame.Angles(math.rad(90), 0, 0)

  local tween = TweenService:Create(root, TweenInfo.new(t, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = cf })
  currentTween = tween
  tween:Play()
  tween.Completed:Wait()
end

local function tweenToTarget(hrp)
  if not hrp then
    return
  end
  tweenToPosition(hrp.Position)
end

local function sendKey(keyCode)
  VirtualInput:SendKeyEvent(true, keyCode, false, game)
  task.wait(0.05)
  VirtualInput:SendKeyEvent(false, keyCode, false, game)
end

local function mouseClick()
  local cam = Workspace.CurrentCamera
  local viewportSize = cam and cam.ViewportSize or Vector2.new(960, 540)
  local pos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
  VirtualInput:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
  task.wait(0.03)
  VirtualInput:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
end

local function fireProxIn(modelOrPart)
  if not modelOrPart then
    return false
  end
  local success = false
  for _, pp in ipairs(modelOrPart:GetDescendants()) do
    if pp:IsA("ProximityPrompt") then
      pcall(function()
        fireproximityprompt(pp)
        success = true
      end)
    end
  end
  return success
end

local function hopServer(reason)
  if CONFIG.hop.notifyInConsole then
    warn("[ToRungHub] Hopping server:", reason or "no reason")
  end
  pcall(function()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
  end)
end

local function bindKeyToggle(keyCode, callback)
  UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then
      return
    end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == keyCode then
      callback()
    end
  end)
end

-- Public API
function Utils.init(config)
  CONFIG = config
end

function Utils.jitterDelay(base)
  return jitter(base)
end

function Utils.getCharacter()
  return getCharacter()
end

function Utils.getRoot()
  return getRoot()
end

function Utils.isAlive()
  return isAlive()
end

function Utils.findNearestMob(pathKeyword)
  return findNearestMonster(CONFIG.monsters, CONFIG.movement.maxTargetRange, pathKeyword)
end

function Utils.findNearestBoss(pathKeyword)
  return findNearestMonster(CONFIG.bosses, CONFIG.movement.maxTargetRange, pathKeyword)
end

function Utils.findNearestDungeonMob()
  if not CONFIG.dungeon.enabled then
    return nil
  end
  return findNearestMonster(CONFIG.dungeon.monsterKeywords, CONFIG.movement.maxTargetRange, CONFIG.dungeon.pathKeyword)
end

function Utils.findNearestDungeonBoss()
  if not CONFIG.dungeon.enabled then
    return nil
  end
  return findNearestMonster(CONFIG.dungeon.bossKeywords, CONFIG.movement.maxTargetRange, CONFIG.dungeon.pathKeyword)
end

function Utils.findNearestMugenMob()
  if not CONFIG.mugen.enabled then
    return nil
  end
  return findNearestMonster(CONFIG.mugen.monsterKeywords, CONFIG.movement.maxTargetRange, CONFIG.mugen.pathKeyword)
end

function Utils.findNearestMugenBoss()
  if not CONFIG.mugen.enabled then
    return nil
  end
  return findNearestMonster(CONFIG.mugen.bossKeywords, CONFIG.movement.maxTargetRange, CONFIG.mugen.pathKeyword)
end

function Utils.findChest()
  return findChestCandidate()
end

function Utils.findChristmasChest()
  return findChristmasChestCandidate()
end

function Utils.tweenToTarget(targetRoot)
  return tweenToTarget(targetRoot)
end

function Utils.basicAttack()
  mouseClick()
end

function Utils.castSkills()
  for _, keyCode in ipairs(CONFIG.keys.skills) do
    sendKey(keyCode)
    task.wait(0.05)
  end
end

function Utils.swapFruit()
  sendKey(CONFIG.keys.fruitSwap)
end

function Utils.fireChest(modelOrPart)
  return fireProxIn(modelOrPart)
end

function Utils.hopServer(reason)
  return hopServer(reason)
end

function Utils.bindMasterToggle(callback)
  if CONFIG.hotkeys and CONFIG.hotkeys.masterToggle then
    bindKeyToggle(CONFIG.hotkeys.masterToggle, callback)
  end
end

function Utils.heartbeat(callback)
  RunService.Heartbeat:Connect(callback)
end

return Utils
