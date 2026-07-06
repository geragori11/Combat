-- =========================================================================
-- Murder Mystery 2: Универсальный Rage Multipoint Aimbot + UI Wrapper
-- Адаптация под ограничения Xeno Executor (Bypass через Camera-Lock)
-- Логика: Предгенерация 317 точек -> Многоточечный Raycast-Шторм -> Клик
-- =========================================================================

local OFFSETS_HEAD = {}
local OFFSETS_TORSO = {}
local OFFSETS_LIMBS = {}

-- Предгенерация сетки смещений (Матрица точек)
local function precomputeGrid(steps, targetTable)
    for x = 1, steps do
        for y = 1, steps do
            for z = 1, steps do
                table.insert(targetTable, Vector3.new(
                    -0.5 + (x - 1) / (steps - 1),
                    -0.5 + (y - 1) / (steps - 1),
                    -0.5 + (z - 1) / (steps - 1)
                ))
            end
        end
    end
end

precomputeGrid(4, OFFSETS_HEAD)   -- 64 точки
precomputeGrid(5, OFFSETS_TORSO)  -- 125 точек
precomputeGrid(4, OFFSETS_LIMBS)  -- 64 точки на каждую конечность

return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    local Camera = workspace.CurrentCamera
    
    local CombatTab = Window:CreateTab("COMBAT", 4483362458)
    
    -- --- ПЕРЕМЕННЫЕ ХИТБОКСА ---
    local HitboxEnabled = false
    local HitboxSize = 15
    local OriginalSizes = {} 
    
    -- --- ПЕРЕМЕННЫЕ АВТОАИМА (SILENT) ---
    local AimEnabled = false
    local AimReactionTime = 0 
    local AutoShootEnabled = false
    local AimTarget = nil
    local LastTarget = nil
    local TargetTime = 0
    local LastShotTime = 0

    -- --- ПЕРЕМЕННЫЕ ТРИГГЕРБОТА ---
    local TriggerBotEnabled = false
    local LastTriggerShotTime = 0

    -- --- ПЕРЕМЕННЫЕ HVH SNAP AIMBOT (XENO) ---
    local HvHAimEnabled = false
    local HvHAutoEquip = false
    local SHOT_COOLDOWN = 0.53
    local lastShotTime = 0

    local wallCheckParams = RaycastParams.new()
    wallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
    wallCheckParams.IgnoreWater = true

    -- ==========================================
    -- ФУНКЦИЯ ПРОВЕРКИ СТЕН (WALL CHECK ДЛЯ SILENT AIM)
    -- ==========================================
    local function IsVisible(TargetPlayer)
        local Character = LocalPlayer.Character
        local TargetCharacter = TargetPlayer.Character
        if not Character or not TargetCharacter then return false end
        
        local Origin = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Head")
        local Destination = TargetCharacter:FindFirstChild("HumanoidRootPart") or TargetCharacter:FindFirstChild("Head")
        if not Origin or not Destination then return false end
        
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = {Character, TargetCharacter, Camera}
        RayParams.IgnoreWater = true
        
        local RayResult = workspace:Raycast(Origin.Position, Destination.Position - Origin.Position, RayParams)
        return RayResult == nil
    end

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
    -- СЕКЦИЯ: ULTIMATE SILENT AIM
    -- ==========================================
    CombatTab:CreateSection("Silent Aim")

    CombatTab:CreateToggle({
        Name = "Включить Магический Аим (Silent)",
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
    -- СЕКЦИЯ: TRIGGER BOT
    -- ==========================================
    CombatTab:CreateSection("Trigger Bot")

    CombatTab:CreateToggle({
        Name = "Включить Триггербот (Auto Fire)",
        CurrentValue = false,
        Flag = "TriggerBotToggle",
        Callback = function(Value)
            TriggerBotEnabled = Value
        end
    })

    -- ==========================================
    -- СЕКЦИЯ: HVH SNAP AIMBOT (XENO EXECUTOR)
    -- ==========================================
    CombatTab:CreateSection("HvH Snap Aimbot (Xeno)")

    CombatTab:CreateToggle({
        Name = "Включить HvH Snap Аим",
        CurrentValue = false,
        Flag = "HvHAimToggle",
        Callback = function(Value)
            HvHAimEnabled = Value
        end
    })

    CombatTab:CreateToggle({
        Name = "Авто-экипировка пистолета",
        CurrentValue = false,
        Flag = "HvHAutoEquipToggle",
        Callback = function(Value)
            HvHAutoEquip = Value
        end
    })

    -- ==========================================
    -- ХУКИ И ПЕРЕХВАТ ДАННЫХ (МЕТАТАБЛИЦЫ ДЛЯ SILENT AIM)
    -- ==========================================
    local Hooked = false
    local hasHook = typeof(hookmetamethod) == "function"
    local hasCheck = typeof(checkcaller) == "function"
    local hasNamecallGetter = typeof(getnamecallmethod) == "function"

    if hasHook and hasCheck and hasNamecallGetter then
        pcall(function()
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                    local isMouse = false
                    pcall(function() isMouse = self:IsA("Mouse") end)
                    
                    if isMouse then
                        local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                        if TargetPart then
                            if key == "Hit" then return TargetPart.CFrame
                            elseif key == "Target" then return TargetPart end
                        end
                    end
                end
                return oldIndex(self, key)
            end)

            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                    local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                    
                    if TargetPart then
                        if method == "FireServer" or method == "InvokeServer" then
                            if self.Name == "Shoot" or self.Name == "ShootGun" or (self.Parent and self.Parent:IsA("Tool")) then
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "Vector3" then
                                        args[i] = TargetPart.Position
                                    end
                                end
                                return oldNamecall(self, unpack(args))
                            end
                        end

                        if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                            local OriginPos = Camera.CFrame.Position
                            local Direction = (TargetPart.Position - OriginPos).Unit * 1000
                            return Ray.new(OriginPos, Direction)
                        elseif method == "Raycast" and self == workspace then
                            local origin = args[1]
                            if typeof(origin) == "Vector3" then
                                args[2] = (TargetPart.Position - origin).Unit * 1000
                                return oldNamecall(self, unpack(args))
                            end
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            Hooked = true
        end)
    end

    if not Hooked and typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function" and typeof(newcclosure) == "function" and hasCheck and hasNamecallGetter then
        pcall(function()
            local mt = getrawmetatable(game)
            local oldIndex = mt.__index
            local oldNamecall = mt.__namecall
            
            setreadonly(mt, false)
            
            mt.__index = newcclosure(function(self, key)
                if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                    local isMouse = false
                    pcall(function() isMouse = self:IsA("Mouse") end)
                    if isMouse then
                        local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                        if TargetPart then
                            if key == "Hit" then return TargetPart.CFrame
                            elseif key == "Target" then return TargetPart end
                        end
                    end
                end
                return oldIndex(self, key)
            end)
            
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                    local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                    if TargetPart then
                        if method == "FireServer" or method == "InvokeServer" then
                            if self.Name == "Shoot" or (self.Parent and self.Parent:IsA("Tool")) then
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "Vector3" then
                                        args[i] = TargetPart.Position
                                    end
                                end
                                return oldNamecall(self, unpack(args))
                            end
                        end
                        if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                            local OriginPos = Camera.CFrame.Position
                            local Direction = (TargetPart.Position - OriginPos).Unit * 1000
                            return Ray.new(OriginPos, Direction)
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            
            setreadonly(mt, true)
            Hooked = true
        end)
    end

    -- ==========================================
    -- ЕДИНЫЙ ЦИКЛ ОБРАБОТКИ (RENDERSTEPPED)
    -- ==========================================
    RunService.RenderStepped:Connect(function()
        local CurrentMurderer = nil

        -- 1. Сбор информации о Маньяке и Хитбоксах
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character then
                local isMurderer = (Player.Character:FindFirstChild("Knife") or 
                                    (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Knife")))
                
                if isMurderer then
                    local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 and IsVisible(Player) then
                        CurrentMurderer = Player
                    end
                end

                -- Контроль динамического изменения хитбоксов
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

        -- 2. Логика Интегрированного Rage Multipoint Aimbot (HvH Snap)
        if HvHAimEnabled then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                local gun = char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))

                if gun then
                    -- Авто-экипировка пистолета
                    if gun.Parent == backpack then
                        if HvHAutoEquip then
                            char.Humanoid:EquipTool(gun)
                        end
                    -- Работает только в том случае, если пистолет находится в руках персонажа
                    elseif gun.Parent == char then
                        local hvhMurderer = nil
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= LocalPlayer and p.Character then
                                if p.Character:FindFirstChild("Knife") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Knife")) then
                                    hvhMurderer = p
                                    break
                                end
                            end
                        end

                        if hvhMurderer and hvhMurderer.Character then
                            local mChar = hvhMurderer.Character
                            
                            -- Исключаем из коллизий лучей себя и элементы одежды цели
                            if LocalPlayer.Character then
                                wallCheckParams.FilterDescendantsInstances = {LocalPlayer.Character, mChar:GetChildren()}
                            end

                            -- Хитбоксы по приоритету Rage (Голова -> Тело -> Ноги)
                            local hitboxes = {
                                {part = mChar:FindFirstChild("Head"), offsets = OFFSETS_HEAD, priority = 3},
                                {part = mChar:FindFirstChild("Torso") or mChar:FindFirstChild("UpperTorso"), offsets = OFFSETS_TORSO, priority = 2},
                                {part = mChar:FindFirstChild("Left Leg") or mChar:FindFirstChild("LeftLowerLeg"), offsets = OFFSETS_LIMBS, priority = 1},
                                {part = mChar:FindFirstChild("Right Leg") or mChar:FindFirstChild("RightLowerLeg"), offsets = OFFSETS_LIMBS, priority = 1}
                            }

                            local cameraPos = Camera.CFrame.Position
                            local bestPointFound = nil
                            local maxPriority = 0

                            -- Многоточечный сканирующий шторм (317 точек)
                            for i = 1, #hitboxes do
                                local data = hitboxes[i]
                                local part = data.part
                                
                                if part and part:IsA("BasePart") and data.priority > maxPriority then
                                    local partCFrame = part.CFrame
                                    local partSize = part.Size
                                    
                                    local cpos = partCFrame.Position
                                    local right = partCFrame.RightVector
                                    local up = partCFrame.UpVector
                                    local look = partCFrame.LookVector
                                    local offsets = data.offsets
                                    
                                    for j = 1, #offsets do
                                        local offset = offsets[j]
                                        local worldPoint = cpos + (right * (offset.X * partSize.X)) + (up * (offset.Y * partSize.Y)) + (look * (offset.Z * partSize.Z))
                                        local direction = worldPoint - cameraPos
                                        
                                        local result = workspace:Raycast(cameraPos, direction, wallCheckParams)
                                        
                                        -- Если до конкретной фантомной точки нет преград — фиксируем ее
                                        if not result then
                                            bestPointFound = worldPoint
                                            maxPriority = data.priority
                                            break -- Нашли лучшую видимую точку на данном хитбоксе
                                        end
                                    end
                                end
                            end

                            -- Если простреливаемая точка найдена — производим захват и выстрел
                            if bestPointFound then
                                -- Мгновенная жесткая доводка камеры (Bypass для ограничений Xeno)
                                Camera.CFrame = CFrame.lookAt(cameraPos, bestPointFound)

                                local currentTime = os.clock()
                                if currentTime - lastShotTime >= SHOT_COOLDOWN then
                                    lastShotTime = currentTime
                                    
                                    local screenSize = Camera.ViewportSize
                                    local centerX = screenSize.X / 2
                                    local centerY = screenSize.Y / 2
                                    
                                    -- Эмуляция клика строго по центру экрана
                                    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
                                    task.defer(function()
                                        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 3. Обработка задержки и автоматический выстрел (Silent Aim)
        if AimEnabled and CurrentMurderer then
            if CurrentMurderer ~= LastTarget then
                LastTarget = CurrentMurderer
                TargetTime = tick() 
            end

            local elapsed = (tick() - TargetTime) * 1000 
            if elapsed >= AimReactionTime then
                AimTarget = CurrentMurderer

                if AutoShootEnabled and not HvHAimEnabled then
                    local Gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
                    if Gun and (tick() - LastShotTime > 0.4) then 
                        LastShotTime = tick()
                        Gun:Activate()
                    end
                end
            end
        else
            LastTarget = nil
            AimTarget = nil
        end

        -- 4. ЛОГИКА ТРИГГЕРБОТА (TRIGGER BOT)
        if TriggerBotEnabled and not HvHAimEnabled then
            local Gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
            if Gun and (tick() - LastTriggerShotTime > 0.4) then 
                local targetPart = Mouse.Target
                if targetPart then
                    local characterModel = targetPart:FindFirstAncestorOfClass("Model")
                    local hoveredPlayer = characterModel and Players:GetPlayerFromCharacter(characterModel)
                    
                    if hoveredPlayer and hoveredPlayer ~= LocalPlayer and hoveredPlayer.Character then
                        local isMurderer = (hoveredPlayer.Character:FindFirstChild("Knife") or 
                                           (hoveredPlayer:FindFirstChild("Backpack") and hoveredPlayer.Backpack:FindFirstChild("Knife")))
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
