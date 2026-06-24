setfpscap(25)

--[[
Auto Farm + Auto Crate Open - MM2 | ULTIMATE BUILD
- Фарм монет (скорость 20 studs/sec)
- АВТО-ОТКРЫТИЕ КЕЙСОВ при 1000+ монет
- Реконнект через GuiService.ErrorMessageChanged
- NoClip ULTIMATE + Антигравитация
- YOffset = -3
]]

-- ================= 🛠️ СЕРВИСЫ =================
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ================= ⚙️ НАСТРОЙКИ =================
local SETTINGS = {
    Enabled = true,
    MoveSpeed = 20,
    CollectionRadius = 4.0,
    LoopDelay = 0.1,
    MaxBagCoins = 40,
    AutoRespawn = true,
    SpawnWaitTime = 2.0,
    YOffset = -3,
    ReconnectDelay = 2,
    
    -- 📦 АВТО-КЕЙСЫ
    AutoOpenCrates = true,
    CrateOpenDelay = 2.5,      -- Задержка между открытиями (защита от кика)
    MinCoinsForCrate = 1000,   -- Сколько монет нужно для открытия
}

local MAX_IGNORED = 10
local IGNORE_DUR = 3.0
local isReconnecting = false

-- ================= 📦 СПИСКИ ДЛЯ КЕЙСОВ =================
local CRATE_BOXES = {
    "MysteryBox1", "MysteryBox2",
    "KnifeBox1", "KnifeBox2", "KnifeBox3", "KnifeBox4", "KnifeBox5",
    "GunBox1", "GunBox2", "GunBox3",
    "MLG Box"
}

local CRATE_CURRENCIES = {"Coins", "Gems", "Key"}

-- ================= 📊 СЧЁТЧИК МОНЕТ =================
local depositedCoins = 0       -- Монеты, которые уже сданы (через респавн)
local totalCratesOpened = 0    -- Всего открытых кейсов
local isOpengingCrate = false  -- Флаг открытия кейса

-- Remote'ы для открытия
local Shop = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")
local OpenCrate = Shop:WaitForChild("OpenCrate")
local BoxController = Shop:WaitForChild("BoxController")

-- ================= 🔌 РЕКОННЕКТ (GUI ERROR) =================
local function forceReconnect(reason)
    if isReconnecting then return end
    isReconnecting = true
    
    print("🔌 Reconnecting: " .. tostring(reason))
    
    spawn(function()
        wait(SETTINGS.ReconnectDelay)
        local success = pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
        
        if not success then
            wait(2)
            pcall(function()
                TeleportService:Teleport(game.PlaceId)
            end)
        end
    end)
    
    while true do 
        wait(1) 
        if not LocalPlayer or not LocalPlayer.Parent then
            break
        end
    end
end

-- Метод 1: GuiService.ErrorMessageChanged ✅
GuiService.ErrorMessageChanged:Connect(function(errorMessage)
    if errorMessage and errorMessage ~= "" then
        forceReconnect("Error: " .. errorMessage)
    end
end)

-- Метод 2: PlayerRemoving
Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        forceReconnect("PlayerRemoving")
    end
end)

-- Метод 3: OnTeleport
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed or state == Enum.TeleportState.Started then
        forceReconnect("OnTeleport: " .. tostring(state))
    end
end)

-- Метод 4: Heartbeat проверка
local consecutiveFailures = 0
RunService.Heartbeat:Connect(function()
    if not LocalPlayer or not LocalPlayer.Parent then
        consecutiveFailures = consecutiveFailures + 1
        if consecutiveFailures >= 3 and not isReconnecting then
            forceReconnect("Heartbeat: Player not found")
        end
    else
        consecutiveFailures = 0
    end
end)

-- ================= 🖱️ ВЫБОР УСТРОЙСТВА =================
local function selectDevice()
    while wait(0.1) do
        local DeviceSelectGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("DeviceSelect")
        if DeviceSelectGui then
            local Container = DeviceSelectGui:WaitForChild("Container")
            local button = Container:WaitForChild("Phone"):WaitForChild("Button")
            local bp = button.AbsolutePosition
            local bs = button.AbsoluteSize
            VirtualInputManager:SendMouseButtonEvent(bp.X + bs.X/2, bp.Y + bs.Y/2, 0, true, game, 1)
            wait(0.1)
            VirtualInputManager:SendMouseButtonEvent(bp.X + bs.X/2, bp.Y + bs.Y/2, 0, false, game, 1)
            break
        end
    end
end
spawn(selectDevice)
wait(10)

-- ================= 🔄 СОСТОЯНИЕ =================
local isRoundActive = false
local collectedCoins = {}
local currentTween = nil
local isMoving = false

