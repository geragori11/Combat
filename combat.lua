return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    
    local CombatTab = Window:CreateTab("COMBAT", 4483362458)
    
    local HitboxEnabled = false
    local HitboxSize = 15
    local OriginalSizes = {} -- Сюда сохраняем заводские параметры головы
    
    CombatTab:CreateSection("Hitbox Assistant")
    
    -- Переключатель функции
    CombatTab:CreateToggle({
        Name = "Увеличить хитбокс Мардера",
        CurrentValue = false,
        Flag = "MurdererHitboxToggle",
        Callback = function(Value)
            HitboxEnabled = Value
            if not Value then
                -- При выключении возвращаем всем Мардерам их нормальную голову
                for player, data in pairs(OriginalSizes) do
                    if player.Character and player.Character:FindFirstChild("Head") then
                        local head = player.Character.Head
                        head.Size = data.Size
                        head.Transparency = data.Transparency
                        head.CanCollide = data.CanCollide
                    end
                end
                table.clear(OriginalSizes)
            end
        end
    })
    
    -- Ползунок размеров
    CombatTab:CreateSlider({
        Name = "Размер хитбокса (Головы)",
        Range = {2, 40},
        Increment = 1,
        Suffix = " studs",
        CurrentValue = 15,
        Flag = "HitboxSizeSlider",
        Callback = function(Value)
            HitboxSize = Value
        end
    })
    
    -- Цикл рендера для постоянного контроля размера
    RunService.RenderStepped:Connect(function()
        if not HitboxEnabled then return end
        
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character then
                -- Проверяем, Мардер ли это сейчас
                local isMurderer = (Player.Character:FindFirstChild("Knife") or 
                                   (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Knife")))
                
                local head = Player.Character:FindFirstChild("Head")
                if head and head:IsA("BasePart") then
                    if isMurderer then
                        -- Запоминаем оригинал перед тем как раздуть голову
                        if not OriginalSizes[Player] then
                            OriginalSizes[Player] = {
                                Size = head.Size,
                                Transparency = head.Transparency,
                                CanCollide = head.CanCollide
                            }
                        end
                        
                        -- Увеличиваем голову (хитбокс)
                        head.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                        head.Transparency = 0.6 -- Делаем полупрозрачной кубической зоной для наглядности
                        head.CanCollide = false -- Чтобы огромная голова не толкала другие предметы/игроков
                        head.Massless = true    -- Убираем вес, чтобы не ломать физику ходьбы Мардера на твоем экране
                    else
                        -- Если раунд закончился или он дропнул нож, возвращаем всё назад
                        if OriginalSizes[Player] then
                            head.Size = OriginalSizes[Player].Size
                            head.Transparency = OriginalSizes[Player].Transparency
                            head.CanCollide = OriginalSizes[Player].CanCollide
                            OriginalSizes[Player] = nil
                        end
                    end
                end
            end
        end
    end)
end
