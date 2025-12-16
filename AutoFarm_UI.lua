-- file: StarterPlayerScripts/AutoFarm_UI.lua
-- Use only in your own game / permitted environment.

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local Workspace = game:GetService('Workspace')
local UIS = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local plr = Players.LocalPlayer

local function now()
  return os.clock()
end

-- =========================
-- Anti-freeze logging (THROTTLED)
-- =========================
local _logThrottle = {} -- [key] = { t=number, suppressed=int }
local function warnThrottled(key, msg, intervalSec)
  local t = os.clock()
  local e = _logThrottle[key]
  if not e then
    _logThrottle[key] = { t = t, suppressed = 0 }
    warn(msg)
    return
  end
  if (t - e.t) >= intervalSec then
    local extra = ''
    if e.suppressed > 0 then
      extra = (' (suppressed %d logs)'):format(e.suppressed)
    end
    e.t = t
    e.suppressed = 0
    warn(msg .. extra)
  else
    e.suppressed += 1
  end
end

local CFG = {
  -- Core
  Enabled = false,
  BossOnly = false,
  SmoothMove = true,

  -- Performance / debug
  DebugLog = false,              -- set true only when debugging
  WarnThrottleSeconds = 6,       -- throttle warn spam
  MonsterCacheSeconds = 0.30,    -- cache mob list
  MonsterFolderRefreshSeconds = 2.0,
  HpCacheSeconds = 0.15,         -- cache HP percent
  UiStatusHz = 10,               -- status label update rate
  SliderHz = 10,                 -- slider sampling rate

  -- Targeting / movement
  Radius = 3000,
  FollowDist = 6,
  HeightOffset = 0,
  Alpha = 0.35,

  -- Scan / timing
  RetargetTick = 0.12,
  BlacklistSeconds = 6,
  TargetMaxLockSeconds = 25,

  -- NPC folders / tags
  MonsterFolderNames = { 'Monsters', 'NPC' },
  MonsterTag = nil,
  BossTag = 'Boss',

  -- NPC dead detection
  HPAttrName = 'HP',
  StateAttrName = 'State',
  DeadStates = { 'death', 'dead', 'died', 'ko', 'down' },

  -- Features
  AutoAttack = false,
  AutoHakiV = false,
  AutoSwitchFruitR = false,
  AutoMeditate = false,

  -- Aggro sweep (TP qua các cụm quái để kéo aggro trước khi đánh)
  AggroSweep = true,
  AggroRange = 75,
  SweepGridSize = 140,
  SweepMaxPoints = 8,
  SweepDwell = 0.12,
  SweepHeight = 3,
  SweepInterval = 12,

  -- Cooldowns (user adjustable)
  AttackCD = 0.15,
  HakiCD = 6,
  SwitchFruitCD = 12,

  -- Attack options
  AttackMode = 'TOOL', -- TOOL | REMOTE | UI
  AttackRange = 35,
  EquipToolIfNone = true,

  -- OPTIONAL: if your game has a legit remote, set it (do not guess)
  AttackRemoteName = nil,
  AttackRemotePath = nil, -- e.g. { 'Remotes', 'Combat', 'TryAttack' }
  AttackRemoteArgsMode = 'TARGET_ONLY', -- TARGET_ONLY | NONE

  -- Heal thresholds (%)
  HealMinPercent = 25,
  HealMaxPercent = 90,

  -- Safe spot
  SafeCFrame = nil,
  SafeFallbackHeight = 120,

  -- UI lookup names
  UiName_Haki = 'Haki',
  UiName_SwitchFruit = 'SwitchFruit',
  UiName_Attack = 'Attack',
  UiName_Meditate = 'Meditate',

  -- Player HP UI (Dex screenshot: HPBar > CharInfo > Background > HP)
  HpUiRootNames = { 'HPBar', 'HpBar', 'HPBAR' },
  HpUiFillPathCandidates = {
    { 'CharInfo', 'Background', 'HP' },
    { 'CharInfo', 'Background', 'HPFill' },
    { 'CharInfo', 'Background', 'Health' },
    { 'Background', 'HP' },
  },
  HpUiPreferText = true,

  -- Persistence remotes (must exist on server)
  ConfigRFName = 'AutoFarmConfigRF',
  ConfigREName = 'AutoFarmConfigRE',
}

local function safeCall(label, fn, ...)
  local ok, res = pcall(fn, ...)
  if not ok and CFG.DebugLog then
    warnThrottled(
      tostring(label),
      '[AutoFarmUI] ' .. tostring(label) .. ' failed: ' .. tostring(res),
      CFG.WarnThrottleSeconds or 6
    )
  end
  return ok, res
end

-- =========================
-- Character helpers
-- =========================
local function char()
  return plr.Character
end

local function hrp()
  local c = char()
  return c and c:FindFirstChild('HumanoidRootPart')
end

local function getHum(m)
  return m and m:FindFirstChildOfClass('Humanoid')
end

local function getRoot(m)
  if not m then return nil end
  return m:FindFirstChild('HumanoidRootPart') or m.PrimaryPart
end

local function normalizeString(v)
  if typeof(v) ~= 'string' then return '' end
  return string.lower(v)
end

local function stateIsDead(m)
  local st = m:GetAttribute(CFG.StateAttrName)
  local s = normalizeString(st)
  if s == '' then return false end
  for _, deadKey in ipairs(CFG.DeadStates) do
    if s == deadKey then
      return true
    end
  end
  return false
end

local function getNPC_HP(m)
  local hp = m:GetAttribute(CFG.HPAttrName)
  if typeof(hp) == 'number' then return hp end

  local hpObj = m:FindFirstChild(CFG.HPAttrName)
  if hpObj and hpObj:IsA('ValueBase') and typeof(hpObj.Value) == 'number' then
    return hpObj.Value
  end

  local h = getHum(m)
  if h then return h.Health end

  return nil
end

local function deadLike(m)
  if not (m and m:IsA('Model')) then return true end
  if not m:IsDescendantOf(Workspace) then return true end

  local hp = getNPC_HP(m)
  if typeof(hp) == 'number' and hp <= 0 then
    return true
  end

  if stateIsDead(m) then
    return true
  end

  local h = getHum(m)
  if not h then return true end
  if h.Health <= 0 then return true end
  if h:GetState() == Enum.HumanoidStateType.Dead then return true end

  return false
end

local function alive(m)
  local r = getRoot(m)
  if not r then return false end
  return not deadLike(m)
end

local function isBoss(m)
  if not (m and m:IsA('Model')) then return false end
  if CFG.BossTag and CollectionService:HasTag(m, CFG.BossTag) then return true end
  local n = (m.Name or ''):lower()
  return n:find('boss') ~= nil
end

-- =========================
-- Monster listing (CACHED + avoid heavy fallback)
-- =========================
local monsterFolderCache = { t = 0, inst = nil }
local monsterListCache = { t = 0, list = {} }
local workspaceFallbackCache = { t = 0, list = {} }

local function resolveMonsterFolder()
  local t = now()
  if monsterFolderCache.inst and monsterFolderCache.inst.Parent and (t - monsterFolderCache.t) < (CFG.MonsterFolderRefreshSeconds or 2) then
    return monsterFolderCache.inst
  end

  monsterFolderCache.t = t
  monsterFolderCache.inst = nil

  for _, name in ipairs(CFG.MonsterFolderNames) do
    local f = Workspace:FindFirstChild(name)
    if f then
      monsterFolderCache.inst = f
      return f
    end
  end
  return nil
