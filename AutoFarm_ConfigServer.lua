-- file: ServerScriptService/AutoFarm_ConfigServer.lua
-- NOTE: This is a Roblox Studio SERVER script for YOUR OWN game.
-- It intentionally does NOT use DataStore / config persistence.

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')
local CollectionService = game:GetService('CollectionService')

local REMOTE_NAME = 'TorungHub_AutoFarmRE'

local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not remote then
  remote = Instance.new('RemoteEvent')
  remote.Name = REMOTE_NAME
  remote.Parent = ReplicatedStorage
end

local CONFIG = {
  EnabledByDefault = true,

  TickRate = 0.10,        -- main loop tick
  RetargetRate = 0.25,    -- how often we search best target
  TargetLockMax = 25,     -- seconds

  Radius = 3000,
  AttackRange = 35,
  FollowDist = 6,
  HeightOffset = 0,
  SmoothMove = true,
  SmoothAlpha = 0.35,

  AttackCooldown = 0.15,
  DamagePerHit = 10,

  HakiInterval = 20,
  FruitInterval = 8,

  MonsterFolderNames = { 'Monsters', 'NPC' },
  MonsterTag = nil,      -- set to a tag if you use CollectionService tagging
  BossTag = 'Boss',
  BossOnly = false,

  BlacklistSeconds = 6,

  ControlRateLimitHz = 5,
}

type PlayerState = {
  enabled: boolean,
  bossOnly: boolean,
  radius: number,

  target: Model?,
  targetLockedAt: number,

  lastRetarget: number,
  lastAttack: number,
  lastHaki: number,
  lastFruit: number,

  lastControlAt: number,
}

local states: { [Player]: PlayerState } = {}
local blacklist: { [Instance]: number } = {}

local function now(): number
  return os.clock()
end

local function setAttrIfChanged(inst: Instance, key: string, value: any)
  if inst:GetAttribute(key) ~= value then
    inst:SetAttribute(key, value)
  end
end

local function getCharParts(plr: Player): (Model?, BasePart?, Humanoid?)
  local c = plr.Character
  if not c then return nil, nil, nil end
  local hrp = c:FindFirstChild('HumanoidRootPart') :: BasePart?
  local hum = c:FindFirstChildOfClass('Humanoid') :: Humanoid?
  if not hrp or not hum then return nil, nil, nil end
  if hum.Health <= 0 then return nil, nil, nil end
  return c, hrp, hum
end

local function getModelRoot(m: Model): BasePart?
  return (m:FindFirstChild('HumanoidRootPart') :: BasePart?) or (m.PrimaryPart :: BasePart?)
end

local function getModelHumanoid(m: Model): Humanoid?
  return m:FindFirstChildOfClass('Humanoid') :: Humanoid?
end

local function isBlacklisted(m: Instance): boolean
  local exp = blacklist[m]
  if not exp then return false end
  if now() >= exp then
    blacklist[m] = nil
    return false
  end
  return true
end

local function addBlacklist(m: Instance)
  blacklist[m] = now() + CONFIG.BlacklistSeconds
end

-- Monster caching (global)
local folderCache = { t = 0.0, inst = nil :: Instance? }
local monsterCache = { t = 0.0, list = {} :: { Model } }

local function resolveMonsterFolder(): Instance?
  local t = now()
  if folderCache.inst and folderCache.inst.Parent and (t - folderCache.t) < 2.0 then
    return folderCache.inst
  end
  folderCache.t = t
  folderCache.inst = nil

  for _, name in ipairs(CONFIG.MonsterFolderNames) do
    local f = Workspace:FindFirstChild(name)
    if f then
      folderCache.inst = f
      return f
    end
  end
  return nil
end

local function listMonsters(): { Model }
  local t = now()
  if (t - monsterCache.t) < 0.30 then
    return monsterCache.list
  end
  monsterCache.t = t

  local out: { Model } = {}

  if CONFIG.MonsterTag then
    local tagged = CollectionService:GetTagged(CONFIG.MonsterTag)
    for _, inst in ipairs(tagged) do
      if inst:IsA('Model') then
        table.insert(out, inst)
      end
    end
    monsterCache.list = out
    return out
  end

  local folder = resolveMonsterFolder()
  if folder then
    for _, inst in ipairs(folder:GetChildren()) do
      if inst:IsA('Model') then
        table.insert(out, inst)
      end
    end
  end

  monsterCache.list = out
  return out
end

