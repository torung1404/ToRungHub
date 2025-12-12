--// File: StarterPlayerScripts/ToRungHub/Client/Init.client.lua
--!strict
local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)
local UI = require(script.Parent.UI)
local Controller = require(script.Parent.Controller)
local Net = require(game.ReplicatedStorage.ToRungHub.Shared.Net)
local Logger = require(game.ReplicatedStorage.ToRungHub.Shared.Logger)

local log = Logger.new("ClientInit", Config.DebugLevel)
local ClientCommand = Net.getOrCreateRemoteEvent(Net.RemoteNames.ClientCommand)

local uiInstance = UI.new({
	onToggle = function(key, value)
		ClientCommand:FireServer({ type = "toggle", key = key, value = value })
	end,
	onOption = function(key, value)
		ClientCommand:FireServer({ type = "option", key = key, value = value })
	end,
	onAction = function(key, value)
		ClientCommand:FireServer({ type = "action", key = key, value = value })
	end,
})

local controllerInstance = Controller.new()

log:info("ToRungHub client initialized.")
