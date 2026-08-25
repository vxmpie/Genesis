local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local UI = {}

local THEME = {
    Background = Color3.fromRGB(13, 13, 17),
    Sidebar = Color3.fromRGB(18, 18, 24),
    ContentBg = Color3.fromRGB(15, 15, 20),
    CardBg = Color3.fromRGB(22, 22, 30),
    CardBorder = Color3.fromRGB(35, 35, 48),
    Primary = Color3.fromRGB(255, 60, 75),
    PrimaryGlow = Color3.fromRGB(255, 90, 105),
    TextPrimary = Color3.fromRGB(250, 250, 255),
    TextSecondary = Color3.fromRGB(140, 140, 155),
    Success = Color3.fromRGB(45, 200, 105),
    Danger = Color3.fromRGB(240, 60, 70),
    ToggleOff = Color3.fromRGB(40, 40, 52),
    ToggleOn = Color3.fromRGB(255, 60, 75)
}

local RARITY_COLORS = {
    Common = Color3.fromRGB(170, 170, 170),
    Uncommon = Color3.fromRGB(75, 215, 95),
    Rare = Color3.fromRGB(55, 145, 255),
    Epic = Color3.fromRGB(175, 75, 255),
    Legendary = Color3.fromRGB(255, 175, 35),
    Mythical = Color3.fromRGB(255, 55, 115),
    Lost = Color3.fromRGB(0, 225, 225),
    Exclusive = Color3.fromRGB(255, 215, 75)
}

