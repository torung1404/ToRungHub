--!strict
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:give(taskObj)
	table.insert(self._tasks, taskObj)
	return taskObj
end

function Maid:cleanup()
	for _, t in ipairs(self._tasks) do
		local tt = typeof(t)
		if tt == "RBXScriptConnection" then
			if t.Connected then t:Disconnect() end
		elseif tt == "Instance" then
			if t.Parent then t:Destroy() end
		elseif tt == "function" then
			t()
		end
	end
	table.clear(self._tasks)
end

return Maid