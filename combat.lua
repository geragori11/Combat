-- =========================================================================
-- Murder Mystery 2: Универсальный Rage Multipoint Aimbot + UI Wrapper
-- Исправление: Тотальный перехват Mouse (X, Y, Hit) + Глобальный подмен сети
-- Логика: Раздувание огромного хитбокса прямо на позиции Мардера
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
    local hvhlShotCooldown = 0.3   
    local lastHvHShotTime = 0

    -- Создаем локальный фантомный хитбокс
    local PhantomHitbox = Instance.new("Part")
    PhantomHitbox.Transparency = 0.7 -- Поставь 1, чтобы сделать куб полностью невидимым
    PhantomHitbox.Color = Color3.fromRGB(255, 0, 0)
    PhantomHitbox.CanCollide = false
    PhantomHitbox.Anchored = true
    PhantomHitbox.Material = Enum.Material.ForceField
    PhantomHitbox.Name = "LocalTargetPhantomHitbox"
    PhantomHitbox.Parent = nil 

    local wallCheckParams = RaycastParams.new()
    wallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
    wallCheckParams.IgnoreWater = true

    -- ==========================================
    -- ФУНКЦИЯ ПРОВЕРКИ СТЕН (WALL CHECK)
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
        RayParams.FilterDescendantsInstances = {Character, TargetCharacter, Camera, PhantomHitbox}
        RayParams.IgnoreWater = true
        
        local RayResult = workspace:Raycast(Origin.Position, Destination.Position - Origin.Position, RayParams)
        return RayResult == nil
    end

    -- Диспетчер получения текущей цели
    local function GetAimTargetPart()
        if HvHAimEnabled and PhantomHitbox.Parent ~= nil then
            return PhantomHitbox
        elseif AimTarget and AimTarget.Character then
            return AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
        end
        return nil
    end

    -- ==========================================
    -- ОПТИМИЗИРОВАННЫЕ ХУКИ МЕТАТАБЛИЦ (БЛОКИРОВКА МЫШИ)
    -- ==========================================
    local Hooked = false
    local hasHook = typeof(hookmetamethod) == "function"
    local hasCheck = typeof(checkcaller) == "function"
    local hasNamecallGetter = typeof(getnamecallmethod) == "function"

    if hasHook and hasCheck and hasNamecallGetter then
        pcall(function()
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                if not checkcaller() and (AimEnabled or HvHAimEnabled) then
                    if typeof(self) == "Instance" and self.ClassName == "Mouse" then
                        local TargetPart = GetAimTargetPart()
                        if TargetPart then
                            if key == "Hit" then 
                                return TargetPart.CFrame
                            elseif key == "Target" then 
                                return TargetPart 
                            elseif key == "X" or key == "Y" then
                                -- Транслируем 3D позицию огромного хитбокса в 2D координаты экрана для обхода UIS
                                local screenPos, onScreen = Camera:WorldToViewportPoint(TargetPart.Position)
                                if onScreen then
                                    if key == "X" then return screenPos.X end
                                    if key == "Y" then return screenPos.Y end
                                end
                            end
                        end
                    end
                end
                return oldIndex(self, key)
            end)

            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                if not checkcaller() and (AimEnabled or HvHAimEnabled) then
                    local TargetPart = GetAimTargetPart()
                    if TargetPart then
                        -- Подмена лучей камеры (если скрипт использует ViewportPointToRay)
                        if typeof(self) == "Instance" and self.ClassName == "Camera" then
                            if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                                local OriginPos = Camera.CFrame.Position
                                local Direction = (TargetPart.Position - OriginPos).Unit * 1000
                                return Ray.new(OriginPos, Direction)
                            end
                        end

                        -- Жесткий перехват сетевого события выстрела при удержании пистолета
                        if method == "FireServer" or method == "InvokeServer" then
                            local char = LocalPlayer.Character
                            if char and char:FindFirstChild("Gun") then
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "Vector3" then
                                        args[i] = TargetPart.Position
                                    end
                                end
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

    -- Резервный хук для старых сред выполнения
    if not Hooked and typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function" and typeof(newcclosure) == "function" and hasCheck and hasNamecallGetter then
        pcall(function()
            local mt = getrawmetatable(game)
            local oldIndex = mt.__index
            local oldNamecall = mt.__namecall
            
            setreadonly(mt, false)
            
            mt.__index = newcclosure(function(self, key)
                if not checkcaller() and (AimEnabled or HvHAimEnabled) then
                    if typeof(self) == "Instance" and self.ClassName == "Mouse" then
                        local TargetPart = GetAimTargetPart()
                        if TargetPart then
                            if key == "Hit" then return TargetPart.CFrame
                            elseif key == "Target" then return TargetPart
                            elseif key == "X" or key == "Y" then
                                local screenPos, onScreen = Camera:WorldToViewportPoint(TargetPart.Position)
                                if onScreen then
                                    if key == "X" then return screenPos.X end
                                    if key == "Y" then return screenPos.Y end
                                end
                            end
                        end
                    end
                end
                return oldIndex(self, key)
            end)
            
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                if not checkcaller() and (AimEnabled or HvHAimEnabled) then
                    local TargetPart = GetAimTargetPart()
                    if TargetPart then
                        if typeof(self) == "Instance" and self.ClassName == "Camera" then
                            if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                                local OriginPos = Camera.CFrame.Position
                                local Direction = (TargetPart.Position - OriginPos).Unit * 1000
                                return Ray.new(OriginPos, Direction)
                            end
                        end
                        if method == "FireServer" or method == "InvokeServer" then
                            local char = LocalPlayer.Character
                            if char and char:FindFirstChild("Gun") then
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "Vector3" then
                                        args[i] = TargetPart.Position
                                    end
                                end
                                return oldNamecall(self, unpack(args))
                            end
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
    -- СОЗДАНИЕ ЭЛЕМЕНТОВ ИНТЕРФЕЙСА (UI)
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
        Name = "Размер хитбокса (Головы/Фантома)",
        Range = {2, 50},
        Increment = 1,
        Suffix = " studs",
        CurrentValue = 20,
        Flag = "HitboxSizeSlider",
        Callback = function(Value)
            HitboxSize = Value
        end
    })

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

    CombatTab:CreateSection("Trigger Bot")

    CombatTab:CreateToggle({
        Name = "Включить Триггербот (Auto Fire)",
        CurrentValue = false,
        Flag = "TriggerBotToggle",
        Callback = function(Value)
            TriggerBotEnabled = Value
        end
    })

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
    -- ЕДИНЫЙ ЦИКЛ ОБРАБОТКИ (RENDERSTEPPED)
    -- ==========================================
    RunService.RenderStepped:Connect(function()
        local CurrentMurderer = nil

        -- 1. Сканирование игроков и классических хитбоксов
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

        -- 2. Логика HvH: Центрирование ОГРОМНОГО локального хитбокса на Мардере
        if HvHAimEnabled and CurrentMurderer then
            AimEnabled = true
            AimReactionTime = 0
            AutoShootEnabled = false 

            local char = LocalPlayer.Character
            local myRoot = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
            
            if char and char:FindFirstChild("Humanoid") and myRoot then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                local gun = char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))

                if gun then
                    if gun.Parent == backpack and HvHAutoEquip then
                        char.Humanoid:EquipTool(gun)
                    elseif gun.Parent == char then
                        
                        local mChar = CurrentMurderer.Character
                        wallCheckParams.FilterDescendantsInstances = {char, mChar:GetChildren(), PhantomHitbox}

                        local hitboxes = {
                            {part = mChar:FindFirstChild("Head"), offsets = OFFSETS_HEAD, priority = 3},
                            {part = mChar:FindFirstChild("Torso") or mChar:FindFirstChild("UpperTorso"), offsets = OFFSETS_TORSO, priority = 2}
                        }

                        local cameraPos = Camera.CFrame.Position
                        local bestPointFound = nil

                        for i = 1, #hitboxes do
                            local part = hitboxes[i].part
                            if part and part:IsA("BasePart") then
                                local partCFrame = part.CFrame
                                local partSize = part.Size
                                local offsets = hitboxes[i].offsets
                                
                                for j = 1, #offsets do
                                    local offset = offsets[j]
                                    local worldPoint = partCFrame.Position + (partCFrame.RightVector * (offset.X * partSize.X)) + (partCFrame.UpVector * (offset.Y * partSize.Y)) + (partCFrame.LookVector * (offset.Z * partSize.Z))
                                    local result = workspace:Raycast(cameraPos, worldPoint - cameraPos, wallCheckParams)
                                    
                                    if not result then
                                        bestPointFound = worldPoint
                                        break
                                    end
                                end
                            end
                            if bestPointFound then break end
                        end

                        if bestPointFound then
                            -- Фиксируем огромные размеры фантома прямо на позиции цели
                            PhantomHitbox.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                            PhantomHitbox.Position = bestPointFound
                            PhantomHitbox.Parent = workspace
                            
                            local currentTime = os.clock()
                            if currentTime - lastHvHShotTime >= hvhlShotCooldown then
                                lastHvHShotTime = currentTime
                                
                                -- Вызов выстрела. Хуки полностью подменяют направление в этот куб
                                gun:Activate()
                            end
                        else
                            PhantomHitbox.Parent = nil
                        end
                    end
                end
            end
        else
            PhantomHitbox.Parent = nil
        end

        -- 3. Обычный Silent Aim (Если HvH выключен)
        if AimEnabled and not HvHAimEnabled then  
            if CurrentMurderer then
                if CurrentMurderer ~= LastTarget then
                    LastTarget = CurrentMurderer
                    TargetTime = tick() 
                end

                local elapsed = (tick() - TargetTime) * 1000 
                if elapsed >= AimReactionTime then
                    AimTarget = CurrentMurderer

                    if AutoShootEnabled then
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
