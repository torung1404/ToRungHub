--// File: ServerScriptService/ToRungHub/Server/AutomationFSM.lua
--!strict
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)
local Util = require(game.ReplicatedStorage.ToRungHub.Shared.Util)
local Logger = require(game.ReplicatedStorage.ToRungHub.Shared.Logger)

local AutomationFSM = {}
AutomationFSM.__index = AutomationFSM

export type Options = {
	autoBoss: boolean,
	autoChest: boolean,
	autoHop: boolean,
	autoMedi: boolean,
	hpThreshold: number,
	chestMode: string,
	moveMode: string,
	useSkills: boolean,
}

export type Snapshot = {
	state: string,
	targetName: string?,
	kills: number,
	lastAction: string?,
	placeId: number,
	jobId: string,
}

local function clamp01(n: number): number
	if n < 0 then return 0 end
	if n > 100 then return 100 end
	return n
end

function AutomationFSM.new(player: Player, worldIndex, combatAdapter, lootAdapter, hopService, stateUpdateEvent: RemoteEvent)
	local self = setmetatable({}, AutomationFSM)

	self.player = player
	self.worldIndex = worldIndex
	self.combat = combatAdapter
	self.loot = lootAdapter
	self.hop = hopService
	self.re = stateUpdateEvent

	self.log = Logger.new(("FSM:%s"):format(player.Name), Config.DebugLevel)

	self.enabled = false
	self.opts = {
		autoBoss = Config.Boss.Enabled,
		autoChest = Config.Chest.Enabled,
		autoHop = Config.Hop.Enabled,
		autoMedi = Config.QoL.AutoMediEnabled,
		hpThreshold = Config.QoL.HPThresholdPercent,
		chestMode = Config.Chest.Mode,
		moveMode = Config.Movement.Mode,
		useSkills = Config.Combat.UseSkills,
	} :: Options

	self.state = "Idle"
	self.target = nil :: Model?
	self.targetChest = nil :: Instance?
	self.kills = 0
	self._accum = 0
	self._attackT = 0
	self._skillT = 0
	self._mediT = 0
	self._noChestT = 0
	self._lastPos = nil :: Vector3?
	self._stuckT = 0

	self._conn = RunService.Heartbeat:Connect(function(dt)
		self:_tick(dt)
	end)

	return self
end

function AutomationFSM:destroy()
	if self._conn then self._conn:Disconnect() end
end

function AutomationFSM:setEnabled(on: boolean)
	self.enabled = on
	self.state = on and "FindTarget" or "Idle"
	self.target = nil
	self.targetChest = nil
	self._noChestT = 0
	self.log:info("Enabled=" .. tostring(on))
end

function AutomationFSM:setOption(key: string, value: any)
	if key == "hpThreshold" then
		self.opts.hpThreshold = clamp01(tonumber(value) or self.opts.hpThreshold)
	elseif key == "autoBoss" then
		self.opts.autoBoss = value == true
	elseif key == "autoChest" then
		self.opts.autoChest = value == true
	elseif key == "autoHop" then
		self.opts.autoHop = value == true
	elseif key == "autoMedi" then
		self.opts.autoMedi = value == true
	elseif key == "chestMode" then
		self.opts.chestMode = tostring(value)
	elseif key == "moveMode" then
		self.opts.moveMode = tostring(value)
	elseif key == "useSkills" then
		self.opts.useSkills = value == true
	end
end

local function humanoidOf(m: Model): Humanoid?
	return m:FindFirstChildOfClass("Humanoid")
end

function AutomationFSM:_snap(lastAction: string?): Snapshot
	local placeId, jobId = Util.safeGetPlaceJob()
	return {
		state = self.state,
		targetName = self.target and self.target.Name or (self.targetChest and self.targetChest.Name) or nil,
		kills = self.kills,
		lastAction = lastAction,
		placeId = placeId,
		jobId = jobId,
	}
end

function AutomationFSM:_pushSnapshot(lastAction: string?)
	self.re:FireClient(self.player, self:_snap(lastAction))
