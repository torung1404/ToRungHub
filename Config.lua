--!strict
local Config = {}

Config.DebugLevel = "INFO" -- "ERROR" | "WARN" | "INFO" | "DEBUG"

Config.Tags = {
	Boss = "Boss",
	Mob = "Mob",
	Chest = "Chest",
}

Config.Folders = {
	Monsters = "Monsters", -- Workspace.Monsters (fallback)
	ChestRoot = "Chest",   -- Workspace.Chest (fallback)
	ChristmasChestZone = "ChristmasChestZone", -- Workspace.ChristmasChestZone (optional)
}

Config.Scan = {
	ScanInterval = 1.0,       -- seconds
	InitialScanBatch = 400,   -- descendants per yield
}

Config.Movement = {
	Mode = "TP", -- "TP" | "Walk"
	HeightOffset = 6.0,
	CombatHoldDistance = 2.0,
	RepositionJitter = 3.0,
	StuckSeconds = 2.0,
	StuckMinMove = 0.75,
}

Config.Combat = {
	AttackInterval = 0.18,
	SkillInterval = 0.55,
	UseSkills = true,
	SkillSlots = { 1, 2, 3, 4 },
	BaseDamage = 15,
	SkillDamageMultiplier = 2.2,
}

Config.Chest = {
	Enabled = true,
	Mode = "TP_Loot", -- "TP_Loot" | "Walk_Loot" | "HighlightOnly"
	MaxDistance = 999999, -- scan toàn map, filter sau
	CooldownSeconds = 2.0,
	NoChestHopSeconds = 10.0,
	NameContains = { "chest", "christmas" },
}

Config.Boss = {
	Enabled = true,
	PriorityList = { -- optional: pattern ưu tiên
		"boss0803",
		"boss0802",
		"boss0801",
		"boss0703",
		"boss0702",
		"boss0701",
	},
}

Config.Hop = {
	Enabled = false,
	TTLMinutes = 20,
	MaxRecent = 24,
	BackoffSeconds = { 1, 2, 4, 8 },
	MinPlayers = 1,
	MaxPlayers = 40,
}

Config.QoL = {
	HakiFeatureName = "Haki",
	AutoMediEnabled = true,
	HPThresholdPercent = 35,
	RecoveryHysteresis = 10, -- +10% so với threshold mới thoát medi
	MediCooldownSeconds = 8.0,
}

Config.UI = {
	Theme = {
		Bg = Color3.fromRGB(16, 18, 28),
		Panel = Color3.fromRGB(22, 25, 40),
		Stroke = Color3.fromRGB(60, 70, 120),
		Text = Color3.fromRGB(230, 235, 255),
		Muted = Color3.fromRGB(150, 160, 210),
		Accent = Color3.fromRGB(110, 170, 255),
		Good = Color3.fromRGB(80, 220, 160),
		Bad = Color3.fromRGB(255, 120, 120),
	},
	DefaultOpacity = 0.95,
}

return Config