end

local function listMonsters()
  local t = now()
  if monsterListCache.list and (t - monsterListCache.t) < (CFG.MonsterCacheSeconds or 0.30) then
    return monsterListCache.list
  end
  monsterListCache.t = t

  local out = {}

  -- Tagged
  if CFG.MonsterTag then
    local tagged = CollectionService:GetTagged(CFG.MonsterTag)
    if tagged and #tagged > 0 then
      for _, inst in ipairs(tagged) do
        if inst and inst:IsA('Model') then
          table.insert(out, inst)
        end
      end
      monsterListCache.list = out
      return out
    end
  end

  -- Folder
  local folder = resolveMonsterFolder()
  if folder then
    local kids = folder:GetChildren()
    for i = 1, #kids do
      local m = kids[i]
      if m and m:IsA('Model') then
        out[#out + 1] = m
      end
    end
    monsterListCache.list = out
    return out
  end

  -- LAST RESORT: Workspace scan but VERY RARE
  if (t - workspaceFallbackCache.t) > 6 then
    workspaceFallbackCache.t = t
    local kids = Workspace:GetChildren()
    local tmp = {}
    for i = 1, #kids do
      local m = kids[i]
      if m and m:IsA('Model') then
        tmp[#tmp + 1] = m
      end
    end
    workspaceFallbackCache.list = tmp
    if CFG.DebugLog then
      warnThrottled(
        'WorkspaceFallback',
        '[AutoFarmUI] Monster folder/tag not found -> using slow Workspace scan (cached). Fix CFG.MonsterFolderNames/MonsterTag.',
        10
      )
    end
  end

  monsterListCache.list = workspaceFallbackCache.list or {}
  return monsterListCache.list
end

-- =========================
-- Blacklist (anti stuck on corpse)
-- =========================
local blacklist = {} -- [Instance] = expireTime

local function isBlacklisted(m)
  local exp = blacklist[m]
  if not exp then return false end
  if now() >= exp then
    blacklist[m] = nil
    return false
  end
  return true
end

local function addBlacklist(m)
  blacklist[m] = now() + CFG.BlacklistSeconds
end

-- =========================
-- Target selection (FAST: distance^2, no sqrt)
-- =========================
local function bestTarget(myHrp)
  local best = nil
  local bestScore = -math.huge

  local myPos = myHrp.Position
  local r2 = CFG.Radius * CFG.Radius

  local mobs = listMonsters()
  for i = 1, #mobs do
    local m = mobs[i]
    if m and m:IsA('Model') and (not isBlacklisted(m)) and alive(m) then
      local boss = isBoss(m)
      if (not CFG.BossOnly) or boss then
        local r = getRoot(m)
        if r then
          local dp = myPos - r.Position
          local d2 = dp:Dot(dp)
          if d2 <= r2 then
            local hp = getNPC_HP(m)
            if not (typeof(hp) == 'number' and hp <= 0) then
              local hpScore = (typeof(hp) == 'number') and hp or 0
              local score = (boss and 1e9 or 0) + (hpScore * 0.001) - (d2 * 0.0005)
              if score > bestScore then
                bestScore = score
                best = m
              end
            end
          end
        end
      end
    end
  end

  return best
end

-- =========================
-- Movement
-- =========================
local function moveBehind(myHrp, target, dt)
  local r = getRoot(target)
  if not r then return end

  local goalPos = (r.CFrame * CFrame.new(0, CFG.HeightOffset, CFG.FollowDist)).Position
  goalPos = Vector3.new(goalPos.X, r.Position.Y + CFG.HeightOffset, goalPos.Z)

  if CFG.SmoothMove then
    local t = math.clamp(CFG.Alpha * (dt * 60), 0, 1)
    local newPos = myHrp.Position:Lerp(goalPos, t)
    myHrp.CFrame = CFrame.lookAt(newPos, r.Position)
  else
    myHrp.CFrame = CFrame.lookAt(goalPos, r.Position)
  end
end

-- =========================
-- UI cache helpers
-- =========================
local function getPlayerGui()
  return plr:FindFirstChildOfClass('PlayerGui')
end

local uiCache = {}
local btnCache = {}
local lastLookup = {}

local function findFirstDescendantByName(root, name)
  if not root then return nil end
  if root.Name == name then return root end
  for _, d in ipairs(root:GetDescendants()) do
    if d.Name == name then
      return d
    end
  end
  return nil
end

local function findClickable(inst)
  if not inst then return nil end
  if inst:IsA('GuiButton') then return inst end
  for _, d in ipairs(inst:GetDescendants()) do
    if d:IsA('GuiButton') then
      return d
    end
  end
  return nil
end

local function getUiInstance(name)
  local pg = getPlayerGui()
  if not pg then return nil end

  local cached = uiCache[name]
  if cached and cached:IsDescendantOf(pg) then
    return cached
  end

  local t = now()
  if lastLookup[name] and (t - lastLookup[name]) < 0.75 then
    return nil
  end
  lastLookup[name] = t

  local inst = findFirstDescendantByName(pg, name)
  if inst then
    uiCache[name] = inst
    btnCache[name] = nil
  end

  return inst
end

local function tryActivateByName(name)
  local inst = getUiInstance(name)
  if not inst then return false end

  local btn = btnCache[name]
  if not (btn and btn:IsDescendantOf(inst)) then
    btn = findClickable(inst)
    btnCache[name] = btn
  end
  if not btn then return false end

  local ok = false
  safeCall('Activate ' .. name, function()
    btn:Activate()
    ok = true
  end)
  return ok
end

local function isUiStateActive(name)
  local inst = getUiInstance(name)
  if not inst then return nil end
  local st = inst:GetAttribute('State')
  if typeof(st) ~= 'string' then return nil end
  local s = string.lower(st)
  if s == 'idle' or s == 'off' or s == 'false' then
    return false
  end
  return true
end

-- Key press helper (optional)
local vim
safeCall('Get VirtualInputManager', function()
  vim = game:GetService('VirtualInputManager')
end)

local function pressKey(keyCode)
  if not vim then return false end
  local ok = false
  safeCall('PressKey ' .. tostring(keyCode), function()
    vim:SendKeyEvent(true, keyCode, false, game)
    task.wait()
    vim:SendKeyEvent(false, keyCode, false, game)
    ok = true
  end)
  return ok
end

-- =========================
-- Safe spot
-- =========================
local function getOrBuildSafeCFrame()
  if typeof(CFG.SafeCFrame) == 'CFrame' then
    return CFG.SafeCFrame
  end

  local my = hrp()
  if not my then return nil end
  return my.CFrame * CFrame.new(0, CFG.SafeFallbackHeight, 0)
end

local function tpToCFrame(cf)
  local my = hrp()
  if not my or not cf then return end
  my.CFrame = cf
  my.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
  my.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local function tpToSafe()
  tpToCFrame(getOrBuildSafeCFrame())
end

-- =========================
-- Attack adapter (default: TOOL Activate)
-- =========================
local function getEquippedTool()
  local c = char()
  if not c then return nil end
  for _, child in ipairs(c:GetChildren()) do
    if child:IsA('Tool') then
      return child
    end
  end
  return nil
end

local function equipAnyTool()
  if not CFG.EquipToolIfNone then return nil end
  local c = char()
  if not c then return nil end
  local hum = c:FindFirstChildOfClass('Humanoid')
  local bp = plr:FindFirstChildOfClass('Backpack')
  if not (hum and bp) then return nil end
  local tool = bp:FindFirstChildOfClass('Tool')
  if not tool then return nil end
  safeCall('EquipTool', function()
    hum:EquipTool(tool)
  end)
  return getEquippedTool()
end

local attackRemoteCache
local function getAttackRemote()
  if attackRemoteCache and attackRemoteCache.Parent then
    return attackRemoteCache
  end

  local remote = nil

  if CFG.AttackRemotePath and typeof(CFG.AttackRemotePath) == 'table' then
    local cur = ReplicatedStorage
    for _, seg in ipairs(CFG.AttackRemotePath) do
      if typeof(seg) ~= 'string' then
        cur = nil
        break
      end
      cur = cur and cur:FindFirstChild(seg)
    end
    if cur and (cur:IsA('RemoteEvent') or cur:IsA('RemoteFunction')) then
      remote = cur
    end
  end

  if not remote and typeof(CFG.AttackRemoteName) == 'string' then
    local found = ReplicatedStorage:FindFirstChild(CFG.AttackRemoteName, true)
    if found and (found:IsA('RemoteEvent') or found:IsA('RemoteFunction')) then
      remote = found
    end
  end

  attackRemoteCache = remote
  return remote
end

local function doAttack(target)
  if CFG.AttackMode == 'TOOL' then
    local tool = getEquippedTool() or equipAnyTool()
    if not tool then return false end

    local ok = false
    safeCall('Tool:Activate', function()
      tool:Activate()
      ok = true
    end)
    return ok
  end

  if CFG.AttackMode == 'REMOTE' then
    local remote = getAttackRemote()
    if not remote then return false end

    local ok = false
    safeCall('Remote attack', function()
      if remote:IsA('RemoteEvent') then
        if CFG.AttackRemoteArgsMode == 'TARGET_ONLY' then
          remote:FireServer(target)
        else
          remote:FireServer()
        end
      else
        if CFG.AttackRemoteArgsMode == 'TARGET_ONLY' then
          remote:InvokeServer(target)
        else
          remote:InvokeServer()
        end
      end
      ok = true
    end)
    return ok
  end

  return tryActivateByName(CFG.UiName_Attack)
end

-- =========================
-- HP percent (UI read + cached)
-- =========================
local hpUiCache = {
  root = nil,
  fill = nil,
  base = nil,
  text = nil,
  lastResolve = 0,
  src = 'NONE',
}

local function parseShortNumber(s)
  s = tostring(s or ''):gsub(',', ''):gsub('%s+', '')
  local num = tonumber(s:match('^[%+%-]?%d+%.?%d*'))
  if not num then return nil end
  local suf = s:match('[KMBT]$')
  local mul = 1
  if suf == 'K' then mul = 1e3 end
  if suf == 'M' then mul = 1e6 end
  if suf == 'B' then mul = 1e9 end
  if suf == 'T' then mul = 1e12 end
  return num * mul
end

local function findByPath(root, path)
  local cur = root
  for _, seg in ipairs(path) do
    if not cur then return nil end
    cur = cur:FindFirstChild(seg)
  end
  return cur
end

local function resolveHpUi()
  local t = now()
  if (t - hpUiCache.lastResolve) < 0.8 and hpUiCache.root and hpUiCache.root.Parent then
    return
  end
  hpUiCache.lastResolve = t
  hpUiCache.root, hpUiCache.fill, hpUiCache.base, hpUiCache.text = nil, nil, nil, nil
  hpUiCache.src = 'NONE'

  local pg = getPlayerGui()
  if not pg then return end

  local root
  for _, rn in ipairs(CFG.HpUiRootNames) do
    root = pg:FindFirstChild(rn, true)
    if root then break end
  end
  if not root then return end

  local fill, base
  for _, path in ipairs(CFG.HpUiFillPathCandidates) do
    local cand = findByPath(root, path)
    if cand and cand:IsA('Frame') then
      local inner = cand:FindFirstChildWhichIsA('Frame')
      if inner and inner.AbsoluteSize.X > 5 then
        fill = inner
        base = cand
      else
        fill = cand
        base = cand.Parent
      end
      break
    end
  end

  if not (fill and base and base:IsA('GuiObject')) then
    local best, bestScore = nil, -math.huge
    for _, d in ipairs(root:GetDescendants()) do
      if d:IsA('Frame') then
        local p = d.Parent
        if p and p:IsA('GuiObject') and p.AbsoluteSize.X > 30 and d.AbsoluteSize.X <= p.AbsoluteSize.X then
          local ratio = (p.AbsoluteSize.X > 0) and (d.AbsoluteSize.X / p.AbsoluteSize.X) or nil
          if ratio and ratio >= 0 and ratio <= 1.02 then
            local name = string.lower(d.Name)
            local score = 0
            if name:find('hp') then score += 50 end
            if name:find('fill') then score += 40 end
            if name:find('bar') then score += 20 end
            score += (ratio * 10)
            if score > bestScore then
              bestScore = score
              best = d
            end
          end
        end
      end
    end
    if best then
      fill = best
      base = best.Parent
    end
  end

  local hpText
  if CFG.HpUiPreferText then
    for _, d in ipairs(root:GetDescendants()) do
      if d:IsA('TextLabel') then
        local txt = d.Text or ''
        if txt:find('/') then
          hpText = d
          break
        end
      end
    end
  end

  hpUiCache.root = root
  hpUiCache.fill = fill
  hpUiCache.base = base
  hpUiCache.text = hpText
end

local function getHpPercentFromUi()
  resolveHpUi()

  local fill, base = hpUiCache.fill, hpUiCache.base
  if fill and base and fill.Parent and base.AbsoluteSize.X > 0 then
    if fill.Size.X.Scale > 0 and fill.Size.X.Scale <= 1.01 then
      hpUiCache.src = 'UI_SCALE'
      return math.clamp(fill.Size.X.Scale * 100, 0, 100)
    end

    local bw = base.AbsoluteSize.X
    local fw = fill.AbsoluteSize.X
    if bw > 0 and fw >= 0 then
      hpUiCache.src = 'UI_ABS'
      return math.clamp((fw / bw) * 100, 0, 100)
    end
  end

  local tl = hpUiCache.text
  if tl and tl.Parent then
    local txt = (tl.Text or ''):gsub('%s', '')
    local a, b = txt:match('([^/]+)/([^/]+)')
    if a and b then
      local cur = parseShortNumber(a)
      local mx = parseShortNumber(b)
      if cur and mx and mx > 0 then
        hpUiCache.src = 'UI_TEXT'
        return math.clamp((cur / mx) * 100, 0, 100)
      end
    end
  end

  return nil
end

local myHpCache = { t = 0, val = nil, src = 'NONE' }
local function getMyHpPercent()
  local t = now()
  if (t - myHpCache.t) < (CFG.HpCacheSeconds or 0.15) then
    hpUiCache.src = myHpCache.src
    return myHpCache.val
  end
  myHpCache.t = t

  local p = getHpPercentFromUi()
  if p then
    myHpCache.val = p
    myHpCache.src = hpUiCache.src or 'UI'
    return p
  end

  local c = char()
  if c then
    local hp = c:GetAttribute('HP')
    local mx = c:GetAttribute('MaxHP')
    if typeof(hp) == 'number' and typeof(mx) == 'number' and mx > 0 then
      hpUiCache.src = 'ATTR'
      myHpCache.val = (hp / mx) * 100
      myHpCache.src = 'ATTR'
      return myHpCache.val
    end

    local h = c:FindFirstChildOfClass('Humanoid')
    if h and h.MaxHealth > 0 then
      hpUiCache.src = 'HUM'
      myHpCache.val = (h.Health / h.MaxHealth) * 100
      myHpCache.src = 'HUM'
      return myHpCache.val
    end
  end

  hpUiCache.src = 'NONE'
  myHpCache.val = nil
  myHpCache.src = 'NONE'
  return nil
end

-- =========================
-- Aggro Sweep (TP qua cụm quái)
-- =========================
local function getMobPoint(m)
  local sp = m:GetAttribute('SpawnCFrame')
  if typeof(sp) == 'CFrame' then
    return sp.Position
  end
  local r = getRoot(m)
  return r and r.Position or nil
end

local function quantKey(pos, grid)
  local gx = math.floor((pos.X / grid) + 0.5)
  local gz = math.floor((pos.Z / grid) + 0.5)
  return gx .. ':' .. gz
end

local function buildSweepPoints(myPos)
  local grid = math.max(40, CFG.SweepGridSize)
  local buckets = {} -- key -> {sum=Vector3, count=int, mobs=int}

  local mobs = listMonsters()
  local r2 = CFG.Radius * CFG.Radius

  for i = 1, #mobs do
    local m = mobs[i]
    if m and m:IsA('Model') and not isBlacklisted(m) and alive(m) then
      if (not CFG.BossOnly) or isBoss(m) then
        local pos = getMobPoint(m)
        if pos then
          local dp = (myPos - pos)
          local d2 = dp:Dot(dp)
          if d2 <= r2 then
            local key = quantKey(pos, grid)
            local b = buckets[key]
            if not b then
              b = { sum = Vector3.new(0, 0, 0), count = 0, mobs = 0 }
              buckets[key] = b
            end
            b.sum = b.sum + pos
            b.count += 1
            b.mobs += 1
          end
        end
      end
    end
  end

  local clusters = {}
  for _, b in pairs(buckets) do
    if b.count > 0 then
      local center = b.sum / b.count
      local dp = (myPos - center)
      local d2 = dp:Dot(dp)
      table.insert(clusters, { pos = center, d2 = d2, mobs = b.mobs })
    end
  end

  table.sort(clusters, function(a, b)
    if a.d2 == b.d2 then
      return a.mobs > b.mobs
    end
    return a.d2 > b.d2
  end)

  local pts = {}
  local n = math.min(#clusters, math.max(1, CFG.SweepMaxPoints))
  for i = 1, n do
    local p = clusters[i].pos
    local jitter = Vector3.new((math.random() - 0.5) * 6, 0, (math.random() - 0.5) * 6)
    local tpPos = p + jitter + Vector3.new(0, CFG.SweepHeight, 0)
    table.insert(pts, CFrame.new(tpPos))
  end

  return pts
end

-- =========================
-- Feature actions (V / R / meditate)
-- =========================
local lastAttack = 0
local lastHaki = 0
local lastSwitchFruit = 0

local function doAutoHaki()
  if not CFG.AutoHakiV then return end
  if now() - lastHaki < CFG.HakiCD then return end

  local active = isUiStateActive(CFG.UiName_Haki)
  if active == true then return end

  local ok = tryActivateByName(CFG.UiName_Haki)
  if not ok then
    ok = pressKey(Enum.KeyCode.V)
  end

  if ok then
    lastHaki = now()
  end
end

local function doAutoSwitchFruit()
  if not CFG.AutoSwitchFruitR then return end
  if now() - lastSwitchFruit < CFG.SwitchFruitCD then return end

  local ok = tryActivateByName(CFG.UiName_SwitchFruit)
  if not ok then
    ok = pressKey(Enum.KeyCode.R)
  end

  if ok then
    lastSwitchFruit = now()
  end
end

local function doMeditateOn()
  local active = isUiStateActive(CFG.UiName_Meditate)
  if active == true then return end
  tryActivateByName(CFG.UiName_Meditate)
end

local function doMeditateOff()
  local active = isUiStateActive(CFG.UiName_Meditate)
  if active == false then return end
  tryActivateByName(CFG.UiName_Meditate)
end

-- =========================
-- Persistence (server DataStore)
-- =========================
local remotes = { rf = nil, re = nil }
local persistenceReady = false
local _saveToken = 0

local function findRemote()
  local rf = ReplicatedStorage:FindFirstChild(CFG.ConfigRFName)
  local re = ReplicatedStorage:FindFirstChild(CFG.ConfigREName)
  if rf and rf:IsA('RemoteFunction') and re and re:IsA('RemoteEvent') then
    remotes.rf = rf
    remotes.re = re
    persistenceReady = true
    return true
  end
  return false
end

local function u2ToTbl(u)
  return {
    xScale = u.X.Scale, xOffset = u.X.Offset,
    yScale = u.Y.Scale, yOffset = u.Y.Offset,
  }
end

local function tblToU2(t)
  if type(t) ~= 'table' then return nil end
  local xs, xo = tonumber(t.xScale), tonumber(t.xOffset)
  local ys, yo = tonumber(t.yScale), tonumber(t.yOffset)
  if not (xs and xo and ys and yo) then return nil end
  return UDim2.new(xs, xo, ys, yo)
end

local function cfToTbl(cf)
  if typeof(cf) ~= 'CFrame' then return nil end
  local p = cf.Position
  if not (p and p.Magnitude < 1e7) then return nil end
  return { x = p.X, y = p.Y, z = p.Z }
end

local function tblToCf(t)
  if type(t) ~= 'table' then return nil end
  local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
  if not (x and y and z) then return nil end
  if math.abs(x) > 1e7 or math.abs(y) > 1e7 or math.abs(z) > 1e7 then return nil end
  if y < -2000 or y > 200000 then return nil end
  return CFrame.new(x, y, z)
end

-- Whitelist config to save (NOT saving Enabled to avoid auto-start on join)
local function serializeConfig(framePos, frameVisible, minimized, dragLocked)
  local cfg = {
    BossOnly = CFG.BossOnly,
    SmoothMove = CFG.SmoothMove,
    Radius = CFG.Radius,
    FollowDist = CFG.FollowDist,
    HeightOffset = CFG.HeightOffset,

    RetargetTick = CFG.RetargetTick,
    BlacklistSeconds = CFG.BlacklistSeconds,
    TargetMaxLockSeconds = CFG.TargetMaxLockSeconds,

    AutoAttack = CFG.AutoAttack,
    AutoHakiV = CFG.AutoHakiV,
    AutoSwitchFruitR = CFG.AutoSwitchFruitR,
    AutoMeditate = CFG.AutoMeditate,

    AggroSweep = CFG.AggroSweep,
    SweepGridSize = CFG.SweepGridSize,
    SweepMaxPoints = CFG.SweepMaxPoints,
    SweepDwell = CFG.SweepDwell,
    SweepHeight = CFG.SweepHeight,
    SweepInterval = CFG.SweepInterval,

    AttackCD = CFG.AttackCD,
    HakiCD = CFG.HakiCD,
    SwitchFruitCD = CFG.SwitchFruitCD,

    AttackMode = CFG.AttackMode,
    AttackRange = CFG.AttackRange,

    HealMinPercent = CFG.HealMinPercent,
    HealMaxPercent = CFG.HealMaxPercent,

    -- optional safe spot
    SafeCFrame = cfToTbl(CFG.SafeCFrame),
  }

  local ui = {
    pos = u2ToTbl(framePos),
    visible = frameVisible and true or false,
    minimized = minimized and true or false,
    dragLocked = dragLocked and true or false,
  }

  return {
    v = 2,
    cfg = cfg,
    ui = ui,
  }
end

local function applyLoaded(data)
  if type(data) ~= 'table' then return end
  local cfg = (type(data.cfg) == 'table') and data.cfg or {}
  local ui = (type(data.ui) == 'table') and data.ui or {}

  local function setBool(k)
    if typeof(cfg[k]) == 'boolean' then CFG[k] = cfg[k] end
  end
  local function setNum(k, minv, maxv)
    if typeof(cfg[k]) == 'number' then
      local v = cfg[k]
      if minv then v = math.max(minv, v) end
      if maxv then v = math.min(maxv, v) end
      CFG[k] = v
    end
  end
  local function setStr(k)
    if typeof(cfg[k]) == 'string' then CFG[k] = cfg[k] end
  end

  setBool('BossOnly')
  setBool('SmoothMove')
  setBool('AutoAttack')
  setBool('AutoHakiV')
  setBool('AutoSwitchFruitR')
  setBool('AutoMeditate')
  setBool('AggroSweep')

  setNum('Radius', 20, 20000)
  setNum('FollowDist', 1, 60)
  setNum('HeightOffset', -50, 200)

  setNum('RetargetTick', 0.03, 2)
  setNum('BlacklistSeconds', 1, 60)
  setNum('TargetMaxLockSeconds', 5, 300)

  setNum('SweepGridSize', 40, 500)
  setNum('SweepMaxPoints', 1, 30)
  setNum('SweepDwell', 0.02, 3)
  setNum('SweepHeight', 0, 30)
  setNum('SweepInterval', 1, 180)

  setNum('AttackCD', 0, 1)
  setNum('HakiCD', 0, 60)
  setNum('SwitchFruitCD', 0, 60)

  setStr('AttackMode')
  setNum('AttackRange', 1, 200)

  setNum('HealMinPercent', 0, 99)
  setNum('HealMaxPercent', 1, 100)

  if type(cfg.SafeCFrame) == 'table' then
    local cf = tblToCf(cfg.SafeCFrame)
    if cf then CFG.SafeCFrame = cf end
  end

  return ui
end

local function scheduleSave(getUiStateFn, setSaveTextFn)
  if not persistenceReady then return end
  _saveToken += 1
  local token = _saveToken
  if setSaveTextFn then setSaveTextFn('Saving...') end
  task.delay(1.2, function()
    if token ~= _saveToken then return end
    local pos, vis, minimized, locked = getUiStateFn()
    local payload = serializeConfig(pos, vis, minimized, locked)
    safeCall('SaveConfig', function()
      remotes.re:FireServer(payload)
    end)
    if setSaveTextFn then setSaveTextFn('Saved') end
  end)
end

-- =========================
-- UI (draggable + minimize + floating toggle)
-- =========================
local gui = Instance.new('ScreenGui')
gui.Name = 'AutoFarmUI'
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild('PlayerGui')

-- Floating mini button when hidden
local floatBtn = Instance.new('TextButton')
floatBtn.Parent = gui
floatBtn.Size = UDim2.fromOffset(44, 24)
floatBtn.Position = UDim2.new(0, 10, 0, 10)
floatBtn.Text = 'AF'
floatBtn.Visible = false

local frame = Instance.new('Frame')
frame.Parent = gui
frame.Size = UDim2.fromOffset(390, 560)
frame.Position = UDim2.new(0, 16, 0.5, -280)
frame.Active = true

-- Header for dragging
local header = Instance.new('Frame')
header.Parent = frame
header.Size = UDim2.new(1, 0, 0, 32)
header.Position = UDim2.fromOffset(0, 0)

local title = Instance.new('TextLabel')
title.Parent = header
title.Size = UDim2.new(1, -160, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = 'Auto Farm'

local saveLbl = Instance.new('TextLabel')
saveLbl.Parent = header
saveLbl.Size = UDim2.fromOffset(70, 32)
saveLbl.Position = UDim2.new(1, -230, 0, 0)
saveLbl.BackgroundTransparency = 1
saveLbl.TextXAlignment = Enum.TextXAlignment.Right
saveLbl.Text = ''

local pinBtn = Instance.new('TextButton')
pinBtn.Parent = header
pinBtn.Size = UDim2.fromOffset(44, 24)
pinBtn.Position = UDim2.new(1, -152, 0, 4)
pinBtn.Text = 'PIN'

local miniBtn = Instance.new('TextButton')
miniBtn.Parent = header
miniBtn.Size = UDim2.fromOffset(44, 24)
miniBtn.Position = UDim2.new(1, -102, 0, 4)
miniBtn.Text = '-'

local closeBtn = Instance.new('TextButton')
closeBtn.Parent = header
closeBtn.Size = UDim2.fromOffset(44, 24)
closeBtn.Position = UDim2.new(1, -52, 0, 4)
closeBtn.Text = 'X'

-- Content container (for minimize)
local content = Instance.new('Frame')
content.Parent = frame
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(0, 32)
content.Size = UDim2.new(1, 0, 1, -32)

local status = Instance.new('TextLabel')
status.Parent = content
status.Size = UDim2.new(1, -20, 0, 88)
status.Position = UDim2.fromOffset(10, 4)
status.BackgroundTransparency = 1
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = 'Status: OFF'

local function mkButton(text, x, y, w, h)
  local b = Instance.new('TextButton')
  b.Parent = content
  b.Position = UDim2.fromOffset(x, y)
  b.Size = UDim2.fromOffset(w, h)
  b.Text = text
  return b
end

-- mkSlider returns { get=fn, set=fn }
local function mkSlider(labelText, y, minVal, maxVal, initial, suffix, onChange)
  local wrap = Instance.new('Frame')
  wrap.Parent = content
  wrap.Position = UDim2.fromOffset(10, y)
  wrap.Size = UDim2.fromOffset(370, 34)
  wrap.BackgroundTransparency = 1

  local lbl = Instance.new('TextLabel')
  lbl.Parent = wrap
  lbl.Position = UDim2.fromOffset(0, 0)
  lbl.Size = UDim2.fromOffset(120, 34)
  lbl.BackgroundTransparency = 1
  lbl.TextXAlignment = Enum.TextXAlignment.Left
  lbl.Text = labelText

  local bar = Instance.new('Frame')
  bar.Parent = wrap
  bar.Position = UDim2.fromOffset(125, 14)
  bar.Size = UDim2.fromOffset(190, 6)

  local knob = Instance.new('Frame')
  knob.Parent = wrap
  knob.Size = UDim2.fromOffset(12, 20)
  knob.Position = UDim2.fromOffset(125, 7)

  local valLbl = Instance.new('TextLabel')
  valLbl.Parent = wrap
  valLbl.Position = UDim2.fromOffset(320, 0)
  valLbl.Size = UDim2.fromOffset(50, 34)
  valLbl.BackgroundTransparency = 1
  valLbl.TextXAlignment = Enum.TextXAlignment.Right

  local dragging = false
  local value = math.clamp(initial, minVal, maxVal)

  local function updateUiFromValue()
    local barW = math.max(1, bar.AbsoluteSize.X)
    local t = (value - minVal) / math.max(1, (maxVal - minVal))
    knob.Position = UDim2.fromOffset(125 + math.floor(t * barW) - 6, 7)
    valLbl.Text = tostring(value) .. (suffix or '')
  end

  local function setValueFromX(x)
    local barX = bar.AbsolutePosition.X
    local barW = math.max(1, bar.AbsoluteSize.X)
    local t = math.clamp((x - barX) / barW, 0, 1)
    value = math.floor((minVal + t * (maxVal - minVal)) + 0.5)
    updateUiFromValue()
    onChange(value)
  end

  valLbl.Text = tostring(value) .. (suffix or '')

  bar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      dragging = true
      setValueFromX(input.Position.X)
    end
  end)

  knob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      dragging = true
      setValueFromX(input.Position.X)
    end
  end)

  UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
      setValueFromX(input.Position.X)
    end
  end)

  UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      dragging = false
    end
  end)

  task.delay(0.05, updateUiFromValue)

  return {
    get = function() return value end,
    set = function(v)
      if typeof(v) ~= 'number' then return end
      value = math.clamp(math.floor(v + 0.5), minVal, maxVal)
      updateUiFromValue()
      onChange(value)
    end,
  }
