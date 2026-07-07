-- UI/core.lua
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Library = {
    CurrentTab = nil,
    TooltipDelay = 0.6
}

function Library:Tween(object, info, properties)
    local tween = TweenService:Create(object, TweenInfo.new(unpack(info)), properties)
    tween:Play()
    return tween
end

function Library:CreateWindow(config)
    local WindowName = config.Name or "Xeno Menu"
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RayfieldStyleMenu"
    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Главное окно
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Position = UDim2.new(0.5, -275, 0.5, -175)
    MainFrame.Size = UDim2.new(0, 550, 0, 350)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    -- Закругление краев главного окна
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    -- Заголовок активной вкладки по центру сверху
    local TopTabTitle = Instance.new("TextLabel")
    TopTabTitle.Name = "TopTabTitle"
    TopTabTitle.Position = UDim2.new(0, 160, 0, 12)
    TopTabTitle.Size = UDim2.new(1, -210, 0, 25)
    TopTabTitle.BackgroundTransparency = 1
    TopTabTitle.Text = "Select a Tab"
    TopTabTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    TopTabTitle.Font = Enum.Font.GothamBold
    TopTabTitle.TextSize = 16
    TopTabTitle.TextXAlignment = Enum.TextXAlignment.Center
    TopTabTitle.Parent = MainFrame

    -- Кнопка закрытия меню (X) справа сверху
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Position = UDim2.new(1, -35, 0, 12)
    CloseButton.Size = UDim2.new(0, 23, 0, 23)
    CloseButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    CloseButton.Text = "✕"
    CloseButton.TextColor3 = Color3.fromRGB(255, 75, 75)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 12
    CloseButton.Parent = MainFrame

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseButton

    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)

    -- Бинд на кнопку K для открытия/закрытия меню
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.K then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end)

    -- Тултип (подсказки)
    local Tooltip = Instance.new("TextLabel")
    Tooltip.Name = "Tooltip"
    Tooltip.Size = UDim2.new(0, 180, 0, 0)
    Tooltip.AutomaticSize = Enum.AutomaticSize.Y
    Tooltip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Tooltip.TextColor3 = Color3.fromRGB(200, 200, 200)
    Tooltip.Font = Enum.Font.Gotham
    Tooltip.TextSize = 12
    Tooltip.TextWrapped = true
    Tooltip.Visible = false
    Tooltip.ZIndex = 10
    Tooltip.Parent = ScreenGui
    
    local TooltipPadding = Instance.new("UIPadding")
    TooltipPadding.PaddingTop = UDim.new(0, 6)
    TooltipPadding.PaddingBottom = UDim.new(0, 6)
    TooltipPadding.PaddingLeft = UDim.new(0, 6)
    TooltipPadding.PaddingRight = UDim.new(0, 6)
    TooltipPadding.Parent = Tooltip

    -- Логика перетаскивания (Drag)
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Боковая панель
    local SideBar = Instance.new("Frame")
    SideBar.Name = "SideBar"
    SideBar.Size = UDim2.new(0, 150, 1, 0)
    SideBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    SideBar.BorderSizePixel = 0
    SideBar.Parent = MainFrame

    local SideCorner = Instance.new("UICorner")
    SideCorner.CornerRadius = UDim.new(0, 10)
    SideCorner.Parent = SideBar

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.Parent = SideBar
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Padding = UDim.new(0, 6)
    
    local SidePadding = Instance.new("UIPadding")
    SidePadding.PaddingTop = UDim.new(0, 10)
    SidePadding.PaddingLeft = UDim.new(0, 8)
    SidePadding.PaddingRight = UDim.new(0, 8)
    SidePadding.Parent = SideBar

    -- Контейнер для контента (опущен чуть ниже, чтобы уступить место заголовку)
    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Position = UDim2.new(0, 165, 0, 45)
    Container.Size = UDim2.new(1, -175, 1, -55)
    Container.BackgroundTransparency = 1
    Container.Parent = MainFrame

    function Library:AddTooltip(element, text)
        local hoverToken = 0
        element.MouseEnter:Connect(function()
            hoverToken = hoverToken + 1
            local currentToken = hoverToken
            task.wait(Library.TooltipDelay)
            if currentToken == hoverToken then
                Tooltip.Text = text
                Tooltip.Visible = true
                
                local connection
                connection = game:GetService("RunService").RenderStepped:Connect(function()
                    if not Tooltip.Visible then connection:Disconnect() return end
                    Tooltip.Position = UDim2.new(0, Mouse.X + 15, 0, Mouse.Y + 15)
                end)
            end
        end)
        element.MouseLeave:Connect(function()
            hoverToken = hoverToken + 1
            Tooltip.Visible = false
        end)
    end

    local WindowAPI = {}
    function WindowAPI:CreateTab(tabName)
        -- Кнопка вкладки
        local TabButton = Instance.new("TextButton")
        TabButton.Size = UDim2.new(1, 0, 0, 32)
        TabButton.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
        TabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        TabButton.Text = tabName
        TabButton.Font = Enum.Font.GothamMedium
        TabButton.TextSize = 13
        TabButton.Parent = SideBar

        local TabBtnCorner = Instance.new("UICorner")
        TabBtnCorner.CornerRadius = UDim.new(0, 6)
        TabBtnCorner.Parent = TabButton

        -- Страница с функциями
        local Page = Instance.new("ScrollingFrame")
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.Visible = false
        Page.CanvasSize = UDim2.new(0, 0, 0, 0)
        Page.ScrollBarThickness = 2
        Page.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 50)
        Page.Parent = Container

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent = Page
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 6)
        
        -- ИСПРАВЛЕННЫЙ ХЕНДЛЕР: Теперь холст динамически расширяется и показывает функции!
        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 15)
        end)

        -- Логика переключения
        local function SelectThisTab()
            if Library.CurrentTab then
                Library.CurrentTab.Page.Visible = false
                Library.CurrentTab.Button.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
                Library.CurrentTab.Button.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
            Page.Visible = true
            TopTabTitle.Text = tabName:upper() -- Меняем текст по центру сверху
            TabButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
            TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            Library.CurrentTab = {Page = Page, Button = TabButton}
        end

        TabButton.MouseButton1Click:Connect(SelectThisTab)

        -- Если это самая первая вкладка — активируем её сразу
        if not Library.CurrentTab then
            SelectThisTab()
        end

        -- Безопасный загрузчик компонентов
        local TabAPI = {}
        local baseUrl = "https://raw.githubusercontent.com/geragori11/XMENUE/refs/heads/main/UI/options/"
        local optCache = "?t=" .. math.random(1, 999999)
        
        local function loadModule(fileName, ...)
            local targetUrl = baseUrl .. fileName .. optCache
            local success, code = pcall(game.HttpGet, game, targetUrl)
            if not success or not code then return error("Не удалось загрузить компонент: " .. fileName) end
            
            local chunk, err = loadstring(code)
            if not chunk then return error("Ошибка синтаксиса в " .. fileName .. ": " .. tostring(err)) end
            
            return chunk()(...)
        end

        function TabAPI:AddText(text)
            return loadModule("text.lua", Page, text, Library)
        end

        function TabAPI:AddKeybind(config)
            return loadModule("keybind.lua", Page, config, Library)
        end

        function TabAPI:AddSlider(config)
            return loadModule("slidermove.lua", Page, config, Library)
        end

        function TabAPI:AddColorpicker(config)
            return loadModule("colorpicker.lua", Page, config, Library)
        end

        return TabAPI
    end

    return WindowAPI
end

return Library
