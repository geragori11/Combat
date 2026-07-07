-- =========================================================================
-- Murder Mystery 2: Оптимизированный скрипт (ОБНОВЛЕН ПОД REPLICATEDSTORAGE)
-- Библиотека интерфейса: Rayfield UI
-- =========================================================================

return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    local Camera = workspace.CurrentCamera
    
    local CombatTab = Window:CreateTab("COMBAT", 4483362458)
    
    -- --- НАСТРОЙКИ ХИТБОКСА ---
    local HitboxEnabled = false
    local HitboxSize = 15
    local OriginalSizes = {} 

    -- --- НАСТРОЙКИ TRIGGERBOT ---
    local TriggerBotEnabled = false
    local LastTriggerShotTime = 0

    -- --- НАСТРОЙКИ YARHM AIMBOT ---
    local autoShooting = false
    local shootOffset = 5
    local offsetToPingMult = 1
    local predictionAIEngine = false
    local predictionOngoing = false
    local predictionCooldown = false

    local fu = {
        notification = function(message)
            print("[YARHM]: " .. tostring(message))
        end
    }

    -- ==========================================
    -- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ПОИСКА РОЛЕЙ
    -- ==========================================
    local function findMurderer()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and (player.Character:FindFirstChild("Knife") or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife"))) then
                return player
            end
        end
        return nil
    end

    local function findSheriff()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and (player.Character:FindFirstChild("Gun") or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Gun"))) then
                return player
            end
        end
        return nil
    end

    -- ==========================================
    -- АЛГОРИТМ УПРЕЖДЕНИЯ (PREDICTION)
    -- ==========================================
    local function getPredictedPosition(player, shootOffset)
        local usingBasicPred = not predictionAIEngine
        if predictionOngoing then
            usingBasicPred = true
        end
        
        pcall(function()
            if player.Character then
                player = player.Character
            end
        end)
        
        local playerHRP = player:FindFirstChild("UpperTorso") or player:FindFirstChild("HumanoidRootPart")
        local playerHum = player:FindFirstChild("Humanoid")
        if not playerHRP or not playerHum then
            return Vector3.new(0,0,0)
        end
    
        local playerPosition = playerHRP.Position
        local velocity = playerHRP.AssemblyLinearVelocity or Vector3.new()
        local playerMoveDirection = playerHum.MoveDirection
        
        local predictedPosition = playerHRP.Position + (velocity * Vector3.new(0.75, 0.5, 0.75)) * (shootOffset / 15) + playerMoveDirection * shootOffset
        
        local ping = 0.05
        pcall(function() ping = LocalPlayer:GetNetworkPing() end)
        predictedPosition = predictedPosition * (((ping * 1000) * ((offsetToPingMult - 1) * 0.01)) + 1)
    
        return predictedPosition
    end

    -- ==========================================
    -- ФУНКЦИЯ МГНОВЕННОГО ВЫСТРЕЛА (ДЛЯ БИНДА)
    -- ==========================================
    local function performInstantShot()
        local murderer = findMurderer()
        if not murderer or not murderer.Character then
            fu.notification("Мардер не найден или еще не взял нож!")
            return
        end

        if not LocalPlayer.Character:FindFirstChild("Gun") then
            if LocalPlayer.Backpack:FindFirstChild("Gun") then
                LocalPlayer.Character.Humanoid:EquipTool(LocalPlayer.Backpack.Gun)
                task.wait(0.15)
            else
                fu.notification("У вас нет пистолета!")
                return
            end
        end

        if not LocalPlayer.Character:FindFirstChild("Gun") then
            fu.notification("Ошибка экипировки пистолета!")
            return
        end

        fu.notification("Выстрел по кнопке/бинду!")
        local predictedPosition = getPredictedPosition(murderer, shootOffset)
        
        -- Сборка аргументов для нового RemoteEvent
        local args = {
            [1] = 1,
            [2] = predictedPosition,
            [3] = "AH2"
        }
        
        -- ОТПРАВКА НА НОВЫЙ ХУК ИЗ ReplicatedStorage
        pcall(function()
            ReplicatedStorage.WeaponEvents.GunBeam:FireServer(unpack(args))
        end)
    end

    -- ==========================================
    -- ПОТОК АВТО-ВЫСТРЕЛА YARHM (AUTO-SHOOT)
    -- ==========================================
    task.spawn(function()
        while task.wait(0.5) do
            if findSheriff() == LocalPlayer and autoShooting then
                fu.notification("Auto-shooting started.")
                repeat
                    task.wait(0.1)
                    if not autoShooting then break end
                    
                    local murderer = findMurderer()
                    if not murderer or not murderer.Character then continue end
                    
                    local murdererHRP = murderer.Character:FindFirstChild("HumanoidRootPart") or murderer.Character:FindFirstChild("UpperTorso")
                    local characterRootPart = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Head"))
                    
                    if murdererHRP and characterRootPart then
                        local rayDirection = murdererHRP.Position - characterRootPart.Position
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
        
                        local hit = workspace:Raycast(characterRootPart.Position, rayDirection, raycastParams)
                        if not hit or hit.Instance:IsDescendantOf(murderer.Character) then 
                            fu.notification("Auto-shooting!")
                            
                            if not LocalPlayer.Character:FindFirstChild("Gun") then
                                if LocalPlayer.Backpack:FindFirstChild("Gun") then
                                    LocalPlayer.Character.Humanoid:EquipTool(LocalPlayer.Backpack.Gun)
                                    task.wait(0.1)
                                else
                                    continue
                                end
                            end
                            
                            local predictedPosition = getPredictedPosition(murderer, shootOffset)
                            local args = {
                                [1] = 1,
                                [2] = predictedPosition,
                                [3] = "AH2"
                            }
                            
                            -- ОТПРАВКА НА НОВЫЙ ХУК ИЗ ReplicatedStorage
                            pcall(function()
                                ReplicatedStorage.WeaponEvents.GunBeam:FireServer(unpack(args))
                            end)
                        end
                    end
                until findSheriff() ~= LocalPlayer or not autoShooting
            end
        end
    end)

    -- ==========================================
    -- UI ЭЛЕМЕНТЫ В COMBAT TAB (RAYFIELD)
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
        Name = "Размер хитбокса головы",
        Range = {2, 50},
        Increment = 1,
        Suffix = " studs",
        CurrentValue = 20,
        Flag = "HitboxSizeSlider",
        Callback = function(Value)
            HitboxSize = Value
        end
    })

    CombatTab:CreateSection("YARHM Auto-Shoot Aimbot")

    CombatTab:CreateToggle({
        Name = "Включить YARHM Авто-выстрел",
        CurrentValue = false,
        Flag = "YarhmAutoShootToggle",
        Callback = function(Value)
            autoShooting = Value
        end
    })

    CombatTab:CreateSlider({
        Name = "Смещение упреждения (Shoot Offset)",
        Range = {1, 15},
        Increment = 1,
        Suffix = " units",
        CurrentValue = 5,
        Flag = "YarhmShootOffsetSlider",
        Callback = function(Value)
            shootOffset = Value
        end
    })

    CombatTab:CreateKeybind({
        Name = "Клавиша мгновенного выстрела",
        CurrentKeybind = "R",
        Default = "R",        
        Keybind = "R",        
        HoldToInteract = false,
        Flag = "InstantShotKeybind",
        Callback = function()
            performInstantShot()
        end
    })

    CombatTab:CreateSection("Trigger Bot")

    CombatTab:CreateToggle({
        Name = "Включить Триггербот (При наведении)",
        CurrentValue = false,
        Flag = "TriggerBotToggle",
        Callback = function(Value)
            TriggerBotEnabled = Value
        end
    })

    -- ==========================================
    -- РАБОЧИЙ ЦИКЛ ХИТБОКСОВ И ТРИГГЕРБОТА
    -- ==========================================
    RunService.RenderStepped:Connect(function()
        if HitboxEnabled then
            for _, Player in ipairs(Players:GetPlayers()) do
                if Player ~= LocalPlayer and Player.Character then
                    local isMurderer = (Player.Character:FindFirstChild("Knife") or (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Knife")))
                    local head = Player.Character:FindFirstChild("Head")
                    
                    if head and head:IsA("BasePart") and head.Name == "Head" then
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

        if TriggerBotEnabled then
            local Gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
            if Gun and (tick() - LastTriggerShotTime > 0.4) then 
                local targetPart = Mouse.Target
                if targetPart then
                    local characterModel = targetPart:FindFirstAncestorOfClass("Model")
                    local hoveredPlayer = characterModel and Players:GetPlayerFromCharacter(characterModel)
                    
                    if hoveredPlayer and hoveredPlayer ~= LocalPlayer and hoveredPlayer.Character then
                        local isMurderer = (hoveredPlayer.Character:FindFirstChild("Knife") or (hoveredPlayer:FindFirstChild("Backpack") and hoveredPlayer.Backpack:FindFirstChild("Knife")))
                        local humanoid = hoveredPlayer.Character:FindFirstChildOfClass("Humanoid")
                        
                        if isMurderer and humanoid and humanoid.Health > 0 then
                            LastTriggerShotTime = tick()
                            Gun:Activate()
                        end
                    end
                end
            end
        end
    end)
end
