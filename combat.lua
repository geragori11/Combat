return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    
    local CombatTab = Window:CreateTab("COMBAT", 4483362458)
    
    local AimEnabled = false
    local AimKeyName = "E"
    
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
        Name = "Кнопка наведения",
        CurrentKeybind = "E",
        Flag = "AimAssistKey",
        Callback = function(Keybind)
            AimKeyName = tostring(Keybind):gsub("Enum.KeyCode.", "")
        end,
    })
    
    RunService.RenderStepped:Connect(function()
        if AimEnabled and UserInputService:IsKeyDown(Enum.KeyCode[AimKeyName]) then
            for _, Player in ipairs(Players:GetPlayers()) do
                if Player ~= LocalPlayer and Player.Character then
                    local Hum = Player.Character:FindFirstChild("Humanoid")
                    local root = Player.Character:FindFirstChild("HumanoidRootPart")
                    if Hum and root and (Player.Character:FindFirstChild("Knife") or Player.Backpack:FindFirstChild("Knife")) then
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, root.Position)
                    end
                end
            end
        end
    end)
    print("Combat Tab Loaded Successfully")
end
