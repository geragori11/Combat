-- =========================================================================
-- XCLIENT MODULE: OPTIMIZED MM2 VOTING TAB (ZERO-LAG + FIXED IMAGES)
-- Формат внешнего подключаемого модуля (как player.lua / combat.lua)
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
            if padIcon and padIcon:FindFirstChild("Surface") and padIcon.Surface:FindFirstChild("Background") then
                local bg = padIcon.Surface.Background
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
    -- УПРАВЛЕНИЕ ГЛИТЧЕМ
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
            Notify("Заблокировано", "Картинка отсутствует! Раунд уже начался или идёт.", 3.5)
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
    VotingTab:CreateSection("Статус Голосования")

    local VoteStatusParagraph = VotingTab:CreateParagraph({
        Title = "Статус системы",
        Content = "Ожидание раунда голосования..."
    })

    VotingTab:CreateSection("Выбор Карты (Нажмите для фарма)")

    local ButtonWidgets = {}
    local UniqueTags = {
        "__XC_VOTE_SLOT_1__",
        "__XC_VOTE_SLOT_2__",
        "__XC_VOTE_SLOT_3__"
    }

    for i = 1, 3 do
        local btn = VotingTab:CreateButton({
            Name = UniqueTags[i],
            Callback = function()
                startVoteGlitchLoop(i)
            end
        })
        ButtonWidgets[i] = {
            ButtonInstance = btn,
            TextLabel = nil,
            ImageLabel = nil,
            LastText = "",
            LastImage = ""
        }
    end

    VotingTab:CreateSection("Управление")

    VotingTab:CreateButton({
        Name = "🛑 ОСТАНОВИТЬ ФАРМ",
        Callback = function()
            stopVoteGlitch()
        end
    })

    -- ==========================================
    -- ОДНОКРАТНАЯ ИНЪЕКЦИЯ С ПРЯМЫМ КЭШИРОВАНИЕМ
    -- ==========================================
    local function getGuiContainer()
        if CoreGui:FindFirstChild("Rayfield") then return CoreGui.Rayfield end
        if CoreGui:FindFirstChild("XClient") then return CoreGui.XClient end
        if LocalPlayer:FindFirstChild("PlayerGui") then
            if LocalPlayer.PlayerGui:FindFirstChild("Rayfield") then return LocalPlayer.PlayerGui.Rayfield end
            if LocalPlayer.PlayerGui:FindFirstChild("XClient") then return LocalPlayer.PlayerGui.XClient end
        end
        for _, g in ipairs(CoreGui:GetChildren()) do
            if g:IsA("ScreenGui") and (g.Name:find("Rayfield") or g.Name:find("XClient")) then
                return g
            end
        end
        return nil
    end

    local injectionDone = false
    local function setupInjectedButtons()
        if injectionDone then return true end

        local gui = getGuiContainer()
        if not gui then return false end

        local foundCount = 0
        for i = 1, 3 do
            if not ButtonWidgets[i].TextLabel then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text == UniqueTags[i] then
                        local btnContainer = desc.Parent
                        if btnContainer then
                            desc.Text = string.format("Карта %d (Ожидание...)", i)
                            desc.Position = UDim2.new(0, 46, 0, 0)
                            desc.Size = UDim2.new(1, -52, 1, 0)
                            desc.TextXAlignment = Enum.TextXAlignment.Left
                            desc.TextTruncate = Enum.TextTruncate.AtEnd

                            local preview = Instance.new("ImageLabel")
                            preview.Name = "MapIconPreview_" .. i
                            preview.Size = UDim2.new(0, 32, 0, 32)
                            preview.Position = UDim2.new(0, 7, 0.5, -16)
                            preview.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
                            preview.BorderSizePixel = 0
                            preview.BackgroundTransparency = 0
                            preview.ZIndex = 25
                            preview.ScaleType = Enum.ScaleType.Crop
                            preview.Visible = false
                            preview.Parent = btnContainer

                            local corner = Instance.new("UICorner")
                            corner.CornerRadius = UDim.new(0, 6)
                            corner.Parent = preview

                            ButtonWidgets[i].TextLabel = desc
                            ButtonWidgets[i].ImageLabel = preview
                            foundCount = foundCount + 1
                            break
                        end
                    end
                end
            else
                foundCount = foundCount + 1
            end
        end

        if foundCount == 3 then
            injectionDone = true
            return true
        end
        return false
    end

    task.spawn(function()
        for _ = 1, 10 do
            if setupInjectedButtons() then break end
            task.wait(0.5)
        end
    end)

    -- ==========================================
    -- ОПТИМИЗИРОВАННЫЙ ЦИКЛ ОБНОВЛЕНИЯ (БЕЗ ЛАГОВ)
    -- ==========================================
    local lastStatusText = ""

    task.spawn(function()
        while task.wait(0.4) do
            if not injectionDone then
                setupInjectedButtons()
            end

            local anyVoteActive = false

            for i = 1, 3 do
                local mName, vCount, mImg, isCardActive = getVoteCardData(i)
                if isCardActive then anyVoteActive = true end

                local widget = ButtonWidgets[i]

                -- 1. Обновление изображения
                if widget.ImageLabel then
                    if isValidVoteImage(mImg) then
                        if widget.LastImage ~= mImg then
                            widget.ImageLabel.Image = mImg
                            widget.ImageLabel.Visible = true
                            widget.LastImage = mImg
                        end
                    else
                        if widget.ImageLabel.Visible then
                            widget.ImageLabel.Image = ""
                            widget.ImageLabel.Visible = false
                            widget.LastImage = ""
                        end
                    end
                end

                -- 2. Обновление текста
                local prefix = ""
                if IsGlitchingVote and TargetVoteIndex == i then
                    prefix = "[ФАРМИТСЯ] "
                elseif not isCardActive then
                    prefix = "[ЗАКРЫТО] "
                end

                local cleanName = (mName ~= "" and mName ~= "MapName") and mName or ("Карта " .. i)
                local newButtonText = string.format("%s%s  (Голосов: %d)", prefix, cleanName, vCount)

                if widget.LastText ~= newButtonText then
                    widget.LastText = newButtonText
                    if widget.TextLabel then
                        widget.TextLabel.Text = newButtonText
                    elseif widget.ButtonInstance and widget.ButtonInstance.Set then
                        widget.ButtonInstance:Set(newButtonText)
                    end
                end
            end

            -- 3. Обновление параграфа статуса
            local newStatusTitle = ""
            local newStatusContent = ""

            if IsGlitchingVote then
                local aName = getVoteCardData(TargetVoteIndex)
                newStatusTitle = "Фарм Активен!"
                newStatusContent = string.format("Выбрана карта: %s\nЦикл: ТП -> 0.8с -> Ресет", tostring(aName))
            elseif anyVoteActive then
                newStatusTitle = "Идёт голосование"
                newStatusContent = "Картинки карт загружены. Нажмите на карту для запуска глитча."
            else
                newStatusTitle = "Раунд начался"
                newStatusContent = "Голосование недоступно (картинки отсутствуют). Фарм заблокирован."
            end

            local combinedStatus = newStatusTitle .. newStatusContent
            if lastStatusText ~= combinedStatus then
                lastStatusText = combinedStatus
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
