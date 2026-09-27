-- =========================================================================
-- XCLIENT MODULE: MM2 VOTING TAB (FIXED GETHUI INJECTION & IMAGES)
-- =========================================================================

return function(Window)
    local Players = game:GetService("Players")
    local StarterGui = game:GetService("StarterGui")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer

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

        local votePads = lobby:FindFirstChild("VotePads")
        if votePads then
            local detector = votePads:FindFirstChild("Detector" .. tostring(index))
            if detector and detector:IsA("BasePart") then
                return detector
            end
        end

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

            local mapInfoGui = votePadModel:FindFirstChild("MapInfoGui")
            local mapIcon = mapInfoGui and mapInfoGui:FindFirstChild("MapIcon")
            if mapIcon and mapIcon:IsA("ImageLabel") and isValidVoteImage(mapIcon.Image) then
                mapImage = mapIcon.Image
            end
        end

        if not isValidVoteImage(mapImage) and lobby:FindFirstChild("VoteIcons") then
            local padIcon = lobby.VoteIcons:FindFirstChild("VotePad" .. tostring(index))
            if padIcon then
                local surface = padIcon:FindFirstChild("Surface")
                local bg = surface and surface:FindFirstChild("Background")
                if bg and bg:IsA("ImageLabel") and isValidVoteImage(bg.Image) then
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
    -- УПРАВЛЕНИЕ ГЛИТЧЕМ (0.8с -> Ресет)
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
            Notify("Заблокировано", "Картинка карты не загружена! Раунд уже начался или идёт.", 3.5)
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

                local _, _, checkImg, checkActive = getVoteCardData(index)
                if not checkActive or not isValidVoteImage(checkImg) then
                    stopVoteGlitch("Раунд начался! Фарм отключен.")
                    break
                end

                hrp.CFrame = targetPart.CFrame + Vector3.new(0, 2.2, 0)
                pcall(function()
                    if typeof(firetouchinterest) == "function" then
                        firetouchinterest(hrp, targetPart, 0)
                    end
                end)

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

                pcall(function() hum.Health = 0 end)
                pcall(function() char:BreakJoints() end)

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
    VotingTab:CreateSection("Инфо")

    local VoteStatusParagraph = VotingTab:CreateParagraph({
        Title = "Статус системы",
        Content = "Ожидание раунда голосования..."
    })

    VotingTab:CreateButton({
        Name = "🛑 ОСТАНОВИТЬ ФАРМ",
        Callback = function()
            stopVoteGlitch()
        end
    })

    local MapWidgets = {}
    local UniqueSlotTags = {
        "__RAYFIELD_MAP_IMG_1__",
        "__RAYFIELD_MAP_IMG_2__",
        "__RAYFIELD_MAP_IMG_3__"
    }

    for i = 1, 3 do
        VotingTab:CreateSection("Слот карты #" .. i)

        VotingTab:CreateParagraph({
            Title = UniqueSlotTags[i],
            Content = ""
        })

        local btn = VotingTab:CreateButton({
            Name = string.format("Выбрать Карту %d (Ожидание)", i),
            Callback = function()
                startVoteGlitchLoop(i)
            end
        })

        MapWidgets[i] = {
            Button = btn,
            ImageLabel = nil,
            Placeholder = nil,
            Container = nil,
            LastImage = "",
            LastText = ""
        }
    end

    -- ==========================================
    -- ПОИСК И ИНЪЕКЦИЯ С ПОДДЕРЖКОЙ GETHUI()
    -- ==========================================
    local function getSearchRoots()
        local roots = {}
        if typeof(gethui) == "function" then
            local ok, h = pcall(gethui)
            if ok and h then table.insert(roots, h) end
        end
        if CoreGui then table.insert(roots, CoreGui) end
        if LocalPlayer:FindFirstChild("PlayerGui") then
            table.insert(roots, LocalPlayer.PlayerGui)
        end
        return roots
    end

    local function tryInjectSlot(slotIndex)
        local tag = UniqueSlotTags[slotIndex]
        local roots = getSearchRoots()

        for _, root in ipairs(roots) do
            local foundDesc = nil
            pcall(function()
                for _, desc in ipairs(root:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text:find(tag) then
                        foundDesc = desc
                        break
                    end
                end
            end)

            if foundDesc then
                local box = foundDesc.Parent
                if box and (box:IsA("Frame") or box:IsA("GuiObject")) then
                    -- Скрываем стандартные тексты меток Rayfield
                    for _, child in ipairs(box:GetChildren()) do
                        if child:IsA("TextLabel") then
                            child.Text = ""
                            child.Visible = false
                        end
                    end

                    -- Фиксируем высоту блока под баннер
                    box.Size = UDim2.new(1, 0, 0, 115)
                    box.ClipsDescendants = true
                    box.BackgroundTransparency = 0
                    box.BackgroundColor3 = Color3.fromRGB(20, 20, 26)

                    -- Создаём ImageLabel для картинки карты
                    local img = Instance.new("ImageLabel")
                    img.Name = "InjectedMapPreview_" .. slotIndex
                    img.Size = UDim2.new(1, -12, 1, -12)
                    img.Position = UDim2.new(0, 6, 0, 6)
                    img.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
                    img.BorderSizePixel = 0
                    img.ScaleType = Enum.ScaleType.Crop
                    img.ZIndex = 25
                    img.Visible = false
                    img.Parent = box

                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, 8)
                    corner.Parent = img

                    -- Текст-заглушка на случай отсутствия изображения
                    local placeholder = Instance.new("TextLabel")
                    placeholder.Name = "Placeholder"
                    placeholder.Size = UDim2.new(1, 0, 1, 0)
                    placeholder.BackgroundTransparency = 1
                    placeholder.Text = "КАРТА НЕ ЗАГРУЖЕНА / РАУНД ИДЁТ"
                    placeholder.TextColor3 = Color3.fromRGB(130, 130, 145)
                    placeholder.Font = Enum.Font.GothamBold
                    placeholder.TextSize = 11
                    placeholder.ZIndex = 26
                    placeholder.Visible = true
                    placeholder.Parent = box

                    MapWidgets[slotIndex].ImageLabel = img
                    MapWidgets[slotIndex].Placeholder = placeholder
                    MapWidgets[slotIndex].Container = box
                    return true
                end
            end
        end
        return false
    end

    -- ==========================================
    -- ЛЁГКИЙ ЦИКЛ ОБНОВЛЕНИЯ (БЕЗ ПРОСАДОК FPS)
    -- ==========================================
    local lastStatusText = ""

    task.spawn(function()
        while task.wait(0.4) do
            local anyVoteActive = false

            for i = 1, 3 do
                local widget = MapWidgets[i]

                -- Если картинка ещё не внедрена в этот слот, пробуем внедрить
                if not widget.ImageLabel then
                    tryInjectSlot(i)
                end

                local mName, vCount, mImg, isCardActive = getVoteCardData(i)
                if isCardActive then anyVoteActive = true end

                -- 1. Обновление изображения
                if widget.ImageLabel then
                    if isValidVoteImage(mImg) then
                        if widget.LastImage ~= mImg then
                            widget.ImageLabel.Image = mImg
                            widget.ImageLabel.Visible = true
                            widget.LastImage = mImg
                            if widget.Placeholder then widget.Placeholder.Visible = false end
                        end
                    else
                        if widget.ImageLabel.Visible then
                            widget.ImageLabel.Image = ""
                            widget.ImageLabel.Visible = false
                            widget.LastImage = ""
                            if widget.Placeholder then widget.Placeholder.Visible = true end
                        end
                    end
                end

                -- 2. Обновление текста кнопки
                local prefix = ""
                if IsGlitchingVote and TargetVoteIndex == i then
                    prefix = "[ФАРМИТСЯ] "
                elseif not isCardActive then
                    prefix = "[ЗАКРЫТО] "
                end

                local cleanName = (mName ~= "" and mName ~= "MapName") and mName or ("Карта " .. i)
                local newBtnText = string.format("%s%s  (Голосов: %d)", prefix, cleanName, vCount)

                if widget.LastText ~= newBtnText then
                    widget.LastText = newBtnText
                    if widget.Button and widget.Button.Set then
                        widget.Button:Set(newBtnText)
                    end
                end
            end

            -- 3. Обновление статуса
            local newStatusTitle = ""
            local newStatusContent = ""

            if IsGlitchingVote then
                local aName = getVoteCardData(TargetVoteIndex)
                newStatusTitle = "Фарм Активен!"
                newStatusContent = string.format("Выбрана карта: %s\nЦикл: ТП -> 0.8с -> Ресет", tostring(aName))
            elseif anyVoteActive then
                newStatusTitle = "Идёт голосование"
                newStatusContent = "Картинки карт отображаются. Нажмите кнопку под нужной картой."
            else
                newStatusTitle = "Раунд начался"
                newStatusContent = "Голосование недоступно (картинок нет). Фарм заблокирован."
            end

            local combined = newStatusTitle .. newStatusContent
            if lastStatusText ~= combined then
                lastStatusText = combined
                if VoteStatusParagraph and VoteStatusParagraph.Set then
                    VoteStatusParagraph:Set({
                        Title = newStatusTitle,
                        Content = newStatusContent
                    })
                end
            end
        end
    end)
end
