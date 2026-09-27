-- =========================================================================
-- XCLIENT MODULE: MM2 VOTING TAB (HORIZONTAL 3-CARD ROW + FIXED SLOT 3)
-- Полный внешний модуль для меню XClient / Rayfield
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

    local function findImageInInstance(inst)
        if not inst then return nil end
        for _, desc in ipairs(inst:GetDescendants()) do
            if desc:IsA("ImageLabel") or desc:IsA("Decal") then
                local img = desc:IsA("ImageLabel") and desc.Image or desc.Texture
                if typeof(img) == "string" and #img > 5 and isValidVoteImage(img) then
                    return img
                end
            end
        end
        return nil
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

            mapImage = findImageInInstance(votePadModel) or ""
        end

        if not isValidVoteImage(mapImage) and lobby:FindFirstChild("VoteIcons") then
            local padIcon = lobby.VoteIcons:FindFirstChild("VotePad" .. tostring(index))
            if padIcon then
                mapImage = findImageInInstance(padIcon) or ""
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
    -- УПРАВЛЕНИЕ ГЛИТЧЕМ (ТП -> 0.8с -> Ресет)
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

    VotingTab:CreateSection("Карты Лобби")

    local UNIQUE_ROW_TAG = "HORIZONTAL_ROW_CONTAINER_VOTE"

    local HostParagraph = VotingTab:CreateParagraph({
        Title = UNIQUE_ROW_TAG,
        Content = " "
    })

    local HorizontalCards = {}

    -- ==========================================
    -- ИНЪЕКЦИЯ ГОРИЗОНТАЛЬНОЙ ПАНЕЛИ ИЗ 3 КАРТ
    -- ==========================================
    local function getHostFrame()
        local getupvals = debug.getupvalues or getupvalues
        if getupvals and HostParagraph and type(HostParagraph.Set) == "function" then
            local found = nil
            pcall(function()
                for _, uv in pairs(getupvals(HostParagraph.Set)) do
                    if typeof(uv) == "Instance" and (uv:IsA("Frame") or uv:IsA("GuiObject")) then
                        found = uv
                        break
                    elseif type(uv) == "table" then
                        for _, sub in pairs(uv) do
                            if typeof(sub) == "Instance" and (sub:IsA("Frame") or sub:IsA("GuiObject")) then
                                found = sub
                                break
                            end
                        end
                    end
                end
            end)
            if found then return found end
        end

        local searchRoots = {}
        if typeof(gethui) == "function" then
            local ok, h = pcall(gethui)
            if ok and h then table.insert(searchRoots, h) end
        end
        if CoreGui then table.insert(searchRoots, CoreGui) end
        if LocalPlayer:FindFirstChild("PlayerGui") then
            table.insert(searchRoots, LocalPlayer.PlayerGui)
        end

        for _, root in ipairs(searchRoots) do
            local match = nil
            pcall(function()
                for _, desc in ipairs(root:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text:find(UNIQUE_ROW_TAG) then
                        match = desc.Parent
                        break
                    end
                end
            end)
            if match then return match end
        end
        return nil
    end

    local function setupHorizontalRow()
        local host = getHostFrame()
        if not host then return false end

        -- Скрываем стандартный текст Rayfield
        for _, child in ipairs(host:GetChildren()) do
            if child:IsA("TextLabel") then
                child.Visible = false
            end
        end

        -- Задаём размеры базового контейнера
        host.Size = UDim2.new(1, 0, 0, 160)
        host.ClipsDescendants = true
        host.BackgroundTransparency = 1

        -- Очищаем старые инъецированные фреймы, если модуль перезапускался
        local oldRow = host:FindFirstChild("MapRowContainer")
        if oldRow then oldRow:Destroy() end

        local rowFrame = Instance.new("Frame")
        rowFrame.Name = "MapRowContainer"
        rowFrame.Size = UDim2.new(1, 0, 1, 0)
        rowFrame.BackgroundTransparency = 1
        rowFrame.Parent = host

        -- 3 равные колонки с отступами
        local cardPositions = {
            UDim2.new(0, 0, 0, 0),
            UDim2.new(0.345, 0, 0, 0),
            UDim2.new(0.69, 0, 0, 0)
        }

        for i = 1, 3 do
            local card = Instance.new("Frame")
            card.Name = "CardSlot_" .. i
            card.Size = UDim2.new(0.31, 0, 1, 0)
            card.Position = cardPositions[i]
            card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
            card.BorderSizePixel = 0
            card.Parent = rowFrame

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 8)
            cardCorner.Parent = card

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Name = "Stroke"
            cardStroke.Color = Color3.fromRGB(48, 48, 58)
            cardStroke.Thickness = 1.2
            cardStroke.Parent = card

            -- Превью картинки карты (аккуратный баннер сверху)
            local img = Instance.new("ImageLabel")
            img.Name = "MapImage"
            img.Size = UDim2.new(1, -8, 0, 64)
            img.Position = UDim2.new(0, 4, 0, 4)
            img.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
            img.BorderSizePixel = 0
            img.ScaleType = Enum.ScaleType.Crop
            img.ZIndex = 15
            img.Visible = false
            img.Parent = card

            local imgCorner = Instance.new("UICorner")
            imgCorner.CornerRadius = UDim.new(0, 6)
            imgCorner.Parent = img

            -- Заглушка, если картинки нет
            local placeholder = Instance.new("TextLabel")
            placeholder.Name = "Placeholder"
            placeholder.Size = UDim2.new(1, -8, 0, 64)
            placeholder.Position = UDim2.new(0, 4, 0, 4)
            placeholder.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
            placeholder.Text = "РАУНД ИДЁТ"
            placeholder.TextColor3 = Color3.fromRGB(100, 100, 115)
            placeholder.Font = Enum.Font.GothamBold
            placeholder.TextSize = 9
            placeholder.ZIndex = 14
            placeholder.Parent = card

            local phCorner = Instance.new("UICorner")
            phCorner.CornerRadius = UDim.new(0, 6)
            phCorner.Parent = placeholder

            -- Название карты
            local titleLbl = Instance.new("TextLabel")
            titleLbl.Name = "TitleLabel"
            titleLbl.Size = UDim2.new(1, -8, 0, 18)
            titleLbl.Position = UDim2.new(0, 4, 0, 71)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = "Карта #" .. i
            titleLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
            titleLbl.Font = Enum.Font.GothamBold
            titleLbl.TextSize = 11
            titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
            titleLbl.TextXAlignment = Enum.TextXAlignment.Center
            titleLbl.Parent = card

            -- Счетчик голосов
            local votesLbl = Instance.new("TextLabel")
            votesLbl.Name = "VotesLabel"
            votesLbl.Size = UDim2.new(1, -8, 0, 14)
            votesLbl.Position = UDim2.new(0, 4, 0, 89)
            votesLbl.BackgroundTransparency = 1
            votesLbl.Text = "Голосов: 0"
            votesLbl.TextColor3 = Color3.fromRGB(130, 180, 255)
            votesLbl.Font = Enum.Font.Gotham
            votesLbl.TextSize = 10
            votesLbl.TextXAlignment = Enum.TextXAlignment.Center
            votesLbl.Parent = card

            -- Кнопка выбора/глитча карты
            local actionBtn = Instance.new("TextButton")
            actionBtn.Name = "ActionButton"
            actionBtn.Size = UDim2.new(1, -8, 0, 28)
            actionBtn.Position = UDim2.new(0, 4, 1, -33)
            actionBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
            actionBtn.Text = "ВЫБРАТЬ"
            actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            actionBtn.Font = Enum.Font.GothamBold
            actionBtn.TextSize = 11
            actionBtn.Parent = card

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = actionBtn

            actionBtn.MouseButton1Click:Connect(function()
                startVoteGlitchLoop(i)
            end)

            HorizontalCards[i] = {
                Card = card,
                Stroke = cardStroke,
                Image = img,
                Placeholder = placeholder,
                Title = titleLbl,
                Votes = votesLbl,
                Button = actionBtn,
                LastImage = "",
                LastTitle = "",
                LastVotes = -1,
                LastState = nil
            }
        end

        return true
    end

    task.spawn(function()
        for _ = 1, 15 do
            if setupHorizontalRow() then break end
            task.wait(0.3)
        end
    end)

    -- ==========================================
    -- ЦИКЛ ОБНОВЛЕНИЯ ДАННЫХ (0.4 СЕК)
    -- ==========================================
    local lastStatusText = ""

    task.spawn(function()
        while task.wait(0.4) do
            if not HorizontalCards[1] then
                setupHorizontalRow()
            end

            local anyVoteActive = false

            for i = 1, 3 do
                local mName, vCount, mImg, isCardActive = getVoteCardData(i)
                if isCardActive then anyVoteActive = true end

                local cardUI = HorizontalCards[i]
                if cardUI then
                    -- 1. Картинка
                    if isValidVoteImage(mImg) then
                        if cardUI.LastImage ~= mImg then
                            cardUI.Image.Image = mImg
                            cardUI.Image.Visible = true
                            cardUI.Placeholder.Visible = false
                            cardUI.LastImage = mImg
                        end
                    else
                        if cardUI.Image.Visible then
                            cardUI.Image.Image = ""
                            cardUI.Image.Visible = false
                            cardUI.Placeholder.Visible = true
                            cardUI.LastImage = ""
                        end
                    end

                    -- 2. Название
                    local cleanName = (mName ~= "" and mName ~= "MapName") and mName or ("Карта " .. i)
                    if cardUI.LastTitle ~= cleanName then
                        cardUI.Title.Text = cleanName
                        cardUI.LastTitle = cleanName
                    end

                    -- 3. Голоса
                    if cardUI.LastVotes ~= vCount then
                        cardUI.Votes.Text = "Голосов: " .. tostring(vCount)
                        cardUI.LastVotes = vCount
                    end

                    -- 4. Статус кнопки и карточки
                    local stateKey = (IsGlitchingVote and TargetVoteIndex == i and "FARM")
                        or (isCardActive and "READY")
                        or "CLOSED"

                    if cardUI.LastState ~= stateKey then
                        cardUI.LastState = stateKey

                        if stateKey == "FARM" then
                            cardUI.Card.BackgroundColor3 = Color3.fromRGB(20, 60, 32)
                            cardUI.Stroke.Color = Color3.fromRGB(50, 220, 100)
                            cardUI.Button.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
                            cardUI.Button.Text = "ФАРМ..."
                            cardUI.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
                        elseif stateKey == "READY" then
                            cardUI.Card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
                            cardUI.Stroke.Color = Color3.fromRGB(48, 48, 58)
                            cardUI.Button.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
                            cardUI.Button.Text = "ВЫБРАТЬ"
                            cardUI.Button.TextColor3 = Color3.fromRGB(240, 240, 240)
                        else
                            cardUI.Card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                            cardUI.Stroke.Color = Color3.fromRGB(36, 36, 42)
                            cardUI.Button.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
                            cardUI.Button.Text = "ЗАКРЫТО"
                            cardUI.Button.TextColor3 = Color3.fromRGB(110, 110, 120)
                        end
                    end
                end
            end

            -- 5. Верхний статус
            local newStatusTitle = ""
            local newStatusContent = ""

            if IsGlitchingVote then
                local aName = getVoteCardData(TargetVoteIndex)
                newStatusTitle = "Фарм Активен!"
                newStatusContent = string.format("Карта: %s (ТП -> 0.8с -> Ресет)", tostring(aName))
            elseif anyVoteActive then
                newStatusTitle = "Идёт голосование"
                newStatusContent = "Картинки карт доступны. Нажмите «ВЫБРАТЬ» под нужной картой."
            else
                newStatusTitle = "Раунд начался"
                newStatusContent = "Голосование закрыто (картинки отсутствуют). Фарм заблокирован."
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