end

local toggleFarm = mkButton('START', 10, 96, 370, 34)
local bossOnlyBtn = mkButton('Boss only: OFF', 10, 136, 180, 28)
local smoothBtn = mkButton('Smooth: ON', 200, 136, 180, 28)

local autoAttackBtn = mkButton('Auto Attack: OFF', 10, 170, 180, 28)
local attackModeBtn = mkButton('Attack mode: TOOL', 200, 170, 180, 28)

local autoHakiBtn = mkButton('Auto Haki (V): OFF', 10, 204, 180, 28)
local autoSwitchFruitBtn = mkButton('Auto SwitchFruit (R): OFF', 200, 204, 180, 28)

local aggroSweepBtn = mkButton('Aggro Sweep: ON', 10, 238, 370, 28)

local resetBtn = mkButton('Reset settings', 10, 272, 370, 28)

local safeSetBtn = mkButton('Set Safe Spot', 10, 440, 180, 28)
local safeTpBtn = mkButton('TP Safe Now', 200, 440, 180, 28)

local autoMeditateBtn = mkButton('Auto Meditate: OFF', 10, 474, 370, 28)

local hint = Instance.new('TextLabel')
hint.Parent = content
hint.Size = UDim2.new(1, -20, 0, 22)
hint.Position = UDim2.fromOffset(10, 504)
hint.BackgroundTransparency = 1
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = 'RightShift: Hide/Show | Drag header to move'

