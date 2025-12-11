-- FILE: main_loops_example.lua
-- MẪU LOOP KIỂU A – DÙNG CHO main.lua HOẶC AnimeScript_FINAL.lua

-- Giả sử có:
--   config.features.xxx
--   isRunning / state.isRunning
--   utils:...  (với bản module)
-- Với AnimeScript_FINAL.lua bạn đổi tên cho khớp (CONFIG vs config, state vs isRunning).

local function smoothWait(base, jitterPercent)
    -- jitter nhẹ ±% để anti-ban nhưng không lag
    jitterPercent = jitterPercent or 0.2
    if base <= 0 then
        task.wait()
        return
    end
    local delta = base * jitterPercent
    local offset = (math.random() * 2 - 1) * delta
    local delay = math.max(0, base + offset)
    task.wait(delay)
end

----------------------------------------------------------------------
-- AUTO CLICK (MODULE STYLE)
----------------------------------------------------------------------

local function loopAutoClick(config, utils)
    task.spawn(function()
        while true do
            if isRunning and config.features.autoClick and utils:isAlive() then
                -- click base delay ±20%
                local base = config.click.autoClickSpeed
                smoothWait(base, 0.2)

                -- random hành vi nhẹ
                if math.random() < config.click.randomClickChance then
                    smoothWait(base * 2, 0.1)
                end
            else
                -- feature off hoặc chết → nghỉ 0.2s để không tốn CPU
                task.wait(0.2)
            end
        end
    end)
end

----------------------------------------------------------------------
-- AUTO SKILL
----------------------------------------------------------------------