end

function AutomationFSM:_getChar()
	local char = self.player.Character
	if not char then return nil, nil, nil end
	local hum = Util.getHumanoid(char)
	local hrp = Util.getHRP(char)
	return char, hum, hrp
end

function AutomationFSM:_shouldRecover(hum: Humanoid): boolean
	if not self.opts.autoMedi then return false end
	local hp = hum.Health
	local maxHp = hum.MaxHealth
	if maxHp <= 0 then return false end
	local pct = (hp / maxHp) * 100
	if self.player:GetAttribute("IsMedi") == true then
		return pct <= (self.opts.hpThreshold + Config.QoL.RecoveryHysteresis)
	end
	return pct <= self.opts.hpThreshold
end

function AutomationFSM:_moveToAbove(hrp: BasePart, targetPos: Vector3)
	local above = targetPos + Vector3.new(0, Config.Movement.HeightOffset, 0)
	local cf = Util.lookAtDown(above, targetPos)
	hrp.CFrame = cf
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

function AutomationFSM:_stuckCheck(hrp: BasePart, dt: number): boolean
	local pos = hrp.Position
	if not self._lastPos then
		self._lastPos = pos
		self._stuckT = 0
		return false
	end
	local moved = (pos - self._lastPos).Magnitude
	self._lastPos = pos
	if moved < Config.Movement.StuckMinMove then
		self._stuckT += dt
	else
		self._stuckT = 0
	end
	return self._stuckT >= Config.Movement.StuckSeconds
end

function AutomationFSM:_nudge(hrp: BasePart)
	local j = Config.Movement.RepositionJitter
	local dx = (math.random() * 2 - 1) * j
	local dz = (math.random() * 2 - 1) * j
	hrp.CFrame = hrp.CFrame + Vector3.new(dx, 0, dz)
end

function AutomationFSM:_pickBoss(origin: Vector3): Model?
	local bosses = self.worldIndex:getBosses()
	local candidates = {}

	for _, b in ipairs(bosses) do
		if self.combat:isValidTarget(b) then
			table.insert(candidates, b)
		end
	end

	for _, pattern in ipairs(Config.Boss.PriorityList) do
		for _, b in ipairs(candidates) do
			if string.find(string.lower(b.Name), string.lower(pattern), 1, true) then
				return b
			end
		end
	end

	if #candidates == 0 then return nil end
	Util.sortByDistance(origin, candidates)
	return candidates[1]
end

function AutomationFSM:_pickChest(origin: Vector3): Instance?
	local chests = self.worldIndex:getChests()
	local best = nil
	local bestD = math.huge
	for _, c in ipairs(chests) do
		if c.Parent and self.loot:canLoot(c) then
			local pos: Vector3? = nil
			if c:IsA("Model") then
				pos = Util.modelPos(c)
			elseif c:IsA("BasePart") then
				pos = c.Position
			end
			if pos then
				local d = (pos - origin).Magnitude
				if d < bestD and d <= Config.Chest.MaxDistance then
					best = c
					bestD = d
				end
			end
		end
	end
	return best
end

