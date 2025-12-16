--[[
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local Workspace = game:GetService('Workspace')

local REMOTE_NAME = 'ToRungHubControl'
local OWNER_ONLY = true

local function isOwner(plr)
	if not OWNER_ONLY then return true end
	if plr.UserId == game.CreatorId then return true end
	return false
end

local function sanitizeConfig(cfg)
	if typeof(cfg) ~= 'table' then return nil end
	local a = cfg.autofarm
	if typeof(a) ~= 'table' then return nil end
	return {
		Enabled = (a.Enabled == true),
		BossOnly = (a.BossOnly == true),
		Radius = math.clamp(tonumber(a.Radius) or 3000, 0, 20000),
		FollowDist = math.clamp(tonumber(a.FollowDist) or 6, 1, 40),
		AttackCD = math.clamp(tonumber(a.AttackCD) or 0.2, 0.05, 1.0),
	}
end

local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not remote then
	remote = Instance.new('RemoteEvent')
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage
end

local stateByUserId = {} -- userId -> { cfg=table, nextAttack=number }

local MONSTER_FOLDER = Workspace:FindFirstChild('Monsters')
local MONSTER_TAG = 'Monster'
local BOSS_TAG = 'Boss'

local function getChar(plr)
	local c = plr.Character
	if not c then return nil end
	local hrp = c:FindFirstChild('HumanoidRootPart')
	local hum = c:FindFirstChildOfClass('Humanoid')
	if not (hrp and hum) then return nil end
	return c, hrp, hum
end

local function isAliveModel(m)
	if not (m and m:IsA('Model')) then return false end
	local hum = m:FindFirstChildOfClass('Humanoid')
	local hrp = m:FindFirstChild('HumanoidRootPart') or m.PrimaryPart
	if not (hum and hrp) then return false end
	if hum.Health <= 0 then return false end
	return true
end

local function isBoss(m)
	if CollectionService:HasTag(m, BOSS_TAG) then return true end
	return (m.Name or ''):lower():find('boss') ~= nil
end

local function listMonsters()
	local out = {}
	local tagged = CollectionService:GetTagged(MONSTER_TAG)
	for _, inst in ipairs(tagged) do
		if inst:IsA('Model') then out[#out+1] = inst end
	end
	if #out > 0 then return out end
	if MONSTER_FOLDER then
		for _, inst in ipairs(MONSTER_FOLDER:GetChildren()) do
			if inst:IsA('Model') then out[#out+1] = inst end
		end
	end
	return out
end

local function bestTarget(hrp, cfg)
	local best, bestD2 = nil, math.huge
	local pos = hrp.Position
	local r2 = cfg.Radius * cfg.Radius
	for _, m in ipairs(listMonsters()) do
		if isAliveModel(m) then
			if (not cfg.BossOnly) or isBoss(m) then
				local r = m:FindFirstChild('HumanoidRootPart') or m.PrimaryPart
				if r then
					local d = pos - r.Position
					local d2 = d:Dot(d)
					if d2 <= r2 and d2 < bestD2 then
						bestD2 = d2
						best = m
					end
				end
			end
		end
	end
	return best
end

remote.OnServerEvent:Connect(function(plr, action, payload)
	if not isOwner(plr) then return end
	if action ~= 'Config' then return end
	local cfg = sanitizeConfig(payload)
	if not cfg then return end

	stateByUserId[plr.UserId] = stateByUserId[plr.UserId] or { nextAttack = 0 }
	stateByUserId[plr.UserId].cfg = cfg
end)

Players.PlayerRemoving:Connect(function(plr)
	stateByUserId[plr.UserId] = nil
end)

RunService.Heartbeat:Connect(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		local st = stateByUserId[plr.UserId]
		if st and st.cfg and st.cfg.Enabled then
			local _, hrp = getChar(plr)
			if hrp then
				local target = bestTarget(hrp, st.cfg)
				if target then
					local thrp = target:FindFirstChild('HumanoidRootPart') or target.PrimaryPart
					local thum = target:FindFirstChildOfClass('Humanoid')
					if thrp and thum then
						local goal = (thrp.CFrame * CFrame.new(0, 0, st.cfg.FollowDist)).Position
						hrp.CFrame = CFrame.new(goal, thrp.Position)

						if os.clock() >= st.nextAttack then
							st.nextAttack = os.clock() + st.cfg.AttackCD
							thum:TakeDamage(5) -- TODO: thay bằng logic combat thật của game bạn
						end
					end
				end
			end
		end
	end
end)
]]
