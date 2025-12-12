--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FolderName = "ToRungHub"
Net.RemotesFolderName = "Remotes"

Net.RemoteNames = {
	ClientCommand = "ClientCommand",   -- RemoteEvent: client -> server (toggle/options/actions)
	StateUpdate = "StateUpdate",       -- RemoteEvent: server -> client (state snapshot)
	QuerySnapshot = "QuerySnapshot",   -- RemoteFunction: client -> server (pull snapshot)
}

export type ClientCommandPayload = {
	type: "toggle" | "option" | "action",
	key: string,
	value: any?,
}

function Net.getOrCreateRoot(): Folder
	local root = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if root and root:IsA("Folder") then return root end
	root = Instance.new("Folder")
	root.Name = Net.FolderName
	root.Parent = ReplicatedStorage
	return root
end

function Net.getOrCreateRemotes(): Folder
	local root = Net.getOrCreateRoot()
	local rem = root:FindFirstChild(Net.RemotesFolderName)
	if rem and rem:IsA("Folder") then return rem end
	rem = Instance.new("Folder")
	rem.Name = Net.RemotesFolderName
	rem.Parent = root
	return rem
end

function Net.getOrCreateRemoteEvent(name: string): RemoteEvent
	local remotes = Net.getOrCreateRemotes()
	local re = remotes:FindFirstChild(name)
	if re and re:IsA("RemoteEvent") then return re end
	re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = remotes
	return re
end

function Net.getOrCreateRemoteFunction(name: string): RemoteFunction
	local remotes = Net.getOrCreateRemotes()
	local rf = remotes:FindFirstChild(name)
	if rf and rf:IsA("RemoteFunction") then return rf end
	rf = Instance.new("RemoteFunction")
	rf.Name = name
	rf.Parent = remotes
	return rf
end

return Net