local function isBoss(m: Model): boolean
  if CONFIG.BossTag and CollectionService:HasTag(m, CONFIG.BossTag) then
    return true
  end
  return string.find(string.lower(m.Name), 'boss') ~= nil
end

local function isAliveMonster(m: Model): boolean
  if not m:IsDescendantOf(Workspace) then return false end
  local hum = getModelHumanoid(m)
  if not hum then return false end
  return hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead
end

local function bestTarget(hrp: BasePart, st: PlayerState): Model?
  local best: Model? = nil
  local bestScore = -math.huge
  local myPos = hrp.Position
  local r2 = st.radius * st.radius

  for _, m in ipairs(listMonsters()) do
    if m and m:IsA('Model') and not isBlacklisted(m) and isAliveMonster(m) then
      local boss = isBoss(m)
      if (not st.bossOnly) or boss then
        local root = getModelRoot(m)
        if root then
          local dp = myPos - root.Position
          local d2 = dp:Dot(dp)
          if d2 <= r2 then
            local score = (boss and 1e9 or 0) - d2
            if score > bestScore then
              bestScore = score
              best = m
            end
          end
        end
      end
    end
  end

  return best
end

local function moveBehind(hrp: BasePart, target: Model, dt: number)
  local root = getModelRoot(target)
  if not root then return end

  local goalPos = (root.CFrame * CFrame.new(0, CONFIG.HeightOffset, CONFIG.FollowDist)).Position
  goalPos = Vector3.new(goalPos.X, root.Position.Y + CONFIG.HeightOffset, goalPos.Z)

  if CONFIG.SmoothMove then
    local t = math.clamp(CONFIG.SmoothAlpha * (dt * 60), 0, 1)
    local newPos = hrp.Position:Lerp(goalPos, t)
    hrp.CFrame = CFrame.lookAt(newPos, root.Position)
  else
    hrp.CFrame = CFrame.lookAt(goalPos, root.Position)
  end
end

-- Integrations (edit these 3 functions to match YOUR game systems)
local function ensureHakiOn(plr: Player)
  -- WHY: make it idempotent; no spam if already on.
  if plr:GetAttribute('TorungHub_HakiOn') == true then return end
  plr:SetAttribute('TorungHub_HakiOn', true)
  -- TODO: hook into your real haki system here (server-side).
end

local function switchFruit(plr: Player)
  -- WHY: keep state server-side so it doesn't depend on UI button finding.
  local idx = plr:GetAttribute('TorungHub_FruitIndex')
  if typeof(idx) ~= 'number' then idx = 0 end
  idx += 1
  plr:SetAttribute('TorungHub_FruitIndex', idx)
  -- TODO: hook into your real fruit switch system here (server-side).
end

local function doAttack(plr: Player, target: Model)
  -- Default server damage (works if monsters have Humanoid).
  local hum = getModelHumanoid(target)
  if not hum or hum.Health <= 0 then
    addBlacklist(target)
    return
  end
  hum:TakeDamage(CONFIG.DamagePerHit)
end

local function shouldAttack(hrp: BasePart, target: Model): boolean
  local root = getModelRoot(target)
  if not root then return false end
  local dp = hrp.Position - root.Position
  return dp:Dot(dp) <= (CONFIG.AttackRange * CONFIG.AttackRange)
end

