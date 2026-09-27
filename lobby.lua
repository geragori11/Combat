

return function(Window)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local StarterGui = game:GetService("StarterGui")
    local CoreGui = game:GetService("CoreGui")

    local LocalPlayer = Players.LocalPlayer

    -- Создание отдельной вкладки модуля
    local VotingTab = Window:CreateTab("Голосование", 4483362458)

    local function Notify(title, text, duration)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title or "XClient Vote",
                Text = text or "",
                Duration = duration or 2.5
            })
        end)
    end

    -- ==========================================
    -- СОСТОЯНИЕ ГЛИТЧА
    -- ==========================================
    local IsGlitchingVote = false
    local TargetVoteIndex = nil
    local CurrentVoteThread = nil
    local InjectedVoteImages = {}

    -- ==========================================
    -- ПОИСК ОБЪЕКТОВ ЛОББИ MM2
    -- ==========================================
    local function getLobby()
        return workspace:FindFirstChild("RegularLobby")
            or workspace:FindFirstChild("Lobby")
            or workspace:FindFirstChild("ChristmasLobby")
            or workspace:FindFirstChild("HalloweenLobby")
    end

    local function getVoteTargetPart(index)
        local lobby = getLobby()
        if not lobby then return nil end

        -- 1. Детекторы касания в VotePads (Detector1, Detector2, Detector3)
        local votePads = lobby:FindFirstChild("VotePads")
        if votePads then
            local detector = votePads:FindFirstChild("Detector" .. tostring(index))
            if detector and detector:IsA("BasePart") then
                return detector
            end
        end

        -- 2. Детали Pad в VotePadX
        local padModel = lobby:FindFirstChild("VotePad" .. tostring(index))
        if padModel then
            local pad = padModel:FindFirstChild("Pad")
            if pad and pad:IsA("BasePart") then
                return pad
            end
        end

        return nil
    end

    local function isValidVoteImage(imgStr)
        if typeof(imgStr) ~= "string" then return false end
        if imgStr == "" or imgStr == "rbxassetid://0" or imgStr == "0" then
            return false
        end
        return true
    end

    -- Считывание актуального названия карты, счетчика голосов и картинки
    local function getVoteCardData(index)
        local lobby = getLobby()
        if not lobby then return "Карта " .. index, 0, "", false end

        local mapName = "Ожидание..."
        local votesCount = 0
        local mapImage = ""

        local votePadModel = lobby:FindFirstChild("VotePad" .. tostring(index))
        if votePadModel then
            local voteInfoGui = votePadModel:FindFirstChild("VoteInfoGui")
            local container = voteInfoGui and voteInfoGui:FindFirstChild("Container")
            if container then
                local nameLabel = container:FindFirstChild("MapName")
                local votesLabel = container:FindFirstChild("Votes")
                if nameLabel and nameLabel.Text ~= "" and nameLabel.Text ~= "MapName" and nameLabel.Text ~= "MAP NAME" then
                    mapName = nameLabel.Text
                end
                if votesLabel then
                    votesCount = tonumber(votesLabel.Text:match("%d+")) or 0
                end
            end

            -- Извлечение превью карты из MapInfoGui
            local mapInfoGui = votePadModel:FindFirstChild("MapInfoGui")
            local mapIcon = mapInfoGui and mapInfoGui:FindFirstChild("MapIcon")
            if mapIcon and mapIcon:IsA("ImageLabel") and isValidVoteImage(mapIcon.Image) then
                mapImage = mapIcon.Image
            end
        end

        -- Резервное извлечение картинки из VoteIcons
        if not isValidVoteImage(mapImage) and lobby:FindFirstChild("VoteIcons") then
            local padIcon = lobby.VoteIcons:FindFirstChild("VotePad" .. tostring(index))
            if padIcon and padIcon:FindFirstChild("Surface") and padIcon.Surface:FindFirstChild("Background") then
                local bg = padIcon.Surface.Background
                if bg:IsA("ImageLabel") and isValidVoteImage(bg.Image) then
                    mapImage = bg.Image
                end
            end
        end

        local isVotingActive = isValidVoteImage(mapImage)
        return mapName, votesCount, mapImage, isVotingActive
    end

    local function getVoteAliveCharacter()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum.Health > 0 then
                return char, char.HumanoidRootPart, hum
            end
        end
        return nil, nil, nil
    end

    local function waitVoteRespawn()
        local newChar = LocalPlayer.CharacterAdded:Wait()
        local hrp = newChar:WaitForChild("HumanoidRootPart", 10)
        local hum = newChar:WaitForChild("Humanoid", 10)
        task.wait(0.15)
        return newChar, hrp, hum
    end

    -- ==========================================
    -- УПРАВЛЕНИЕ ГЛИТЧ-ГОЛОСОВАНИЕМ
    -- ==========================================
    local function stopVoteGlitch(reason)
        if not IsGlitchingVote and not CurrentVoteThread then return end
        IsGlitchingVote = false
        TargetVoteIndex = nil

        if CurrentVoteThread then
            task.cancel(CurrentVoteThread)
            CurrentVoteThread = nil
        end

        if reason then
            Notify("Голосование", reason, 3)
        else
            Notify("Голосование", "Фарм голосов остановлен!", 2)
        end
    end

    local function startVoteGlitchLoop(index)
        local mapName, _, mapImage, isVoting = getVoteCardData(index)
        if not isVoting or not isValidVoteImage(mapImage) then
            Notify("Заблокировано", "Картинка карты отсутствует! Раунд уже начался или идёт.", 3.5)
            return
        end

        if IsGlitchingVote and TargetVoteIndex == index then
            stopVoteGlitch()
            return
        end

        IsGlitchingVote = true
        TargetVoteIndex = index
        Notify("Голосование", "Запущен фарм за: " .. tostring(mapName), 2.5)

        if CurrentVoteThread then
            task.cancel(CurrentVoteThread)
            CurrentVoteThread = nil
        end

        CurrentVoteThread = task.spawn(function()
            while IsGlitchingVote do
                -- 1. Проверка перед телепортацией: доступна ли карта
                local _, _, curImg, curActive = getVoteCardData(index)
                if not curActive or not isValidVoteImage(curImg) then
                    stopVoteGlitch("Раунд начался! Картинка карты исчезла, фарм отключен.")
                    break
                end

                local targetPart = getVoteTargetPart(index)
                if not targetPart then
                    task.wait(0.5)
                    continue
                end

                local char, hrp, hum = getVoteAliveCharacter()
                if not char or not hrp or not hum then
                    char, hrp, hum = waitVoteRespawn()
                end
                if not IsGlitchingVote then break end

                -- 2. Проверка после возможного респавна
                local _, _, checkImg, checkActive = getVoteCardData(index)
                if not checkActive or not isValidVoteImage(checkImg) then
                    stopVoteGlitch("Раунд начался! Фарм отключен.")
                    break
                end

                -- 3. Телепортация на детектор платформы
                hrp.CFrame = targetPart.CFrame + Vector3.new(0, 2.2, 0)
                pcall(function()
                    if typeof(firetouchinterest) == "function" then
                        firetouchinterest(hrp, targetPart, 0)
                    end
                end)

                -- 4. Ожидание ровно 0.8 сек с микро-проверками на старт раунда
                local timer = 0
                while timer < 0.8 and IsGlitchingVote do
                    task.wait(0.05)
                    timer = timer + 0.05
                    local _, _, mImg, mActive = getVoteCardData(index)
                    if not mActive or not isValidVoteImage(mImg) then
                        stopVoteGlitch("Раунд начался во время ожидания! Фарм отключен.")
                        break
                    end
                end
                if not IsGlitchingVote then break end

                -- 5. Сброс персонажа
                pcall(function() hum.Health = 0 end)
                pcall(function() char:BreakJoints() end)

                -- 6. Ожидание возрождения перед повторением
                if IsGlitchingVote then
                    waitVoteRespawn()
                    task.wait(0.08)
                end
            end
        end)
    end

    -- ==========================================
    -- ИНТЕРФЕЙС ВКЛАДКИ
    -- ==========================================
    VotingTab:CreateSection("Статус Голосования")

    local VoteStatusParagraph = VotingTab:CreateParagraph({
        Title = "Статус системы",
        Content = "Ожидание раунда голосования..."
    })

    VotingTab:CreateSection("Выбор Карты (Нажмите для фарма)")

    local RayfieldVoteButtons = {}

    for i = 1, 3 do
        local btn = VotingTab:CreateButton({
            Name = string.format("Карта %d: Ожидание...", i),
            Callback = function()
                startVoteGlitchLoop(i)
            end
        })
        RayfieldVoteButtons[i] = btn
    end

    VotingTab:CreateSection("Управление")

    VotingTab:CreateButton({
        Name = "🛑 ОСТАНОВИТЬ ФАРМ",
        Callback = function()
            stopVoteGlitch()
        end
    })

    -- ==========================================
    -- ВНЕДРЕНИЕ КАРТИНОК В КНОПКИ МЕНЮ
    -- ==========================================
    local function findRayfieldGuiInstance()
        if CoreGui:FindFirstChild("Rayfield") then return CoreGui.Rayfield end
        if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Rayfield") then
            return LocalPlayer.PlayerGui.Rayfield
        end
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name == "Rayfield" or gui.Name:find("XClient") or gui:FindFirstChild("Main", true)) then
                return gui
            end
        end
        return nil
    end

    local function injectVoteImages()
        local rfGui = findRayfieldGuiInstance()
        if not rfGui then return end

        for i = 1, 3 do
            if not InjectedVoteImages[i] then
                for _, desc in ipairs(rfGui:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text:find("Карта " .. tostring(i)) then
                        local btnContainer = desc.Parent
                        if btnContainer and (btnContainer:IsA("Frame") or btnContainer:IsA("TextButton")) then
                            btnContainer.Size = UDim2.new(btnContainer.Size.X.Scale, btnContainer.Size.X.Offset, 0, 52)
                            desc.Position = UDim2.new(0, 56, desc.Position.Y.Scale, desc.Position.Y.Offset)
                            desc.Size = UDim2.new(1, -64, desc.Size.Y.Scale, desc.Size.Y.Offset)

                            local img = Instance.new("ImageLabel")
                            img.Name = "RayfieldMapPreview" .. i
                            img.Size = UDim2.new(0, 38, 0, 38)
                            img.Position = UDim2.new(0, 8, 0.5, -19)
                            img.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                            img.BorderSizePixel = 0
                            img.ScaleType = Enum.ScaleType.Crop
                            img.Parent = btnContainer

                            local corner = Instance.new("UICorner")
                            corner.CornerRadius = UDim.new(0, 6)
                            corner.Parent = img

                            InjectedVoteImages[i] = img
                            break
                        end
                    end
                end
            end
        end
    end

    task.delay(0.5, function()
        injectVoteImages()
    end)

    -- ==========================================
    -- ОСНОВНОЙ ЦИКЛ ОБНОВЛЕНИЯ
    -- ==========================================
    RunService.Heartbeat:Connect(function()
        if not InjectedVoteImages[1] or not InjectedVoteImages[2] or not InjectedVoteImages[3] then
            injectVoteImages()
        end

        local anyVoteActive = false

        for i = 1, 3 do
            local mName, vCount, mImg, isCardActive = getVoteCardData(i)
            if isCardActive then anyVoteActive = true end

            local imgLabel = InjectedVoteImages[i]
            if imgLabel then
                if isValidVoteImage(mImg) then
                    imgLabel.Image = mImg
                    imgLabel.Visible = true
                else
                    imgLabel.Image = ""
                    imgLabel.Visible = false
                end
            end

            local rBtn = RayfieldVoteButtons[i]
            if rBtn and rBtn.Set then
                local prefix = ""
                if IsGlitchingVote and TargetVoteIndex == i then
                    prefix = "[ФАРМИТСЯ] "
                elseif not isCardActive then
                    prefix = "[ЗАКРЫТО] "
                end

                local cleanName = (mName ~= "" and mName ~= "MapName") and mName or ("Карта " .. i)
                rBtn:Set(string.format("%s%s  (Голосов: %d)", prefix, cleanName, vCount))
            end
        end

        if VoteStatusParagraph and VoteStatusParagraph.Set then
            if IsGlitchingVote then
                local aName = getVoteCardData(TargetVoteIndex)
                VoteStatusParagraph:Set({
                    Title = "Фарм Активен!",
                    Content = string.format("Выбрана карта: %s\nЦикл: ТП -> 0.8с -> Ресет", tostring(aName))
                })
            elseif anyVoteActive then
                VoteStatusParagraph:Set({
                    Title = "Идёт голосование",
                    Content = "Картинки карт загружены. Нажмите на нужную карту для запуска глитча."
                })
            else
                VoteStatusParagraph:Set({
                    Title = "Раунд начался",
                    Content = "Голосование завершено (картинки отсутствуют). Фарм заблокирован."
                })
            end
        end
    end)
end
