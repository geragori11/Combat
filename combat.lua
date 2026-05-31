return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    
    local CombatTab = Window:CreateTab("COMBAT", 4483362458)
    
    local AimEnabled = false
    local AimKeyName = nil -- Убрал дефолтную клавишу
    
    CombatTab:CreateSection("Aim Assistant")
    
    CombatTab:CreateToggle({
        Name = "Включить Aim Assistant",
        CurrentValue = false,
        Flag = "AimAssistToggle",
        Callback = function(Value)
            AimEnabled = Value
        end
    })
    
    CombatTab:CreateKeybind({
        Name = "Выберите клавишу для наведения",
        CurrentKeybind = nil, -- По умолчанию пусто
        Flag = "AimAssistKey",
        Callback = function(Keybind)
            AimKeyName = Keybind -- Сохраняем как объект Enum
        end,
    })
    
    RunService.RenderStepped:Connect(function()
        -- Проверяем, что AimEnabled включен, клавиша выбрана и она зажата
        if AimEnabled and AimKeyName and UserInputService:IsKeyDown(AimKeyName) then
            for _, Player in ipairs(Players:GetPlayers()) do
                if Player ~= LocalPlayer and Player.Character then
                    -- Проверка на Мардера
                    local isMurderer = (Player.Character:FindFirstChild("Knife") or 
                                       (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Knife")))
                    
                    if isMurderer then
                        local root = Player.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, root.Position)
                        end
                    end
                end
            end
        end
    end)
end
