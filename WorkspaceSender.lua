-- file: loader.lua
local BASE_URL = "https://raw.githubusercontent.com/torung1404/ToRungHub/main/"

local function safeHttpGet(url)
    local ok, result = pcall(game.HttpGet, game, url, true)
    if ok then
        return result
    end
    return game:HttpGet(url, true)
end

local function loadRemoteChunk(path)
    local src = safeHttpGet(BASE_URL .. path)
    local fn, err = loadstring(src, "@" .. path)
    if not fn then
        error("[ToRungHub] Failed to load " .. path .. ": " .. tostring(err))
    end
    return fn()
end

local CONFIG  = loadRemoteChunk("config.lua")
local Utils   = loadRemoteChunk("utils.lua")
local UI      = loadRemoteChunk("ui.lua")
local Webhook = loadRemoteChunk("webhook.lua")
local mainFn  = loadRemoteChunk("main.lua")

mainFn({
    config  = CONFIG,
    utils   = Utils,
    ui      = UI,
    webhook = Webhook,
})



-- file: config.lua
local CONFIG = {}

CONFIG.monsters = {
    "monster0101",
    "monster0102",
    "monster0604",
    "monster0801",
    "monster0809",
    "monster0810",
}

CONFIG.bosses = {
    "boss0101", "boss0102",
    "boss0201", "boss0202",
    "boss0301", "boss0302",
    "boss0401", "boss0402",
    "boss0501", "boss0502",
    "boss0601", "boss0602",
    "boss0701", "boss0702", "boss0703",
    "boss0801", "boss0802", "boss0803",
}

CONFIG.chestNames = {
    "ChestPoint",
    "Chest",
    "Chest1",
    "Chest2",
}

CONFIG.timing = {
    attackSpeed   = 0.12,
    moveDelay     = 0.10,
    skillDelay    = 0.35,
    chestDelay    = 0.30,
    scanDelay     = 0.40,
    hopCheckDelay = 5.0,
}

CONFIG.movement = {
    aboveOffsetY   = 7,
    tweenSpeed     = 80,
    minTweenTime   = 0.15,
    maxTargetRange = 1200,
}

CONFIG.features = {
    autoFarm     = true,
    autoBoss     = true,
    autoSkill    = true,
    autoChest    = false,
    autoDungeon  = false,
    autoMugen    = false,
    autoHop      = false,
}

CONFIG.hotkeys = {
    masterToggle = Enum.KeyCode.J,
}

CONFIG.keys = {
    skills = {
        Enum.KeyCode.One,
        Enum.KeyCode.Two,
        Enum.KeyCode.Three,
        Enum.KeyCode.Four,
    },
    fruitSwap = Enum.KeyCode.R,
}

CONFIG.hop = {
    enableBossHop   = true,
    noBossSeconds   = 60,
    notifyInConsole = true,
}

CONFIG.dungeon = {
    enabled         = false,
    pathKeyword     = "Dungeon",
    monsterKeywords = {},
    bossKeywords    = {},
}

CONFIG.mugen = {
    enabled         = false,
    pathKeyword     = "Mugen",
    monsterKeywords = {},
    bossKeywords    = {},
}

CONFIG.stats = {
    enabled = true,
}

do
    local t = CONFIG.timing
    t.attackSpeed   = math.clamp(t.attackSpeed or 0.12, 0.05, 1.0)
    t.moveDelay     = math.clamp(t.moveDelay   or 0.10, 0.03, 1.0)
    t.skillDelay    = math.clamp(t.skillDelay  or 0.35, 0.05, 2.0)
    t.chestDelay    = math.clamp(t.chestDelay  or 0.30, 0.05, 2.0)
    t.scanDelay     = math.clamp(t.scanDelay   or 0.40, 0.05, 2.0)
    t.hopCheckDelay = math.clamp(t.hopCheckDelay or 5.0, 1.0, 60.0)

    local m = CONFIG.movement
    m.aboveOffsetY   = math.clamp(m.aboveOffsetY or 7, 4, 20)
    m.tweenSpeed     = math.clamp(m.tweenSpeed   or 80, 30, 150)
    m.minTweenTime   = math.clamp(m.minTweenTime or 0.15, 0.05, 1.0)
    m.maxTargetRange = math.clamp(m.maxTargetRange or 1200, 100, 3000)
end

return CONFIG



-- file: utils.lua
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local TeleportService   = game:GetService("TeleportService")
local VirtualInput      = game:GetService("VirtualInputManager")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer       = Players.LocalPlayer

local Utils = {}

local CONFIG
local currentTween

local function jit(base, percent)
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

