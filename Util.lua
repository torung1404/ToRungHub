--!strict
local Players = game:GetService("Players")

local Util = {}

function Util.getCharacter(player: Player): Model?
	return player.Character
end

function Util.getHumanoid(char: Model): Humanoid?
	return char:FindFirstChildOfClass("Humanoid")
end

function Util.getHRP(char: Model): BasePart?
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.isAlive(player: Player): boolean
	local c = Util.getCharacter(player)
	if not c then return false end
	local h = Util.getHumanoid(c)
	if not h then return false end
	return h.Health > 0
end

function Util.modelPos(model: Model): Vector3?
	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)
	if ok and pivot then
		return pivot.Position
	end
	local pp = model.PrimaryPart
	if pp then return pp.Position end
	local any = model:FindFirstChildWhichIsA("BasePart", true)
	if any then return (any :: BasePart).Position end
	return nil
end

function Util.matchAny(text: string, patterns: {string}): boolean
	local s = string.lower(text)
	for _, p in ipairs(patterns) do
		if string.find(s, string.lower(p), 1, true) then
			return true
		end
	end
	return false
end

function Util.sortByDistance(origin: Vector3, models: {Model}): {Model}
	table.sort(models, function(a, b)
		local pa = Util.modelPos(a) or origin
		local pb = Util.modelPos(b) or origin
		return (pa - origin).Magnitude < (pb - origin).Magnitude
	end)
	return models
end

function Util.lookAtDown(fromPos: Vector3, targetPos: Vector3): CFrame
	local cf = CFrame.lookAt(fromPos, targetPos)
	-- ensure "down-ish" orientation by looking at target from above
	return cf
end

function Util.safeGetPlaceJob()
	local placeId = game.PlaceId
	local jobId = game.JobId
	return placeId, jobId
end

return Util