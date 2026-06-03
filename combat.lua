return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    local Mouse = LocalPlayer:GetMouse()
    
    local CombatTab = Window:CreateTab("COMBAT", 4483362458)
    
    local SilentAimEnabled = false
    local ShowFOV = false
    local FOVRadius = 100
    
    -- Создаем круг FOV
    local FOVCircle = Drawing.new("Circle")
    FOVCircle.Color = Color3.fromRGB(255, 0, 0)
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 64
    FOVCircle.Radius = FOVRadius
    FOVCircle.Filled = false
    FOVCircle.Visible = false
    
    CombatTab:CreateSection("Silent Aim Assistant")
    
    -- Включение/Выключение Сайлент Аима
    CombatTab:CreateToggle({
        Name = "Включить Silent Aim (На Мардера)",
        CurrentValue = false,
        Flag = "SilentAimToggle",
        Callback = function(Value)
            SilentAimEnabled = Value
        end
    })
    
    -- Тумблер видимости круга
    CombatTab:CreateToggle({
        Name = "Показать круг FOV",
        CurrentValue = false,
        Flag = "FOVVisibleToggle",
        Callback = function(Value)
            ShowFOV = Value
            FOVCircle.Visible = Value
        end
    })
    
    -- Ползунок радиуса круга
    CombatTab:CreateSlider({
        Name = "Радиус круга (Зона захвата)",
        Range = {30, 400},
        Increment = 5,
        Suffix = " px",
        CurrentValue = 100,
        Flag = "FOVRadiusSlider",
        Callback = function(Value)
            FOVRadius = Value
            FOVCircle.Radius = Value
        end
    })
    
    -- Функция поиска ближайшего Мардера внутри круга FOV
    local function GetClosestMurdererInFOV()
        local Target = nil
        local ClosestDist = FOVRadius
        -- ФИКС: Используем Mouse.X и Mouse.Y + 36 для точного определения позиции мыши
        local MousePos = Vector2.new(Mouse.X, Mouse.Y + 36)
        
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character then
                -- Проверяем роль (наличие ножа)
                local isMurderer = Player.Character:FindFirstChild("Knife") or 
                                   (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Knife"))
                
                if isMurderer then
                    local root = Player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local ScreenPos, OnScreen = Camera:WorldToViewportPoint(root.Position)
                        if OnScreen then
                            -- Считаем расстояние от курсора до цели на экране
                            local Distance = (Vector2.new(ScreenPos.X, ScreenPos.Y) - MousePos).Magnitude
                            if Distance <= ClosestDist then
                                Target = root
                                ClosestDist = Distance
                            end
                        end
                    end
                end
            end
        end
        return Target
    end
    
    -- Перехватываем выстрелы игры через метатаблицы
    local OldIndex
    OldIndex = hookmetamethod(game, "__index", function(Self, Key)
        if SilentAimEnabled and not checkcaller() then
            if Self == Mouse and (Key == "Hit" or Key == "Target") then
                local TargetPart = GetClosestMurdererInFOV()
                if TargetPart then
                    if Key == "Hit" then
                        return TargetPart.CFrame
                    elseif Key == "Target" then
                        return TargetPart
                    end
                end
            end
        end
        return OldIndex(Self, Key)
    end)
    
    -- ФИКС: Привязываем круг к координатам мыши в каждом кадре с учетом смещения
    RunService.RenderStepped:Connect(function()
        if ShowFOV then
            FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
        else
            FOVCircle.Visible = false
        end
    end)
end
