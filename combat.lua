return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    
    local CombatTab = Window:CreateTab("COMBAT", 4483362458)
    
    local HitboxEnabled = false
    local HitboxSize = 15
    local OriginalSizes = {} -- Сюда сохраняем стандартные размеры, чтобы вернуть их при выключении
    
    CombatTab:CreateSection("Hitbox Assistant")
    
    -- Переключатель функции
    CombatTab:CreateToggle({
        Name = "Увеличить хитбокс Мардера",
        CurrentValue = false,
        Flag = "MurdererHitboxToggle",
        Callback = function(Value)
            HitboxEnabled = Value
            if not Value then
                -- Если выключили — возвращаем всем Мардерам их исходный размер хитбокса
                for player, originalSize in pairs(OriginalSizes) do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        player.Character.HumanoidRootPart.Size = originalSize
                        player.Character.HumanoidRootPart.Transparency = 1 -- Возвращаем невидимость
                    end
                end
                table.clear(OriginalSizes)
            end
        end
    })
    
    -- Настройка размера хитбокса
    CombatTab:CreateSlider({
        Name = "Размер хитбокса (Размеры)",
        Range = {2, 50},
        Increment = 1,
        Suffix = " studs",
        CurrentValue = 15,
        Flag = "HitboxSizeSlider",
        Callback = function(Value)
            HitboxSize = Value
        end
    })
    
    -- Постоянное обновление в цикле рендера
    RunService.RenderStepped:Connect(function()
        if not HitboxEnabled then return end
        
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character then
                -- Проверка: является ли игрок Мардером (нож в руках или в рюкзаке)
                local isMurderer = (Player.Character:FindFirstChild("Knife") or 
                                   (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Knife")))
                
                local root = Player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    if isMurderer then
                        -- Запоминаем оригинальный размер перед изменением
                        if not OriginalSizes[Player] then
                            OriginalSizes[Player] = root.Size
                        end
                        -- Меняем размер и делаем его полупрозрачным для визуального контроля
                        root.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                        root.Transparency = 0.7 
                        root.CanCollide = false
                    else
                        -- Если игрок перестал быть мардером (или раунд закончился), возвращаем настройки
                        if OriginalSizes[Player] then
                            root.Size = OriginalSizes[Player]
                            root.Transparency = 1
                            OriginalSizes[Player] = nil
                        end
                    end
                end
            end
        end
    end)
end