-- Sliders
local sliderHaki = mkSlider('V cooldown', 304, 0, 60, CFG.HakiCD, 's', function(v) CFG.HakiCD = math.clamp(v, 0, 60) end)
local sliderSwitch = mkSlider('R cooldown', 338, 0, 60, CFG.SwitchFruitCD, 's', function(v) CFG.SwitchFruitCD = math.clamp(v, 0, 60) end)
local sliderAtk = mkSlider('Attack delay', 372, 0, 20, math.floor(CFG.AttackCD * 20 + 0.5), 't', function(v) CFG.AttackCD = math.clamp(v / 20, 0, 1) end)
local sliderHealMin = mkSlider('Heal MIN', 406, 0, 99, CFG.HealMinPercent, '%', function(v)
  CFG.HealMinPercent = math.clamp(v, 0, 99)
  if CFG.HealMinPercent >= CFG.HealMaxPercent then
    CFG.HealMaxPercent = math.clamp(CFG.HealMinPercent + 1, 1, 100)
  end
end)
local sliderHealMax = mkSlider('Heal MAX', 440, 1, 100, CFG.HealMaxPercent, '%', function(v)
  CFG.HealMaxPercent = math.clamp(v, 1, 100)
  if CFG.HealMaxPercent <= CFG.HealMinPercent then
    CFG.HealMinPercent = math.clamp(CFG.HealMaxPercent - 1, 0, 99)
  end
end)

