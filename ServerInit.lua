--// File: ServerScriptService/ToRungHub/Server/Init.server.lua
--!strict
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)
local Net = require(game.ReplicatedStorage.ToRungHub.Shared.Net)
local Logger = require(game.ReplicatedStorage.ToRungHub.Shared.Logger)

local WorldIndex = require(script.Parent.WorldIndex)
local CombatAdapter = require(script.Parent.CombatAdapter)
local LootAdapter = require(script.Parent.LootAdapter)
local HopService = require(script.Parent.HopService)
local AutomationFSM = require(script.Parent.AutomationFSM)

local log = Logger.new("ServerInit", Config.DebugLevel)

local ClientCommand = Net.getOrCreateRemoteEvent(Net.RemoteNames.ClientCommand)
local StateUpdate = Net.getOrCreateRemoteEvent(Net.RemoteNames.StateUpdate)
local QuerySnapshot = Net.getOrCreateRemoteFunction(Net.RemoteNames.QuerySnapshot)

local world = WorldIndex.new()
local combat = CombatAdapter.new()
local loot = LootAdapter.new()
local hop = HopService.new()

local sessions: {[Player]: any} = {}

local function getSession(p: Player)
	return sessions[p]
end

Players.PlayerAdded:Connect(function(player)
	log:info("PlayerAdded " .. player.Name)
	local fsm = AutomationFSM.new(player, world, combat, loot, hop, StateUpdate)
	sessions[player] = fsm

	player.CharacterRemoving:Connect(function()
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	log:info("PlayerRemoving " .. player.Name)
	local fsm = sessions[player]
	if fsm then
		fsm:destroy()
		sessions[player] = nil
	end
end)

ClientCommand.OnServerEvent:Connect(function(player, payload)
	local fsm = getSession(player)
	if not fsm then return end
	if typeof(payload) ~= "table" then return end

	if payload.type == "toggle" then
		if payload.key == "enabled" then
			fsm:setEnabled(payload.value == true)
		else
			fsm:setOption(payload.key, payload.value)
		end
	elseif payload.type == "option" then
		fsm:setOption(payload.key, payload.value)
	elseif payload.type == "action" then
		if payload.key == "toggleHaki" then
			local on = payload.value == true
			combat:toggleHaki(player, on)
		elseif payload.key == "manualMedi" then
			combat:useMedi(player)
		elseif payload.key == "stopMedi" then
			combat:stopMedi(player)
		elseif payload.key == "hop" then
			hop:hopPlayer(player)
		end
	end
end)

QuerySnapshot.OnServerInvoke = function(player)
	local fsm = getSession(player)
	if not fsm then return nil end
	return {
		state = fsm.state,
		kills = fsm.kills,
		target = fsm.target and fsm.target.Name or nil,
		jobId = game.JobId,
		placeId = game.PlaceId,
	}
end

log:info("ToRungHub server initialized.")
