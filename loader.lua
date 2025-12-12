local BASE_URL = "https://raw.githubusercontent.com/torung1404/ToRungHub/main/"

local function safeHttpGet(url)
    local ok, result = pcall(game.HttpGet, game, url, true)
    if ok then
        return result
    end
    return game:HttpGet(url, true)
end

local function loadRemoteChunk(path)
    local src = safeHttpGet(BASE_URL .. path)
    local fn, err = loadstring(src, "@" .. path)
    if not fn then
        error("[ToRungHub] Failed to load " .. path .. ": " .. tostring(err))
    end
    return fn()
end

local CONFIG  = loadRemoteChunk("config.lua")
local Utils   = loadRemoteChunk("utils.lua")
local UI      = loadRemoteChunk("ui.lua")
local Webhook = loadRemoteChunk("webhook.lua")
local mainFn  = loadRemoteChunk("main.lua")

mainFn({
    config  = CONFIG,
    utils   = Utils,
    ui      = UI,
    webhook = Webhook,
})
