local Shop = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Shop")
local OpenCrate = Shop:WaitForChild("OpenCrate")
local BoxController = Shop:WaitForChild("BoxController")

local BOX  = "Summer2026Box"
local CURS = {"SummerKey2026", "Shells", "BeachBalls2026"} -- внутренний ID первым

for i = 1, 40 do
    local opened = false
    for _, cur in ipairs(CURS) do
        local ok, item = pcall(function()
            return OpenCrate:InvokeServer(BOX, "MysteryBox", cur)
        end)
        if ok and item ~= nil and item ~= false then
            pcall(function()
                local payload = {{ MysteryBoxId = BOX, RewardedItemId = item }}
                if type(BoxController.FireServer) == "function" then
                    BoxController:FireServer(payload)
                else
                    BoxController:Fire(payload)
                end
            end)
            print(i .. "/" .. 10, "| валюта:", cur, "| выпало:", item)
            opened = true
            break
        end
    end
    if not opened then warn(i .. ": сервер отклонил все валюты (нет Shells на аккаунте?)") end
    wait(2.5)
end
