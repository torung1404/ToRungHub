--// File: ReplicatedStorage/ToRungHub/Shared/Logger.lua
--!strict
local Logger = {}
Logger.__index = Logger

local LEVELS = {
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	DEBUG = 4,
}

function Logger.new(scope: string, levelName: string)
	local self = setmetatable({}, Logger)
	self.scope = scope
	self.level = LEVELS[levelName] or LEVELS.INFO
	return self
end

function Logger:withScope(scope: string)
	return Logger.new(scope, (self.level == 4 and "DEBUG") or (self.level == 3 and "INFO") or (self.level == 2 and "WARN") or "ERROR")
end

local function now()
	return os.date("!%H:%M:%S")
end

function Logger:_print(minLevel: number, tag: string, msg: string)
	if self.level < minLevel then return end
	print(("[ToRungHub][%s][%s][%s] %s"):format(now(), self.scope, tag, msg))
end

function Logger:error(msg: string) self:_print(LEVELS.ERROR, "ERR", msg) end
function Logger:warn(msg: string) self:_print(LEVELS.WARN, "WRN", msg) end
function Logger:info(msg: string) self:_print(LEVELS.INFO, "INF", msg) end
function Logger:debug(msg: string) self:_print(LEVELS.DEBUG, "DBG", msg) end

return Logger