local function startPlayer(plr: Player)
  local st: PlayerState = {
    enabled = CONFIG.EnabledByDefault,
    bossOnly = CONFIG.BossOnly,
    radius = CONFIG.Radius,

    target = nil,
    targetLockedAt = 0,

    lastRetarget = 0,
    lastAttack = 0,
    lastHaki = 0,
    lastFruit = 0,

    lastControlAt = 0,
  }
  states[plr] = st

  setAttrIfChanged(plr, 'TorungHub_Enabled', st.enabled)
  setAttrIfChanged(plr, 'TorungHub_BossOnly', st.bossOnly)
  setAttrIfChanged(plr, 'TorungHub_Radius', st.radius)
  setAttrIfChanged(plr, 'TorungHub_Status', 'Starting...')
  setAttrIfChanged(plr, 'TorungHub_Target', '')

  task.spawn(function()
    local lastTick = now()
    while plr.Parent do
      task.wait(CONFIG.TickRate)
      local t = now()
      local dt = t - lastTick
      lastTick = t

      if not st.enabled then
        setAttrIfChanged(plr, 'TorungHub_Status', 'Stopped')
        continue
      end

      local _, hrp = getCharParts(plr)
      if not hrp then
        setAttrIfChanged(plr, 'TorungHub_Status', 'No character')
        continue
      end

      -- timed actions (no spam)
      if (t - st.lastHaki) >= CONFIG.HakiInterval then
        st.lastHaki = t
        ensureHakiOn(plr)
      end
      if (t - st.lastFruit) >= CONFIG.FruitInterval then
        st.lastFruit = t
        switchFruit(plr)
      end

      -- retarget
      local target = st.target
      local lockExpired = target and ((t - st.targetLockedAt) > CONFIG.TargetLockMax) or false
      if (t - st.lastRetarget) >= CONFIG.RetargetRate or lockExpired then
        st.lastRetarget = t
        if target and (not target:IsDescendantOf(Workspace) or not isAliveMonster(target) or isBlacklisted(target)) then
          target = nil
        end

        if not target then
          local newTarget = bestTarget(hrp, st)
          if newTarget then
            st.target = newTarget
            st.targetLockedAt = t
            setAttrIfChanged(plr, 'TorungHub_Target', newTarget.Name)
          else
            st.target = nil
            setAttrIfChanged(plr, 'TorungHub_Target', '')
          end
        end
      end

      target = st.target
      if not target then
        setAttrIfChanged(plr, 'TorungHub_Status', 'No target')
        continue
      end
      if not target:IsDescendantOf(Workspace) or not isAliveMonster(target) then
        addBlacklist(target)
        st.target = nil
        setAttrIfChanged(plr, 'TorungHub_Target', '')
        setAttrIfChanged(plr, 'TorungHub_Status', 'Retargeting...')
        continue
      end

      moveBehind(hrp, target, dt)

      if shouldAttack(hrp, target) and (t - st.lastAttack) >= CONFIG.AttackCooldown then
        st.lastAttack = t
        doAttack(plr, target)
      end

      setAttrIfChanged(plr, 'TorungHub_Status', 'Running')
    end
  end)
end

remote.OnServerEvent:Connect(function(plr: Player, action: any, payload: any)
  local st = states[plr]
  if not st then return end

  local t = now()
  if st.lastControlAt > 0 and (t - st.lastControlAt) < (1 / CONFIG.ControlRateLimitHz) then
    return
  end
  st.lastControlAt = t

  if action == 'SET_ENABLED' then
    if typeof(payload) ~= 'boolean' then return end
    st.enabled = payload
    setAttrIfChanged(plr, 'TorungHub_Enabled', st.enabled)
    if not st.enabled then
      st.target = nil
      setAttrIfChanged(plr, 'TorungHub_Target', '')
    end
    return
  end

  if action == 'SET_BOSS_ONLY' then
    if typeof(payload) ~= 'boolean' then return end
    st.bossOnly = payload
    setAttrIfChanged(plr, 'TorungHub_BossOnly', st.bossOnly)
    st.target = nil
    setAttrIfChanged(plr, 'TorungHub_Target', '')
    return
  end

  if action == 'SET_RADIUS' then
    if typeof(payload) ~= 'number' then return end
    local v = math.clamp(payload, 20, 20000)
    st.radius = v
    setAttrIfChanged(plr, 'TorungHub_Radius', st.radius)
    st.target = nil
    setAttrIfChanged(plr, 'TorungHub_Target', '')
    return
  end
end)

Players.PlayerAdded:Connect(startPlayer)
Players.PlayerRemoving:Connect(function(plr)
  states[plr] = nil
end)

for _, plr in ipairs(Players:GetPlayers()) do
  startPlayer(plr)
end


-- file: README.md
-- Replace your repo README with this (Studio usage only).

--[[
# torunghub (Studio version)

This repo contains Roblox Studio scripts for **your own game**.

## Install
1. In Roblox Studio:
   - Put `AutoFarm_ConfigServer.lua` into **ServerScriptService**
   - Put `AutoFarm_UI.lua` into **StarterPlayer > StarterPlayerScripts**
2. Ensure your monsters are either:
   - Under `Workspace.Monsters` (or `Workspace.NPC`), OR
   - Tagged with `CollectionService` tag `CONFIG.MonsterTag` (edit in server script)

## What it does
- Auto-start ON for players
- Every **20s**: ensure Haki ON (server-side placeholder)
- Every **8s**: switch Fruit (server-side placeholder)
- Auto-attack uses server Humanoid damage (edit `doAttack`, `ensureHakiOn`, `switchFruit` to hook into your systems)
- No DataStore, no persistence, no spam logging/remote calls
]]
