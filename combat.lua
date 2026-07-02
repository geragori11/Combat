return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    
    local CombatTab = Window:CreateTab("COMBAT", 4483362458)
    
    -- --- ПЕРЕМЕННЫЕ ХИТБОКСА ---
    local HitboxEnabled = false
    local HitboxSize = 15
    local OriginalSizes = {} 
    
    -- --- ПЕРЕМЕННЫЕ АВТОАИМА ---
    local AimEnabled = false
    local AimReactionTime = 0 -- Задержка в миллисекундах
    local AutoShootEnabled = false
    local AimTarget = nil
    local LastTarget = nil
    local TargetTime = 0
    local LastShotTime = 0

    -- ==========================================
    -- СЕКЦИЯ: HITBOX ASSISTANT
    -- ==========================================
    CombatTab:CreateSection("Hitbox Assistant")
    
    CombatTab:CreateToggle({
        Name = "Увеличить хитбокс Мардера",
        CurrentValue = false,
        Flag = "MurdererHitboxToggle",
        Callback = function(Value)
            HitboxEnabled = Value
            if not Value then
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

    -- ==========================================
    -- СЕКЦИЯ: SILENT AUTO AIM (НОВАЯ)
    -- ==========================================
    CombatTab:CreateSection("Silent Auto Aim")

    CombatTab:CreateToggle({
        Name = "Включить Автоаим (Silent)",
        CurrentValue = false,
        Flag = "AutoAimToggle",
        Callback = function(Value)
            AimEnabled = Value
            if not Value then
                AimTarget = nil
                LastTarget = nil
            end
        end
    })

    CombatTab:CreateSlider({
        Name = "Время реакции (Задержка)",
        Range = {0, 300},
        Increment = 10,
        Suffix = " ms",
        CurrentValue = 0,
        Flag = "AimReactionSlider",
        Callback = function(Value)
            AimReactionTime = Value
        end
    })

    CombatTab:CreateToggle({
        Name = "Автовыстрел (Auto Shoot)",
        CurrentValue = false,
        Flag = "AutoShootToggle",
        Callback = function(Value)
            AutoShootEnabled = Value
        end
    })

    -- ==========================================
    -- ЯДРО SILENT AIM (ПОДМЕНА ПОЛОЖЕНИЯ МЫШКИ)
    -- ==========================================
    local HooksSupported, err = pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                local TargetPart = AimTarget.Character:FindFirstChild("HumanoidRootPart") or AimTarget.Character:FindFirstChild("Head")
                if TargetPart and self == Mouse then
                    if key == "Hit" then
                        return TargetPart.CFrame
                    elseif key == "Target" then
                        return TargetPart
                    end
                end
            end
            return oldIndex(self, key)
        end)
    end)

    -- Резервный метод перехвата, если executor не поддерживает hookmetamethod
    if not HooksSupported then
        pcall(function()
            local mt = getrawmetatable(game)
            local oldIndex = mt.__index
            setreadonly(mt, false)
            mt.__index = newcclosure(function(self, key)
                if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                    local TargetPart = AimTarget.Character:FindFirstChild("HumanoidRootPart") or AimTarget.Character:FindFirstChild("Head")
                    if TargetPart and self == Mouse then
                        if key == "Hit" then
                            return TargetPart.CFrame
                        elseif key == "Target" then
                            return TargetPart
                        end
                    end
                end
                return oldIndex(self, key)
            end)
            setreadonly(mt, true)
        end)
    end

    -- ==========================================
    -- ЕДИНЫЙ ЦИКЛ ОБРАБОТКИ (RENDERSTEPPED)
    -- ==========================================
    RunService.RenderStepped:Connect(function()
        local CurrentMurderer = nil

        -- Проходим по игрокам один раз для оптимизации
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character then
                local isMurderer = (Player.Character:FindFirstChild("Knife") or 
                                   (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Knife")))
                
                if isMurderer then
                    local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        CurrentMurderer = Player
                    end
                end

                -- Логика хитбоксов (Твоя оригинальная функция)
                if HitboxEnabled then
                    local head = Player.Character:FindFirstChild("Head")
                    if head and head:IsA("BasePart") then
                        if isMurderer then
                            if not OriginalSizes[Player] then
                                OriginalSizes[Player] = {
                                    Size = head.Size,
                                    Transparency = head.Transparency,
                                    CanCollide = head.CanCollide
                                }
                            end
                            head.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                            head.Transparency = 0.6 
                            head.CanCollide = false 
                            head.Massless = true    
                        else
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
        end

        -- Логика расчёта таймингов Автоаима
        if AimEnabled and CurrentMurderer then
            if CurrentMurderer ~= LastTarget then
                LastTarget = CurrentMurderer
                TargetTime = tick() -- Сбрасываем таймер при новой цели
            end

            local elapsed = (tick() - TargetTime) * 1000 -- Переводим в миллисекунды
            if elapsed >= AimReactionTime then
                AimTarget = CurrentMurderer

                -- Автоматическая активация выстрела (если пушка в руках)
                if AutoShootEnabled then
                    local Gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
                    if Gun and (tick() - LastShotTime > 0.5) then -- Защита от спама/краша скрипта оружейного модуля
                        LastShotTime = tick()
                        Gun:Activate()
                    end
                end
            else
                AimTarget = nil
            end
        else
            LastTarget = nil
            AimTarget = nil
        end
    end)
end
