--// File: ServerScriptService/ToRungHub/Server/WorldIndex.lua
--!strict
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)
local Util = require(game.ReplicatedStorage.ToRungHub.Shared.Util)
local Logger = require(game.ReplicatedStorage.ToRungHub.Shared.Logger)

local WorldIndex = {}
WorldIndex.__index = WorldIndex

export type Snapshot = {
	bosses: {Model},
	mobs: {Model},
	chests: {Instance},
}

local function isHumanoidModel(m: Instance): boolean
	if not m:IsA("Model") then return false end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	return true
end

local function classify(model: Model): string?
	local name = string.lower(model.Name)
	local path = string.lower(model:GetFullName())

	if string.find(name, "boss", 1, true) or string.find(path, ".boss", 1, true) then
		return "boss"
	end
	if string.find(name, "monster", 1, true) or string.find(name, "mob", 1, true) or string.find(path, ".monster", 1, true) then
		return "mob"
	end
	if string.find(name, "npc", 1, true) or string.find(path, ".npc", 1, true) then
		return "npc"
	end
	return "other"
end

local function isChestInstance(inst: Instance): boolean
	local n = string.lower(inst.Name)
	if Util.matchAny(n, Config.Chest.NameContains) then
		return true
	end
	local parentName = inst.Parent and string.lower(inst.Parent.Name) or ""
	if Util.matchAny(parentName, Config.Chest.NameContains) then
		return true
	end
	return false
end

function WorldIndex.new()
	local self = setmetatable({}, WorldIndex)
	self.log = Logger.new("WorldIndex", Config.DebugLevel)
	self._bosses = {} :: {Model}
	self._mobs = {} :: {Model}
	self._chests = {} :: {Instance}
	self._setBoss = {} :: {[Instance]: boolean}
	self._setMob = {} :: {[Instance]: boolean}
	self._setChest = {} :: {[Instance]: boolean}
	self._lastScan = 0
	self:_fullScan()
	self:_bind()
	return self
end

function WorldIndex:_addBoss(m: Model)
	if self._setBoss[m] then return end
	self._setBoss[m] = true
	table.insert(self._bosses, m)
end

function WorldIndex:_addMob(m: Model)
	if self._setMob[m] then return end
	self._setMob[m] = true
	table.insert(self._mobs, m)
end

function WorldIndex:_addChest(i: Instance)
	if self._setChest[i] then return end
	self._setChest[i] = true
	table.insert(self._chests, i)
end

function WorldIndex:_removeFrom(list: {any}, set: {[Instance]: boolean}, inst: Instance)
	if not set[inst] then return end
	set[inst] = nil
	for idx = #list, 1, -1 do
		if list[idx] == inst then
			table.remove(list, idx)
			break
		end
	end
end

function WorldIndex:_fullScan()
	local bossesTagged = CollectionService:GetTagged(Config.Tags.Boss)
	local mobsTagged = CollectionService:GetTagged(Config.Tags.Mob)
	local chestsTagged = CollectionService:GetTagged(Config.Tags.Chest)

	local usedTags = (#bossesTagged + #mobsTagged + #chestsTagged) > 0

	local function scanByTags()
		for _, inst in ipairs(bossesTagged) do
			if inst:IsA("Model") and isHumanoidModel(inst) then self:_addBoss(inst) end
		end
		for _, inst in ipairs(mobsTagged) do
			if inst:IsA("Model") and isHumanoidModel(inst) then self:_addMob(inst) end
		end
		for _, inst in ipairs(chestsTagged) do
			self:_addChest(inst)
		end
	end

	local function scanWorkspaceFallback()
		local all = Workspace:GetDescendants()
		local batch = Config.Scan.InitialScanBatch
		for i = 1, #all do
			local inst = all[i]
			if inst:IsA("Model") and isHumanoidModel(inst) then
				local t = classify(inst)
				if t == "boss" then self:_addBoss(inst) end
				if t == "mob" then self:_addMob(inst) end
			elseif isChestInstance(inst) then
				self:_addChest(inst)
			end
			if (i % batch) == 0 then task.wait() end
		end
	end

	if usedTags then
		self.log:info("Using CollectionService tags for scan.")
		scanByTags()
	else
		self.log:warn("No tags found; using Workspace fallback scan (heavier).")
		scanWorkspaceFallback()
	end

	self._lastScan = os.clock()
	self.log:info(("Scan done. bosses=%d mobs=%d chests=%d"):format(#self._bosses, #self._mobs, #self._chests))
end

function WorldIndex:_bind()
	Workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("Model") and isHumanoidModel(inst) then
			local t = classify(inst)
			if t == "boss" then self:_addBoss(inst) end
			if t == "mob" then self:_addMob(inst) end
		elseif isChestInstance(inst) then
			self:_addChest(inst)
		end
	end)

	Workspace.DescendantRemoving:Connect(function(inst)
		self:_removeFrom(self._bosses, self._setBoss, inst)
		self:_removeFrom(self._mobs, self._setMob, inst)
		self:_removeFrom(self._chests, self._setChest, inst)
	end)
end

function WorldIndex:refreshIfNeeded()
	if (os.clock() - self._lastScan) < Config.Scan.ScanInterval then return end
	self._lastScan = os.clock()
	for i = #self._bosses, 1, -1 do
		local m = self._bosses[i]
		if not m.Parent then
			self._setBoss[m] = nil
			table.remove(self._bosses, i)
		end
	end
	for i = #self._mobs, 1, -1 do
		local m = self._mobs[i]
		if not m.Parent then
			self._setMob[m] = nil
			table.remove(self._mobs, i)
		end
	end
	for i = #self._chests, 1, -1 do
		local c = self._chests[i]
		if not c.Parent then
			self._setChest[c] = nil
			table.remove(self._chests, i)
		end
	end
end

function WorldIndex:getBosses(): {Model}
	return self._bosses
end

function WorldIndex:getMobs(): {Model}
	return self._mobs
end

function WorldIndex:getChests(): {Instance}
	return self._chests
end

return WorldIndex
