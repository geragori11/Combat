-- =========================================================================
-- Murder Mystery 2: Auto-Shoot + Manual Shoot (R) + Upgraded HvH Multi-Pierce
-- + Murderer/Sheriff Exploits + Remote Kill Spoof + Knife Aura
-- =========================================================================

return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local StarterGui = game:GetService("StarterGui")
    local LocalPlayer = Players.LocalPlayer

    local CombatTab = Window:CreateTab("COMBAT", 4483362458)

    -- --- НАСТРОЙКИ АВТОВЫСТРЕЛА И РУЧНОГО ВЫСТРЕЛА ---
    local AutoShootEnabled = false
    local AutoShootEquip = true
    local IsAutoShooting = false
    local IsManualShooting = false
    local ManualRequireVisible = false
    local shootOffset = 2.1
    local offsetToPingMult = 1
    local referenceDistance = 30
    local shootCooldown = 1.5

    -- --- НАСТРОЙКИ HvH РЕЖИМА ---
    local HvHMode = false
    local HvHMaxDistance = 65
    local HvHRequireVisible = true
    local HvHShootCooldown = 0.2
    local HvHMultiPredict = true

    -- --- НАСТРОЙКИ KNIFE AURA ---
    local KnifeAuraEnabled = false
    local KnifeAuraRange = 30
    local KnifeAuraCooldown = 1.2
    local KnifeAuraNextUse = 0

    -- --- СОСТОЯНИЕ EXPLOITS ---
    local isKillingAll = false
    local isKillingSheriff = false
    local isKillingTarget = false
    local SelectedPlayerName = ""

    local function Notify(Title, Text)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = Title or "MM2 Combat",
                Text = Text or "",
                Duration = 2
            })
        end)
    end

    -- ==========================================
    -- 1. ПОИСК УБИЙЦЫ / ШЕРИФА
    -- ==========================================
    local function findMurderer()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local backpack = player:FindFirstChild("Backpack")
                    if player.Character:FindFirstChild("Knife")
                        or (backpack and backpack:FindFirstChild("Knife")) then
                        return player
                    end
                end
            end
        end
        return nil
    end

    local function isSheriff(player)
        if not player or not player.Character then return false end
        local backpack = player:FindFirstChild("Backpack")
        return (player.Character:FindFirstChild("Gun") ~= nil)
            or (player.Character:FindFirstChild("Revolver") ~= nil)
            or (backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver")) ~= nil)
    end

    -- ==========================================
    -- 2. УПРЕЖДЕНИЕ (LEGIT)
    -- ==========================================
    local function getMyOriginPart(myChar)
        if not myChar then return nil end
        return myChar:FindFirstChild("RightHand")
            or myChar:FindFirstChild("Right Arm")
            or myChar:FindFirstChild("HumanoidRootPart")
    end

    local function getPredictedPosition(targetPart, myChar, baseOffset)
        if not targetPart or not myChar then return Vector3.new(0, 0, 0) end
        local originPart = getMyOriginPart(myChar)
        if not originPart then return targetPart.Position end

        local targetHRP = targetPart.Parent and targetPart.Parent:FindFirstChild("HumanoidRootPart")
        local targetVelocity = targetHRP and targetHRP.AssemblyLinearVelocity or targetPart.AssemblyLinearVelocity
        local myHRP = myChar:FindFirstChild("HumanoidRootPart")
        local myVelocity = myHRP and myHRP.AssemblyLinearVelocity or Vector3.new(0, 0, 0)

        local distance = (targetPart.Position - originPart.Position).Magnitude
        local distanceMultiplier = distance / referenceDistance

        local relativeVelocity = targetVelocity - myVelocity
        local diff = targetPart.Position - originPart.Position
        local directionToTarget = (diff.Magnitude > 0.001) and diff.Unit or Vector3.new(0, 0, -1)
        local closingSpeed = relativeVelocity:Dot(directionToTarget)
        local timeAdjust = 1 + (closingSpeed / 150)

        local predictionTime = (baseOffset / 16) * distanceMultiplier * timeAdjust
        local pingInSeconds = 0
        pcall(function() pingInSeconds = LocalPlayer:GetNetworkPing() end)
        local totalPredictionTime = math.max(0, predictionTime + pingInSeconds * offsetToPingMult)
        return targetPart.Position + (targetVelocity * totalPredictionTime)
    end

    -- ==========================================
    -- 3. ПРОВЕРКА ВИДИМОСТИ
    -- ==========================================
    local function getVisiblePart(targetCharacter)
        local myChar = LocalPlayer.Character
        local originPart = getMyOriginPart(myChar)
        if not originPart then return nil end

        local origin = originPart.Position
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = { myChar }
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.IgnoreWater = true

        local priorityNames = { "Head", "UpperTorso", "Torso", "LowerTorso" }
        for _, name in ipairs(priorityNames) do
            local part = targetCharacter:FindFirstChild(name)
            if part and part:IsA("BasePart") and part.Transparency < 1 then
                local diff = part.Position - origin
                if diff.Magnitude > 0.01 then
                    local direction = diff.Unit * (diff.Magnitude + 2)
                    local result = workspace:Raycast(origin, direction, raycastParams)
                    if result and result.Instance and result.Instance:IsDescendantOf(targetCharacter) then
                        return part
                    end
                end
            end
        end

        for _, part in ipairs(targetCharacter:GetDescendants()) do
            if part:IsA("BasePart")
                and part.Name ~= "HumanoidRootPart"
                and part.Transparency < 1
            then
                local diff = part.Position - origin
                if diff.Magnitude > 0.01 then
                    local direction = diff.Unit * (diff.Magnitude + 2)
                    local result = workspace:Raycast(origin, direction, raycastParams)
                    if result and result.Instance and result.Instance:IsDescendantOf(targetCharacter) then
                        return part
                    end
                end
            end
        end
        return nil
    end

    -- ==========================================
    -- 4. ХЕЛПЕРЫ ЭКИПИРОВКИ
    -- ==========================================
    local function getEquippedGun(forceEquip)
        local char = LocalPlayer.Character
        if not char then return nil end
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local gun = char:FindFirstChild("Gun") or char:FindFirstChild("Revolver")
        if gun then return gun end

        local bagGun = backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver"))
        if bagGun and (AutoShootEquip or forceEquip) then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(bagGun)
                return bagGun
            end
        end
        return nil
    end

    local function getEquippedKnife()
        local char = LocalPlayer.Character
        if not char then return nil end
        local knife = char:FindFirstChild("Knife")
        if knife then return knife end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local bagKnife = backpack and backpack:FindFirstChild("Knife")
        if bagKnife then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(bagKnife) end
            return bagKnife
        end
        return nil
    end

    -- ==========================================
    -- 5. REMOTE KILL SPOOF
    -- ==========================================
    local function spoofKill(targetPlayer, knife)
        if not targetPlayer or not targetPlayer.Character then return false end
        local victimChar = targetPlayer.Character
        local victimHum = victimChar:FindFirstChildOfClass("Humanoid")
        if not victimHum or victimHum.Health <= 0 then return false end

        knife = knife or getEquippedKnife()
        if not knife then return false end

        local events = knife:FindFirstChild("Events")
        if not events then return false end

        local knifeStabbed = events:FindFirstChild("KnifeStabbed")
        local handleTouched = events:FindFirstChild("HandleTouched")
        if not handleTouched then return false end

        if knifeStabbed then
            pcall(function() knifeStabbed:FireServer() end)
        end

        local parts = {}
        for _, name in ipairs({"Head", "UpperTorso", "Torso", "LowerTorso",
                               "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"}) do
            local p = victimChar:FindFirstChild(name)
            if p and p:IsA("BasePart") then table.insert(parts, p) end
        end
        if #parts == 0 then
            for _, d in ipairs(victimChar:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    table.insert(parts, d)
                end
            end
        end

        for _, part in ipairs(parts) do
            pcall(function() handleTouched:FireServer(part) end)
        end

        return true
    end

    local function spoofKillBurst(targetList)
        local knife = getEquippedKnife()
        if not knife then return 0 end
        for _, player in ipairs(targetList) do
            task.spawn(function()
                task.wait(math.random() * 0.01)
                spoofKill(player, knife)
            end)
        end
        return #targetList
    end

    -- ==========================================
    -- 6. UPGRADED BULLET-AT-HITBOX (СНАРУЖИ НАСКВОЗЬ + MULTI-PREDICT)
    -- ==========================================
    local function fireSingleRay(shootRemote, beamRemote, originPos, centerPos)
        local dir = centerPos - originPos
        if dir.Magnitude < 0.001 then
            dir = Vector3.new(0, 0, -1)
        else
            dir = dir.Unit
        end

        -- Прошиваем хитбокс насквозь через центр (+0.6 стада за центр детали)
        local throughPos = centerPos + dir * 0.6
        local originCFrame = CFrame.lookAt(originPos, throughPos)
        local targetCFrame = CFrame.new(throughPos)

        if shootRemote then
            pcall(function()
                shootRemote:FireServer(originCFrame, targetCFrame)
            end)
        elseif beamRemote then
            pcall(function()
                beamRemote:InvokeServer(1, throughPos, "AH2")
            end)
        end
    end

    local function fireBulletAtTarget(targetCharacter, gun)
        if not targetCharacter or not gun then return false end

        local mRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
        if not mRoot then return false end

        local shootRemote = gun:FindFirstChild("Shoot")
        local beamRemote = (gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam"))
            and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction") or nil

        if not shootRemote and not beamRemote then return false end

        local velocity = mRoot.AssemblyLinearVelocity
        local speed = velocity.Magnitude

        local ping = 0
        pcall(function() ping = LocalPlayer:GetNetworkPing() end)
        ping = math.clamp(ping, 0, 0.5)

        -- Вертикальная коррекция при прыжке/падении (гравитация в воздухе часто сбивает хитбокс)
        local verticalVel = velocity.Y
        local airOffset = Vector3.new(0, 0, 0)
        if math.abs(verticalVel) > 2 then
            airOffset = Vector3.new(0, verticalVel * ping * 0.85, 0)
        end

        -- Собираем части тела: сначала главные, затем конечности
        local coreParts = {}
        for _, name in ipairs({ "Head", "UpperTorso", "Torso", "LowerTorso" }) do
            local part = targetCharacter:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                table.insert(coreParts, part)
            end
        end

        local limbParts = {}
        for _, name in ipairs({
            "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
            "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
            "Left Arm", "Right Arm", "Left Leg", "Right Leg"
        }) do
            local part = targetCharacter:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                table.insert(limbParts, part)
            end
        end

        if #coreParts == 0 and #limbParts == 0 then
            for _, d in ipairs(targetCharacter:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    table.insert(coreParts, d)
                end
            end
        end
        if #coreParts == 0 and #limbParts == 0 then return false end

        -- Оптимальное расстояние старта луча снаружи хитбокса (чтобы не спавниться внутри детали)
        local primaryDir = (speed > 2.5) and -velocity.Unit or mRoot.CFrame.LookVector
        local spawnDist = math.clamp(1.8 - speed * 0.015, 0.65, 1.8)

        -- 1. Основной залп по ключевым частям (Head, Torso) с мульти-предсказанием
        for _, part in ipairs(coreParts) do
            local basePos = part.Position
            local pred1 = basePos + (velocity * ping) + airOffset

            -- Выстрел спереди по ходу движения (классический рабочий вариант, но с CFrame.lookAt и насквозь)
            fireSingleRay(shootRemote, beamRemote, pred1 + primaryDir * spawnDist, pred1)

            if HvHMultiPredict then
                -- Выстрел с обратной стороны (если цель резко стрейфанула или остановилась)
                fireSingleRay(shootRemote, beamRemote, pred1 - primaryDir * spawnDist, pred1)

                -- Выстрел в чистую позицию (0 пинг — идеально при фейклагах/резком стопе)
                fireSingleRay(shootRemote, beamRemote, basePos + primaryDir * 0.85, basePos)

                -- Выстрел с повышенным упреждением (1.35x пинг — для быстрых прыжков и спидхака)
                if speed > 6 then
                    local predFast = basePos + (velocity * (ping * 1.35)) + airOffset
                    fireSingleRay(shootRemote, beamRemote, predFast + primaryDir * spawnDist, predFast)
                end
            end
        end

        -- 2. Добивающий залп по всем конечностям в том же тике
        for _, part in ipairs(limbParts) do
            local predPos = part.Position + (velocity * ping)
            fireSingleRay(shootRemote, beamRemote, predPos + primaryDir * spawnDist, predPos)
        end

        return true
    end

    -- ==========================================
    -- 7. KNIFE THROW HvH (ПРОКАЧАННЫЙ СНАРУЖИ ВНУТРЬ)
    -- ==========================================
    local function fireKnifeThrowAt(targetCharacter, spawnDist)
        if not targetCharacter then return false end
        spawnDist = spawnDist or 0.5

        local knife = getEquippedKnife()
        if not knife then return false end

        local events = knife:FindFirstChild("Events")
        if not events then return false end
        local knifeThrown = events:FindFirstChild("KnifeThrown")
        if not knifeThrown then return false end

        local mRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
        if not mRoot then return false end

        local velocity = mRoot.AssemblyLinearVelocity
        local speed = velocity.Magnitude

        local ping = 0
        pcall(function() ping = LocalPlayer:GetNetworkPing() end)
        ping = math.clamp(ping, 0, 0.4)

        local dir = (speed > 2.5) and -velocity.Unit or mRoot.CFrame.LookVector

        local parts = {}
        for _, name in ipairs({"Head", "UpperTorso", "Torso", "LowerTorso",
                               "LeftUpperArm", "RightUpperArm"}) do
            local p = targetCharacter:FindFirstChild(name)
            if p and p:IsA("BasePart") then table.insert(parts, p) end
        end
        if #parts == 0 then
            for _, d in ipairs(targetCharacter:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    table.insert(parts, d)
                end
            end
        end
        if #parts == 0 then return false end

        for _, part in ipairs(parts) do
            local predictedPos = part.Position + velocity * ping
            local originPos = predictedPos + dir * spawnDist
            local throughPos = predictedPos - dir * 0.4
            local originCFrame = CFrame.lookAt(originPos, throughPos)
            local targetCFrame = CFrame.new(throughPos)
            pcall(function()
                knifeThrown:FireServer(originCFrame, targetCFrame)
            end)
        end

        return true
    end

    -- ==========================================
    -- 8. ФУНКЦИИ ВЫСТРЕЛА (HVH / LEGIT / MANUAL R)
    -- ==========================================
    local function tryHvHShot(targetChar, gun, ignoreChecks)
        if not targetChar or not gun then return false end

        local myChar = LocalPlayer.Character
        local originPart = getMyOriginPart(myChar)
        if not originPart then return false end

        local mRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if not mRoot then return false end

        if not ignoreChecks then
            local dist = (mRoot.Position - originPart.Position).Magnitude
            if dist > HvHMaxDistance then return false end

            if HvHRequireVisible then
                if not getVisiblePart(targetChar) then return false end
            end
        end

        return fireBulletAtTarget(targetChar, gun)
    end

    local function tryLegitShot(targetChar, gun, ignoreVisibility)
        local myChar = LocalPlayer.Character
        local originPart = getMyOriginPart(myChar)
        if not originPart or not targetChar or not gun then return false end

        local targetPart = getVisiblePart(targetChar)
        if not targetPart then
            if ignoreVisibility then
                targetPart = targetChar:FindFirstChild("UpperTorso")
                    or targetChar:FindFirstChild("Torso")
                    or targetChar:FindFirstChild("Head")
                    or targetChar:FindFirstChild("HumanoidRootPart")
            else
                return false
            end
        end
        if not targetPart then return false end

        local predictedPosition = getPredictedPosition(targetPart, myChar, shootOffset)
        local originCFrame = CFrame.lookAt(originPart.Position, predictedPosition)
        local targetCFrame = CFrame.new(predictedPosition)

        if gun:FindFirstChild("Shoot") then
            pcall(function()
                gun.Shoot:FireServer(originCFrame, targetCFrame)
            end)
            return true
        elseif gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") then
            pcall(function()
                gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, predictedPosition, "AH2")
            end)
            return true
        end

        return false
    end

    -- Одиночный выстрел по нажатию R
    local function executeManualShot()
        if IsManualShooting then return end

        local char = LocalPlayer.Character
        if not char then return end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        local murderer = findMurderer()
        if not murderer or not murderer.Character then
            Notify("Выстрел (R)", "Мардер не найден или мертв!")
            return
        end

        local gun = getEquippedGun(true)
        if not gun then
            Notify("Выстрел (R)", "У вас нет пистолета!")
            return
        end

        if gun.Parent ~= char then
            task.wait(0.08)
            gun = char:FindFirstChild("Gun") or char:FindFirstChild("Revolver") or gun
        end

        if ManualRequireVisible and not getVisiblePart(murderer.Character) then
            Notify("Выстрел (R)", "Мардер за стеной!")
            return
        end

        IsManualShooting = true
        local activeCooldown = HvHMode and HvHShootCooldown or shootCooldown

        if HvHMode then
            fireBulletAtTarget(murderer.Character, gun)
        else
            tryLegitShot(murderer.Character, gun, not ManualRequireVisible)
        end

        task.delay(activeCooldown, function()
            IsManualShooting = false
        end)
    end

    -- ==========================================
    -- СОЗДАНИЕ UI
    -- ==========================================
    CombatTab:CreateSection("Ручной выстрел по клавише (Manual Shoot)")

    CombatTab:CreateKeybind({
        Name = "Выстрелить по Мардеру (одиночный на R)",
        CurrentKeybind = "R",
        HoldToInteract = false,
        Flag = "ManualShootKeybind",
        Callback = function()
            executeManualShot()
        end
    })

    CombatTab:CreateToggle({
        Name = "Ручной выстрел: проверять видимость (стены)",
        CurrentValue = false,
        Flag = "ManualRequireVisibleToggle",
        Callback = function(Value)
            ManualRequireVisible = Value
        end
    })

    CombatTab:CreateSection("Auto-Shoot (Автовыстрел по Мардеру)")

    CombatTab:CreateToggle({
        Name = "Включить Автовыстрел",
        CurrentValue = false,
        Flag = "AutoShootMasterToggle",
        Callback = function(Value)
            AutoShootEnabled = Value
            if not Value then IsAutoShooting = false end
        end
    })

    CombatTab:CreateKeybind({
        Name = "Клавиша вкл/выкл Автовыстрела",
        CurrentKeybind = "T",
        HoldToInteract = false,
        Flag = "AutoShootKeybind",
        Callback = function()
            AutoShootEnabled = not AutoShootEnabled
            if not AutoShootEnabled then IsAutoShooting = false end
            Notify("Автовыстрел", AutoShootEnabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН")
        end
    })

    CombatTab:CreateToggle({
        Name = "Авто-экипировка пистолета",
        CurrentValue = true,
        Flag = "AutoShootEquipToggle",
        Callback = function(Value) AutoShootEquip = Value end
    })

    CombatTab:CreateSection("HvH Mode (Multi-Pierce Hitbox)")

    CombatTab:CreateToggle({
        Name = "Включить HvH (прострел всех хитбоксов)",
        CurrentValue = false,
        Flag = "HvHModeToggle",
        Callback = function(Value) HvHMode = Value end
    })

    CombatTab:CreateToggle({
        Name = "HvH Multi-Predict (3 фазы пинга + встречный угол)",
        CurrentValue = true,
        Flag = "HvHMultiPredictToggle",
        Callback = function(Value) HvHMultiPredict = Value end
    })

    CombatTab:CreateSlider({
        Name = "HvH макс. дистанция Автовыстрела (studs)",
        Range = {10, 200}, Increment = 1, CurrentValue = 65,
        Flag = "HvHMaxDistance",
        Callback = function(Value) HvHMaxDistance = Value end
    })

    CombatTab:CreateToggle({
        Name = "HvH Автовыстрел: только по видимым частям",
        CurrentValue = true,
        Flag = "HvHRequireVisible",
        Callback = function(Value) HvHRequireVisible = Value end
    })

    CombatTab:CreateSlider({
        Name = "HvH кулдаун выстрела (сек)",
        Range = {0.05, 2}, Increment = 0.05, CurrentValue = 0.2,
        Flag = "HvHShootCooldown",
        Callback = function(Value) HvHShootCooldown = Value end
    })

    CombatTab:CreateSection("Auto-Shoot (Fine-Tune Legit)")

    CombatTab:CreateSlider({
        Name = "Упреждение (Shoot Offset)",
        Range = {0, 10}, Increment = 0.1, CurrentValue = 2.1,
        Flag = "AutoShootOffset",
        Callback = function(Value) shootOffset = Value end
    })

    CombatTab:CreateSlider({
        Name = "Множитель пинга",
        Range = {0, 5}, Increment = 0.1, CurrentValue = 1,
        Flag = "AutoShootPingMult",
        Callback = function(Value) offsetToPingMult = Value end
    })

    CombatTab:CreateSlider({
        Name = "Эталонная дистанция (studs)",
        Range = {5, 100}, Increment = 1, CurrentValue = 30,
        Flag = "AutoShootRefDistance",
        Callback = function(Value) referenceDistance = Value end
    })

    CombatTab:CreateSlider({
        Name = "Задержка между выстрелами (legit, сек)",
        Range = {0.1, 5}, Increment = 0.1, CurrentValue = 1.5,
        Flag = "AutoShootCooldown",
        Callback = function(Value) shootCooldown = Value end
    })

    -- ==========================================
    -- MURDERER EXPLOITS
    -- ==========================================
    CombatTab:CreateSection("Murderer Exploits (Remote Spoof)")

    CombatTab:CreateButton({
        Name = "Убить всех (Remote Spoof)",
        Callback = function()
            if isKillingAll then return end
            local knife = getEquippedKnife()
            if not knife then Notify("MM2 Exploit", "Вы не Мардер!") return end
            isKillingAll = true
            local targets = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then table.insert(targets, player) end
                end
            end
            spoofKillBurst(targets)
            isKillingAll = false
        end
    })

    CombatTab:CreateButton({
        Name = "Убить всех кроме Шерифа",
        Callback = function()
            if isKillingAll then return end
            local knife = getEquippedKnife()
            if not knife then Notify("MM2 Exploit", "Вы не Мардер!") return end
            isKillingAll = true
            local targets = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and not isSheriff(player) then
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then table.insert(targets, player) end
                end
            end
            spoofKillBurst(targets)
            isKillingAll = false
            Notify("MM2 Exploit", "Все кроме Шерифа обработаны")
        end
    })

    CombatTab:CreateButton({
        Name = "Убить Шерифа (Remote Spoof)",
        Callback = function()
            if isKillingSheriff then return end
            local knife = getEquippedKnife()
            if not knife then Notify("MM2 Exploit", "Вы не Мардер!") return end

            local targetSheriff = nil
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and isSheriff(player) then
                    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then targetSheriff = player break end
                end
            end

            if not targetSheriff then Notify("MM2 Exploit", "Шериф не найден или мертв!") return end

            isKillingSheriff = true
            for round = 1, 5 do
                task.spawn(function() spoofKill(targetSheriff, knife) end)
                task.wait(0.04)
                local hum = targetSheriff.Character and targetSheriff.Character:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then break end
            end
            isKillingSheriff = false
        end
    })

    local PlayerDropdown = CombatTab:CreateDropdown({
        Name = "Выбрать игрока для убийства",
        Options = {},
        CurrentOption = {},
        Flag = "KillTargetDropdown",
        Callback = function(Value)
            if type(Value) == "table" then Value = Value[1] end
            SelectedPlayerName = Value or ""
        end
    })

    task.spawn(function()
        while task.wait(2) do
            local names = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(names, p.Name) end
            end
            pcall(function() PlayerDropdown:Refresh(names, true) end)
        end
    end)

    CombatTab:CreateButton({
        Name = "Убить выбранного игрока (Remote Spoof)",
        Callback = function()
            if isKillingTarget or SelectedPlayerName == "" then return end
            local knife = getEquippedKnife()
            if not knife then Notify("MM2 Exploit", "Вы не Мардер!") return end

            local targetPlayer = Players:FindFirstChild(SelectedPlayerName)
            if not targetPlayer or not targetPlayer.Character then
                Notify("MM2 Exploit", "Цель покинула сервер или не найдена!")
                return
            end

            local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end

            isKillingTarget = true
            for round = 1, 5 do
                task.spawn(function() spoofKill(targetPlayer, knife) end)
                task.wait(0.04)
                local h = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
                if not h or h.Health <= 0 then break end
            end
            isKillingTarget = false
        end
    })

    -- ==========================================
    -- KNIFE AURA
    -- ==========================================
    CombatTab:CreateSection("Knife Aura")

    CombatTab:CreateToggle({
        Name = "Включить Knife Aura",
        CurrentValue = false,
        Flag = "KnifeAuraToggle",
        Callback = function(Value) KnifeAuraEnabled = Value end
    })

    CombatTab:CreateSlider({
        Name = "Дальность Aura (studs)",
        Range = {5, 100}, Increment = 1, CurrentValue = 30,
        Flag = "KnifeAuraRange",
        Callback = function(Value) KnifeAuraRange = Value end
    })

    CombatTab:CreateSlider({
        Name = "Кулдаун Aura (сек)",
        Range = {0.2, 3}, Increment = 0.1, CurrentValue = 1.2,
        Flag = "KnifeAuraCooldown",
        Callback = function(Value) KnifeAuraCooldown = Value end
    })

    -- ==========================================
    -- SHERIFF EXPLOITS
    -- ==========================================
    CombatTab:CreateSection("Sheriff Exploits")

    CombatTab:CreateButton({
        Name = "Убить Мардера (пуля в хитбокс)",
        Callback = function()
            local char = LocalPlayer.Character
            if not char then return end

            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local gun = char:FindFirstChild("Gun") or char:FindFirstChild("Revolver")
                or (backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver")))

            if not gun then Notify("MM2 Exploit", "Вы не Шериф (нет пистолета)!") return end

            if gun.Parent == backpack then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(gun) end
                task.wait(0.15)
                gun = char:FindFirstChild("Gun") or char:FindFirstChild("Revolver") or gun
            end

            local murderer = findMurderer()
            if not murderer or not murderer.Character then
                Notify("MM2 Exploit", "Мардер не найден или мертв!")
                return
            end

            fireBulletAtTarget(murderer.Character, gun)
            task.delay(0.1, function()
                local mChar = murderer.Character
                if mChar then
                    local hum = mChar:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local g2 = char:FindFirstChild("Gun") or char:FindFirstChild("Revolver") or gun
                        fireBulletAtTarget(mChar, g2)
                    end
                end
            end)
        end
    })

    -- ==========================================
    -- ЕДИНЫЙ ЦИКЛ
    -- ==========================================
    RunService.Heartbeat:Connect(function()
        -- Knife Aura
        if KnifeAuraEnabled and os.clock() >= KnifeAuraNextUse then
            local char = LocalPlayer.Character
            local knife = char and char:FindFirstChild("Knife")
            if knife then
                local nearest, nearestDist = nil, KnifeAuraRange
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        local root = player.Character:FindFirstChild("HumanoidRootPart")
                        if hum and hum.Health > 0 and root and myRoot then
                            local dist = (root.Position - myRoot.Position).Magnitude
                            if dist < nearestDist then
                                if getVisiblePart(player.Character) then
                                    nearest = player
                                    nearestDist = dist
                                end
                            end
                        end
                    end
                end
                if nearest and nearest.Character then
                    if fireKnifeThrowAt(nearest.Character, 0.5) then
                        KnifeAuraNextUse = os.clock() + KnifeAuraCooldown
                    end
                end
            end
        end

        -- Auto-Shoot
        if not AutoShootEnabled or IsAutoShooting then return end

        local murderer = findMurderer()
        if not murderer or not murderer.Character then return end

        local char = LocalPlayer.Character
        if not getMyOriginPart(char) then return end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        local gun = getEquippedGun(false)
        if not gun then return end

        -- HvH MODE
        if HvHMode then
            if tryHvHShot(murderer.Character, gun, false) then
                IsAutoShooting = true
                task.delay(HvHShootCooldown, function()
                    IsAutoShooting = false
                end)
            end
            return
        end

        -- LEGIT MODE
        if tryLegitShot(murderer.Character, gun, false) then
            IsAutoShooting = true
            task.delay(shootCooldown, function()
                IsAutoShooting = false
            end)
        end
    end)
end
