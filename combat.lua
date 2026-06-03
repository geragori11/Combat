return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
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
    
    -- УМНАЯ ФУНКЦИЯ: Гарантированно находит позицию прицела/мыши
    local function GetCustomMousePosition()
        local UISPos = UserInputService:GetMouseLocation()
        
        -- Если исполнитель выдает баг с 0,0 или мышь скрыта/залочена обзором камеры
        if UISPos.X == 0 and UISPos.Y == 0 then
            if Mouse.X ~= 0 or Mouse.Y ~= 0 then
                return Vector2.new(Mouse.X, Mouse.Y + 36)
            else
                -- Полный фолбэк: жестко берем центр экрана (куда направлена камера)
                return Camera.ViewportSize / 2
            end
        end
        return UISPos
    end
    
    -- Функция поиска ближайшего Мардера внутри круга FOV
    local function GetClosestMurdererInFOV()
        local Target = nil
        local ClosestDist = FOVRadius
        local MousePos = GetCustomMousePosition() -- Используем умную позицию
        
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
                            -- Считаем расстояние от круга до цели
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
    
    -- Постоянное обновление позиции и видимости круга в каждом кадре
    RunService.RenderStepped:Connect(function()
        if ShowFOV then
            FOVCircle.Position = GetCustomMousePosition()
            FOVCircle.Visible = true -- Принудительно держим видимым
        else
            FOVCircle.Visible = false
        end
    end)
end
