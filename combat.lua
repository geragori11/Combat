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
    
    -- --- ПЕРЕМЕННЫЕ АВТОАИМА ---
    local AimEnabled = false
    local AimReactionTime = 0 
    local AutoShootEnabled = false
    local AimTarget = nil
    local LastTarget = nil
    local TargetTime = 0
    local LastShotTime = 0

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
                        local_sizes = data.Size
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
    -- СЕКЦИЯ: AUTO AIM
    -- ==========================================
    CombatTab:CreateSection("Auto Aim")

    CombatTab:CreateToggle({
        Name = "Включить Наведение (Hard Aim)",
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
    -- ЗАЩИЩЕННЫЙ ПЕРЕХВАТ ДВИЖКА ИГРЫ (HOOKS)
    -- ==========================================
    local Hooked = false
    local hasHook = typeof(hookmetamethod) == "function"
    local hasCheck = typeof(checkcaller) == "function"
    local hasNamecallGetter = typeof(getnamecallmethod) == "function"

    if hasHook and hasCheck then
        pcall(function()
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                    local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                    if TargetPart and (self == Mouse or self == LocalPlayer:GetMouse()) then
                        if key == "Hit" then return TargetPart.CFrame
                        elseif key == "Target" then return TargetPart end
                    end
                end
                return oldIndex(self, key)
            end)

            if hasNamecallGetter then
                local oldNamecall
                oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                        if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                            local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                            if TargetPart then
                                local OriginPos = Camera.CFrame.Position
                                local Direction = (TargetPart.Position - OriginPos).Unit * 1000
                                return Ray.new(OriginPos, Direction)
                            end
                        end
                    end
                    return oldNamecall(self, ...)
                end)
            end
            Hooked = true
        end)
    end

    if not Hooked and typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function" and typeof(newcclosure) == "function" and hasCheck then
        pcall(function()
            local mt = getrawmetatable(game)
            local oldIndex = mt.__index
            local oldNamecall = mt.__namecall
            
            setreadonly(mt, false)
            
            mt.__index = newcclosure(function(self, key)
                if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                    local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                    if TargetPart and (self == Mouse or self == LocalPlayer:GetMouse()) then
                        if key == "Hit" then return TargetPart.CFrame
                        elseif key == "Target" then return TargetPart end
                    end
                end
                return oldIndex(self, key)
            end)
            
            if hasNamecallGetter then
                mt.__namecall = newcclosure(function(self, ...)
                    local method = getnamecallmethod()
                    if AimEnabled and AimTarget and AimTarget.Character and not checkcaller() then
                        if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                            local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                            if TargetPart then
                                local OriginPos = Camera.CFrame.Position
                                local Direction = (TargetPart.Position - OriginPos).Unit * 1000
                                return Ray.new(OriginPos, Direction)
                            end
                        end
                    end
                    return oldNamecall(self, ...)
                end)
            end
            
            setreadonly(mt, true)
            Hooked = true
        end)
    end

    -- ==========================================
    -- ЕДИНЫЙ ЦИКЛ ОБРАБОТКИ (RENDERSTEPPED)
    -- ==========================================
    RunService.RenderStepped:Connect(function()
        local CurrentMurderer = nil

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

                -- Логика контроля хитбоксов
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

        -- Вычисление задержки реакции, наведение камеры и автовыстрел
        if AimEnabled and CurrentMurderer then
            if CurrentMurderer ~= LastTarget then
                LastTarget = CurrentMurderer
                TargetTime = tick() 
            end

            local elapsed = (tick() - TargetTime) * 1000 
            if elapsed >= AimReactionTime then
                AimTarget = CurrentMurderer

                -- [НОВОЕ] Физическое наведение камеры на голову Мардера
                if AimTarget.Character then
                    local TargetPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                    if TargetPart then
                        -- Плавно или мгновенно разворачиваем камеру к цели
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, TargetPart.Position)
                    end
                end

                -- Логика автовыстрела
                if AutoShootEnabled then
                    local Gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
                    if Gun and (tick() - LastShotTime > 0.4) then 
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