-- =========================
-- UI state + drag
-- =========================
local minimized = false
local dragLocked = false
local normalSize = frame.Size
local minimizedSize = UDim2.fromOffset(390, 32)

local function setSaveText(t)
  saveLbl.Text = t or ''
end

local function getUiState()
  return frame.Position, frame.Visible, minimized, dragLocked
end

local function requestSave()
  scheduleSave(getUiState, setSaveText)
end

local function applyMinimize(on)
  minimized = on and true or false
  if minimized then
    content.Visible = false
    frame.Size = minimizedSize
    miniBtn.Text = '+'
  else
    content.Visible = true
    frame.Size = normalSize
    miniBtn.Text = '-'
  end
end

-- Dragging header
local dragging = false
local dragStartPos
local frameStartPos
local dragInput

local function updateDrag(input)
  if not dragging then return end
  local delta = input.Position - dragStartPos
  frame.Position = UDim2.new(
    frameStartPos.X.Scale,
    frameStartPos.X.Offset + delta.X,
    frameStartPos.Y.Scale,
    frameStartPos.Y.Offset + delta.Y
  )
end

header.InputBegan:Connect(function(input)
  if dragLocked then return end
  if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    dragging = true
    dragStartPos = input.Position
    frameStartPos = frame.Position
    dragInput = input
    input.Changed:Connect(function()
      if input.UserInputState == Enum.UserInputState.End then
        dragging = false
        dragInput = nil
        requestSave()
      end
    end)
  end
end)

