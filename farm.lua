--[[
Auto Farm Coins - Murder Mystery 2 | EVENT-DRIVEN BUILD
- Строго по событию RoundStart
- Сброс при смерти/респавне
- Все твои настройки сохранены
- Надежный Anti-AFK (VirtualUser)
]]

-- Объявляем сервисы для надежности
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser") -- Сервис для надежного Anti-AFK
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- нажатие на кнопку в начале 
local function selectDevice()
    while task.wait(0.1) do
        -- Ждём появления окна выбора устройства
        local DeviceSelectGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("DeviceSelect")
        
        if DeviceSelectGui then
            local Container = DeviceSelectGui:WaitForChild("Container")
            
            -- Находим кнопку "Phone"
            local button = Container:WaitForChild("Phone"):WaitForChild("Button")
            
            -- Вычисляем центр кнопки для клика
            local buttonPos = button.AbsolutePosition
            local buttonSize = button.AbsoluteSize
            local centerX = buttonPos.X + buttonSize.X / 2
            local centerY = buttonPos.Y + buttonSize.Y / 2
            
            -- Эмулируем нажатие мыши (down + up)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
            task.wait(0.1)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
            
            break -- Останавливаем цикл после успешного клика
        end
    end
end

-- Запуск функции в отдельном потоке
task.spawn(selectDevice)
task.wait(10)

-- ⚙️ ТВОИ НАСТРОЙКИ
local SETTINGS = {
    Enabled = true,
    Mode = "Tween",
    MoveSpeed = 20,
    MinMoveTime = 0.4,
    MaxMoveTime = 2.5,
    CollectionRadius = 2.5,
    LoopDelay = 0.05,
    
    MaxBagCoins = 40,
    AutoRespawn = true,
    SpawnWaitTime = 2.0
}

local MAX_IGNORED = 10
local IGNORE_DUR = 3.0

-- 🔥 СОСТОЯНИЕ РАУНДА
local isRoundActive = false
local collectedCoins = {}

-- ================= ПЕРЕХВАТ СОБЫТИЯ РАУНДА =================
local function setupRoundDetection()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local gameplay = remotes and remotes:FindFirstChild("Gameplay")
    local roundStart = gameplay and gameplay:FindFirstChild("RoundStart")

    if roundStart and roundStart:IsA("RemoteEvent") then
        roundStart.OnClientEvent:Connect(function()
            isRoundActive = true
            print("🟢 [EVENT] RoundStart received! Farming ENABLED.")
        end)
        print("✅ Hooked to ReplicatedStorage.Remotes.Gameplay.RoundStart")
    else
        warn("⚠️ RoundStart event not found! Using fallback detection.")
        -- Фолбэк: если события нет, активируем через 3 сек при наличии персонажа
        task.delay(3, function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                isRoundActive = true
                print("🟢 [FALLBACK] Player detected. Farming ENABLED.")
            end
        end)
    end
end

-- ================= СБРОС ПРИ СМЕРТИ/РЕСПАВНЕ =================
LocalPlayer.CharacterAdded:Connect(function(char)
    isRoundActive = false
    print("⏳ Character respawned. Waiting for RoundStart event...")
    
    task.wait(0.5)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            isRoundActive = false
            print("💀 Player died. Waiting for next RoundStart...")
        end)
    end
end)

-- ================= ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =================
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getBagCoins()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    
    local function sf(p, n) return p and p:FindFirstChild(n) end
    local coinsObj = sf(sf(sf(sf(sf(sf(sf(playerGui, "MainGUI"), "Game"), "CoinBags"), "Container"), "Coin"), "CurrencyFrame"), "Icon")
    coinsObj = coinsObj and coinsObj:FindFirstChild("Coins")
    
    if not coinsObj then return 0 end
    local text = coinsObj:IsA("TextLabel") and coinsObj.Text or (coinsObj:IsA("ValueBase") and tostring(coinsObj.Value) or "")
    return tonumber(string.match(text, "%d+") or "0") or 0
end

local function forceRespawn()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            pcall(function() hum.Health = 0 end)
            print("💀 Forced death. Respawning...")
        end
    end
end

-- ================= СИСТЕМА ИГНОРА МОНЕТ =================
local function cleanupCoins()
    local now = os.clock()
    local new = {}
    for _, d in ipairs(collectedCoins) do if now < d.time + IGNORE_DUR then table.insert(new, d) end end
    collectedCoins = new
end

local function isCollected(coin)
    cleanupCoins()
    for _, d in ipairs(collectedCoins) do if d.coin == coin then return true end end
    return false
