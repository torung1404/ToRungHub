-- ToRungHub - Full Workspace Scanner Sender (ONE-SHOT, STRONG)
-- Scan 1 lần toàn bộ Workspace, phân loại boss/mob/npc/other/chest, gửi về WebSocket server.

----------------------------------------------------------------------
-- 1. CONFIG
----------------------------------------------------------------------

local WS_URL    = "wss://web-production-252ee.up.railway.app"
local MAX_LINES = 1200  -- số dòng tối đa gửi lên server (rất lớn)

----------------------------------------------------------------------
-- 2. SERVICES
----------------------------------------------------------------------

local Players     = game:GetService("Players")
local Workspace   = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local function jsonEncode(tbl)
    local ok, res = pcall(HttpService.JSONEncode, HttpService, tbl)
    if ok then
        return res
    else
        warn("[ToRungHub WS] JSONEncode error:", res)
        return nil
    end
end

local function jsonDecode(str)
    local ok, res = pcall(HttpService.JSONDecode, HttpService, str)
    if ok then
        return res
    else
        warn("[ToRungHub WS] JSONDecode error:", res)
        return nil
    end
end

----------------------------------------------------------------------
-- 3. WebSocket CONNECT
----------------------------------------------------------------------

local function connectWebSocket(url)
    local wsConnect
    local execName = "Unknown"

    if syn and syn.websocket and syn.websocket.connect then
        wsConnect = syn.websocket.connect
        execName = "syn.websocket"
    elseif websocket and websocket.connect then
        wsConnect = websocket.connect
        execName = "websocket.connect"
    elseif WebSocket and WebSocket.connect then
        wsConnect = WebSocket.connect
        execName = "WebSocket.connect"
    end

    warn("[ToRungHub WS] Detect executor WebSocket API =", execName)

    if not wsConnect then
        warn("[ToRungHub WS] Executor KHÔNG có WebSocket API (syn.websocket / websocket / WebSocket).")
        return nil
    end

    local ok, wsOrErr = pcall(wsConnect, url)
    if not ok or not wsOrErr then
        warn("[ToRungHub WS] Kết nối WebSocket thất bại.")
        warn("[ToRungHub WS] URL :", url)
        warn("[ToRungHub WS] Err :", tostring(wsOrErr or ok))
        return nil
    end

    print("[ToRungHub WS] Connected to", url, "via", execName)
    return wsOrErr
end

----------------------------------------------------------------------
-- 4. SCAN WORKSPACE & CLASSIFY
----------------------------------------------------------------------

local function getFullPath(obj)
    local parts = {}
    local current = obj
    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return table.concat(parts, ".")
end

local function classifyModel(model, pathLower)
    local nameLower = string.lower(model.Name)
    pathLower = pathLower or string.lower(getFullPath(model))

    -- boss ưu tiên cao
    if string.find(nameLower, "boss", 1, true)
       or string.find(pathLower, "boss", 1, true) then
        return "boss"
    end

    -- npc
    if string.find(nameLower, "npc", 1, true)
       or string.find(pathLower, "npc", 1, true) then
        return "npc"
    end

    -- mobs / monsters
    if string.find(nameLower, "monster", 1, true)
       or string.find(pathLower, "monster", 1, true)
       or string.find(pathLower, "monsters", 1, true)
       or string.find(nameLower, "mob", 1, true)
       or string.find(pathLower, "mob", 1, true) then
        return "mob"
    end

    return "other"
end

