--// File: ServerScriptService/ToRungHub/Server/LootAdapter.lua
--!strict
local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)

local LootAdapter = {}
LootAdapter.__index = LootAdapter

function LootAdapter.new()
	return setmetatable({}, LootAdapter)
end

local function cooldownKey(inst: Instance): string
	return "ToRungHub_LastLooted"
end

function LootAdapter:canLoot(chest: Instance): boolean
	if not chest.Parent then return false end
	local last = chest:GetAttribute(cooldownKey(chest))
	if typeof(last) == "number" then
		return (os.clock() - last) >= Config.Chest.CooldownSeconds
	end
	return true
end

function LootAdapter:loot(player: Player, chest: Instance): boolean
	if not self:canLoot(chest) then return false end
	chest:SetAttribute(cooldownKey(chest), os.clock())
	return true
end

return LootAdapter
