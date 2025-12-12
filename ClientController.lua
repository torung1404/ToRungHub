--// File: StarterPlayerScripts/ToRungHub/Client/Controller.lua
--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)
local Net = require(game.ReplicatedStorage.ToRungHub.Shared.Net)
local Logger = require(game.ReplicatedStorage.ToRungHub.Shared.Logger)

local log = Logger.new("ClientController", Config.DebugLevel)

local ClientCommand = Net.getOrCreateRemoteEvent(Net.RemoteNames.ClientCommand)
local StateUpdate = Net.getOrCreateRemoteEvent(Net.RemoteNames.StateUpdate)
local QuerySnapshot = Net.getOrCreateRemoteFunction(Net.RemoteNames.QuerySnapshot)

local Controller = {}
Controller.__index = Controller

function Controller.new()
	local self = setmetatable({}, Controller)
	self.lastSnap = nil
	self:_bind()
	return self
end

function Controller:_bind()
	StateUpdate.OnClientEvent:Connect(function(snap)
		self.lastSnap = snap
		log:debug(("State: %s, Kills: %d"):format(snap.state, snap.kills))
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.J then
			local snap = QuerySnapshot:InvokeServer()
			if snap then
				log:info(("Toggle FSM. Current state: %s"):format(snap.state))
				ClientCommand:FireServer({ type = "toggle", key = "enabled", value = snap.state == "Idle" })
			end
		end
	end)
end

return Controller