local function distance(a, b)
    return (a - b).Magnitude
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

    local bestPart, bestDist
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            if matchChestName(obj.Name) then
                local pos = obj.Position or (obj:IsA("Model") and obj:GetPivot().Position)
                if pos then
                    local d = distance(root.Position, pos)
                    if d <= CONFIG.movement.maxTargetRange and (not bestDist or d < bestDist) then
                        bestPart, bestDist = obj, d
                    end
                end
            end
        end
    end

    return bestPart
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
    local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(960, 540)
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

function Utils.init(config)
    CONFIG = config
end

function Utils.jitterDelay(base)
    return jit(base)
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



-- file: ui.lua
local Players   = game:GetService("Players")
local CoreGui   = game:GetService("CoreGui")

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
    frame.Size = UDim2.new(0, 390, 0, 260)
    frame.Position = UDim2.new(0, 40, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(4, 7, 20)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(30, 64, 175)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
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
    title.Size = UDim2.new(1, -60, 0, 24)
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
    status.Size = UDim2.new(0, 60, 0, 24)
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
    onOff.Size = UDim2.new(0, 40, 0, 16)
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
    list.Size = UDim2.new(1, 0, 1, -60)
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
    makeToggle("Auto Dungeon", "autoDungeon")
    makeToggle("Auto Mugen", "autoMugen")
    makeToggle("Auto Hop Server", "autoHop")

    local info = {
        screenGui   = sg,
        mainFrame   = frame,
        statusLabel = statusLabel,
        statsLabel  = statsLabel,
        buttons     = buttons,
    }

    callbacks.onUiReady(info)

    return info
end

return UI



-- file: webhook.lua
local Webhook = {}

function Webhook.init(CONFIG)
    Webhook.config = CONFIG
end

function Webhook.sendBossKill(stats, bossName)
    -- Giữ stub cho tương thích, sau này bạn tự thêm Discord webhook nếu muốn.
end

function Webhook.sendError(message)
    warn("[ToRungHub Webhook] ERROR:", message)
end

return Webhook



-- file: main.lua
local Players   = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

return function(ctx)
    local CONFIG  = ctx.config
    local Utils   = ctx.utils
    local UI      = ctx.ui
    local Webhook = ctx.webhook

    Utils.init(CONFIG)
    Webhook.init(CONFIG)

    local state = {
        running        = false,
        farmThread     = nil,
        chestThread    = nil,
        skillThread    = nil,
        dungeonThread  = nil,
        mugenThread    = nil,
        lastBossSeenAt = os.clock(),
    }

    local stats = {
        enabled   = CONFIG.stats.enabled,
        kills     = 0,
        bossKills = 0,
        chests    = 0,
        startTime = os.clock(),
    }

    local uiInfo

    local function formatTime(seconds)
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%02d:%02d", m, s)
    end

    local function updateStatsLabel()
        if not stats.enabled or not uiInfo or not uiInfo.statsLabel then
            return
        end
        local elapsed = os.clock() - stats.startTime
        uiInfo.statsLabel.Text = string.format(
            "Kills: %d | Boss: %d | Chest: %d | Time: %s",
            stats.kills,
            stats.bossKills,
            stats.chests,
            formatTime(elapsed)
        )
    end

    local function setStatus(text)
        if uiInfo and uiInfo.statusLabel then
            uiInfo.statusLabel.Text = text
            if text == "RUNNING" then
                uiInfo.statusLabel.TextColor3 = Color3.fromRGB(52, 211, 153)
            else
                uiInfo.statusLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
            end
        end
    end

    local function shouldHop()
        if not CONFIG.features.autoHop or not CONFIG.hop.enableBossHop then
            return false
        end
        local now = os.clock()
        local diff = now - (state.lastBossSeenAt or now)
        return diff >= CONFIG.hop.noBossSeconds
    end

    local function markBossSeen()
        state.lastBossSeenAt = os.clock()
    end

    local function farmSingleTarget(findFn, labelName)
        if not Utils.isAlive() then
            return
        end
        local model, hum, hrp = findFn()
        if not model or not hum or not hrp or hum.Health <= 0 then
            return
        end

        markBossSeen()

        Utils.tweenToTarget(hrp)
        Utils.basicAttack()

        local hpBefore = hum.Health
        task.wait(Utils.jitterDelay(CONFIG.timing.attackSpeed))
        if hum.Health <= 0 and hpBefore > 0 then
            if labelName == "boss" then
                stats.bossKills += 1
                Webhook.sendBossKill(stats, model.Name)
            else
                stats.kills += 1
            end
        end
    end

    local function chestStep()
        local chestObj = Utils.findChest()
        if not chestObj then
            return
        end
        local pos = chestObj.Position or (chestObj:IsA("Model") and chestObj:GetPivot().Position)
        if not pos then
            return
        end
        Utils.tweenToTarget({ Position = pos })
        if Utils.fireChest(chestObj) then
            stats.chests += 1
        end
        task.wait(Utils.jitterDelay(CONFIG.timing.chestDelay))
    end

    local function runFarmLoop()
        if state.farmThread then
            return
        end
        state.farmThread = task.spawn(function()
            while state.running do
                if not Utils.isAlive() then
                    task.wait(0.5)
                else
                    if CONFIG.features.autoBoss then
                        farmSingleTarget(Utils.findNearestBoss, "boss")
                    elseif CONFIG.features.autoFarm then
                        farmSingleTarget(Utils.findNearestMob, "mob")
                    end

                    if shouldHop() then
                        Utils.hopServer("No boss detected")
                        break
                    end
                end
                task.wait(Utils.jitterDelay(CONFIG.timing.attackSpeed))
            end
            state.farmThread = nil
        end)
    end

    local function runChestLoop()
        if state.chestThread then
            return
        end
        state.chestThread = task.spawn(function()
            while state.running do
                if CONFIG.features.autoChest and Utils.isAlive() then
                    chestStep()
                else
                    task.wait(0.5)
                end
            end
            state.chestThread = nil
        end)
    end

    local function runSkillLoop()
        if state.skillThread then
            return
        end
        state.skillThread = task.spawn(function()
            while state.running do
                if CONFIG.features.autoSkill and Utils.isAlive() then
                    Utils.castSkills()
                    if CONFIG.features.autoBoss then
                        Utils.swapFruit()
                    end
                    task.wait(Utils.jitterDelay(CONFIG.timing.skillDelay))
                else
                    task.wait(0.3)
                end
            end
            state.skillThread = nil
        end)
    end

    local function runDungeonLoop()
        if state.dungeonThread then
            return
        end
        state.dungeonThread = task.spawn(function()
            while state.running do
                if CONFIG.features.autoDungeon and Utils.isAlive() then
                    local bossModel, bossHum, bossRoot = Utils.findNearestDungeonBoss()
                    if bossModel and bossHum and bossRoot then
                        farmSingleTarget(Utils.findNearestDungeonBoss, "boss")
                    else
                        local mobModel, mobHum, mobRoot = Utils.findNearestDungeonMob()
                        if mobModel and mobHum and mobRoot then
                            farmSingleTarget(Utils.findNearestDungeonMob, "mob")
                        else
                            task.wait(0.4)
                        end
                    end
                else
                    task.wait(0.5)
                end
            end
            state.dungeonThread = nil
        end)
    end

    local function runMugenLoop()
        if state.mugenThread then
            return
        end
        state.mugenThread = task.spawn(function()
            while state.running do
                if CONFIG.features.autoMugen and Utils.isAlive() then
                    local bossModel, bossHum, bossRoot = Utils.findNearestMugenBoss()
                    if bossModel and bossHum and bossRoot then
                        farmSingleTarget(Utils.findNearestMugenBoss, "boss")
                    else
                        local mobModel, mobHum, mobRoot = Utils.findNearestMugenMob()
                        if mobModel and mobHum and mobRoot then
                            farmSingleTarget(Utils.findNearestMugenMob, "mob")
                        else
                            task.wait(0.4)
                        end
                    end
                else
                    task.wait(0.5)
                end
            end
            state.mugenThread = nil
        end)
    end

    local function startRuntime()
        if state.running then
            return
        end
        state.running = true
        stats.startTime = os.clock()
        setStatus("RUNNING")

        runFarmLoop()
        runChestLoop()
        runSkillLoop()
        runDungeonLoop()
        runMugenLoop()
    end

    local function stopRuntime()
        if not state.running then
            return
        end
        state.running = false
        setStatus("STOPPED")
    end

    local callbacks = {}

    function callbacks.onFeatureToggle(key, value)
        CONFIG.features[key] = value
        if key == "autoBoss" and value then
            CONFIG.features.autoFarm = false
        end
        if state.running then
            runFarmLoop()
            runChestLoop()
            runSkillLoop()
            runDungeonLoop()
            runMugenLoop()
        end
    end

    function callbacks.onUiReady(info)
        uiInfo = info
        if CONFIG.features.autoFarm or CONFIG.features.autoBoss then
            startRuntime()
        else
            setStatus("STOPPED")
        end
    end

    UI.init(CONFIG, state, callbacks)

    Utils.bindMasterToggle(function()
        if state.running then
            stopRuntime()
        else
            startRuntime()
        end
    end)

    if stats.enabled then
        task.spawn(function()
            while true do
                updateStatsLabel()
                task.wait(1)
            end
        end)
    end

    print("[ToRungHub] Hub initialized. Press " .. tostring(CONFIG.hotkeys.masterToggle) .. " to toggle.")
end
