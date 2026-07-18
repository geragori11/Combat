-- =========================================================================
-- Murder Mystery 2: Универсальный Rage Multipoint Aimbot + UI Wrapper
-- Исправление: Синхронизация Phantom Hitbox с костями и регистрацией MM2
-- Логика: Внедрение хитбокса в модель Мардера + подмена Target на реальную Head
-- Добавлено: Kill All, Kill Sheriff, Kill Target Player (с выбором из Dropdown)
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

    -- --- СОСТОЯНИЕ EXPLOITS ---
    local isKillingAll = false
    local isKillingMurderer = false
    local isKillingSheriff = false
    local isKillingTarget = false
    local SelectedPlayerName = ""

    -- Создаем локальный фантомный хитбокс
    local PhantomHitbox = Instance.new("Part")
    PhantomHitbox.Transparency = 0.7 -- Поставь 1, чтобы сделать куб полностью невидимым
    PhantomHitbox.Color = Color3.fromRGB(255, 0, 0)
    PhantomHitbox.CanCollide = false
    PhantomHitbox.Anchored = true
    PhantomHitbox.Material = Enum.Material.ForceField
    PhantomHitbox.Name = "Head" -- Мимикрируем под голову для простейших проверок
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

    -- ==========================================
    -- УЛЬТРА-ХУКИ ДЛЯ ИДЕАЛЬНОЙ РЕГИСТРАЦИИ ХИТОВ
    -- ==========================================
    local Hooked = false
    local hasHook = typeof(hookmetamethod) == "function"
    local hasCheck = typeof(checkcaller) == "function"
    local hasNamecallGetter = typeof(getnamecallmethod) == "function"

    if hasHook and hasCheck and hasNamecallGetter then
        pcall(function()
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                if not checkcaller() and (AimEnabled or HvHAimEnabled) and AimTarget and AimTarget.Character then
                    if typeof(self) == "Instance" and self.ClassName == "Mouse" then
                        local realPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                        if realPart then
                            if key == "Hit" then 
                                return HvHAimEnabled and PhantomHitbox.CFrame or realPart.CFrame
                            elseif key == "Target" then 
                                return realPart 
                            elseif key == "X" or key == "Y" then
                                local targetPos = HvHAimEnabled and PhantomHitbox.Position or realPart.Position
                                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
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
                
                if not checkcaller() and (AimEnabled or HvHAimEnabled) and AimTarget and AimTarget.Character then
                    local realHead = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                    if realHead then
                        if typeof(self) == "Instance" and self.ClassName == "Camera" then
                            if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                                local OriginPos = Camera.CFrame.Position
                                local targetPos = HvHAimEnabled and PhantomHitbox.Position or realHead.Position
                                local Direction = (targetPos - OriginPos).Unit * 1000
                                return Ray.new(OriginPos, Direction)
                            end
                        end

                        if method == "FireServer" or method == "InvokeServer" then
                            local char = LocalPlayer.Character
                            if char and char:FindFirstChild("Gun") then
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "Vector3" then
                                        args[i] = HvHAimEnabled and PhantomHitbox.Position or realHead.Position
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

    if not Hooked and typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function" and typeof(newcclosure) == "function" and hasCheck and hasNamecallGetter then
        pcall(function()
            local mt = getrawmetatable(game)
            local oldIndex = mt.__index
            local oldNamecall = mt.__namecall
            
            setreadonly(mt, false)
            
            mt.__index = newcclosure(function(self, key)
                if not checkcaller() and (AimEnabled or HvHAimEnabled) and AimTarget and AimTarget.Character then
                    if typeof(self) == "Instance" and self.ClassName == "Mouse" then
                        local realPart = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                        if realPart then
                            if key == "Hit" then 
                                return HvHAimEnabled and PhantomHitbox.CFrame or realPart.CFrame
                            elseif key == "Target" then 
                                return realPart
                            elseif key == "X" or key == "Y" then
                                local targetPos = HvHAimEnabled and PhantomHitbox.Position or realPart.Position
                                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
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
                if not checkcaller() and (AimEnabled or HvHAimEnabled) and AimTarget and AimTarget.Character then
                    local realHead = AimTarget.Character:FindFirstChild("Head") or AimTarget.Character:FindFirstChild("HumanoidRootPart")
                    if realHead then
                        if typeof(self) == "Instance" and self.ClassName == "Camera" then
                            if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                                local OriginPos = Camera.CFrame.Position
                                local targetPos = HvHAimEnabled and PhantomHitbox.Position or realHead.Position
                                local Direction = (targetPos - OriginPos).Unit * 1000
                                return Ray.new(OriginPos, Direction)
                            end
                        end
                        if method == "FireServer" or method == "InvokeServer" then
                            local char = LocalPlayer.Character
                            if char and char:FindFirstChild("Gun") then
                                for i, arg in ipairs(args) do
                                    if typeof(arg) == "Vector3" then
                                        args[i] = HvHAimEnabled and PhantomHitbox.Position or realHead.Position
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
        CurrentValue = "",
        Flag = "KillTargetDropdown",
        Callback = function(Value)
            SelectedPlayerName = Value
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
    -- ЕДИНЫЙ ЦИКЛ ОБРАБОТКИ (RENDERSTEPPED)
    -- ==========================================
    RunService.RenderStepped:Connect(function()
        local CurrentMurderer = nil

        -- 1. Сканирование игроков
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
                    if head and head:IsA("BasePart") and head.Name == "Head" and head ~= PhantomHitbox then
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

        -- Своевременное обновление таргета для хуков метатаблиц
        if CurrentMurderer then
            AimTarget = CurrentMurderer
        else
            AimTarget = nil
        end

        -- 2. Логика HvH: Раздувание и инжекция ОГРОМНОГО хитбокса внутрь модели Мардера
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
                            if part and part:IsA("BasePart") and part ~= PhantomHitbox then
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
                            -- Конфигурируем огромный фантом
                            PhantomHitbox.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                            PhantomHitbox.Position = bestPointFound
                            
                            -- ПРИНУДИТЕЛЬНО пушим хитбокс в модель Мардера, чтобы игра засчитала ХИТ
                            PhantomHitbox.Parent = mChar
                            
                            local currentTime = os.clock()
                            if currentTime - lastHvHShotTime >= hvhlShotCooldown then
                                lastHvHShotTime = currentTime
                                
                                -- Выстрел! Траектория идет в фантом, но хуки подменят деталь на настоящую голову
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

        -- 3. Обработка обычного Silent Aim (Если HvH выключен)
        if AimEnabled and not HvHAimEnabled then  
            if CurrentMurderer then
                if CurrentMurderer ~= LastTarget then
                    LastTarget = CurrentMurderer
                    TargetTime = tick() 
                end

                local elapsed = (tick() - TargetTime) * 1000 
                if elapsed >= AimReactionTime then
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