local function scanWorkspace()
    local stats = {
        boss  = {},
        mob   = {},
        npc   = {},
        other = {},
        chest = {},
    }

    local descendants = Workspace:GetDescendants()  -- toàn bộ Workspace, không giới hạn vùng

    for _, obj in ipairs(descendants) do
        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum then
                local path = getFullPath(obj)
                local pathLower = string.lower(path)
                local category = classifyModel(obj, pathLower)

                local group = stats[category]
                if group then
                    local name = obj.Name
                    local stat = group[name]
                    if not stat then
                        stat = { count = 0, path = path }
                        group[name] = stat
                    end
                    stat.count += 1
                end
            end
        end

        -- CHEST: bất cứ object nào tên chứa "chest"
        local lowerName = string.lower(obj.Name)
        if string.find(lowerName, "chest", 1, true) then
            local group = stats.chest
            local name = obj.Name
            local stat = group[name]
            if not stat then
                stat = { count = 0, path = getFullPath(obj) }
                group[name] = stat
            end
            stat.count += 1
        end
    end

    return stats
end

local function sortedKeys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
    return keys
end

local function buildSummaryLines(stats, maxLines)
    maxLines = maxLines or MAX_LINES
    local lines = {}

    local function addSection(title, key)
        table.insert(lines, title)
        local group = stats[key]
        if not group or next(group) == nil then
            table.insert(lines, "(empty)")
            return
        end

        for _, name in ipairs(sortedKeys(group)) do
            local info = group[name]
            table.insert(lines, string.format(
                "- %s | type=%s | count = %d\n  path = %s",
                name,
                key,
                info.count or 0,
                info.path or "?"
            ))
        end
    end

    addSection("========= BOSSES (Model + Humanoid) =========",   "boss")
    addSection("========= MOBS / MONSTERS (Model + Humanoid, tên/path có 'monster'/'mob') =========", "mob")
    addSection("========= NPCs (Model + Humanoid, tên/path có 'npc') =========", "npc")
    addSection("========= OTHERS (Model + Humanoid, không match boss/mob/npc) =========", "other")
    addSection("========= CHESTS (tên chứa 'chest') =========", "chest")

    if #lines > maxLines then
        local trimmed = {}
        for i = 1, maxLines do
            trimmed[i] = lines[i]
        end
        table.insert(trimmed, string.format("... (truncated, total = %d lines)", #lines))
        return trimmed
    end

    return lines
end

----------------------------------------------------------------------
-- 5. BUILD PAYLOAD + SEND (ONE-SHOT)
----------------------------------------------------------------------

local function getNowMillis()
    local ok, dt = pcall(function()
        return DateTime.now()
    end)
    if ok and dt then
        return dt.UnixTimestampMillis
    else
        return os.time() * 1000
    end
end

local function makePayload()
    local stats = scanWorkspace()
    local summaryLines = buildSummaryLines(stats, MAX_LINES)

    local payload = {
        type    = "pets_update",
        player  = LocalPlayer and LocalPlayer.Name or "Unknown",
        placeId = game.PlaceId,
        jobId   = game.JobId,
        pets    = summaryLines,
        ts      = getNowMillis(),
    }

    return payload, summaryLines
end

local function sendSnapshot(ws)
    local payload, lines = makePayload()
    local json = jsonEncode(payload)
    if not json then
        return
    end

    ws:Send(json)
    print(string.format(
        "[ToRungHub WS] SENT workspace snapshot (lines=%d, player=%s)",
        #lines,
        payload.player
    ))
end

----------------------------------------------------------------------
-- 6. MAIN: CONNECT + SCAN 1 LẦN + GỬI
----------------------------------------------------------------------

local function main()
    local ws = connectWebSocket(WS_URL)
    if not ws then
        warn("[ToRungHub WS] Không thể kết nối WebSocket, dừng sender.")
        return
    end

    pcall(function()
        if ws.OnMessage then
            ws.OnMessage:Connect(function(msg)
                local data = jsonDecode(msg)
                if data and data.type then
                    print("[ToRungHub WS] Message from server:", data.type)
                end
            end)
        end
        if ws.OnClose then
            ws.OnClose:Connect(function()
                warn("[ToRungHub WS] WebSocket closed.")
            end)
        end
    end)

    sendSnapshot(ws)

    pcall(function()
        if ws.Close then
            ws:Close()
        end
    end)

    print("[ToRungHub] Workspace Scanner Sender finished (one-shot, full workspace).")
end

task.spawn(main)
