-- ========================================================
-- file: webhook.lua
-- ========================================================
local Webhook = {}

function Webhook.init(CONFIG)
  Webhook.config = CONFIG
end

function Webhook.sendBossKill(stats, bossName)
  -- Placeholder for Discord webhook integration
  -- Future: Add Discord logging if needed
end

function Webhook.sendError(message)
  warn("[ToRungHub Webhook] ERROR:", message)
end

return Webhook
