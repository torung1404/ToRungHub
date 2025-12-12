-- ========================================================
-- file: main.lua
-- ========================================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return function(ctx)
  local CONFIG = ctx.config
  local Utils = ctx.utils
  local UI = ctx.ui
  local Webhook = ctx.webhook

  Utils.init(CONFIG)
  Webhook.init(CONFIG)

  local state = {
    running = false,
    farmThread = nil,
    chestThread = nil,
    xmasThread = nil,
    skillThread = nil,
    dungeonThread = nil,
    mugenThread = nil,
    lastBossSeenAt = os.clock(),
  }

  local stats = {
    enabled = CONFIG.stats.enabled,
    kills = 0,
    bossKills = 0,
    chests = 0,
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

  local function shouldBossHop()
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

    if labelName == "boss" then
      markBossSeen()
    end

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

          if shouldBossHop() then
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
        if CONFIG.features.autoChest
          and not CONFIG.features.autoXmasChest
          and Utils.isAlive()
        then
          chestStep()
        else
          task.wait(0.5)
        end
      end
      state.chestThread = nil
    end)
  end

  local function runXmasLoop()
    if state.xmasThread then
      return
    end
    state.xmasThread = task.spawn(function()
      local lastSeen = os.clock()
      local timeout = (CONFIG.xmasChest and CONFIG.xmasChest.hopTimeout) or 10
      while state.running do
        if CONFIG.features.autoXmasChest and Utils.isAlive() then
          local chest = Utils.findChristmasChest()
          if chest then
            lastSeen = os.clock()
            Utils.tweenToTarget(chest)
            if Utils.fireChest(chest) then
              stats.chests += 1
            end
            task.wait(Utils.jitterDelay(CONFIG.timing.chestDelay))
          else
            if CONFIG.xmasChest and CONFIG.xmasChest.hopIfMissing then
              local diff = os.clock() - lastSeen
              if diff >= timeout then
                Utils.hopServer("No Christmas chest for " .. math.floor(diff) .. "s")
                break
              end
            end
            task.wait(0.5)
          end
        else
          task.wait(0.5)
        end
      end
      state.xmasThread = nil
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
    runXmasLoop()
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
      runXmasLoop()
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