header.InputChanged:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    dragInput = input
  end
end)

UIS.InputChanged:Connect(function(input)
  if input == dragInput and dragging then
    updateDrag(input)
  end
end)

-- =========================
-- Button text refresh
-- =========================
local function refreshButtons()
  toggleFarm.Text = CFG.Enabled and 'STOP' or 'START'
  bossOnlyBtn.Text = 'Boss only: ' .. (CFG.BossOnly and 'ON' or 'OFF')
  smoothBtn.Text = 'Smooth: ' .. (CFG.SmoothMove and 'ON' or 'OFF')
  autoAttackBtn.Text = 'Auto Attack: ' .. (CFG.AutoAttack and 'ON' or 'OFF')
  attackModeBtn.Text = 'Attack mode: ' .. tostring(CFG.AttackMode)
  autoHakiBtn.Text = 'Auto Haki (V): ' .. (CFG.AutoHakiV and 'ON' or 'OFF')
  autoSwitchFruitBtn.Text = 'Auto SwitchFruit (R): ' .. (CFG.AutoSwitchFruitR and 'ON' or 'OFF')
  aggroSweepBtn.Text = 'Aggro Sweep: ' .. (CFG.AggroSweep and 'ON' or 'OFF')
  autoMeditateBtn.Text = 'Auto Meditate: ' .. (CFG.AutoMeditate and 'ON' or 'OFF')
  pinBtn.Text = dragLocked and 'PIN*' or 'PIN'
end

-- =========================
-- UI events
-- =========================
closeBtn.MouseButton1Click:Connect(function()
  frame.Visible = false
  floatBtn.Visible = true
  requestSave()
end)

floatBtn.MouseButton1Click:Connect(function()
  frame.Visible = true
  floatBtn.Visible = false
  requestSave()
end)