function AutomationFSM:_tick(dt: number)
	self._accum += dt
	if self._accum < 0.1 then return end
	local step = self._accum
	self._accum = 0

	self.worldIndex:refreshIfNeeded()

	if not self.enabled then return end

	local char, hum, hrp = self:_getChar()
	if not char or not hum or not hrp then
		self.state = "Idle"
		return
	end
	if hum.Health <= 0 then
		self.state = "Idle"
		return
	end

	if self:_shouldRecover(hum) then
		self.state = "Recover"
		self._mediT += step
		if self._mediT >= Config.QoL.MediCooldownSeconds then
			self._mediT = 0
			self.combat:useMedi(self.player)
			self:_pushSnapshot("AutoMedi")
		end
		return
	else
		if self.player:GetAttribute("IsMedi") == true then
			self.combat:stopMedi(self.player)
		end
	end

	if self.state == "Idle" then
		self.state = "FindTarget"
	end

	if self.state == "FindTarget" then
		local origin = hrp.Position
		if self.opts.autoChest then
			local chest = self:_pickChest(origin)
			if chest then
				self.targetChest = chest
				self.target = nil
				self.state = "Loot"
				self._noChestT = 0
				self:_pushSnapshot("FoundChest")
				return
			else
				self._noChestT += step
				if self.opts.autoHop and self._noChestT >= Config.Chest.NoChestHopSeconds then
					self.state = "Hop"
					self:_pushSnapshot("NoChestHop")
					return
				end
			end
		end

		if self.opts.autoBoss then
			local boss = self:_pickBoss(origin)
			if boss then
				self.target = boss
				self.targetChest = nil
				self.state = "MoveToTarget"
				self:_pushSnapshot("FoundBoss")
				return
			else
				if self.opts.autoHop then
					self.state = "Hop"
					self:_pushSnapshot("NoBossHop")
					return
				end
			end
		end

		self:_pushSnapshot("NothingToDo")
		return
	end

	if self.state == "Loot" then
		local chest = self.targetChest
		if not chest or not chest.Parent then
			self.state = "FindTarget"
			return
		end

		local pos: Vector3? = nil
		if chest:IsA("Model") then
			pos = Util.modelPos(chest)
		elseif chest:IsA("BasePart") then
			pos = chest.Position
		end
		if not pos then
			self.state = "FindTarget"
			return
		end

		if self.opts.chestMode == "HighlightOnly" then
			self:_pushSnapshot("HighlightOnly")
			self.state = "FindTarget"
			return
		end

		if self.opts.chestMode == "Walk_Loot" or self.opts.moveMode == "Walk" then
			hum:MoveTo(pos)
		else
			hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		end

		local ok = self.loot:loot(self.player, chest)
		self:_pushSnapshot(ok and "Looted" or "LootFail")
		self.state = "FindTarget"
		return
	end

	if self.state == "MoveToTarget" then
		local boss = self.target
		if not boss or not boss.Parent or not self.combat:isValidTarget(boss) then
			self.state = "FindTarget"
			return
		end
		local bpos = Util.modelPos(boss)
		if not bpos then
			self.state = "FindTarget"
			return
		end

		if self.opts.moveMode == "Walk" then
			hum:MoveTo(bpos)
		else
			self:_moveToAbove(hrp, bpos)
		end

		if self:_stuckCheck(hrp, step) then
			self:_nudge(hrp)
			self:_pushSnapshot("StuckNudge")
		end

		local dist = (hrp.Position - bpos).Magnitude
		if dist <= (Config.Movement.HeightOffset + Config.Movement.CombatHoldDistance + 2) then
			self.state = "Combat"
			self:_pushSnapshot("Engage")
		end
		return
	end

	if self.state == "Combat" then
		local boss = self.target
		if not boss or not boss.Parent or not self.combat:isValidTarget(boss) then
			self.kills += 1
			self.target = nil
			self.state = "FindTarget"
			self:_pushSnapshot("BossDown")
			return
		end

		local bpos = Util.modelPos(boss)
		if not bpos then
			self.state = "FindTarget"
			return
		end

		if self.opts.moveMode ~= "Walk" then
			self:_moveToAbove(hrp, bpos)
		end

		self._attackT += step
		self._skillT += step

		if self._attackT >= Config.Combat.AttackInterval then
			self._attackT = 0
			self.combat:attack(self.player, boss)
		end

		if self.opts.useSkills and self._skillT >= Config.Combat.SkillInterval then
			self._skillT = 0
			local slot = Config.Combat.SkillSlots[math.random(1, #Config.Combat.SkillSlots)]
			self.combat:useSkill(self.player, slot, boss)
		end

		return
	end

	if self.state == "Hop" then
		self:_pushSnapshot("HopAttempt")
		self.hop:hopPlayer(self.player)
		self.state = "Idle"
		return
	end
end

return AutomationFSM