local function loopAutoSkill(config, utils)
    task.spawn(function()
        local skillIndex = 1

        while true do
            if isRunning and config.features.autoSkill and utils:isAlive() then
                local skill = config.skill.sequence[skillIndex]
                if skill then
                    local ok, err = pcall(function()
                        utils:castSkill(skill)
                    end)
                    if not ok then
                        utils:log("Skill cast error: " .. tostring(err), "WARN")
                    end
                end

                skillIndex = (skillIndex % #config.skill.sequence) + 1
                smoothWait(config.antiBan.skillDelay.min or 0.5, 0.15)
            else
                task.wait(0.2)
            end
        end
    end)
end

----------------------------------------------------------------------
-- FARM + BOSS PRIORITY
-- Quy ước: nếu autoBoss ON → ưu tiên boss, farm chỉ chạy khi không thấy boss.
----------------------------------------------------------------------

local function loopAutoFarmAndBoss(config, utils, webhook)
    task.spawn(function()
        while true do
            if not isRunning or not utils:isAlive() then
                task.wait(0.3)
            else
                -- Nếu đang bật autoBoss → check boss trước
                if config.features.autoBoss then
                    local boss = nil
                    local okBoss, bossResult = pcall(function()
                        local targets = config.boss.farmAllBosses and
                            {"Boss", "Mini Boss", "Raid Boss", "Dragon", "Titan"} or
                            config.boss.targetBosses
                        return utils:findNearestBoss(targets, config.boss.bossDetectRadius)
                    end)

                    if okBoss then boss = bossResult end

                    if boss then
                        local rootPart = boss:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            utils:teleportTo(rootPart.Position + Vector3.new(0, 0, -20), 50)

                            utils:humanizedAction(function()
                                utils:attackEnemy(boss)
                            end, config.antiBan.clickDelay)

                            -- webhook (nếu dùng module)
                            if webhook and config.webhook.enabled and config.webhook.url ~= "" and config.webhook.logBoss then
                                pcall(function()
                                    webhook:logBossKill(config.webhook.url, boss.Name, "TBD")
                                end)
                            end
                        end

                        smoothWait(config.antiBan.detectionCheckInterval, 0.15)
                        -- CHÚ Ý: có boss thì không farm thường ở tick này
                        goto continue_loop
                    end
                end

                -- Nếu tới đây: hoặc autoBoss off, hoặc không tìm được boss → farm thường
                if config.features.autoFarm then
                    local enemy = nil
                    local okEnemy, enemyResult = pcall(function()
                        local targets = config.farm.autoFarmAllMonsters and
                            {"Bandit", "Pirate", "Zombie", "Skeleton", "Ghost"} or
                            config.farm.targetMonsters
                        return utils:findNearestEnemy(targets, config.farm.farmDistance)
                    end)

                    if okEnemy then enemy = enemyResult end

                    if enemy then
                        local hrp = enemy:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local offset = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
                            utils:teleportTo(hrp.Position + offset, 30)

                            utils:humanizedAction(function()
                                utils:attackEnemy(enemy)
                            end, config.antiBan.clickDelay)
                        end
                    end
                end

                smoothWait(config.antiBan.detectionCheckInterval, 0.15)
            end

            ::continue_loop::
        end
    end)
end

----------------------------------------------------------------------
-- AUTO CHEST
----------------------------------------------------------------------

local function loopAutoChest(config, utils)
    task.spawn(function()
        while true do
            if isRunning and config.features.autoChest and utils:isAlive() then
                local ok, workspaceObj = pcall(function()
                    return game:GetService("Workspace")
                end)

                if ok and workspaceObj then
                    for _, chest in pairs(workspaceObj:GetChildren() or {}) do
                        if chest:IsA("Model") and string.find(chest.Name:lower(), "chest") then
                            local rootPart = chest:FindFirstChild("HumanoidRootPart")
                            local playerRoot = utils:getRootPart()

                            if rootPart and playerRoot then
                                local dist = (rootPart.Position - playerRoot.Position).Magnitude
                                if dist < config.gameplay.chestDetectRadius then
                                    utils:teleportTo(rootPart.Position, 40)
                                    utils:humanizedAction(function()
                                        -- TODO: nếu cần fireproximityprompt / clickdetector
                                    end, config.antiBan.clickDelay)
                                end
                            end
                        end
                    end
                end
                task.wait(5)
            else
                task.wait(0.5)
            end
        end
    end)
end

----------------------------------------------------------------------
-- AUTO REJOIN
----------------------------------------------------------------------

local function loopAutoRejoin(config, utils)
    task.spawn(function()
        while true do
            if isRunning and config.features.autoRejoin then
                task.wait(config.rejoin.autoRejoinTime)

                local shouldRejoin = false

                if config.rejoin.rejoinOnNoBoss then
                    local ok, boss = pcall(function()
                        return utils:findNearestBoss(config.boss.targetBosses)
                    end)
                    if ok and not boss then
                        utils:log("No boss found, auto rejoining.", "WARN")
                        shouldRejoin = true
                    end
                else
                    utils:log("Time elapsed, auto rejoining.", "WARN")
                    shouldRejoin = true
                end

                if shouldRejoin then
                    task.wait(math.random(config.rejoin.rejoinDelay.min, config.rejoin.rejoinDelay.max))
                    local ok, TeleportService = pcall(function()
                        return game:GetService("TeleportService")
                    end)
                    if ok and TeleportService then
                        TeleportService:Teleport(game.PlaceId)
                    end
                end
            else
                task.wait(1)
            end
        end
    end)
end

----------------------------------------------------------------------
-- HÀM KHỞI ĐỘNG CHUNG (thay cho main:start hiện tại)
----------------------------------------------------------------------

local function startAllFeatures(config, utils, webhook)
    -- validate & log vẫn giữ nguyên như main:start cũ
    config:validate()
    utils:log("Starting auto farm features (loop style A).", "INFO")

    loopAutoClick(config, utils)
    loopAutoSkill(config, utils)
    loopAutoFarmAndBoss(config, utils, webhook)
    loopAutoChest(config, utils)
    loopAutoRejoin(config, utils)

    utils:log("All loops initialized!", "SUCCESS")
end
