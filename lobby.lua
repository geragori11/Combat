return function(Window)
    local Players = game:GetService("Players")
    local StarterGui = game:GetService("StarterGui")
    local CoreGui = game:GetService("CoreGui")
    local Lighting = game:GetService("Lighting")
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
    -- СОСТОЯНИЕ ГЛИТЧА И АВТОВЫБОРА
    -- ==========================================
    local IsGlitchingVote = false
    local TargetVoteIndex = nil
    local CurrentVoteThread = nil
    local HiddenOverlays = {}
    local OverlayConnection = nil

    local AutoVoteEnabled = false
    local AutoVotedInCurrentSession = false
    local SelectedAutoMaps = {}
    local AutoMapCards = {}

    -- Режим отладки и дампа карт
    local DebugDumpEnabled = false
    local DumpedMapsCache = {}

    -- Актуальный список карт MM2 (обновлён по дампам mm2maps/)
    local MM2_MAPS = {
        { Name = "Bio Lab",           Image = "rbxassetid://3214475802" },
        { Name = "Factory",           Image = "rbxassetid://3214476069" },
        { Name = "Hospital 3",        Image = "rbxassetid://3214476562" },
        { Name = "Hotel 2",           Image = "rbxassetid://3214477063" },
        { Name = "House 2",           Image = "rbxassetid://3214477411" },
        { Name = "Mansion 2",         Image = "rbxassetid://3214477676" },
        { Name = "Mil Base",          Image = "rbxassetid://3214477899" },
        { Name = "Office 3",          Image = "rbxassetid://3214478924" },
        { Name = "Police Station",    Image = "rbxassetid://3214479176" },
        { Name = "Research Facility", Image = "rbxassetid://4751350477" },
        { Name = "Workplace",         Image = "rbxassetid://3214479481" },
        { Name = "Bank 2",            Image = "rbxassetid://3214475169" }
    }

    for _, mapData in ipairs(MM2_MAPS) do
        SelectedAutoMaps[mapData.Name] = false
    end

    -- ==========================================
    -- ФУНКЦИИ ДАМПА КАРТ ДЛЯ ОТЛАДКИ
    -- ==========================================
    local function sanitizeFilename(name)
        local clean = tostring(name or ""):gsub('[\\/:*?"<>|]', "_")
        clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
        return clean
    end

    local function dumpMapInfo(mapName, imageId)
        if not DebugDumpEnabled then return end
        if typeof(writefile) ~= "function" then return end

        pcall(function()
            pcall(function()
                if typeof(makefolder) == "function" then
                    makefolder("mm2maps")
                end
            end)

            local cleanName = sanitizeFilename(mapName)
            if cleanName == "" or cleanName == "Ожидание..." or cleanName == "Ожидание" then
                return
            end

            local cacheKey = cleanName .. "_" .. tostring(imageId)
            if DumpedMapsCache[cacheKey] then
                return
            end
            DumpedMapsCache[cacheKey] = true

            local filePath = "mm2maps/" .. cleanName .. ".txt"
            local fileData = string.format("Название: %s\nID Картинки: %s\nВремя: %s\n", tostring(mapName), tostring(imageId), os.date("%X"))
            
            writefile(filePath, fileData)

            -- Дополнительно пишем в общий лог-файл
            pcall(function()
                local logPath = "mm2maps/dump_log.txt"
                local existing = ""
                if typeof(readfile) == "function" then
                    pcall(function() existing = readfile(logPath) end)
                end
                writefile(logPath, existing .. string.format("[%s] Карта: %s | ImageID: %s\n", os.date("%X"), tostring(mapName), tostring(imageId)))
            end)

            Notify("Отладка MM2", "Сдамплена карта: " .. cleanName, 2.5)
            print("[XClient Debug] Сдамплена карта: " .. cleanName .. " | ID: " .. tostring(imageId))
        end)
    end

    -- ==========================================
    -- БЫСТРОЕ И ЛЁГКОЕ ОТКЛЮЧЕНИЕ ОВЕРЛЕЕВ
    -- ==========================================
    local function isOverlayName(name)
        local n = name:lower()
        return n:find("fade")
            or n:find("black")
            or n:find("overlay")
            or n:find("blind")
            or n:find("death")
            or n:find("vignette")
            or n:find("loading")
            or n:find("transition")
            or n:find("intro")
    end

    local function handleGuiObject(gui)
        if not gui then return end
        if gui:IsA("ScreenGui") then
            if isOverlayName(gui.Name) and gui.Enabled then
                HiddenOverlays[gui] = true
                gui.Enabled = false
            else
                for _, child in ipairs(gui:GetChildren()) do
                    if (child:IsA("Frame") or child:IsA("ImageLabel")) and isOverlayName(child.Name) and child.Visible then
                        HiddenOverlays[child] = true
                        child.Visible = false
                    end
                end
            end
        end
    end

    local function suppressOverlays()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetChildren()) do
                handleGuiObject(gui)
            end
        end

        for _, effect in ipairs(Lighting:GetChildren()) do
            if (effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect")) and effect.Enabled then
                if isOverlayName(effect.Name) then
                    HiddenOverlays[effect] = true
                    effect.Enabled = false
                end
            end
        end

        local camera = workspace.CurrentCamera
        if camera then
            for _, effect in ipairs(camera:GetChildren()) do
                if (effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect")) and effect.Enabled then
                    if isOverlayName(effect.Name) then
                        HiddenOverlays[effect] = true
                        effect.Enabled = false
                    end
                end
            end
        end
    end

    local function enableOverlayProtection()
        suppressOverlays()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui and not OverlayConnection then
            OverlayConnection = playerGui.ChildAdded:Connect(function(child)
                if IsGlitchingVote then
                    task.wait()
                    handleGuiObject(child)
                end
            end)
        end
    end

    local function restoreOverlays()
        if OverlayConnection then
            OverlayConnection:Disconnect()
            OverlayConnection = nil
        end

        for obj, _ in pairs(HiddenOverlays) do
            pcall(function()
                if obj and obj.Parent then
                    if obj:IsA("ScreenGui") or obj:IsA("PostEffect") then
                        obj.Enabled = true
                    elseif obj:IsA("GuiObject") then
                        obj.Visible = true
                    end
                end
            end)
        end
        table.clear(HiddenOverlays)
    end

    -- ==========================================
    -- ПОИСК ОБЪЕКТОВ ЛОББИ И КАРТ MM2
    -- ==========================================
    local function getLobby()
        return workspace:FindFirstChild("RegularLobby")
            or workspace:FindFirstChild("NormalLobby")
            or workspace:FindFirstChild("Lobby")
            or workspace:FindFirstChild("ChristmasLobby")
            or workspace:FindFirstChild("HalloweenLobby")
    end

    local function getVotePadModel(index)
        local lobby = getLobby()
        local sIdx = tostring(index)

        if lobby then
            local votePads = lobby:FindFirstChild("VotePads")
            if votePads then
                local pad = votePads:FindFirstChild("VotePad" .. sIdx)
                    or votePads:FindFirstChild("Pad" .. sIdx)
                    or votePads:FindFirstChild(sIdx)
                if pad then return pad end
            end

            local directPad = lobby:FindFirstChild("VotePad" .. sIdx)
                or lobby:FindFirstChild("Pad" .. sIdx)
            if directPad then return directPad end

            for _, desc in ipairs(lobby:GetDescendants()) do
                if desc.Name == "VotePad" .. sIdx or desc.Name == "VotePad_" .. sIdx then
                    return desc
                end
            end
        end

        local globalVotePads = workspace:FindFirstChild("VotePads")
        if globalVotePads then
            local pad = globalVotePads:FindFirstChild("VotePad" .. sIdx)
                or globalVotePads:FindFirstChild("Pad" .. sIdx)
                or globalVotePads:FindFirstChild(sIdx)
            if pad then return pad end
        end

        return nil
    end

    local function getVoteTargetPart(index)
        local padModel = getVotePadModel(index)
        if padModel then
            local detector = padModel:FindFirstChild("Detector" .. tostring(index))
                or padModel:FindFirstChild("Detector")
                or padModel:FindFirstChild("Pad")
            if detector and detector:IsA("BasePart") then
                return detector
            end
            if padModel:IsA("BasePart") then
                return padModel
            end
            local anyPart = padModel:FindFirstChildWhichIsA("BasePart")
            if anyPart then return anyPart end
        end

        local lobby = getLobby()
        if lobby then
            local votePads = lobby:FindFirstChild("VotePads")
            if votePads then
                local detector = votePads:FindFirstChild("Detector" .. tostring(index))
                    or votePads:FindFirstChild("Pad" .. tostring(index))
                if detector and detector:IsA("BasePart") then
                    return detector
                end
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

    local function extractMapInfoFromInstance(inst)
        if not inst then return nil, nil, nil end
        local mapName = nil
        local votesCount = nil
        local mapImage = nil

        for _, desc in ipairs(inst:GetDescendants()) do
            if desc:IsA("TextLabel") then
                local text = desc.Text:gsub("^%s+", ""):gsub("%s+$", "")
                local textLower = text:lower()
                local nameLower = desc.Name:lower()

                if nameLower:find("vote") or nameLower:find("count") then
                    local num = tonumber(text:match("%d+"))
                    if num then votesCount = num end
                elseif nameLower == "mapname" or nameLower == "maptitle" or nameLower == "title" or nameLower == "map" then
                    if text ~= "" and text ~= "MapName" and text ~= "MAP NAME" then
                        mapName = text
                    end
                elseif not mapName and text ~= "" and not textLower:find("vote") and not textLower:find("голос")
                    and not text:match("^%d+$") and textLower ~= "map name" and textLower ~= "mapname"
                    and textLower ~= "раунд идёт" and textLower ~= "ожидание" then
                    mapName = text
                end
            elseif desc:IsA("ImageLabel") or desc:IsA("Decal") then
                if not mapImage then
                    local img = desc:IsA("ImageLabel") and desc.Image or desc.Texture
                    if typeof(img) == "string" and #img > 5 and isValidVoteImage(img) then
                        mapImage = img
                    end
                end
            end
        end

        return mapName, votesCount, mapImage
    end

    local function getVoteCardData(index)
        local lobby = getLobby()
        if not lobby then return "Карта " .. index, 0, "", false end

        local sIdx = tostring(index)
        local padModel = getVotePadModel(index)

        local name1, votes1, img1 = extractMapInfoFromInstance(padModel)

        local iconModel = nil
        if lobby:FindFirstChild("VoteIcons") then
            iconModel = lobby.VoteIcons:FindFirstChild("VotePad" .. sIdx)
                or lobby.VoteIcons:FindFirstChild("Pad" .. sIdx)
                or lobby.VoteIcons:FindFirstChild(sIdx)
        end
        local name2, votes2, img2 = extractMapInfoFromInstance(iconModel)

        local mapName = name1 or name2 or ("Карта " .. index)
        local votesCount = votes1 or votes2 or 0
        local mapImage = img1 or img2 or ""

        local isVotingActive = isValidVoteImage(mapImage)
        return mapName, votesCount, mapImage, isVotingActive
    end

    -- ==========================================
    -- ПРОВЕРКА КАРТЫ ДЛЯ АВТОВЫБОРА
    -- ==========================================
    local function cleanMapString(str)
        return tostring(str or ""):lower():gsub("[%s%-_%p]", "")
    end

    local function isMapSelectedForAuto(rawMapName)
        local cleanGameName = cleanMapString(rawMapName)
        if cleanGameName == "" or cleanGameName:find("карта") or cleanGameName:find("ожидание") then
            return false
        end

        for targetMapName, isChecked in pairs(SelectedAutoMaps) do
            if isChecked then
                local cleanTarget = cleanMapString(targetMapName)
                if cleanGameName:find(cleanTarget, 1, true) or cleanTarget:find(cleanGameName, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    -- ==========================================
    -- БЫСТРОЕ ОЖИДАНИЕ ПЕРСОНАЖА (0.01 СЕК)
    -- ==========================================
    local function waitVoteRespawnFast(oldChar)
        while IsGlitchingVote do
            local char = LocalPlayer.Character
            if char and char ~= oldChar and char.Parent == workspace then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    return char, hrp, hum
                end
            end
            task.wait(0.01)
        end
        return nil, nil, nil
    end

    -- ==========================================
    -- УПРАВЛЕНИЕ ГЛИТЧЕМ (ТП СТОЯ -> 0.2с -> РЕСЕТ)
    -- ==========================================
    local function stopVoteGlitch(reason)
        if not IsGlitchingVote and not CurrentVoteThread then return end
        IsGlitchingVote = false
        TargetVoteIndex = nil

        if CurrentVoteThread then
            task.cancel(CurrentVoteThread)
            CurrentVoteThread = nil
        end

        restoreOverlays()

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

        enableOverlayProtection()

        CurrentVoteThread = task.spawn(function()
            local currentChar = LocalPlayer.Character

            while IsGlitchingVote do
                local _, _, curImg, curActive = getVoteCardData(index)
                if not curActive or not isValidVoteImage(curImg) then
                    stopVoteGlitch("Раунд начался! Картинка карты исчезла, фарм отключен.")
                    break
                end

                local targetPart = getVoteTargetPart(index)
                if not targetPart then
                    task.wait(0.2)
                    continue
                end

                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")

                if not char or not hrp or not hum or hum.Health <= 0 or char.Parent ~= workspace then
                    char, hrp, hum = waitVoteRespawnFast(currentChar)
                end
                if not IsGlitchingVote or not char or not hrp or not hum then break end

                currentChar = char

                local targetPosition = targetPart.Position + Vector3.new(0, 3.2, 0)
                hrp.CFrame = CFrame.new(targetPosition)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero

                hum.PlatformStand = false
                hum.Sit = false
                hum:ChangeState(Enum.HumanoidStateType.Running)

                pcall(function()
                    if typeof(firetouchinterest) == "function" then
                        firetouchinterest(hrp, targetPart, 0)
                    end
                end)

                task.wait(0.2)
                if not IsGlitchingVote then break end

                if (hrp.Position - targetPosition).Magnitude > 5 then
                    hrp.CFrame = CFrame.new(targetPosition)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    pcall(function()
                        if typeof(firetouchinterest) == "function" then
                            firetouchinterest(hrp, targetPart, 0)
                        end
                    end)
                end

                pcall(function() hum.Health = 0 end)
                pcall(function() char:BreakJoints() end)

                if IsGlitchingVote then
                    currentChar, _, _ = waitVoteRespawnFast(currentChar)
                end
            end
        end)
    end

    -- ==========================================
    -- УНИВЕРСАЛЬНЫЙ ПОИСК КОНТЕЙНЕРА В RAYFIELD
    -- ==========================================
    local function findContainerByTag(paragraphObj, tag)
        local getupvals = debug.getupvalues or getupvalues
        if getupvals and paragraphObj and type(paragraphObj.Set) == "function" then
            local found = nil
            pcall(function()
                for _, uv in pairs(getupvals(paragraphObj.Set)) do
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
                    if desc:IsA("TextLabel") and desc.Text:find(tag) then
                        match = desc.Parent
                        break
                    end
                end
            end)
            if match then return match end
        end
        return nil
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

    local function setupHorizontalRow()
        local host = findContainerByTag(HostParagraph, UNIQUE_ROW_TAG)
        if not host then return false end

        for _, child in ipairs(host:GetChildren()) do
            if child:IsA("TextLabel") then
                child.Visible = false
            end
        end

        local rayfieldPadding = host:FindFirstChildOfClass("UIPadding")
        if rayfieldPadding then
            rayfieldPadding.PaddingTop = UDim.new(0, 0)
            rayfieldPadding.PaddingBottom = UDim.new(0, 0)
            rayfieldPadding.PaddingLeft = UDim.new(0, 0)
            rayfieldPadding.PaddingRight = UDim.new(0, 0)
        end

        host.Size = UDim2.new(1, 0, 0, 185)
        host.ClipsDescendants = true
        host.BackgroundTransparency = 1

        local oldRow = host:FindFirstChild("MapRowContainer")
        if oldRow then oldRow:Destroy() end

        local rowFrame = Instance.new("Frame")
        rowFrame.Name = "MapRowContainer"
        rowFrame.Size = UDim2.new(1, 0, 1, 0)
        rowFrame.Position = UDim2.new(0, 0, 0, 0)
        rowFrame.BackgroundTransparency = 1
        rowFrame.Parent = host

        local cardPositions = {
            UDim2.new(0, 0, 0, 0),
            UDim2.new(0.3425, 0, 0, 0),
            UDim2.new(0.685, 0, 0, 0)
        }

        for i = 1, 3 do
            local card = Instance.new("Frame")
            card.Name = "CardSlot_" .. i
            card.Size = UDim2.new(0.315, 0, 1, 0)
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

            local imgBox = Instance.new("Frame")
            imgBox.Name = "ImageBox"
            imgBox.Size = UDim2.new(1, -8, 0, 84)
            imgBox.Position = UDim2.new(0, 4, 0, 5)
            imgBox.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
            imgBox.BorderSizePixel = 0
            imgBox.ClipsDescendants = true
            imgBox.Parent = card

            local boxCorner = Instance.new("UICorner")
            boxCorner.CornerRadius = UDim.new(0, 6)
            boxCorner.Parent = imgBox

            local img = Instance.new("ImageLabel")
            img.Name = "MapImage"
            img.Size = UDim2.new(1, 0, 1, 0)
            img.Position = UDim2.new(0, 0, 0, 0)
            img.BackgroundTransparency = 1
            img.ScaleType = Enum.ScaleType.Fit
            img.ZIndex = 15
            img.Visible = false
            img.Parent = imgBox

            local placeholder = Instance.new("TextLabel")
            placeholder.Name = "Placeholder"
            placeholder.Size = UDim2.new(1, 0, 1, 0)
            placeholder.Position = UDim2.new(0, 0, 0, 0)
            placeholder.BackgroundTransparency = 1
            placeholder.Text = "РАУНД ИДЁТ"
            placeholder.TextColor3 = Color3.fromRGB(110, 110, 125)
            placeholder.Font = Enum.Font.GothamBold
            placeholder.TextSize = 10
            placeholder.ZIndex = 14
            placeholder.Parent = imgBox

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Name = "TitleLabel"
            titleLbl.Size = UDim2.new(1, -6, 0, 18)
            titleLbl.Position = UDim2.new(0, 3, 0, 93)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = "Карта #" .. i
            titleLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
            titleLbl.Font = Enum.Font.GothamBold
            titleLbl.TextSize = 11
            titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
            titleLbl.TextXAlignment = Enum.TextXAlignment.Center
            titleLbl.Parent = card

            local votesLbl = Instance.new("TextLabel")
            votesLbl.Name = "VotesLabel"
            votesLbl.Size = UDim2.new(1, -6, 0, 16)
            votesLbl.Position = UDim2.new(0, 3, 0, 113)
            votesLbl.BackgroundTransparency = 1
            votesLbl.Text = "Голосов: 0"
            votesLbl.TextColor3 = Color3.fromRGB(130, 180, 255)
            votesLbl.Font = Enum.Font.Gotham
            votesLbl.TextSize = 10
            votesLbl.TextXAlignment = Enum.TextXAlignment.Center
            votesLbl.Parent = card

            local actionBtn = Instance.new("TextButton")
            actionBtn.Name = "ActionButton"
            actionBtn.Size = UDim2.new(1, -8, 0, 28)
            actionBtn.Position = UDim2.new(0, 4, 1, -34)
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

    -- ==========================================
    -- ПОДВКЛАДКА: АВТОВЫБОР КАРТЫ
    -- ==========================================
    VotingTab:CreateSection("Автовыбор карты")

    VotingTab:CreateToggle({
        Name = "Включить автонакрутку",
        CurrentValue = false,
        Flag = "Toggle_AutoVoteMaster",
        Callback = function(Value)
            AutoVoteEnabled = Value
            if Value then
                Notify("Автовыбор", "Автонакрутка включена!", 2)
            else
                Notify("Автовыбор", "Автонакрутка выключена", 2)
            end
        end
    })

    VotingTab:CreateToggle({
        Name = "Режим отладки (дамп карт в mm2maps/)",
        CurrentValue = false,
        Flag = "Toggle_DebugDumpMaps",
        Callback = function(Value)
            DebugDumpEnabled = Value
            if Value then
                Notify("Отладка MM2", "Дамп включен! Карты сохраняются в mm2maps/", 3)
            else
                Notify("Отладка MM2", "Дамп карт отключен", 2)
            end
        end
    })

    local function updateCardVisual(mapName)
        local cardInfo = AutoMapCards[mapName]
        if not cardInfo then return end

        local isSelected = SelectedAutoMaps[mapName] == true
        if isSelected then
            cardInfo.Card.BackgroundColor3 = Color3.fromRGB(24, 58, 36)
            cardInfo.Stroke.Color = Color3.fromRGB(55, 230, 110)
            cardInfo.Stroke.Thickness = 1.8
        else
            cardInfo.Card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
            cardInfo.Stroke.Color = Color3.fromRGB(44, 44, 52)
            cardInfo.Stroke.Thickness = 1.2
        end
    end

    VotingTab:CreateButton({
        Name = "Выбрать все карты",
        Callback = function()
            for _, mapData in ipairs(MM2_MAPS) do
                SelectedAutoMaps[mapData.Name] = true
                updateCardVisual(mapData.Name)
            end
            Notify("Автовыбор", "Все карты выбраны!", 1.5)
        end
    })

    VotingTab:CreateButton({
        Name = "Снять выбор со всех",
        Callback = function()
            for _, mapData in ipairs(MM2_MAPS) do
                SelectedAutoMaps[mapData.Name] = false
                updateCardVisual(mapData.Name)
            end
            Notify("Автовыбор", "Выбор со всех карт сброшен!", 1.5)
        end
    })

    local UNIQUE_AUTO_GRID_TAG = "AUTO_MAP_GRID_CONTAINER"
    local AutoGridParagraph = VotingTab:CreateParagraph({
        Title = UNIQUE_AUTO_GRID_TAG,
        Content = " "
    })

    local function setupAutoMapGrid()
        local host = findContainerByTag(AutoGridParagraph, UNIQUE_AUTO_GRID_TAG)
        if not host then return false end

        for _, child in ipairs(host:GetChildren()) do
            if child:IsA("TextLabel") then
                child.Visible = false
            end
        end

        local rayfieldPadding = host:FindFirstChildOfClass("UIPadding")
        if rayfieldPadding then
            rayfieldPadding.PaddingTop = UDim.new(0, 0)
            rayfieldPadding.PaddingBottom = UDim.new(0, 0)
            rayfieldPadding.PaddingLeft = UDim.new(0, 0)
            rayfieldPadding.PaddingRight = UDim.new(0, 0)
        end

        host.Size = UDim2.new(1, 0, 0, 275)
        host.ClipsDescendants = true
        host.BackgroundTransparency = 1

        local oldGrid = host:FindFirstChild("AutoMapScroll")
        if oldGrid then oldGrid:Destroy() end

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "AutoMapScroll"
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.Position = UDim2.new(0, 0, 0, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(75, 75, 95)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Parent = host

        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.new(0.485, 0, 0, 56)
        gridLayout.CellPadding = UDim2.new(0.025, 0, 0, 7)
        gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.Parent = scroll

        local gridPadding = Instance.new("UIPadding")
        gridPadding.PaddingTop = UDim.new(0, 4)
        gridPadding.PaddingBottom = UDim.new(0, 8)
        gridPadding.PaddingLeft = UDim.new(0, 4)
        gridPadding.PaddingRight = UDim.new(0, 4)
        gridPadding.Parent = scroll

        for idx, mapData in ipairs(MM2_MAPS) do
            local cardBtn = Instance.new("TextButton")
            cardBtn.Name = "MapCard_" .. mapData.Name
            cardBtn.Text = ""
            cardBtn.AutoButtonColor = false
            cardBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
            cardBtn.BorderSizePixel = 0
            cardBtn.LayoutOrder = idx
            cardBtn.Parent = scroll

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 7)
            cardCorner.Parent = cardBtn

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Name = "Stroke"
            cardStroke.Color = Color3.fromRGB(44, 44, 52)
            cardStroke.Thickness = 1.2
            cardStroke.Parent = cardBtn

            local imgBox = Instance.new("Frame")
            imgBox.Name = "ImageBox"
            imgBox.Size = UDim2.new(0, 44, 0, 44)
            imgBox.Position = UDim2.new(0, 6, 0.5, -22)
            imgBox.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
            imgBox.BorderSizePixel = 0
            imgBox.ClipsDescendants = true
            imgBox.Parent = cardBtn

            local boxCorner = Instance.new("UICorner")
            boxCorner.CornerRadius = UDim.new(0, 5)
            boxCorner.Parent = imgBox

            local imgLabel = Instance.new("ImageLabel")
            imgLabel.Name = "Thumb"
            imgLabel.Size = UDim2.new(1, 0, 1, 0)
            imgLabel.BackgroundTransparency = 1
            imgLabel.ScaleType = Enum.ScaleType.Crop
            imgLabel.Image = mapData.Image
            imgLabel.Parent = imgBox

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Name = "Title"
            titleLbl.Size = UDim2.new(1, -58, 1, 0)
            titleLbl.Position = UDim2.new(0, 56, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = mapData.Name
            titleLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
            titleLbl.Font = Enum.Font.GothamBold
            titleLbl.TextSize = 12
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.TextYAlignment = Enum.TextYAlignment.Center
            titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
            titleLbl.Parent = cardBtn

            cardBtn.MouseButton1Click:Connect(function()
                SelectedAutoMaps[mapData.Name] = not SelectedAutoMaps[mapData.Name]
                updateCardVisual(mapData.Name)
            end)

            AutoMapCards[mapData.Name] = {
                Card = cardBtn,
                Stroke = cardStroke,
                Image = imgLabel,
                Title = titleLbl
            }

            updateCardVisual(mapData.Name)
        end

        return true
    end

    task.spawn(function()
        for _ = 1, 15 do
            local okRow = setupHorizontalRow()
            local okGrid = setupAutoMapGrid()
            if okRow and okGrid then break end
            task.wait(0.3)
        end
    end)

    -- ==========================================
    -- ЦИКЛ ОБНОВЛЕНИЯ ДАННЫХ И АВТОВЫБОРА (0.4 СЕК)
    -- ==========================================
    local lastStatusText = ""

    task.spawn(function()
        while task.wait(0.4) do
            if not HorizontalCards[1] then
                setupHorizontalRow()
            end
            if not next(AutoMapCards) then
                setupAutoMapGrid()
            end

            local anyVoteActive = false
            local availableVotingCards = {}

            for i = 1, 3 do
                local mName, vCount, mImg, isCardActive = getVoteCardData(i)
                if isCardActive and isValidVoteImage(mImg) then
                    anyVoteActive = true
                    table.insert(availableVotingCards, {
                        Index = i,
                        Name = mName
                    })

                    -- Дамп карты в папку mm2maps при включенной отладке
                    if DebugDumpEnabled then
                        dumpMapInfo(mName, mImg)
                    end

                    -- Динамическое обновление картинок в сетке
                    for _, mData in ipairs(MM2_MAPS) do
                        if cleanMapString(mName):find(cleanMapString(mData.Name), 1, true) then
                            if mData.Image ~= mImg then
                                mData.Image = mImg
                                local cardRef = AutoMapCards[mData.Name]
                                if cardRef and cardRef.Image then
                                    cardRef.Image.Image = mImg
                                end
                            end
                        end
                    end
                end

                local cardUI = HorizontalCards[i]
                if cardUI then
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

                    local cleanName = (mName ~= "" and mName ~= "MapName") and mName or ("Карта " .. i)
                    if cardUI.LastTitle ~= cleanName then
                        cardUI.Title.Text = cleanName
                        cardUI.LastTitle = cleanName
                    end

                    if cardUI.LastVotes ~= vCount then
                        cardUI.Votes.Text = "Голосов: " .. tostring(vCount)
                        cardUI.LastVotes = vCount
                    end

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

            -- Автовыбор карты при начале голосования
            if anyVoteActive then
                if AutoVoteEnabled and not IsGlitchingVote and not AutoVotedInCurrentSession then
                    local matchedTargets = {}
                    for _, cardInfo in ipairs(availableVotingCards) do
                        if isMapSelectedForAuto(cardInfo.Name) then
                            table.insert(matchedTargets, cardInfo)
                        end
                    end

                    if #matchedTargets > 0 then
                        AutoVotedInCurrentSession = true
                        local chosen = matchedTargets[math.random(1, #matchedTargets)]
                        Notify("Автовыбор", "Совпадение! Выбрана карта: " .. tostring(chosen.Name), 3)
                        startVoteGlitchLoop(chosen.Index)
                    end
                end
            else
                AutoVotedInCurrentSession = false
            end

            local newStatusTitle = ""
            local newStatusContent = ""

            if IsGlitchingVote then
                local aName = getVoteCardData(TargetVoteIndex)
                newStatusTitle = "Фарм Активен!"
                newStatusContent = string.format("Карта: %s (ТП -> 0.2с -> Ресет)", tostring(aName))
            elseif anyVoteActive then
                newStatusTitle = "Идёт голосование"
                newStatusContent = AutoVoteEnabled and "Автовыбор активен. Ожидание совпадений..." or "Картинки карт доступны. Нажмите «ВЫБРАТЬ» под нужной картой."
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