local function getGuiParent()
    local success, parent = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    if success and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function UI.Create(Config, ResetModule, WashModule)
    local State = Config.GetState()
    local parent = getGuiParent()
    local connections = {}

    local existing = parent:FindFirstChild("GenesisRedUI")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GenesisRedUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 9999
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = parent

    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = "FloatingBtn"
    FloatingBtn.Size = UDim2.new(0, 48, 0, 48)
    FloatingBtn.Position = UDim2.new(1, -65, 0.5, -24)
    FloatingBtn.BackgroundColor3 = THEME.Sidebar
    FloatingBtn.TextColor3 = THEME.Primary
    FloatingBtn.Text = "G"
    FloatingBtn.Font = Enum.Font.GothamBlack
    FloatingBtn.TextSize = 24
    FloatingBtn.AutoButtonColor = false
    FloatingBtn.Parent = ScreenGui

    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(1, 0)
    floatCorner.Parent = FloatingBtn

    local floatStroke = Instance.new("UIStroke")
    floatStroke.Color = THEME.Primary
    floatStroke.Thickness = 2
    floatStroke.Parent = FloatingBtn

    local draggingFloat, floatDragInput, floatDragStart, floatStartPos
    FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingFloat = true
            floatDragStart = input.Position
            floatStartPos = FloatingBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingFloat = false
                end
            end)
        end
    end)
    FloatingBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            floatDragInput = input
        end
    end)
    local floatDragConn = UserInputService.InputChanged:Connect(function(input)
        if input == floatDragInput and draggingFloat then
            local delta = input.Position - floatDragStart
            FloatingBtn.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
        end
    end)
    table.insert(connections, floatDragConn)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 540, 0, 390)
    MainFrame.Position = UDim2.new(0.5, -270, 0.5, -195)
    MainFrame.BackgroundColor3 = THEME.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = MainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = THEME.CardBorder
    mainStroke.Thickness = 1.5
    mainStroke.Parent = MainFrame

    FloatingBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    local draggingMain, mainDragInput, mainDragStart, mainStartPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingMain = true
            mainDragStart = input.Position
            mainStartPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingMain = false
                end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            mainDragInput = input
        end
    end)
    local mainDragConn = UserInputService.InputChanged:Connect(function(input)
        if input == mainDragInput and draggingMain then
            local delta = input.Position - mainDragStart
            MainFrame.Position = UDim2.new(mainStartPos.X.Scale, mainStartPos.X.Offset + delta.X, mainStartPos.Y.Scale, mainStartPos.Y.Offset + delta.Y)
        end
    end)
    table.insert(connections, mainDragConn)

    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 150, 1, 0)
    Sidebar.BackgroundColor3 = THEME.Sidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame

    local sbCorner = Instance.new("UICorner")
    sbCorner.CornerRadius = UDim.new(0, 10)
    sbCorner.Parent = Sidebar

    local BrandFrame = Instance.new("Frame")
    BrandFrame.Size = UDim2.new(1, 0, 0, 52)
    BrandFrame.BackgroundTransparency = 1
    BrandFrame.Parent = Sidebar

    local LogoBadge = Instance.new("TextLabel")
    LogoBadge.Size = UDim2.new(0, 28, 0, 28)
    LogoBadge.Position = UDim2.new(0, 12, 0, 12)
    LogoBadge.BackgroundColor3 = Color3.fromRGB(35, 20, 25)
    LogoBadge.TextColor3 = THEME.Primary
    LogoBadge.Text = "G"
    LogoBadge.Font = Enum.Font.GothamBlack
    LogoBadge.TextSize = 16
    LogoBadge.Parent = BrandFrame

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 6)
    badgeCorner.Parent = LogoBadge

    local badgeStroke = Instance.new("UIStroke")
    badgeStroke.Color = THEME.Primary
    badgeStroke.Thickness = 1
    badgeStroke.Parent = LogoBadge

    local BrandTitle = Instance.new("TextLabel")
    BrandTitle.Size = UDim2.new(1, -50, 0, 18)
    BrandTitle.Position = UDim2.new(0, 46, 0, 11)
    BrandTitle.BackgroundTransparency = 1
    BrandTitle.Text = "GENESIS"
    BrandTitle.TextColor3 = THEME.TextPrimary
    BrandTitle.Font = Enum.Font.GothamBlack
    BrandTitle.TextSize = 14
    BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
    BrandTitle.Parent = BrandFrame

    local BrandSub = Instance.new("TextLabel")
    BrandSub.Size = UDim2.new(1, -50, 0, 14)
    BrandSub.Position = UDim2.new(0, 46, 0, 28)
    BrandSub.BackgroundTransparency = 1
    BrandSub.Text = "STORAGE HUNTER"
    BrandSub.TextColor3 = THEME.TextSecondary
    BrandSub.Font = Enum.Font.GothamBold
    BrandSub.TextSize = 8
    BrandSub.TextXAlignment = Enum.TextXAlignment.Left
    BrandSub.Parent = BrandFrame

    local NavContainer = Instance.new("Frame")
    NavContainer.Size = UDim2.new(1, -16, 1, -64)
    NavContainer.Position = UDim2.new(0, 8, 0, 56)
    NavContainer.BackgroundTransparency = 1
    NavContainer.Parent = Sidebar

    local navLayout = Instance.new("UIListLayout")
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, 4)
    navLayout.Parent = NavContainer

    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Size = UDim2.new(1, -158, 1, -16)
    ContentArea.Position = UDim2.new(0, 154, 0, 8)
    ContentArea.BackgroundColor3 = THEME.ContentBg
    ContentArea.BorderSizePixel = 0
    ContentArea.Parent = MainFrame

    local caCorner = Instance.new("UICorner")
    caCorner.CornerRadius = UDim.new(0, 8)
    caCorner.Parent = ContentArea

    local caStroke = Instance.new("UIStroke")
    caStroke.Color = THEME.CardBorder
    caStroke.Thickness = 1
    caStroke.Parent = ContentArea

    local TopBarRight = Instance.new("Frame")
    TopBarRight.Size = UDim2.new(1, 0, 0, 32)
    TopBarRight.BackgroundTransparency = 1
    TopBarRight.Parent = ContentArea

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 24, 0, 24)
    CloseBtn.Position = UDim2.new(1, -30, 0, 4)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 20, 24)
    CloseBtn.TextColor3 = THEME.Danger
    CloseBtn.Text = "X"
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 11
    CloseBtn.Parent = TopBarRight

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 5)
    cbCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    local TabPages = {}
    local TabButtons = {}

    local function createTab(id, name, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        btn.TextColor3 = THEME.TextSecondary
        btn.Text = "  " .. name
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.LayoutOrder = order
        btn.Parent = NavContainer

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, -16, 1, -44)
        page.Position = UDim2.new(0, 8, 0, 36)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = THEME.Primary
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = false
        page.Parent = ContentArea

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Padding = UDim.new(0, 8)
        pageLayout.Parent = page

        btn.MouseButton1Click:Connect(function()
            for k, p in pairs(TabPages) do
                p.Visible = (k == id)
            end
            for k, b in pairs(TabButtons) do
                b.BackgroundColor3 = (k == id) and THEME.Primary or Color3.fromRGB(22, 22, 28)
                b.TextColor3 = (k == id) and Color3.fromRGB(255, 255, 255) or THEME.TextSecondary
            end
        end)

        TabPages[id] = page
        TabButtons[id] = btn
        return page
    end

    local washPage = createTab("wash", "Auto Wash", 1)
    local resetPage = createTab("reset", "Anti-Stuck", 2)
    local settingsPage = createTab("settings", "Settings", 3)

    local function createCard(parentPage, title)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = THEME.CardBg
        card.BorderSizePixel = 0
        card.Parent = parentPage

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 7)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = THEME.CardBorder
        cardStroke.Thickness = 1
        cardStroke.Parent = card

        local cardPad = Instance.new("UIPadding")
        cardPad.PaddingTop = UDim.new(0, 8)
        cardPad.PaddingBottom = UDim.new(0, 8)
        cardPad.PaddingLeft = UDim.new(0, 10)
        cardPad.PaddingRight = UDim.new(0, 10)
        cardPad.Parent = card

        local cLayout = Instance.new("UIListLayout")
        cLayout.SortOrder = Enum.SortOrder.LayoutOrder
        cLayout.Padding = UDim.new(0, 6)
        cLayout.Parent = card

        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, 0, 0, 20)
        header.BackgroundTransparency = 1
        header.Text = title
        header.TextColor3 = THEME.TextPrimary
        header.Font = Enum.Font.GothamBold
        header.TextSize = 12
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = card

        local CardObj = { Card = card }

        function CardObj:AddToggle(text, default, callback)
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 26)
            row.BackgroundTransparency = 1
            row.Parent = card

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -45, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.Text = text
            lbl.TextColor3 = THEME.TextPrimary
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = row

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 36, 0, 18)
            btn.Position = UDim2.new(1, -36, 0.5, -9)
            btn.BackgroundColor3 = default and THEME.ToggleOn or THEME.ToggleOff
            btn.Text = ""
            btn.Parent = row

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 9)
            btnCorner.Parent = btn

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 14, 0, 14)
            knob.Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knob.Parent = btn

            local knobCorner = Instance.new("UICorner")
            knobCorner.CornerRadius = UDim.new(1, 0)
            knobCorner.Parent = knob

            local state = default
            btn.MouseButton1Click:Connect(function()
                state = not state
                TweenService:Create(btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = state and THEME.ToggleOn or THEME.ToggleOff
                }):Play()
                TweenService:Create(knob, TweenInfo.new(0.15), {
                    Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                }):Play()
                callback(state)
            end)
        end

        function CardObj:AddButton(text, callback)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = THEME.Primary
            btn.Font = Enum.Font.GothamBold
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 11
            btn.Parent = card

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 5)
            btnCorner.Parent = btn

            btn.MouseButton1Click:Connect(callback)
        end

        return CardObj
    end

    local washCard = createCard(washPage, "Auto Wash Master Control")
    washCard:AddToggle("Auto Wash Loop", Config.Get("AutoWash", false), function(val)
        Config.Set("AutoWash", val)
        Config.Save()
        if val then
            WashModule.StartAutoWashLoop(Config.GetState())
        else
            WashModule.StopAutoWashLoop()
        end
    end)
    washCard:AddButton("Quick Wash (1-Shot Instant)", function()
        WashModule.ProcessWash(Config.GetState())
    end)

    local rarityCard = createCard(washPage, "Wash Rarities Matrix")
    local state = Config.GetState()
    local rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Lost", "Exclusive"}
    for _, r in ipairs(rarities) do
        local isAllowed = (state.WashRarities and state.WashRarities[r] ~= nil) and state.WashRarities[r] or true
        rarityCard:AddToggle(r, isAllowed, function(val)
            if not state.WashRarities then state.WashRarities = {} end
            state.WashRarities[r] = val
            Config.Save()
        end)
    end

    local trackerCard = createCard(resetPage, "Anti-Stuck Character Reset Tracker")
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, 0, 0, 20)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = State.IsActive and "ACTIVE" or "INACTIVE"
    StatusLabel.TextColor3 = State.IsActive and THEME.Success or THEME.TextSecondary
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 12
    StatusLabel.Parent = trackerCard.Card

    local CountdownLabel = Instance.new("TextLabel")
    CountdownLabel.Size = UDim2.new(1, 0, 0, 36)
    CountdownLabel.BackgroundTransparency = 1
    CountdownLabel.Text = "00:00"
    CountdownLabel.TextColor3 = THEME.TextPrimary
    CountdownLabel.Font = Enum.Font.GothamBlack
    CountdownLabel.TextSize = 28
    CountdownLabel.Parent = trackerCard.Card

    trackerCard:AddToggle("Anti-Stuck Character Reset Guard", State.IsActive or false, function(val)
        State.IsActive = val
        Config.Set("IsActive", val)
        Config.Save()
        if val then
            ResetModule.StartTracker(State, CountdownLabel, StatusLabel)
        else
            ResetModule.StopTracker(State, CountdownLabel, StatusLabel)
        end
    end)

    local InputRow = Instance.new("Frame")
    InputRow.Size = UDim2.new(1, 0, 0, 28)
    InputRow.BackgroundTransparency = 1
    InputRow.Parent = trackerCard.Card

    local InpLabel = Instance.new("TextLabel")
    InpLabel.Size = UDim2.new(0.65, 0, 1, 0)
    InpLabel.BackgroundTransparency = 1
    InpLabel.Text = "Idle Limit (Seconds)"
    InpLabel.TextColor3 = THEME.TextPrimary
    InpLabel.Font = Enum.Font.GothamMedium
    InpLabel.TextSize = 11
    InpLabel.TextXAlignment = Enum.TextXAlignment.Left
    InpLabel.Parent = InputRow

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0, 75, 0, 22)
    Box.Position = UDim2.new(1, -75, 0.5, -11)
    Box.BackgroundColor3 = THEME.Background
    Box.TextColor3 = THEME.TextPrimary
    Box.Text = tostring(State.IntervalSeconds or 15)
    Box.Font = Enum.Font.GothamBold
    Box.TextSize = 11
    Box.ClearTextOnFocus = false
    Box.Parent = InputRow

    local bxCorner = Instance.new("UICorner")
    bxCorner.CornerRadius = UDim.new(0, 4)
    bxCorner.Parent = Box

    local bxStroke = Instance.new("UIStroke")
    bxStroke.Color = THEME.CardBorder
    bxStroke.Thickness = 1
    bxStroke.Parent = Box

    Box.FocusLost:Connect(function()
        local val = tonumber(Box.Text) or 15
        State.IntervalSeconds = val
        State.IntervalValue = val
        Box.Text = tostring(val)
        Config.Save()
    end)

    local settingsCard = createCard(settingsPage, "Configuration & Core")
    settingsCard:AddButton("Save Settings to JSON", function()
        Config.Save()
        StarterGui:SetCore("SendNotification", {
            Title = "GENESIS",
            Text = "Settings Saved Successfully!",
            Duration = 3
        })
    end)
    settingsCard:AddButton("Unload Genesis Hub", function()
        WashModule.StopAutoWashLoop()
        ResetModule.StopTracker(State, CountdownLabel, StatusLabel)
        for _, conn in ipairs(connections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(connections)
        _G.GenesisRunning = nil
        _G.GenesisLoaded = nil
        shared.GenesisRunning = nil
        shared.GenesisLoaded = nil
        ScreenGui:Destroy()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "GENESIS",
                Text = "Genesis Hub completely unloaded!",
                Duration = 3
            })
        end)
    end)

    TabButtons["wash"].BackgroundColor3 = THEME.Primary
    TabButtons["wash"].TextColor3 = Color3.fromRGB(255, 255, 255)
    TabPages["wash"].Visible = true

    if State.IsActive then
        ResetModule.StartTracker(State, CountdownLabel, StatusLabel)
    end
    if State.AutoWash then
        WashModule.StartAutoWashLoop(State)
    end

    local keybindConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed then
            if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
                MainFrame.Visible = not MainFrame.Visible
            end
        end
    end)
    table.insert(connections, keybindConn)

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "GENESIS",
            Text = "Genesis Red UI Loaded! Press LeftShift or 'G' button to Toggle.",
            Duration = 5
        })
    end)
end

return UI
