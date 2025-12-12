--// File: ServerScriptService/ToRungHub/Server/HopService.lua
--!strict
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local Config = require(game.ReplicatedStorage.ToRungHub.Shared.Config)
local Logger = require(game.ReplicatedStorage.ToRungHub.Shared.Logger)

local HopService = {}
HopService.__index = HopService

type RecentEntry = { jobId: string, t: number }

function HopService.new()
	local self = setmetatable({}, HopService)
	self.log = Logger.new("HopService", Config.DebugLevel)
	self._recentByUser = {} :: {[number]: {RecentEntry}}
	return self
end

function HopService:_prune(userId: number)
	local list = self._recentByUser[userId]
	if not list then return end
	local ttl = Config.Hop.TTLMinutes * 60
	local now = os.time()
	for i = #list, 1, -1 do
		if (now - list[i].t) > ttl then
			table.remove(list, i)
		end
	end
	while #list > Config.Hop.MaxRecent do
		table.remove(list, 1)
	end
end

function HopService:_remember(userId: number, jobId: string)
	local list = self._recentByUser[userId]
	if not list then
		list = {}
		self._recentByUser[userId] = list
	end
	table.insert(list, { jobId = jobId, t = os.time() })
	self:_prune(userId)
end

function HopService:_excludeSet(userId: number): {[string]: boolean}
	self:_prune(userId)
	local set = {} :: {[string]: boolean}
	local list = self._recentByUser[userId]
	if not list then return set end
	for _, e in ipairs(list) do
		set[e.jobId] = true
	end
	return set
end

function HopService:_fetchServers(placeId: number, cursor: string?): (any?, string?)
	local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100"):format(placeId)
	if cursor and cursor ~= "" then
		url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
	end
	local ok, body = pcall(function()
		return HttpService:GetAsync(url)
	end)
	if not ok then
		return nil, nil
	end
	local data = HttpService:JSONDecode(body)
	return data, data and data.nextPageCursor
end

function HopService:hopPlayer(player: Player): boolean
	if not Config.Hop.Enabled then
		self.log:warn("Hop disabled in config.")
		return false
	end

	local placeId = game.PlaceId
	local exclude = self:_excludeSet(player.UserId)
	exclude[game.JobId] = true

	local cursor: string? = nil
	for attempt = 1, 4 do
		local data, nextCursor = self:_fetchServers(placeId, cursor)
		if data and data.data then
			for _, srv in ipairs(data.data) do
				local jobId = srv.id
				local playing = srv.playing or 0
				local maxPlayers = srv.maxPlayers or 0
				if jobId and not exclude[jobId] then
					if playing >= Config.Hop.MinPlayers and playing <= Config.Hop.MaxPlayers and playing < maxPlayers then
						self.log:info(("Teleporting to server jobId=%s playing=%d/%d"):format(jobId, playing, maxPlayers))
						self:_remember(player.UserId, jobId)
						TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
						return true
					end
				end
			end
		end
		cursor = nextCursor
		local backoff = Config.Hop.BackoffSeconds[attempt] or 2
		task.wait(backoff)
	end

	self.log:warn("No suitable server found for hop.")
	return false
end

return HopService