miniBtn.MouseButton1Click:Connect(function()
  applyMinimize(not minimized)
  requestSave()
end)

pinBtn.MouseButton1Click:Connect(function()
  dragLocked = not dragLocked
  refreshButtons()
  requestSave()
end)

UIS.InputBegan:Connect(function(i, gp)
  if gp then return end
  if i.KeyCode == Enum.KeyCode.RightShift then
    frame.Visible = not frame.Visible
    floatBtn.Visible = not frame.Visible
    requestSave()
  end
end)

toggleFarm.MouseButton1Click:Connect(function()
  CFG.Enabled = not CFG.Enabled
  refreshButtons()
  -- Do NOT persist Enabled; but still save UI state (so it remembers hidden/minimize)
  requestSave()
end)

bossOnlyBtn.MouseButton1Click:Connect(function()
  CFG.BossOnly = not CFG.BossOnly
  refreshButtons()
  requestSave()
end)

smoothBtn.MouseButton1Click:Connect(function()
  CFG.SmoothMove = not CFG.SmoothMove
  refreshButtons()
  requestSave()
end)

autoAttackBtn.MouseButton1Click:Connect(function()
  CFG.AutoAttack = not CFG.AutoAttack
  refreshButtons()
  requestSave()
end)

attackModeBtn.MouseButton1Click:Connect(function()
  local modes = { 'TOOL', 'REMOTE', 'UI' }
  local idx = table.find(modes, CFG.AttackMode) or 1
  idx += 1
  if idx > #modes then idx = 1 end
  CFG.AttackMode = modes[idx]
  refreshButtons()
  requestSave()
end)

autoHakiBtn.MouseButton1Click:Connect(function()
  CFG.AutoHakiV = not CFG.AutoHakiV
  refreshButtons()
  requestSave()
end)

autoSwitchFruitBtn.MouseButton1Click:Connect(function()
  CFG.AutoSwitchFruitR = not CFG.AutoSwitchFruitR
  refreshButtons()
  requestSave()
end)

aggroSweepBtn.MouseButton1Click:Connect(function()
  CFG.AggroSweep = not CFG.AggroSweep
  refreshButtons()
  requestSave()
end)

safeSetBtn.MouseButton1Click:Connect(function()
  local my = hrp()
  if not my then return end
  CFG.SafeCFrame = my.CFrame + Vector3.new(0, 3, 0)
  requestSave()
end)

safeTpBtn.MouseButton1Click:Connect(function()
  tpToSafe()
end)

autoMeditateBtn.MouseButton1Click:Connect(function()
  CFG.AutoMeditate = not CFG.AutoMeditate
  refreshButtons()

  if CFG.AutoMeditate and typeof(CFG.SafeCFrame) ~= 'CFrame' then
    local my = hrp()
    if my then
      CFG.SafeCFrame = my.CFrame + Vector3.new(0, 3, 0)
    end
  end
  requestSave()
end)

local DEFAULTS = table.clone(CFG)
resetBtn.MouseButton1Click:Connect(function()
  -- restore only user-facing settings (not remotes, perf fields)
  CFG.BossOnly = DEFAULTS.BossOnly
  CFG.SmoothMove = DEFAULTS.SmoothMove
  CFG.Radius = DEFAULTS.Radius
  CFG.FollowDist = DEFAULTS.FollowDist
  CFG.HeightOffset = DEFAULTS.HeightOffset

  CFG.AutoAttack = DEFAULTS.AutoAttack
  CFG.AutoHakiV = DEFAULTS.AutoHakiV
  CFG.AutoSwitchFruitR = DEFAULTS.AutoSwitchFruitR
  CFG.AutoMeditate = DEFAULTS.AutoMeditate
  CFG.AggroSweep = DEFAULTS.AggroSweep

  CFG.AttackCD = DEFAULTS.AttackCD
  CFG.HakiCD = DEFAULTS.HakiCD
  CFG.SwitchFruitCD = DEFAULTS.SwitchFruitCD
  CFG.AttackMode = DEFAULTS.AttackMode
  CFG.AttackRange = DEFAULTS.AttackRange

  CFG.HealMinPercent = DEFAULTS.HealMinPercent
  CFG.HealMaxPercent = DEFAULTS.HealMaxPercent

  sliderHaki.set(CFG.HakiCD)
  sliderSwitch.set(CFG.SwitchFruitCD)
  sliderAtk.set(math.floor(CFG.AttackCD * 20 + 0.5))
  sliderHealMin.set(CFG.HealMinPercent)
  sliderHealMax.set(CFG.HealMaxPercent)

  refreshButtons()
  requestSave()
end)

-- Any slider change should trigger save (debounced)
local function hookSliderSave()
  -- We already call onChange inside mkSlider.setValueFromX().
  -- We'll just call requestSave at a safe cadence (debounced by scheduleSave).
  requestSave()
end

-- Patch: call hookSliderSave on InputEnded for overall slider area
for _, sliderWrap in ipairs(content:GetChildren()) do
  if sliderWrap:IsA('Frame') then
    sliderWrap.InputEnded:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        hookSliderSave()
      end
    end)
  end
end

-- =========================
-- Load persisted config (if server remotes exist)
-- =========================
task.spawn(function()
  local deadline = now() + 6
  while now() < deadline do
    if findRemote() then break end
    task.wait(0.25)
  end
  if not persistenceReady then
    if CFG.DebugLog then
      warnThrottled('NoPersistence', '[AutoFarmUI] Persistence remotes not found. Add server script AutoFarm_ConfigServer.lua', 10)
    end
    refreshButtons()
    return
  end

  local ok, data = safeCall('LoadConfig', function()
    return remotes.rf:InvokeServer()
  end)

  if ok and type(data) == 'table' then
    local ui = applyLoaded(data) or {}
    -- Apply UI state
    local pos = tblToU2(ui.pos)
    if pos then frame.Position = pos end
    local vis = (ui.visible ~= false)
    frame.Visible = vis
    floatBtn.Visible = not vis

    dragLocked = (ui.dragLocked == true)
    applyMinimize(ui.minimized == true)

    -- Sync sliders to loaded values
    sliderHaki.set(CFG.HakiCD)
    sliderSwitch.set(CFG.SwitchFruitCD)
    sliderAtk.set(math.floor(CFG.AttackCD * 20 + 0.5))
    sliderHealMin.set(CFG.HealMinPercent)
    sliderHealMax.set(CFG.HealMaxPercent)
  end

  refreshButtons()
  setSaveText('Loaded')
  task.delay(1.5, function() setSaveText('') end)
end)

-- =========================
-- Target tracking (anti stuck)
-- =========================
local currentTarget = nil
local targetConns = {}
local targetLockedAt = 0
local forceRetarget = false

local function disconnectTargetConns()
  for _, c in ipairs(targetConns) do
    safeCall('Disconnect', function()
      c:Disconnect()
    end)
  end
  table.clear(targetConns)
end

local function clearTarget()
  if currentTarget then addBlacklist(currentTarget) end
  currentTarget = nil
  targetLockedAt = 0
  forceRetarget = true
  disconnectTargetConns()
end

