local Defaults = {
	AutoStart = true,

	-- Timers requested
	HakiDelaySeconds = 20,
	FruitIntervalSeconds = 8,

	-- Core farm
	Enabled = true,
	BossOnly = false,

	-- Targeting
	Radius = 300,
	AttackRange = 24,
	AttackCooldownSeconds = 0.18,
	RetargetTickSeconds = 0.20,
	MoveTickSeconds = 0.30,

	-- Monster discovery
	MonsterFolderNames = { "Monsters", "NPC" },
	BossTagAttribute = "IsBoss", -- set mob:SetAttribute("IsBoss", true) for bosses

	-- Mob HP detection (supports both Humanoid and custom attribute HP)
	HPAttributeName = "HP",

	-- Damage model (fallback if you don't have your own combat system wired)
	BaseDamagePerHit = 8,
	HakiDamageMultiplier = 1.35,

	-- Fruit rotation (example)
	Fruits = { "FruitA", "FruitB", "FruitC" },
}
