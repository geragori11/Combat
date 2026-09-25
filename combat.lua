-- =========================================================================
-- Murder Mystery 2: Auto-Shoot (Автовыстрел по Мардеру) + UI Wrapper
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
    local shootOffset = 2.1
    local offsetToPingMult = 1
    local referenceDistance = 30
    local shootCooldown = 1.5

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
    -- 1. ПОИСК УБИЙЦЫ
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
    -- 2. ДИНАМИЧЕСКОЕ УПРЕЖДЕНИЕ
    -- ==========================================
    local function getPredictedPosition(targetPart, myChar, baseOffset)
        if not targetPart or not myChar then return Vector3.new(0, 0, 0) end

        local originPart = myChar:FindFirstChild("RightHand")
        if not originPart then return targetPart.Position end

        local targetHRP = targetPart.Parent and targetPart.Parent:FindFirstChild("HumanoidRootPart")
        local targetVelocity = targetHRP and targetHRP.AssemblyLinearVelocity or targetPart.AssemblyLinearVelocity

        local myHRP = myChar:FindFirstChild("HumanoidRootPart")
        local myVelocity = myHRP and myHRP.AssemblyLinearVelocity or Vector3.new(0, 0, 0)

        local distance = (targetPart.Position - originPart.Position).Magnitude
        local distanceMultiplier = distance / referenceDistance

        local relativeVelocity = targetVelocity - myVelocity
        local directionToTarget = (targetPart.Position - originPart.Position).Unit
        local closingSpeed = relativeVelocity:Dot(directionToTarget)
        local timeAdjust = 1 + (closingSpeed / 150)

        local predictionTime = (baseOffset / 16) * distanceMultiplier * timeAdjust

        local pingInSeconds = 0
        pcall(function() pingInSeconds = LocalPlayer:GetNetworkPing() end)
        local totalPredictionTime = math.max(0, predictionTime + pingInSeconds * offsetToPingMult)

        return targetPart.Position + (targetVelocity * totalPredictionTime)
    end

    -- ==========================================
    -- 3. ПРОВЕРКА ВИДИМОСТИ (Raycast от руки)
    -- ==========================================
    local function getVisiblePart(targetCharacter)
        local myChar = LocalPlayer.Character
        if not myChar or not myChar:FindFirstChild("RightHand") then return nil end

        local origin = myChar.RightHand.Position

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {myChar}
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
    -- 4. ФИНАЛЬНАЯ ПРОВЕРКА: линия до предсказанной точки
    --    Возвращает true, если предсказанная позиция не за препятствием.
    -- ==========================================
    local function isPredictedPositionVisible(myChar, targetCharacter, predictedPos)
        if not myChar or not myChar:FindFirstChild("RightHand") then return false end
        local origin = myChar.RightHand.Position
        local delta = predictedPos - origin
        if delta.Magnitude < 0.5 then return false end

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {myChar}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.IgnoreWater = true

        local result = workspace:Raycast(origin, delta.Unit * (delta.Magnitude + 1), raycastParams)
        if result and result.Instance and result.Instance:IsDescendantOf(targetCharacter) then
            return true
        end
        return false
    end

    -- ==========================================
    -- СОЗДАНИЕ UI
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
        Range = {0, 10}, Increment = 0.1, CurrentValue = 2.1, Flag = "AutoShootOffset",
        Callback = function(Value) shootOffset = Value end
    })

    CombatTab:CreateSlider({
        Name = "Множитель пинга",
        Range = {0, 5}, Increment = 0.1, CurrentValue = 1, Flag = "AutoShootPingMult",
        Callback = function(Value) offsetToPingMult = Value end
    })

    CombatTab:CreateSlider({
        Name = "Эталонная дистанция (studs)",
        Range = {5, 100}, Increment = 1, CurrentValue = 30, Flag = "AutoShootRefDistance",
        Callback = function(Value) referenceDistance = Value end
    })

    CombatTab:CreateSlider({
        Name = "Задержка между выстрелами (сек)",
        Range = {0.1, 5}, Increment = 0.1, CurrentValue = 1.5, Flag = "AutoShootCooldown",
        Callback = function(Value) shootCooldown = Value end
    })

    CombatTab:CreateToggle({
        Name = "Авто-экипировка пистолета",
        CurrentValue = true, Flag = "AutoShootEquipToggle",
        Callback = function(Value) AutoShootEquip = Value end
    })

    -- --- РАЗДЕЛ: MURDERER EXPLOITS ---
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
                Notify("MM2 Exploit", "Вы не Мардер!")
                return
            end

            isKillingAll = true

            if knife.Parent == backpack then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid:EquipTool(knife) end
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
                            if root then root.CFrame = cframe end
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

                if knife and knife.Parent == char then knife:Activate() end
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
                Notify("MM2 Exploit", "Вы не Мардер!")
                return
            end

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
                Notify("MM2 Exploit", "Шериф не найден или мертв!")
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
                    if curSRoot and originalCFrame then curSRoot.CFrame = originalCFrame end
                    isKillingSheriff = false
                    return
                end

                curSRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -2)
                if knife and knife.Parent == char then knife:Activate() end
            end)
        end
    })

    -- ==========================================
    -- DROPDOWN выбора игрока
    -- ==========================================
    local PlayerDropdown
    PlayerDropdown = CombatTab:CreateDropdown({
        Name = "Выбрать игрока для убийства",
        Options = {},
        CurrentOption = {},
        Flag = "KillTargetDropdown",
        Callback = function(Value)
            local newVal
            if type(Value) == "table" then
                newVal = Value[1]
            else
                newVal = Value
            end
            newVal = newVal or ""

            -- Игнорируем "пустые" обновления от авто-рефреша,
            -- чтобы не стирать выбор пользователя.
            if newVal == "" and SelectedPlayerName ~= "" then
                return
            end
            SelectedPlayerName = newVal
        end
    })

    -- Автообновление списка. Refresh вызываем ТОЛЬКО если список реально изменился,
    -- иначе каждые 2 сек дропдаун пересобирался и сбрасывал выбор.
    task.spawn(function()
        local lastList = {}
        while task.wait(2) do
            local playerNames = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    table.insert(playerNames, p.Name)
                end
            end
            table.sort(playerNames)

            local changed = (#playerNames ~= #lastList)
            if not changed then
                for i = 1, #playerNames do
                    if playerNames[i] ~= lastList[i] then
                        changed = true
                        break
                    end
                end
            end

            if changed then
                lastList = playerNames
                pcall(function()
                    PlayerDropdown:Refresh(playerNames, true)
                end)
            end
        end
    end)

    CombatTab:CreateButton({
        Name = "Убить выбранного игрока",
        Callback = function()
            if isKillingAll or isKillingSheriff or isKillingTarget then return end

            if not SelectedPlayerName or SelectedPlayerName == "" then
                Notify("MM2 Exploit", "Сначала выберите игрока в списке!")
                return
            end

            local char = LocalPlayer.Character
            if not char then return end

            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local knife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))

            if not knife then
                Notify("MM2 Exploit", "Вы не Мардер!")
                return
            end

            local targetPlayer = Players:FindFirstChild(SelectedPlayerName)
            if not targetPlayer or not targetPlayer.Character then
                Notify("MM2 Exploit", "Цель покинула сервер или не найдена!")
                return
            end

            local tHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not tHum or tHum.Health <= 0 then
                Notify("MM2 Exploit", "Цель уже мертва!")
                return
            end

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
                    if curTRoot and originalCFrame then curTRoot.CFrame = originalCFrame end
                    isKillingTarget = false
                    return
                end

                curTRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -2)
                if knife and knife.Parent == char then knife:Activate() end
            end)
        end
    })

    -- --- РАЗДЕЛ: SHERIFF EXPLOITS ---
    CombatTab:CreateSection("Sheriff Exploits")

    CombatTab:CreateButton({
        Name = "Убить Мардера (Kill Murderer)",
        Callback = function()
            if isKillingMurderer then return end

            local char = LocalPlayer.Character
            if not char then return end

            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local gun = char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))

            if not gun then
                Notify("MM2 Exploit", "Вы не Шериф (нет пистолета)!")
                return
            end

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
                Notify("MM2 Exploit", "Мардер не найден или мертв!")
                return
            end

            isKillingMurderer = true

            if gun.Parent == backpack then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid:EquipTool(gun) end
            end

            local originalCFrame = nil
            local mRoot = targetMurderer.Character:FindFirstChild("HumanoidRootPart")
            if mRoot then originalCFrame = mRoot.CFrame end

            local startTime = os.clock()
            local sheriffConnection
            sheriffConnection = RunService.RenderStepped:Connect(function()
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                local mChar = targetMurderer.Character
                local curMRoot = mChar and mChar:FindFirstChild("HumanoidRootPart")
                local mHum = mChar and mChar:FindFirstChildOfClass("Humanoid")

                if not myRoot or os.clock() - startTime >= 4 or not curMRoot or not mHum or mHum.Health <= 0 or not char:FindFirstChild("Gun") then
                    sheriffConnection:Disconnect()
                    if curMRoot and originalCFrame then curMRoot.CFrame = originalCFrame end
                    isKillingMurderer = false
                    return
                end

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

        if not gun then
            local bagGun = backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver"))
            if bagGun and AutoShootEquip then
                humanoid:EquipTool(bagGun)
                gun = bagGun
            else
                return
            end
        end

        -- 1. Выбираем видимую часть тела (по текущей позиции)
        local visiblePart = getVisiblePart(murderer.Character)
        if not visiblePart then return end

        -- 2. Сразу вычисляем предсказанную позицию
        local predictedPosition = getPredictedPosition(visiblePart, char, shootOffset)

        -- 3. ФИНАЛЬНАЯ проверка — не за стеной ли ПРЕДСКАЗАННАЯ точка.
        --    Это критично: между шагом 1 и выстрелом враг мог уйти за укрытие,
        --    а мы стреляем именно в предсказанную точку, поэтому и проверять надо её.
        if not isPredictedPositionVisible(char, murderer.Character, predictedPosition) then
            return
        end

        -- 4. Только теперь блокируем и стреляем (минимум кода между проверкой и FireServer)
        IsShooting = true

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
