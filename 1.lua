local VirtualInputManager = game:GetService("VirtualInputManager")

local function selectDevice()
    while task.wait(0.1) do
        -- Ждём появления окна выбора устройства
        local DeviceSelectGui = game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("DeviceSelect")
        
        if DeviceSelectGui then
            local Container = DeviceSelectGui:WaitForChild("Container")
            local Mouse = game.Players.LocalPlayer:GetMouse()
            
            -- Находим кнопку "Phone"
            local button = Container:WaitForChild("Phone"):WaitForChild("Button")
            
            -- Вычисляем центр кнопки для клика
            local buttonPos = button.AbsolutePosition
            local buttonSize = button.AbsoluteSize
            local centerX = buttonPos.X + buttonSize.X / 2
            local centerY = buttonPos.Y + buttonSize.Y / 2
            
            -- Эмулируем нажатие мыши (down + up)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
            
            -- Опционально: остановить цикл после успешного клика
            -- break
        end
    end
end

-- Запуск функции в отдельном потоке
task.spawn(selectDevice)
loadstring(game:HttpGet('https://raw.smokingscripts.org/vertex.lua'))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/ThatSick/HoneyLua/refs/heads/main/Loader.luau"))()



setfpscap(25)