-- ================= 🚫 NOCLIP ULTIMATE + АНТИГРАВИТАЦИЯ =================
local noclipActive = false
local antiGravForce = nil

local function setupAntiGravity(hrp)
    if antiGravForce then pcall(function() antiGravForce:Destroy() end) end
    
    local att = hrp:FindFirstChild("AntiGravAttachment")
    if not att then
        att = Instance.new("Attachment")
        att.Name = "AntiGravAttachment"
        att.Parent = hrp
    end
    
    local vf = Instance.new("VectorForce")
    vf.Name = "AntiGravity"
    vf.Attachment0 = att
    vf.Force = Vector3.new(0, hrp.AssemblyMass * 196.2, 0)
    vf.RelativeTo = Enum.ActuatorRelativeTo.World
    vf.ApplyAtCenterOfMass = true
    vf.Parent = hrp
    
    antiGravForce = vf
end

local function removeAntiGravity()
    if antiGravForce then pcall(function() antiGravForce:Destroy() end); antiGravForce = nil end
end

local function applyUltimateNoClip(character)
    if not character then return end
    
    pcall(function()
        PhysicsService:RegisterCollisionGroup("UltimateNC")
        PhysicsService:CollisionGroupSetCollidable("UltimateNC", "Default", false)
    end)
    
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = true
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        for _, state in ipairs({
            Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Freefall,
            Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Landed,
            Enum.HumanoidStateType.Running, Enum.HumanoidStateType.RunningNoPhysics,
            Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Swimming,
        }) do pcall(function() hum:SetStateEnabled(state, false) end) end
    end
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Massless = true
            pcall(function() part.CollisionGroup = "UltimateNC" end)
        end
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp and not antiGravForce then setupAntiGravity(hrp) end
end

local function enableNoClip() if noclipActive then return end; noclipActive = true end

local function disableNoClip()
    if not noclipActive then return end
    noclipActive = false
    
    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
    isMoving = false
    removeAntiGravity()
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        for _, state in ipairs({
            Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Freefall,
            Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Landed,
            Enum.HumanoidStateType.Running, Enum.HumanoidStateType.RunningNoPhysics,
            Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Swimming,
        }) do pcall(function() hum:SetStateEnabled(state, true) end) end
    end
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
            part.Massless = false
            pcall(function() part.CollisionGroup = "Default" end)
        end
    end
end

RunService.Heartbeat:Connect(function()
    if noclipActive then
        pcall(function()
            applyUltimateNoClip(LocalPlayer.Character)
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and antiGravForce then
                antiGravForce.Force = Vector3.new(0, hrp.AssemblyMass * 196.2, 0)
            end
        end)
    end
end)

-- ================= 📡 ОБНАРУЖЕНИЕ РАУНДА =================
local function setupRoundDetection()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local gameplay = remotes and remotes:FindFirstChild("Gameplay")
    local roundStart = gameplay and gameplay:FindFirstChild("RoundStart")

    if roundStart and roundStart:IsA("RemoteEvent") then
        roundStart.OnClientEvent:Connect(function()
            isRoundActive = true
            enableNoClip()
        end)
    else
        delay(3, function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                isRoundActive = true
                enableNoClip()
            end
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    isRoundActive = false
    disableNoClip()
    
    wait(1)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function() isRoundActive = false; disableNoClip() end)
    end
end)

-- ================= 🛠️ ВСПОМОГАТЕЛЬНЫЕ =================
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getBagCoins()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    local function sf(p, n) return p and p:FindFirstChild(n) end
    local obj = sf(sf(sf(sf(sf(sf(sf(playerGui, "MainGUI"), "Game"), "CoinBags"), "Container"), "Coin"), "CurrencyFrame"), "Icon")
    obj = obj and obj:FindFirstChild("Coins")
    if not obj then return 0 end
    local text = obj:IsA("TextLabel") and obj.Text or ""
    return tonumber(string.match(text, "%d+") or "0") or 0
end

local function forceRespawn()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            -- Сохраняем монеты в общий баланс перед респавном
            local currentBag = getBagCoins()
            if currentBag > 0 then
                depositedCoins = depositedCoins + currentBag
            end
            pcall(function() hum.Health = 0 end)
        end
    end
end

-- ================= 🪙 ИГНОР МОНЕТ =================
local function isCollected(coin)
    local now = tick()
    for _, d in ipairs(collectedCoins) do if d.coin == coin and now < d.time + IGNORE_DUR then return true end end
    return false
end

local function markCollected(coin)
    table.insert(collectedCoins, {coin = coin, time = tick()})
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

