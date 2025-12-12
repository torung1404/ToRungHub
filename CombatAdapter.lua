--// File: ServerScriptService/ToRungHub/Server/CombatAdapter.lua
--!strict
local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)
local Util = require(game.ReplicatedStorage.ToRungHub.Shared.Util)

local CombatAdapter = {}
CombatAdapter.__index = CombatAdapter

function CombatAdapter.new()
	return setmetatable({}, CombatAdapter)
end

function CombatAdapter:isValidTarget(target: Model): boolean
	if not target.Parent then return false end
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	return hum.Health > 0
end

function CombatAdapter:attack(player: Player, target: Model)
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum:TakeDamage(Config.Combat.BaseDamage)
end

function CombatAdapter:useSkill(player: Player, slot: number, target: Model)
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum:TakeDamage(Config.Combat.BaseDamage * Config.Combat.SkillDamageMultiplier)
end

function CombatAdapter:toggleHaki(player: Player, enabled: boolean)
	player:SetAttribute(Config.QoL.HakiFeatureName .. "_Enabled", enabled)
end

function CombatAdapter:useMedi(player: Player)
	player:SetAttribute("IsMedi", true)
end

function CombatAdapter:stopMedi(player: Player)
	player:SetAttribute("IsMedi", false)
end

return CombatAdapter