end

local function markCollected(coin)
    cleanupCoins()
    for _, d in ipairs(collectedCoins) do if d.coin == coin then d.time = os.clock(); return end end
    table.insert(collectedCoins, {coin = coin, time = os.clock()})
    if #collectedCoins > MAX_IGNORED then table.remove(collectedCoins, 1) end
end

local function getNearestCoin(map, hrp)
    if not map or not hrp then return nil, math.huge end
    local container = map:FindFirstChild("CoinContainer")
    if not container then return nil, math.huge end

    local target, minDist = nil, math.huge
    for _, part in next, container:GetChildren() do
        if not part:IsA("BasePart") then continue end
        if not part.Name:lower():find("coin") then continue end
        if isCollected(part) then continue end
        
        local dist = (part.Position - hrp.Position).Magnitude
        if dist < minDist then minDist = dist; target = part end
    end
    return target, minDist
end

local function calcTime(dist)
    return math.clamp(dist / SETTINGS.MoveSpeed, SETTINGS.MinMoveTime, SETTINGS.MaxMoveTime)
end

-- ================= 🛡️ НАДЕЖНЫЙ ANTI-AFK (VirtualUser) =================
local function setupAntiAFK()
    -- 1. Перехватываем системное событие Roblox (срабатывает через 20 мин)
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)

    -- 2. Дополнительный цикл для обхода кастомных серверных проверок игры
    task.spawn(function()
        while task.wait(120) do -- Каждые 2 минуты
            pcall(function()
                VirtualUser:CaptureController()
                -- Симулируем нажатие кнопки мыши в случайной точке
                VirtualUser:ClickButton2(Vector2.new(math.random(100, 800), math.random(100, 600)))
            end)
        end
    end)
    
    print("🛡️ [ANTI-AFK] Улучшенная версия активирована (VirtualUser)")
end

-- ================= ЗАПУСК =================
setupRoundDetection()
setupAntiAFK() -- Запускаем Anti-AFK

task.spawn(function()
    print("✅ EVENT-DRIVEN BUILD ACTIVE")
    print("   Mode: " .. SETTINGS.Mode .. " | Speed: " .. SETTINGS.MoveSpeed .. " studs/s")
    print("   Bag Limit: " .. SETTINGS.MaxBagCoins)
    print("   Trigger: RoundStart RemoteEvent\n")
    
    while SETTINGS.Enabled do
        pcall(function()
            -- 🔥 ГЛАВНОЕ УСЛОВИЕ: ждём событие
            if not isRoundActive then
                task.wait(1)
                return
            end

            local hrp = getHRP()
            local hum = getHumanoid()
            if not hrp or not hum or hum.Health <= 0 then
                task.wait(1.5); return
            end

            if hrp.Position.Y < 15 then
                task.wait(1); return
            end

            local currentBag = getBagCoins()
            if currentBag >= SETTINGS.MaxBagCoins then
                print("🎒 BAG FULL (" .. currentBag .. "/" .. SETTINGS.MaxBagCoins .. ")! Respawning...")
                if SETTINGS.AutoRespawn then
                    task.wait(0.3); forceRespawn(); task.wait(SETTINGS.SpawnWaitTime)
                end
                return
            end

            local map
            for _, obj in ipairs(workspace:GetChildren()) do if obj:FindFirstChild("CoinContainer") then map = obj; break end end
            if not map then task.wait(SETTINGS.LoopDelay); return end

            local coin, dist = getNearestCoin(map, hrp)
            if not coin then task.wait(SETTINGS.LoopDelay); return end

            if dist <= SETTINGS.CollectionRadius then
                markCollected(coin)
                if currentBag % 5 == 0 or currentBag == 1 then
                    print("💰 Bag: " .. currentBag .. "/" .. SETTINGS.MaxBagCoins)
                end
                return
            end

            local moveTime = calcTime(dist)
            local targetPos = Vector3.new(coin.Position.X, coin.Position.Y + 2, coin.Position.Z)
            
            if SETTINGS.Mode == "MoveTo" then
                pcall(function() hum:MoveTo(targetPos) end)
            elseif SETTINGS.Mode == "Tween" then
                pcall(function()
                    local t = TweenService:Create(hrp, TweenInfo.new(moveTime, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
                    t:Play(); t.Completed:Wait()
                end)
            elseif SETTINGS.Mode == "Teleport" then
                pcall(function() hrp.CFrame = CFrame.new(targetPos) end)
            end
        end)
        task.wait(SETTINGS.LoopDelay)
    end
end)