-- ================= 🎯 TWEEN =================
local function tweenToTarget(hrp, targetPos)
    if currentTween then pcall(function() currentTween:Cancel() end) end
    
    local dist = (targetPos - hrp.Position).Magnitude
    local moveTime = math.max(dist / SETTINGS.MoveSpeed, 0.1)
    
    local tweenInfo = TweenInfo.new(moveTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
    isMoving = true
    
    currentTween.Completed:Connect(function() isMoving = false; currentTween = nil end)
    currentTween:Play()
end

-- ================= 📦 АВТО-ОТКРЫТИЕ КЕЙСОВ =================
local function openRandomCrate()
    if isOpengingCrate then return false end
    isOpengingCrate = true
    
    local boxId = CRATE_BOXES[math.random(1, #CRATE_BOXES)]
    local success = false
    
    for _, currency in ipairs(CRATE_CURRENCIES) do
        local ok, result = pcall(function()
            return OpenCrate:InvokeServer(boxId, "MysteryBox", currency)
        end)
        
        if ok and result then
            pcall(function()
                BoxController:Fire({{
                    MysteryBoxId = boxId,
                    RewardedItemId = result
                }})
            end)
            print(string.format("📦 [CRATE] %s | %s | Выпало: %s", boxId, currency, tostring(result)))
            success = true
            break
        end
    end
    
    isOpengingCrate = false
    return success
end

-- Отдельный поток для автооткрытия кейсов
local function autoCrateLoop()
    while SETTINGS.AutoOpenCrates and SETTINGS.Enabled do
        wait(SETTINGS.CrateOpenDelay)
        
        -- Проверяем баланс: сданные монеты + текущий мешок
        local currentBag = getBagCoins()
        local totalCoins = depositedCoins + currentBag
        
        if totalCoins >= SETTINGS.MinCoinsForCrate then
            print(string.format("💰 Баланс: %d монет → Открываю кейс!", totalCoins))
            
            local success = openRandomCrate()
            
            if success then
                depositedCoins = depositedCoins - SETTINGS.MinCoinsForCrate
                if depositedCoins < 0 then depositedCoins = 0 end
                totalCratesOpened = totalCratesOpened + 1
                print(string.format("📊 Всего открыто кейсов: %d | Остаток: %d монет", 
                    totalCratesOpened, depositedCoins + getBagCoins()))
            else
                print("❌ Не удалось открыть кейс (нет валюты?)")
            end
        end
    end
end

-- ================= 🛡️ ANTI-AFK =================
spawn(function()
    while wait(120) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(math.random(100, 800), math.random(100, 600)))
        end)
    end
end)

-- ================= 🚀 ЗАПУСК =================
setupRoundDetection()

-- Запускаем поток авто-кейсов
spawn(autoCrateLoop)

local coinCounter = 0
local lastTarget = nil

spawn(function()
    print("✅ AUTO FARM + AUTO CRATE ACTIVE")
    print("   Speed: " .. SETTINGS.MoveSpeed .. " | YOffset: " .. SETTINGS.YOffset)
    print("   📦 Auto Crates: каждые " .. SETTINGS.MinCoinsForCrate .. " монет")
    print("   🔌 Auto-Reconnect: GuiService + PlayerRemoving + Heartbeat")
    print("")
    
    while SETTINGS.Enabled do
        pcall(function()
            if not isRoundActive then wait(1) return end

            local hrp = getHRP()
            if not hrp then wait(1) return end

            if hrp.Position.Y < -50 then
                if currentTween then currentTween:Cancel(); currentTween = nil end
                isMoving = false
                hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
                wait(2)
                return
            end

            local currentBag = getBagCoins()
            if currentBag >= SETTINGS.MaxBagCoins then
                if currentTween then currentTween:Cancel(); currentTween = nil end
                isMoving = false
                if SETTINGS.AutoRespawn then
                    wait(0.3); forceRespawn(); wait(SETTINGS.SpawnWaitTime)
                end
                return
            end

            local map
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:FindFirstChild("CoinContainer") then map = obj; break end
            end
            if not map then wait(SETTINGS.LoopDelay); return end

            local coin, dist = getNearestCoin(map, hrp)
            
            if not coin then lastTarget = nil; wait(SETTINGS.LoopDelay); return end

            local targetPos = Vector3.new(coin.Position.X, coin.Position.Y + SETTINGS.YOffset, coin.Position.Z)

            if dist <= SETTINGS.CollectionRadius then
                markCollected(coin)
                lastTarget = nil
                coinCounter = coinCounter + 1
                
                -- Логи каждые 10 монет
                if coinCounter % 10 == 0 then
                    print(string.format("💰 Собрано: %d монет | Мешок: %d/%d | Сдано: %d", 
                        coinCounter, currentBag, SETTINGS.MaxBagCoins, depositedCoins))
                end
                return
            end

            if not isMoving or lastTarget ~= coin then
                lastTarget = coin
                tweenToTarget(hrp, targetPos)
            end
        end)
        
        wait(SETTINGS.LoopDelay)
    end
end)