local function watchTarget(m)
  disconnectTargetConns()
  if not m then return end
  targetLockedAt = now()

  local h = getHum(m)
  if h then
    table.insert(targetConns, h.Died:Connect(function()
      clearTarget()
    end))
    table.insert(targetConns, h.HealthChanged:Connect(function(hp)
      if hp <= 0 then clearTarget() end
    end))
  end

  table.insert(targetConns, m.AncestryChanged:Connect(function(_, parent)
    if not parent or not m:IsDescendantOf(Workspace) then
      clearTarget()
    end
  end))

  table.insert(targetConns, m:GetAttributeChangedSignal(CFG.HPAttrName):Connect(function()
    local hp = m:GetAttribute(CFG.HPAttrName)
    if typeof(hp) == 'number' and hp <= 0 then
      clearTarget()
    end
  end))

  table.insert(targetConns, m:GetAttributeChangedSignal(CFG.StateAttrName):Connect(function()
    if stateIsDead(m) then clearTarget() end
  end))
end

local function setTarget(m)
  if m == currentTarget then return end
  currentTarget = m
  if currentTarget then
    watchTarget(currentTarget)
  end
end

-- =========================
-- Main loop: HEAL / FARM + (SWEEP/FIGHT)
-- =========================
local mode = 'FARM' -- FARM | HEAL
local phase = 'SWEEP' -- SWEEP | FIGHT

local retargetAcc = 0
local safeHoldAcc = 0

local sweepPlan = {}
local sweepIndex = 0
local sweepNextAt = 0
local nextSweepAllowedAt = 0

local function startSweep(myPos)
  if not CFG.AggroSweep then
    phase = 'FIGHT'
    return
  end
  if now() < nextSweepAllowedAt then
    phase = 'FIGHT'
    return
  end

  sweepPlan = buildSweepPoints(myPos)
  sweepIndex = 1
  sweepNextAt = 0
  phase = (#sweepPlan > 0) and 'SWEEP' or 'FIGHT'
end

local function runSweep()
  if phase ~= 'SWEEP' then return end
  if sweepIndex <= 0 or sweepIndex > #sweepPlan then
    phase = 'FIGHT'
    nextSweepAllowedAt = now() + CFG.SweepInterval
    return
  end
  if now() < sweepNextAt then return end

  tpToCFrame(sweepPlan[sweepIndex])
  sweepIndex += 1
  sweepNextAt = now() + math.max(0.02, CFG.SweepDwell)
end

-- Status update throttle
local _lastStatusText = ''
local _statusNextAt = 0
local function setStatus(text)
  local t = now()
  local interval = 1 / math.max(1, (CFG.UiStatusHz or 10))
  if (t < _statusNextAt) and (text == _lastStatusText) then return end
  _statusNextAt = t + interval
  if text ~= _lastStatusText then
    status.Text = text
    _lastStatusText = text
  end
end

-- Slider sampling throttle (no need every frame)
local _sliderNextAt = 0
local function sampleSliders()
  local t = now()
  local interval = 1 / math.max(1, (CFG.SliderHz or 10))
  if t < _sliderNextAt then return end
  _sliderNextAt = t + interval

  CFG.HakiCD = sliderHaki.get()
  CFG.SwitchFruitCD = sliderSwitch.get()
  sliderAtk.get() -- updates AttackCD via onChange already
  CFG.HealMinPercent = sliderHealMin.get()
  CFG.HealMaxPercent = sliderHealMax.get()
end

RunService.Heartbeat:Connect(function(dt)
  sampleSliders()

  if not CFG.Enabled then
    if currentTarget then clearTarget() end
    mode = 'FARM'
    phase = 'SWEEP'
    setStatus('Status: OFF | Target: -')
    return
  end

  local myHrp = hrp()
  if not myHrp then
    if currentTarget then clearTarget() end
    setStatus('Status: ON | Target: -')
    return
  end

  local myHpP = getMyHpPercent()
  local myHpText = myHpP and tostring(math.floor(myHpP + 0.5)) or '-'
  local safeText = (typeof(CFG.SafeCFrame) == 'CFrame') and 'SET' or '-'
  local hpSrc = hpUiCache.src or 'NONE'

  -- HEAL gating
  if CFG.AutoMeditate and myHpP then
    if mode == 'FARM' and myHpP <= CFG.HealMinPercent then
      mode = 'HEAL'
      phase = 'SWEEP'
      clearTarget()
      if typeof(CFG.SafeCFrame) ~= 'CFrame' then
        CFG.SafeCFrame = myHrp.CFrame + Vector3.new(0, 3, 0)
        safeText = 'SET'
      end
      tpToSafe()
    elseif mode == 'HEAL' and myHpP >= CFG.HealMaxPercent then
      mode = 'FARM'
      doMeditateOff()
      startSweep(myHrp.Position)
    end
  else
    mode = 'FARM'
  end

  if mode == 'HEAL' then
    safeHoldAcc += dt
    if safeHoldAcc >= 0.25 then
      safeHoldAcc = 0
      tpToSafe()
    end
    doMeditateOn()
    setStatus(('Status: ON | Mode: HEAL | MyHP: %s%% (%s) | Safe: %s'):format(myHpText, hpSrc, safeText))
    return
  end

  safeHoldAcc = 0

  -- Buffs
  doAutoHaki()
  doAutoSwitchFruit()

  -- Drop dead target
  if currentTarget then
    local thp = getNPC_HP(currentTarget)
    if (typeof(thp) == 'number' and thp <= 0) or (not alive(currentTarget)) then
      clearTarget()
    end
  end

  if currentTarget and targetLockedAt > 0 and (now() - targetLockedAt) >= CFG.TargetMaxLockSeconds then
    clearTarget()
  end

  -- SWEEP phase
  if phase == 'SWEEP' and (not sweepPlan or #sweepPlan == 0) then
    startSweep(myHrp.Position)
  end

  if phase == 'SWEEP' then
    runSweep()
    setStatus(('Status: ON | Mode: FARM | Phase: SWEEP (%d/%d) | MyHP: %s%% (%s) | Safe: %s'):format(
      math.min(sweepIndex, #sweepPlan),
      #sweepPlan,
      myHpText,
      hpSrc,
      safeText
    ))
    return
  end

  -- FIGHT phase
  retargetAcc += dt
  if forceRetarget or retargetAcc >= CFG.RetargetTick then
    forceRetarget = false
    retargetAcc = 0

    if not currentTarget then
      setTarget(bestTarget(myHrp))
      if not currentTarget then
        startSweep(myHrp.Position)
      end
    end
  end

  if currentTarget and alive(currentTarget) then
    moveBehind(myHrp, currentTarget, dt)

    if CFG.AutoAttack and (now() - lastAttack) >= CFG.AttackCD then
      local tr = getRoot(currentTarget)
      if tr then
        local dp = (myHrp.Position - tr.Position)
        local d2 = dp:Dot(dp)
        local ar2 = CFG.AttackRange * CFG.AttackRange
        if d2 <= ar2 then
          if doAttack(currentTarget) then
            lastAttack = now()
          end
        end
      end
    end

    local thp = getNPC_HP(currentTarget)
    local thpText = (typeof(thp) == 'number') and tostring(math.floor(thp)) or '?'
    setStatus(('Status: ON | Mode: FARM | Phase: FIGHT | Target: %s | THP: %s | MyHP: %s%% (%s) | Safe: %s'):format(
      currentTarget.Name,
      thpText,
      myHpText,
      hpSrc,
      safeText
    ))
  else
    setStatus(('Status: ON | Mode: FARM | Phase: FIGHT | Target: - | MyHP: %s%% (%s) | Safe: %s'):format(myHpText, hpSrc, safeText))
  end
end)
