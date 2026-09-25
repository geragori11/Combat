-- =========================================================================
-- Murder Mystery 2: Auto-Shoot (Автовыстрел по Мардеру) + UI Wrapper
-- Все аимботы удалены (Silent Aim, Hitbox Assistant, Trigger Bot, HvH Snap Aim).
-- Оставлен один автовыстрел с динамическим упреждением (дистанция + пинг).
-- Также: Kill All, Kill Sheriff, Kill Target Player (с выбором из Dropdown).
-- =========================================================================

return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local StarterGui = game:GetService("StarterGui")
    local LocalPlayer = Players.LocalPlayer

    local CombatTab = Window:CreateTab("COMBAT", 4483362458)

    -- --- НАСТРОЙКИ АВТОВЫСТРЕЛА ---
    local AutoShootEnabled = false
    local AutoShootEquip = true
    local IsShooting = false
    local shootOffset = 2.1          -- Упреждение по умолчанию
    local offsetToPingMult = 1       -- Множитель пинга
    local referenceDistance = 30     -- Эталонная дистанция, для которой shootOffset работает идеально
    local shootCooldown = 1.5        -- Задержка между выстрелами (сек)

    -- --- СОСТОЯНИЕ EXPLOITS ---
    local isKillingAll = false
    local isKillingMurderer = false
    local isKillingSheriff = false
    local isKillingTarget = false
    local SelectedPlayerName = ""

    local function Notify(Title, Text)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = Title or "Auto-Shoot",
                Text = Text or "",
                Duration = 2
            })
        end)
    end

    -- ==========================================
    -- 1. ПОИСК УБИЙЦЫ (Knife в руках или в Backpack)
    -- ==========================================
    local function findMurderer()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local backpack = player:FindFirstChild("Backpack")
                    if player.Character:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then
                        return player
                    end
                end
            end
        end
        return nil
    end

    -- ==========================================
    -- 2. ДИНАМИЧЕСКОЕ УПРЕЖДЕНИЕ (Дистанция + Относительная скорость + Пинг)
    -- ==========================================
    local function getPredictedPosition(targetPart, myChar, baseOffset)
        if not targetPart or not myChar then return Vector3.new(0, 0, 0) end

        local originPart = myChar:FindFirstChild("RightHand")
        if not originPart then return targetPart.Position end

        -- Надежнее всего брать скорость с HumanoidRootPart, так как анимации искажают скорость конечностей
        local targetHRP = targetPart.Parent and targetPart.Parent:FindFirstChild("HumanoidRootPart")
        local targetVelocity = targetHRP and targetHRP.AssemblyLinearVelocity or targetPart.AssemblyLinearVelocity

        local myHRP = myChar:FindFirstChild("HumanoidRootPart")
        local myVelocity = myHRP and myHRP.AssemblyLinearVelocity or Vector3.new(0, 0, 0)

        -- Дистанция до цели
        local distance = (targetPart.Position - originPart.Position).Magnitude

        -- Множитель дистанции: чем дальше враг, тем дольше летит пуля -> нужно большее упреждение
        local distanceMultiplier = distance / referenceDistance

        -- Относительная скорость (ваша скорость по отношению к скорости врага)
        local relativeVelocity = targetVelocity - myVelocity
        local directionToTarget = (targetPart.Position - originPart.Position).Unit
        local closingSpeed = relativeVelocity:Dot(directionToTarget)
        local timeAdjust = 1 + (closingSpeed / 150)

        -- Итоговый расчет времени полета снаряда до цели
        local predictionTime = (baseOffset / 16) * distanceMultiplier * timeAdjust

        -- Добавляем пинг
        local pingInSeconds = 0
        pcall(function() pingInSeconds = LocalPlayer:GetNetworkPing() end)
        local totalPredictionTime = math.max(0, predictionTime + pingInSeconds * offsetToPingMult)

        -- Итоговая позиция: Текущая позиция + (Скорость врага * Итоговое время предсказания)
        return targetPart.Position + (targetVelocity * totalPredictionTime)
    end

    -- ==========================================
    -- 3. ПРОВЕРКА ВИДИМОСТИ КАЖДОЙ ЧАСТИ ТЕЛА (Raycast)
    -- ==========================================
    local function getVisiblePart(targetCharacter)
        local myChar = LocalPlayer.Character
        if not myChar or not myChar:FindFirstChild("RightHand") then return nil end

        local origin = myChar.RightHand.Position

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {myChar} -- Игнорируем себя
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.IgnoreWater = true

        for _, part in ipairs(targetCharacter:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                local targetPos = part.Position
                local direction = (targetPos - origin).Unit * ((targetPos - origin).Magnitude + 2)
                local result = workspace:Raycast(origin, direction, raycastParams)

                if result and result.Instance and result.Instance:IsDescendantOf(targetCharacter) then
                    return part
                end
            end
        end

        return nil
    end

    -- ==========================================
    -- СОЗДАНИЕ ЭЛЕМЕНТОВ ИНТЕРФЕЙСА (UI)
    -- ==========================================
    CombatTab:CreateSection("Auto-Shoot (Автовыстрел по Мардеру)")

    CombatTab:CreateToggle({
        Name = "Включить Автовыстрел",
        CurrentValue = false,
        Flag = "AutoShootMasterToggle",
        Callback = function(Value)
            AutoShootEnabled = Value
            if not Value then IsShooting = false end
        end
    })

    CombatTab:CreateKeybind({
        Name = "Клавиша вкл/выкл (по умолчанию R)",
        CurrentKeybind = "R",
        HoldToInteract = false,
        Flag = "AutoShootKeybind",
        Callback = function()
            AutoShootEnabled = not AutoShootEnabled
            Notify("Автовыстрел (R)", AutoShootEnabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН")
        end
    })

    CombatTab:CreateSlider({
        Name = "Упреждение (Shoot Offset)",
        Range = {0, 10},
        Increment = 0.1,
        CurrentValue = 2.1,
        Flag = "AutoShootOffset",
        Callback = function(Value) shootOffset = Value end
    })

    CombatTab:CreateSlider({
        Name = "Множитель пинга",
        Range = {0, 5},
        Increment = 0.1,
        CurrentValue = 1,
        Flag = "AutoShootPingMult",
        Callback = function(Value) offsetToPingMult = Value end
    })

    CombatTab:CreateSlider({
        Name = "Эталонная дистанция (studs)",
        Range = {5, 100},
        Increment = 1,
        CurrentValue = 30,
        Flag = "AutoShootRefDistance",
        Callback = function(Value) referenceDistance = Value end
    })

    CombatTab:CreateSlider({
        Name = "Задержка между выстрелами (сек)",
        Range = {0.1, 5},
        Increment = 0.1,
        CurrentValue = 1.5,
        Flag = "AutoShootCooldown",
        Callback = function(Value) shootCooldown = Value end
    })

    CombatTab:CreateToggle({
        Name = "Авто-экипировка пистолета",
        CurrentValue = true,
        Flag = "AutoShootEquipToggle",
        Callback = function(Value) AutoShootEquip = Value end
    })

    -- --- РАЗДЕЛ: ЭКСПЛОЙТЫ ДЛЯ МАРДЕРА ---
    CombatTab:CreateSection("Murderer Exploits")

    CombatTab:CreateButton({
        Name = "Убить всех (Kill All)",
        Callback = function()
            if isKillingAll or isKillingSheriff or isKillingTarget then return end
            
            local char = LocalPlayer.Character
            if not char then return end
            
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local knife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
            
            if not knife then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "MM2 Exploit",
                        Text = "Вы не Мардер!",
                        Duration = 4
                    })
                end)
                return
            end
            
            isKillingAll = true
            
            if knife.Parent == backpack then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:EquipTool(knife)
                end
            end
            
            local originalCFrames = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    if root and hum and hum.Health > 0 then
                        originalCFrames[player] = root.CFrame
                    end
                end
            end
            
            local startTime = os.clock()
            local killConnection
            
            killConnection = RunService.RenderStepped:Connect(function()
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                
                if not myRoot or os.clock() - startTime >= 4 or not char:FindFirstChild("Knife") then
                    killConnection:Disconnect()
                    
                    for player, cframe in pairs(originalCFrames) do
                        if player.Character then
                            local root = player.Character:FindFirstChild("HumanoidRootPart")
                            if root then
                                root.CFrame = cframe
                            end
                        end
                    end
                    isKillingAll = false
                    return
                end
                
                local targetCFrame = myRoot.CFrame * CFrame.new(0, 0, -2)
                
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local root = player.Character:FindFirstChild("HumanoidRootPart")
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        if root and hum and hum.Health > 0 then
                            root.CFrame = targetCFrame
                        end
                    end
                end
                
                if knife and knife.Parent == char then
                    knife:Activate()
                end
            end)
        end
    })

    CombatTab:CreateButton({
        Name = "Убить Шерифа (Kill Sheriff)",
        Callback = function()
            if isKillingAll or isKillingSheriff or isKillingTarget then return end

            local char = LocalPlayer.Character
            if not char then return end

            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local knife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))

            if not knife then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "MM2 Exploit",
                        Text = "Вы не Мардер!",
                        Duration = 4
                    })
                end)
                return
            end

            -- Сканируем и ищем активного игрока с пистолетом
            local targetSheriff = nil
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hasGun = player.Character:FindFirstChild("Gun") or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Gun"))
                    if hasGun then
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            targetSheriff = player
                            break
                        end
                    end
                end
            end

            if not targetSheriff then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "MM2 Exploit",
                        Text = "Шериф не найден или мертв!",
                        Duration = 4
                    })
                end)
                return
            end

            isKillingSheriff = true

            if knife.Parent == backpack then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid:EquipTool(knife) end
            end

            local originalCFrame = nil
            local sRoot = targetSheriff.Character:FindFirstChild("HumanoidRootPart")
            if sRoot then originalCFrame = sRoot.CFrame end

            local startTime = os.clock()
            local sheriffKillConnection

            sheriffKillConnection = RunService.RenderStepped:Connect(function()
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                local sChar = targetSheriff.Character
                local curSRoot = sChar and sChar:FindFirstChild("HumanoidRootPart")
                local sHum = sChar and sChar:FindFirstChildOfClass("Humanoid")

                if not myRoot or os.clock() - startTime >= 4 or not curSRoot or not sHum or sHum.Health <= 0 or not char:FindFirstChild("Knife") then
                    sheriffKillConnection:Disconnect()
                    if curSRoot and originalCFrame then
                        curSRoot.CFrame = originalCFrame
                    end
                    isKillingSheriff = false
                    return
                end

                -- Стягиваем Шерифа локально под лезвие
                curSRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -2)

                if knife and knife.Parent == char then
                    knife:Activate()
                end
            end)
        end
    })

    -- Выпадающий список для выбора конкретного игрока
    local PlayerDropdown = CombatTab:CreateDropdown({
        Name = "Выбрать игрока для убийства",
        Options = {},
        CurrentOption = {},
        Flag = "KillTargetDropdown",
        Callback = function(Value)
            -- Rayfield передает таблицу выбранных опций (а не строку)
            if type(Value) == "table" then Value = Value[1] end
            SelectedPlayerName = Value or ""
        end
    })

    -- Асинхронный поток для автообновления списка игроков раз в 2 секунды
    task.spawn(function()
        while task.wait(2) do
            local playerNames = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    table.insert(playerNames, p.Name)
                end
            end
            pcall(function()
                PlayerDropdown:Refresh(playerNames, true)
            end)
        end
    end)

    CombatTab:CreateButton({
        Name = "Убить выбранного игрока",
        Callback = function()
            if isKillingAll or isKillingSheriff or isKillingTarget or SelectedPlayerName == "" then return end

            local char = LocalPlayer.Character
            if not char then return end

            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local knife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))

            if not knife then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "MM2 Exploit",
                        Text = "Вы не Мардер!",
                        Duration = 4
                    })
                end)
                return
            end

            local targetPlayer = Players:FindFirstChild(SelectedPlayerName)
            if not targetPlayer or not targetPlayer.Character then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "MM2 Exploit",
                        Text = "Цель покинула сервер или не найдена!",
                        Duration = 4
                    })
                end)
                return
            end

            local tHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not tHum or tHum.Health <= 0 then return end

            isKillingTarget = true

            if knife.Parent == backpack then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid:EquipTool(knife) end
            end

            local originalCFrame = nil
            local tRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if tRoot then originalCFrame = tRoot.CFrame end

            local startTime = os.clock()
            local targetKillConnection

            targetKillConnection = RunService.RenderStepped:Connect(function()
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                local tChar = targetPlayer.Character
                local curTRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                local currentTHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

                if not myRoot or os.clock() - startTime >= 4 or not curTRoot or not currentTHum or currentTHum.Health <= 0 or not char:FindFirstChild("Knife") then
                    targetKillConnection:Disconnect()
                    if curTRoot and originalCFrame then
                        curTRoot.CFrame = originalCFrame
                    end
                    isKillingTarget = false
                    return
                end

                -- Стягиваем цель прямо к ножу
                curTRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -2)

                if knife and knife.Parent == char then
                    knife:Activate()
                end
            end)
        end
    })

    -- --- РАЗДЕЛ: ЭКСПЛОЙТЫ ДЛЯ ШЕРИФА ---
    CombatTab:CreateSection("Sheriff Exploits")

    CombatTab:CreateButton({
        Name = "Убить Мардера (Kill Murderer)",
        Callback = function()
            if isKillingMurderer then return end

            local char = LocalPlayer.Character
            if not char then return end

            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local gun = char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))

            -- 1. Проверка наличия пистолета (роли Шерифа/Героя)
            if not gun then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "MM2 Exploit",
                        Text = "Вы не Шериф (нет пистолета)!",
                        Duration = 4
                    })
                end)
                return
            end

            -- 2. Поиск активного Мардера
            local targetMurderer = nil
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hasKnife = player.Character:FindFirstChild("Knife") or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife"))
                    if hasKnife then
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            targetMurderer = player
                            break
                        end
                    end
                end
            end

            if not targetMurderer then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "MM2 Exploit",
                        Text = "Мардер не найден или мертв!",
                        Duration = 4
                    })
                end)
                return
            end

            isKillingMurderer = true

            -- Экипируем пистолет, если он лежит в инвентаре
            if gun.Parent == backpack then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:EquipTool(gun)
                end
            end

            -- Запоминаем оригинальную позицию Мардера перед телепортом
            local originalCFrame = nil
            local mRoot = targetMurderer.Character:FindFirstChild("HumanoidRootPart")
            if mRoot then
                originalCFrame = mRoot.CFrame
            end

            local startTime = os.clock()
            local sheriffConnection

            sheriffConnection = RunService.RenderStepped:Connect(function()
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                local mChar = targetMurderer.Character
                local curMRoot = mChar and mChar:FindFirstChild("HumanoidRootPart")
                local mHum = mChar and mChar:FindFirstChildOfClass("Humanoid")

                -- Прерывание: вышло время, мардер мертв, шериф мертв или убрал пистолет
                if not myRoot or os.clock() - startTime >= 4 or not curMRoot or not mHum or mHum.Health <= 0 or not char:FindFirstChild("Gun") then
                    sheriffConnection:Disconnect()
                    
                    -- Возвращаем Мардера на его реальную позицию
                    if curMRoot and originalCFrame then
                        curMRoot.CFrame = originalCFrame
                    end
                    isKillingMurderer = false
                    return
                end

                -- Локально стягиваем Мардера прямо под прицел (на расстояние 4 студа лицом к тебе)
                curMRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -4)
            end)
        end
    })

    -- ==========================================
    -- ЕДИНЫЙ ЦИКЛ АВТОВЫСТРЕЛА (HEARTBEAT)
    -- ==========================================
    RunService.Heartbeat:Connect(function()
        if not AutoShootEnabled or IsShooting then return end

        local murderer = findMurderer()
        if not murderer or not murderer.Character then return end

        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("RightHand") then return end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local gun = char:FindFirstChild("Gun") or char:FindFirstChild("Revolver")

        -- Авто-экипировка: достаем пистолет из инвентаря
        if not gun then
            local bagGun = backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver"))
            if bagGun and AutoShootEquip then
                humanoid:EquipTool(bagGun)
                gun = bagGun
            else
                return
            end
        end

        -- Стреляем только если видим хотя бы одну часть тела
        local visiblePart = getVisiblePart(murderer.Character)
        if not visiblePart then return end

        IsShooting = true

        -- Передаем персонажа для считывания вашей позиции и скорости
        local predictedPosition = getPredictedPosition(visiblePart, char, shootOffset)

        local args = {
            CFrame.new(char.RightHand.Position),
            CFrame.new(predictedPosition)
        }

        if gun:FindFirstChild("Shoot") then
            gun.Shoot:FireServer(unpack(args))
        elseif gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") then
            gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, predictedPosition, "AH2")
        end

        task.delay(shootCooldown, function()
            IsShooting = false
        end)
    end)
end
