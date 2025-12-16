local Players = game:GetService('Players')
local TeleportService = game:GetService('TeleportService')

local plr = Players.LocalPlayer
local pg = plr:WaitForChild('PlayerGui')
local tr = pg:WaitForChild('ToRungHubTransport')

local jobId = 'PASTE_JOB_ID_HERE'
local td = tr:Invoke('GetTeleportData')

TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, plr, td)
