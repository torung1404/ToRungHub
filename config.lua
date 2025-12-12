-- ========================================================
-- file: config.lua
-- ========================================================
local CONFIG = {}

-- Monsters & bosses list (customize as needed)
CONFIG.monsters = {
  "monster0101",
  "monster0102",
  "monster0104",
  "monster0604",
  "monster0705",
  "monster0801",
  "monster0806",
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

-- Chest names to detect
CONFIG.chestNames = {
  "ChestPoint",
  "Chest",
  "Chest1",
  "Chest2",
  "ChestZone",
  "ChristmasChestZone",
}

-- Timing configuration (in seconds)
CONFIG.timing = {
  attackSpeed = 0.12,
  moveDelay = 0.10,
  skillDelay = 0.35,
  chestDelay = 0.30,
  scanDelay = 0.40,
  hopCheckDelay = 5.0,
}

-- Movement configuration
CONFIG.movement = {
  aboveOffsetY = 7,
  tweenSpeed = 80,
  minTweenTime = 0.15,
  maxTargetRange = 1200,
}

-- Feature toggles
CONFIG.features = {
  autoFarm = true,
  autoBoss = true,
  autoSkill = true,
  autoChest = false,
  autoXmasChest = true,
  autoDungeon = false,
  autoMugen = false,
  autoHop = false,
}

-- Hotkeys
CONFIG.hotkeys = {
  masterToggle = Enum.KeyCode.J,
}

-- Skill & action keys
CONFIG.keys = {
  skills = {
    Enum.KeyCode.One,
    Enum.KeyCode.Two,
    Enum.KeyCode.Three,
    Enum.KeyCode.Four,
  },
  fruitSwap = Enum.KeyCode.R,
}

-- Hop configuration
CONFIG.hop = {
  enableBossHop = true,
  noBossSeconds = 60,
  notifyInConsole = true,
}

-- Christmas chest configuration
CONFIG.xmasChest = {
  hopIfMissing = true,
  hopTimeout = 10,
}

-- Dungeon configuration
CONFIG.dungeon = {
  enabled = false,
  pathKeyword = "Dungeon",
  monsterKeywords = {},
  bossKeywords = {},
}

-- Mugen configuration
CONFIG.mugen = {
  enabled = false,
  pathKeyword = "Mugen",
  monsterKeywords = {},
  bossKeywords = {},
}

-- Stats display
CONFIG.stats = {
  enabled = true,
}

-- Clamp values for safety
do
  local t = CONFIG.timing
  t.attackSpeed = math.clamp(t.attackSpeed or 0.12, 0.05, 1.0)
  t.moveDelay = math.clamp(t.moveDelay or 0.10, 0.03, 1.0)
  t.skillDelay = math.clamp(t.skillDelay or 0.35, 0.05, 2.0)
  t.chestDelay = math.clamp(t.chestDelay or 0.30, 0.05, 2.0)
  t.scanDelay = math.clamp(t.scanDelay or 0.40, 0.05, 2.0)
  t.hopCheckDelay = math.clamp(t.hopCheckDelay or 5.0, 1.0, 60.0)

  local m = CONFIG.movement
  m.aboveOffsetY = math.clamp(m.aboveOffsetY or 7, 4, 20)
  m.tweenSpeed = math.clamp(m.tweenSpeed or 80, 30, 150)
  m.minTweenTime = math.clamp(m.minTweenTime or 0.15, 0.05, 1.0)
  m.maxTargetRange = math.clamp(m.maxTargetRange or 1200, 100, 3000)
end

return CONFIG
