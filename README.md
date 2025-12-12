# 🎮 ToRungHub - Anime Fruit Farm Modular System

**Production-ready Roblox script for Anime Fruit game automation**

## 📥 Installation

Simply copy this one-liner into your Roblox executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/torung1404/ToRungHub/main/loader.lua"))();
```

## 🎯 Features

- ✅ **Auto Farm** - Hunt monsters automatically
- ✅ **Auto Boss** - Priority boss detection & hunting
- ✅ **Auto Skills** - Cycle through skills (1-4) + fruit swap (R)
- ✅ **Auto Chest** - Collect regular chests
- ✅ **Auto Christmas Chest** - Detect & collect holiday chests
- ✅ **Auto Dungeon** - Farm inside dungeons (configurable)
- ✅ **Auto Mugen** - Farm Mugen areas (configurable)
- ✅ **Server Hop** - Auto-hop if no boss found
- ✅ **Live Stats** - Real-time kill counter & session timer
- ✅ **Smooth Movement** - No lag teleportation
- ✅ **Anti-Detection** - Jittered delays & natural behavior

## 🎮 Controls

| Key | Action |
|-----|--------|
| **J** | Toggle farm ON/OFF |
| **Click Buttons** | Enable/disable individual features |

## ⚙️ Configuration

Edit `config.lua` to customize:

### Monster & Boss Lists
```lua
CONFIG.monsters = { "monster0101", "monster0102", ... }
CONFIG.bosses = { "boss0101", "boss0102", ... }
```

### Timing (Anti-Ban Balance)
```lua
CONFIG.timing = {
  attackSpeed = 0.12,    -- Time between attacks (lower = faster, risky)
  moveDelay = 0.10,      -- Movement detection interval
  skillDelay = 0.35,     -- Time between skill casts
  chestDelay = 0.30,     -- Chest interaction delay
}
```

### Movement Speed
```lua
CONFIG.movement = {
  tweenSpeed = 80,       -- Faster = 100-150, Slower = 30-60
  maxTargetRange = 1200, -- Detection radius
}
```

### Features Toggle
```lua
CONFIG.features = {
  autoFarm = true,
  autoBoss = true,
  autoSkill = true,
  autoChest = false,
  autoXmasChest = true,
  autoHop = false,
}
```

## 📁 File Structure

```
loader.lua      → Entry point, loads all modules
config.lua      → All configuration settings
utils.lua       → Movement, detection, attacks
ui.lua          → Interface & button system
main.lua        → Core farming loops & logic
webhook.lua     → Future Discord logging
```

## 🚀 Quick Start

1. Paste loader into executor
2. Script loads all modules from GitHub
3. Click buttons to enable features
4. Press **J** to start farming
5. Watch stats update in real-time

## 🛡️ Anti-Detection

- ✅ Jittered delays (±15% variance)
- ✅ Random movement offsets
- ✅ Natural timing between actions
- ✅ No instant teleport spam
- ✅ Smooth tween movements
- ✅ Humanized clicking patterns

## ⚠️ Disclaimer

This script is for educational purposes. Using automation scripts on Roblox may violate Terms of Service. Use at your own risk.

## 📞 Support

For issues or improvements, create a GitHub issue or pull request.

---

**Made with ❤️ by ToRung Team**
