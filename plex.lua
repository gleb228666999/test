--[[
Universal Remote Spy Script
]]
local plrs = game:GetService("Players")
local lplr = plrs.LocalPlayer

local remotes = {}
local minimized = false
local GUI = {}

local settings = {
    Font = Enum.Font.SourceSans,
    Theme = "Dark",
    AdvancedMode = false
}

-- ✅ Функция генерации случайной строки (определена ПЕРЕД использованием)
local function generateRandomString()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local length = 10
    local randomString = ""
    math.randomseed(tick() * 1000)
    for i = 1, length do
        local randomIndex = math.random(1, #chars)
        randomString = randomString .. chars:sub(randomIndex, randomIndex)
    end
    return randomString
end

-- ✅ Функция обновления UI
local function refreshRemoteList()
    if not GUI.ScrollingFrame then return end
    
    for _, child in ipairs(GUI.ScrollingFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    for index, remote in ipairs(remotes) do
        local RemoteButton = Instance.new("TextButton", GUI.ScrollingFrame)
        RemoteButton.Size = UDim2.new(1, -16, 0, 30)
        RemoteButton.Position = UDim2.new(0, 8, 0, (index - 1) * 30)
        RemoteButton.BackgroundColor3 = settings.Theme == "Dark" and Color3.new(0.2, 0.2, 0.2) or Color3.new(0.8, 0.8, 0.8)
        RemoteButton.BorderSizePixel = 0
        RemoteButton.TextColor3 = settings.Theme == "Dark" and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
        RemoteButton.Text = remote.Name
        RemoteButton.Font = settings.Font
        RemoteButton.TextSize = 18
        RemoteButton.TextXAlignment = Enum.TextXAlignment.Left
        RemoteButton.MouseButton1Click:Connect(function()
            if setclipboard then
                pcall(function() setclipboard(remote:GetFullName()) end)
            end
        end)
    end
end

-- ✅ Создание GUI
local function createGUI()
    local guiName = generateRandomString()
    local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
    ScreenGui.Name = "PLEX_" .. guiName
    GUI.ScreenGui = ScreenGui

    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0, 400, 0, 300)
    Frame.Position = UDim2.new(0.5, -200, 0.5, -150)
    Frame.BackgroundColor3 = settings.Theme == "Dark" and Color3.new(0.1, 0.1, 0.1) or Color3.new(0.9, 0.9, 0.9)
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.Draggable = true
    GUI.Frame = Frame

    local TitleBar = Instance.new("Frame", Frame)
    TitleBar.Size = UDim2.new(1, 0, 0, 30)
    TitleBar.BackgroundColor3 = settings.Theme == "Dark" and Color3.new(0.2, 0.2, 0.2) or Color3.new(0.8, 0.8, 0.8)
    TitleBar.BorderSizePixel = 0

    local Title = Instance.new("TextLabel", TitleBar)
    Title.Size = UDim2.new(1, -30, 1, 0)
    Title.Position = UDim2.new(0, 5, 0, 0)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = settings.Theme == "Dark" and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    Title.Font = settings.Font
    Title.TextSize = 18
    Title.RichText = true
    Title.Text = "<b>PLEX v3</b> - <i>" .. guiName .. "</i>"

    local MinimizeButton = Instance.new("TextButton", TitleBar)
    MinimizeButton.Size = UDim2.new(0, 30, 1, 0)
    MinimizeButton.Position = UDim2.new(1, -30, 0, 0)
    MinimizeButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.TextColor3 = Color3.new(1, 1, 1)
    MinimizeButton.Text = "—"
    MinimizeButton.Font = settings.Font
    MinimizeButton.TextSize = 18

    local ScrollingFrame = Instance.new("ScrollingFrame", Frame)
    ScrollingFrame.Size = UDim2.new(1, 0, 1, -30)
    ScrollingFrame.Position = UDim2.new(0, 0, 0, 30)
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollingFrame.ScrollBarThickness = 8
    ScrollingFrame.BackgroundTransparency = 1
    ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    GUI.ScrollingFrame = ScrollingFrame

    MinimizeButton.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            ScrollingFrame.Visible = false
            Frame.Size = UDim2.new(0, 400, 0, 30)
        else
            ScrollingFrame.Visible = true
            Frame.Size = UDim2.new(0, 400, 0, 300)
        end
    end)
    
    return guiName
end

-- ✅ Логирование вызовов
local function logRemoteCall(remote, method, args)
    if not table.find(remotes, remote) then
        table.insert(remotes, remote)
        task.defer(refreshRemoteList)
    end

    print("Remote Call Detected:")
    print("Remote:", remote:GetFullName())
    print("Method:", method)
    print("Arguments:")
    for i, v in ipairs(args) do
        print(i, typeof(v), v)
    end

    if settings.AdvancedMode then
        print("Advanced Info:")
        if getcallingscript then
            local caller = getcallingscript()
            print("Caller:", caller and caller.Name or "N/A")
        end
    end
end

-- ✅ Сканирование remote'ов
local function scanRemotes(obj)
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            if not table.find(remotes, child) then
                table.insert(remotes, child)
            end
        end
        scanRemotes(child)
    end
end

-- ✅ Hook (с проверкой на поддержку)
local old_nc
if hookmetamethod and newcclosure then
    old_nc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if not (checkcaller and checkcaller()) and (method == "FireServer" or method == "InvokeServer") then
            logRemoteCall(self, method, args)
        end
        return old_nc(self, ...)
    end))
else
    warn("Ваш эксплойт не поддерживает hookmetamethod/newcclosure")
end

-- ✅ Инициализация (в правильном порядке!)
createGUI()
scanRemotes(game)
refreshRemoteList()

-- ✅ Отслеживание игроков
local function onPlayerAdded(player)
    local function scanChild(child)
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            if not table.find(remotes, child) then
                table.insert(remotes, child)
                task.defer(refreshRemoteList)
            end
        end
    end
    
    player.DescendantAdded:Connect(scanChild)
    if player.Character then
        player.Character.DescendantAdded:Connect(scanChild)
    end
end

plrs.PlayerAdded:Connect(onPlayerAdded)
for _, player in pairs(plrs:GetPlayers()) do
    onPlayerAdded(player)
end

print("✅ PLEX v3 loaded successfully!")
