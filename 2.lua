-- MM2 Auto Random Crate Opener (БЕЗ require - БЕЗОШИБОЧНЫЙ)
local Shop = game.ReplicatedStorage.Remotes.Shop

-- 📦 Список всех ящиков
local boxes = {
    "MysteryBox1", "MysteryBox2",
    "KnifeBox1", "KnifeBox2", "KnifeBox3", "KnifeBox4", "KnifeBox5",
    "GunBox1", "GunBox2", "GunBox3",
    "MLG Box"
}

-- 💰 Валюты по приоритету
local currencies = {"Coins", "Gems", "Key"}

-- ⚙️ Настройки
local CHECK_DELAY = 2.5   -- Задержка между открытиями
local WAIT_DELAY = 5      -- Задержка при ожидании денег

-- 🎲 Открытие одного рандомного кейса
local function openRandomCrate()
    local boxId = boxes[math.random(1, #boxes)]
    
    for _, currency in ipairs(currencies) do
        local ok, result = pcall(function()
            return Shop.OpenCrate:InvokeServer(boxId, "MysteryBox", currency)
        end)
        
        if ok and result then
            pcall(function()
                Shop.BoxController:Fire({{MysteryBoxId = boxId, RewardedItemId = result}})
            end)
            print("✅", boxId, "|", currency, "| Выпало:", result)
            return true
        end
    end
    
    return false
end

-- 🚀 БЕСКОНЕЧНЫЙ ЦИКЛ
print("🔥 MM2 Auto Opener запущен (БЕЗОШИБОЧНЫЙ)")
print("💡 Режим: проверка по факту открытия")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

local openedCount = 0
local failedCount = 0
local waitingForMoney = false

while true do
    local success = openRandomCrate()
    
    if success then
        if waitingForMoney then
            print("\n💰 Деньги появились!")
            waitingForMoney = false
        end
        
        openedCount = openedCount + 1
        print("📊 Открыто: " .. openedCount .. " | Ошибок: " .. failedCount)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        task.wait(CHECK_DELAY)
    else
        if not waitingForMoney then
            print("⏳ Нет денег/ключей. Ожидаю...")
            waitingForMoney = true
        end
        
        failedCount = failedCount + 1
        task.wait(WAIT_DELAY)
    end
end
