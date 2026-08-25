local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
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
    ToggleOn = Color3.fromRGB(255, 60, 75),
}

local RARITY_COLORS = {
    Common = Color3.fromRGB(170, 170, 170),
    Uncommon = Color3.fromRGB(75, 215, 95),
    Rare = Color3.fromRGB(55, 145, 255),
    Epic = Color3.fromRGB(175, 75, 255),
    Legendary = Color3.fromRGB(255, 175, 35),
    Mythic = Color3.fromRGB(255, 55, 115),
    Exotic = Color3.fromRGB(0, 225, 225),
    Secret = Color3.fromRGB(255, 215, 75),
}

local RARITY_LIST = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exotic", "Secret" }

function UI.Create(Config, ResetModule, WashModule, AuctionModule, TeleportModule)
    local State = Config.State

    if CoreGui:FindFirstChild("GenesisHubGUI") then
        CoreGui.GenesisHubGUI:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GenesisHubGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = "FloatingBtn"
    FloatingBtn.Size = UDim2.new(0, 46, 0, 46)
    FloatingBtn.Position = UDim2.new(1, -60, 0.5, -23)
    FloatingBtn.BackgroundColor3 = THEME.Sidebar
    FloatingBtn.TextColor3 = THEME.Primary
    FloatingBtn.Text = "G"
    FloatingBtn.Font = Enum.Font.GothamBlack
    FloatingBtn.TextSize = 24
    FloatingBtn.AutoButtonColor = false
    FloatingBtn.Draggable = true
    FloatingBtn.Parent = ScreenGui

    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(1, 0)
    floatCorner.Parent = FloatingBtn

    local floatStroke = Instance.new("UIStroke")
    floatStroke.Color = THEME.Primary
    floatStroke.Thickness = 2
    floatStroke.Parent = FloatingBtn

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 560, 0, 370)
    MainFrame.Position = UDim2.new(0.5, -280, 0.5, -185)
    MainFrame.BackgroundColor3 = THEME.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false
    MainFrame.Active = true
    MainFrame.Draggable = true
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

    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 160, 1, 0)
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

    local BrandTitle = Instance.new("TextLabel")
    BrandTitle.Size = UDim2.new(1, -20, 0, 24)
    BrandTitle.Position = UDim2.new(0, 14, 0, 10)
    BrandTitle.BackgroundTransparency = 1
    BrandTitle.Text = "GENESIS"
    BrandTitle.TextColor3 = THEME.Primary
    BrandTitle.Font = Enum.Font.GothamBlack
    BrandTitle.TextSize = 17
    BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
    BrandTitle.Parent = BrandFrame

    local BrandSubtitle = Instance.new("TextLabel")
    BrandSubtitle.Size = UDim2.new(1, -20, 0, 14)
    BrandSubtitle.Position = UDim2.new(0, 14, 0, 32)
    BrandSubtitle.BackgroundTransparency = 1
    BrandSubtitle.Text = "Storage Hunter v2.0"
    BrandSubtitle.TextColor3 = THEME.TextSecondary
    BrandSubtitle.Font = Enum.Font.GothamMedium
    BrandSubtitle.TextSize = 10
    BrandSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    BrandSubtitle.Parent = BrandFrame

    local NavContainer = Instance.new("ScrollingFrame")
    NavContainer.Size = UDim2.new(1, -12, 1, -100)
    NavContainer.Position = UDim2.new(0, 6, 0, 56)
    NavContainer.BackgroundTransparency = 1
    NavContainer.ScrollBarThickness = 0
    NavContainer.BorderSizePixel = 0
    NavContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    NavContainer.Parent = Sidebar

    local navLayout = Instance.new("UIListLayout")
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, 4)
    navLayout.Parent = NavContainer

    local ProfileBar = Instance.new("Frame")
    ProfileBar.Size = UDim2.new(1, -16, 0, 36)
    ProfileBar.Position = UDim2.new(0, 8, 1, -44)
    ProfileBar.BackgroundColor3 = THEME.Background
    ProfileBar.BorderSizePixel = 0
    ProfileBar.Parent = Sidebar

    local pbCorner = Instance.new("UICorner")
    pbCorner.CornerRadius = UDim.new(0, 6)
    pbCorner.Parent = ProfileBar

    local UserLabel = Instance.new("TextLabel")
    UserLabel.Size = UDim2.new(1, -12, 1, 0)
    UserLabel.Position = UDim2.new(0, 8, 0, 0)
    UserLabel.BackgroundTransparency = 1
    UserLabel.Text = "@" .. LocalPlayer.Name
    UserLabel.TextColor3 = THEME.TextSecondary
    UserLabel.Font = Enum.Font.GothamMedium
    UserLabel.TextSize = 11
    UserLabel.TextXAlignment = Enum.TextXAlignment.Left
    UserLabel.TextTruncate = Enum.TextTruncate.AtEnd
    UserLabel.Parent = ProfileBar

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, -160, 0, 44)
    TopBar.Position = UDim2.new(0, 160, 0, 0)
    TopBar.BackgroundTransparency = 1
    TopBar.Parent = MainFrame

    local PageTitle = Instance.new("TextLabel")
    PageTitle.Size = UDim2.new(1, -60, 1, 0)
    PageTitle.Position = UDim2.new(0, 16, 0, 0)
    PageTitle.BackgroundTransparency = 1
    PageTitle.Text = "AUTO LOOT & FARM"
    PageTitle.TextColor3 = THEME.TextPrimary
    PageTitle.Font = Enum.Font.GothamBlack
    PageTitle.TextSize = 14
    PageTitle.TextXAlignment = Enum.TextXAlignment.Left
    PageTitle.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 22, 26)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = THEME.Danger
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = TopBar

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 6)
    cbCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    local PagesContainer = Instance.new("Frame")
    PagesContainer.Size = UDim2.new(1, -170, 1, -50)
    PagesContainer.Position = UDim2.new(0, 165, 0, 44)
    PagesContainer.BackgroundTransparency = 1
    PagesContainer.Parent = MainFrame

    local tabs = {}
    local tabButtons = {}
    local activeTab = nil

    local function createTab(id, name, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = THEME.Sidebar
        btn.Text = "   " .. name
        btn.TextColor3 = THEME.TextSecondary
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.LayoutOrder = order
        btn.Parent = NavContainer

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = btn

        local pageScroll = Instance.new("ScrollingFrame")
        pageScroll.Name = id .. "Page"
        pageScroll.Size = UDim2.new(1, -4, 1, -4)
        pageScroll.Position = UDim2.new(0, 0, 0, 0)
        pageScroll.BackgroundTransparency = 1
        pageScroll.ScrollBarThickness = 3
        pageScroll.ScrollBarImageColor3 = THEME.Primary
        pageScroll.BorderSizePixel = 0
        pageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        pageScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        pageScroll.Visible = false
        pageScroll.Parent = PagesContainer

        local pLayout = Instance.new("UIListLayout")
        pLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pLayout.Padding = UDim.new(0, 8)
        pLayout.Parent = pageScroll

        local function activate()
            if activeTab then
                activeTab.Page.Visible = false
                activeTab.Btn.BackgroundColor3 = THEME.Sidebar
                activeTab.Btn.TextColor3 = THEME.TextSecondary
                activeTab.Btn.Font = Enum.Font.GothamMedium
            end
            pageScroll.Visible = true
            btn.BackgroundColor3 = THEME.Background
            btn.TextColor3 = THEME.Primary
            btn.Font = Enum.Font.GothamBold
            PageTitle.Text = name:upper()
            activeTab = { Page = pageScroll, Btn = btn }
        end

        btn.MouseButton1Click:Connect(activate)

        tabs[id] = { Page = pageScroll, Btn = btn, Activate = activate }
        return pageScroll
    end

    local function createCard(parent, titleText, order)
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, -6, 0, 0)
        Card.BackgroundColor3 = THEME.CardBg
        Card.AutomaticSize = Enum.AutomaticSize.Y
        Card.LayoutOrder = order
        Card.Parent = parent

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = Card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = THEME.CardBorder
        cStroke.Thickness = 1
        cStroke.Parent = Card

        local Padding = Instance.new("UIPadding")
        Padding.PaddingTop = UDim.new(0, 10)
        Padding.PaddingBottom = UDim.new(0, 10)
        Padding.PaddingLeft = UDim.new(0, 12)
        Padding.PaddingRight = UDim.new(0, 12)
        Padding.Parent = Card

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = Card

        if titleText then
            local Header = Instance.new("TextLabel")
            Header.Size = UDim2.new(1, 0, 0, 16)
            Header.BackgroundTransparency = 1
            Header.Text = titleText:upper()
            Header.TextColor3 = THEME.Primary
            Header.Font = Enum.Font.GothamBlack
            Header.TextSize = 11
            Header.TextXAlignment = Enum.TextXAlignment.Left
            Header.LayoutOrder = 0
            Header.Parent = Card
        end

        return Card
    end

    local function createToggle(parent, labelText, initialState, onToggle, order)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 28)
        Row.BackgroundTransparency = 1
        Row.LayoutOrder = order
        Row.Parent = parent

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.75, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.Text = labelText
        Label.TextColor3 = THEME.TextPrimary
        Label.Font = Enum.Font.GothamMedium
        Label.TextSize = 12
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0, 44, 0, 20)
        Btn.Position = UDim2.new(1, -44, 0.5, -10)
        Btn.Text = ""
        Btn.AutoButtonColor = false
        Btn.Parent = Row

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(1, 0)
        bCorner.Parent = Btn

        local Circle = Instance.new("Frame")
        Circle.Size = UDim2.new(0, 14, 0, 14)
        Circle.Parent = Btn

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(1, 0)
        cCorner.Parent = Circle

        local function update(val)
            if val then
                Btn.BackgroundColor3 = THEME.Success
                Circle.Position = UDim2.new(1, -17, 0.5, -7)
                Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            else
                Btn.BackgroundColor3 = THEME.ToggleOff
                Circle.Position = UDim2.new(0, 3, 0.5, -7)
                Circle.BackgroundColor3 = Color3.fromRGB(150, 150, 160)
            end
        end

        update(initialState)

        Btn.MouseButton1Click:Connect(function()
            local newState = onToggle()
            update(newState)
            Config.Save()
        end)

        return Row
    end

    local farmPage = createTab("farm", "⚡ Auto Loot & Farm", 1)
    local washPage = createTab("wash", "🧼 Auto Wash Item", 2)
    local guardPage = createTab("guard", "🛡️ Anti-Stuck Guard", 3)
    local tpPage = createTab("teleport", "🗺️ Map Teleports", 4)
    local settingsPage = createTab("settings", "⚙️ Hub Control", 5)

    local lootCard = createCard(farmPage, "Instant Auction Collection", 1)
    createToggle(lootCard, "Fast Loot (Auto-Vehicle & 0ms Pickup)", State.FastPickup, function()
        State.FastPickup = not State.FastPickup
        if State.FastPickup then
            AuctionModule.StartFastPickupLoop(State, WashModule)
        else
            AuctionModule.StopFastPickupLoop()
        end
        return State.FastPickup
    end, 1)

    createToggle(lootCard, "Smart Warp (Bypass Empty Base Returns)", State.SmartWarp, function()
        State.SmartWarp = not State.SmartWarp
        Config.Save()
        return State.SmartWarp
    end, 2)

    local washCard = createCard(washPage, "Auto Item Cleaning", 1)
    createToggle(washCard, "Auto Wash (Send & Collect)", State.AutoWash, function()
        State.AutoWash = not State.AutoWash
        if State.AutoWash then
            WashModule.StartAutoWashLoop(State)
        else
            WashModule.StopAutoWashLoop()
        end
        return State.AutoWash
    end, 1)

    local filterCard = createCard(washPage, "Rarity Filter Matrix", 2)
    local RarityGrid = Instance.new("Frame")
    RarityGrid.Size = UDim2.new(1, 0, 0, 68)
    RarityGrid.BackgroundTransparency = 1
    RarityGrid.LayoutOrder = 1
    RarityGrid.Parent = filterCard

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.23, 0, 0, 30)
    gridLayout.CellPadding = UDim2.new(0.02, 0, 0, 6)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = RarityGrid

    for idx, rarity in ipairs(RARITY_LIST) do
        local rBtn = Instance.new("TextButton")
        rBtn.Size = UDim2.new(1, 0, 1, 0)
        rBtn.Text = rarity
        rBtn.Font = Enum.Font.GothamBold
        rBtn.TextSize = 10
        rBtn.AutoButtonColor = false
        rBtn.LayoutOrder = idx
        rBtn.Parent = RarityGrid

        local rbCorner = Instance.new("UICorner")
        rbCorner.CornerRadius = UDim.new(0, 5)
        rbCorner.Parent = rBtn

        local rbStroke = Instance.new("UIStroke")
        rbStroke.Thickness = 1
        rbStroke.Parent = rBtn

        local col = RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)

        local function updateR()
            local on = State.WashRarities[rarity] == true
            if on then
                rBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
                rBtn.TextColor3 = col
                rbStroke.Color = col
            else
                rBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
                rBtn.TextColor3 = Color3.fromRGB(80, 80, 90)
                rbStroke.Color = Color3.fromRGB(35, 35, 45)
            end
        end

        updateR()

        rBtn.MouseButton1Click:Connect(function()
            State.WashRarities[rarity] = not State.WashRarities[rarity]
            Config.Save()
            updateR()
        end)
    end

    local statusCard = createCard(guardPage, "Watchdog Telemetry", 1)
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, 0, 0, 20)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = State.IsActive and "ACTIVE" or "INACTIVE"
    StatusLabel.TextColor3 = State.IsActive and THEME.Success or THEME.TextSecondary
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 13
    StatusLabel.LayoutOrder = 1
    StatusLabel.Parent = statusCard

    local CountdownLabel = Instance.new("TextLabel")
    CountdownLabel.Size = UDim2.new(1, 0, 0, 36)
    CountdownLabel.BackgroundTransparency = 1
    CountdownLabel.Text = "00:00"
    CountdownLabel.TextColor3 = THEME.TextPrimary
    CountdownLabel.Font = Enum.Font.GothamBlack
    CountdownLabel.TextSize = 28
    CountdownLabel.LayoutOrder = 2
    CountdownLabel.Parent = statusCard

    createToggle(statusCard, "Anti-Stuck Character Reset Guard", State.IsActive, function()
        State.IsActive = not State.IsActive
        if State.IsActive then
            ResetModule.StartTracker(State, CountdownLabel, StatusLabel)
        else
            ResetModule.StopTracker(State, CountdownLabel, StatusLabel)
        end
        return State.IsActive
    end, 3)

    local InputRow = Instance.new("Frame")
    InputRow.Size = UDim2.new(1, 0, 0, 28)
    InputRow.BackgroundTransparency = 1
    InputRow.LayoutOrder = 4
    InputRow.Parent = statusCard

    local InpLabel = Instance.new("TextLabel")
    InpLabel.Size = UDim2.new(0.65, 0, 1, 0)
    InpLabel.BackgroundTransparency = 1
    InpLabel.Text = "Idle Limit (Seconds)"
    InpLabel.TextColor3 = THEME.TextPrimary
    InpLabel.Font = Enum.Font.GothamMedium
    InpLabel.TextSize = 12
    InpLabel.TextXAlignment = Enum.TextXAlignment.Left
    InpLabel.Parent = InputRow

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0, 75, 0, 22)
    Box.Position = UDim2.new(1, -75, 0.5, -11)
    Box.BackgroundColor3 = THEME.Background
    Box.TextColor3 = THEME.TextPrimary
    Box.Text = tostring(State.IntervalValue)
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
        State.IntervalValue = val
        State.IntervalSeconds = val
        Box.Text = tostring(val)
        Config.Save()
    end)

    local mapCard = createCard(tpPage, "Map Fast Travel", 1)
    local locList = TeleportModule.GetLocationList()
    local selectedLoc = State.TeleportTarget or locList[1]

    local TpSelectBtn = Instance.new("TextButton")
    TpSelectBtn.Size = UDim2.new(1, 0, 0, 30)
    TpSelectBtn.BackgroundColor3 = THEME.Background
    TpSelectBtn.Text = "  " .. selectedLoc
    TpSelectBtn.TextColor3 = THEME.TextPrimary
    TpSelectBtn.Font = Enum.Font.GothamBold
    TpSelectBtn.TextSize = 11
    TpSelectBtn.TextXAlignment = Enum.TextXAlignment.Left
    TpSelectBtn.AutoButtonColor = false
    TpSelectBtn.LayoutOrder = 1
    TpSelectBtn.Parent = mapCard

    local tpsCorner = Instance.new("UICorner")
    tpsCorner.CornerRadius = UDim.new(0, 5)
    tpsCorner.Parent = TpSelectBtn

    local tpsStroke = Instance.new("UIStroke")
    tpsStroke.Color = THEME.CardBorder
    tpsStroke.Thickness = 1
    tpsStroke.Parent = TpSelectBtn

    local TpListScroll = Instance.new("ScrollingFrame")
    TpListScroll.Size = UDim2.new(1, 0, 0, 130)
    TpListScroll.BackgroundColor3 = THEME.Background
    TpListScroll.BorderSizePixel = 0
    TpListScroll.ScrollBarThickness = 3
    TpListScroll.ScrollBarImageColor3 = THEME.Primary
    TpListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TpListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    TpListScroll.Visible = false
    TpListScroll.LayoutOrder = 2
    TpListScroll.Parent = mapCard

    local tplsCorner = Instance.new("UICorner")
    tplsCorner.CornerRadius = UDim.new(0, 5)
    tplsCorner.Parent = TpListScroll

    local tplsLayout = Instance.new("UIListLayout")
    tplsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tplsLayout.Padding = UDim.new(0, 2)
    tplsLayout.Parent = TpListScroll

    for idx, locName in ipairs(locList) do
        local lBtn = Instance.new("TextButton")
        lBtn.Size = UDim2.new(1, 0, 0, 24)
        lBtn.BackgroundTransparency = 1
        lBtn.Text = "   " .. locName
        lBtn.TextColor3 = (locName == selectedLoc) and THEME.Primary or THEME.TextSecondary
        lBtn.Font = Enum.Font.GothamMedium
        lBtn.TextSize = 11
        lBtn.TextXAlignment = Enum.TextXAlignment.Left
        lBtn.AutoButtonColor = false
        lBtn.LayoutOrder = idx
        lBtn.Parent = TpListScroll

        lBtn.MouseButton1Click:Connect(function()
            selectedLoc = locName
            State.TeleportTarget = locName
            Config.Save()
            TpSelectBtn.Text = "  " .. selectedLoc
            TpListScroll.Visible = false
        end)
    end

    TpSelectBtn.MouseButton1Click:Connect(function()
        TpListScroll.Visible = not TpListScroll.Visible
    end)

    local TeleportActionBtn = Instance.new("TextButton")
    TeleportActionBtn.Size = UDim2.new(1, 0, 0, 32)
    TeleportActionBtn.BackgroundColor3 = THEME.Primary
    TeleportActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportActionBtn.Text = "TELEPORT NOW"
    TeleportActionBtn.Font = Enum.Font.GothamBold
    TeleportActionBtn.TextSize = 12
    TeleportActionBtn.AutoButtonColor = false
    TeleportActionBtn.LayoutOrder = 3
    TeleportActionBtn.Parent = mapCard

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = TeleportActionBtn

    TeleportActionBtn.MouseButton1Click:Connect(function()
        local ok = TeleportModule.TeleportTo(selectedLoc)
        TeleportActionBtn.Text = ok and "TELEPORTED!" or "LOCATION NOT FOUND"
        task.wait(1.5)
        TeleportActionBtn.Text = "TELEPORT NOW"
    end)

    local coreCard = createCard(settingsPage, "Configuration & Core", 1)

    local SaveBtn = Instance.new("TextButton")
    SaveBtn.Size = UDim2.new(1, 0, 0, 32)
    SaveBtn.BackgroundColor3 = THEME.Background
    SaveBtn.TextColor3 = THEME.TextPrimary
    SaveBtn.Text = "SAVE SETTINGS TO JSON"
    SaveBtn.Font = Enum.Font.GothamBold
    SaveBtn.TextSize = 12
    SaveBtn.AutoButtonColor = false
    SaveBtn.LayoutOrder = 1
    SaveBtn.Parent = coreCard

    local sbBtnCorner = Instance.new("UICorner")
    sbBtnCorner.CornerRadius = UDim.new(0, 6)
    sbBtnCorner.Parent = SaveBtn

    local sbBtnStroke = Instance.new("UIStroke")
    sbBtnStroke.Color = THEME.CardBorder
    sbBtnStroke.Thickness = 1
    sbBtnStroke.Parent = SaveBtn

    SaveBtn.MouseButton1Click:Connect(function()
        Config.Save()
        SaveBtn.Text = "SAVED!"
        task.wait(1.2)
        SaveBtn.Text = "SAVE SETTINGS TO JSON"
    end)

    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Size = UDim2.new(1, 0, 0, 32)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 25)
    UnloadBtn.TextColor3 = THEME.Danger
    UnloadBtn.Text = "UNLOAD GENESIS HUB"
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.TextSize = 12
    UnloadBtn.AutoButtonColor = false
    UnloadBtn.LayoutOrder = 2
    UnloadBtn.Parent = coreCard

    local ubCorner = Instance.new("UICorner")
    ubCorner.CornerRadius = UDim.new(0, 6)
    ubCorner.Parent = UnloadBtn

    UnloadBtn.MouseButton1Click:Connect(function()
        AuctionModule.StopFastPickupLoop()
        WashModule.StopAutoWashLoop()
        ResetModule.StopTracker(State, CountdownLabel, StatusLabel)
        _G.GenesisRunning = nil
        shared.GenesisRunning = nil
        ScreenGui:Destroy()
    end)

    tabs["farm"].Activate()

    if State.IsActive then
        ResetModule.StartTracker(State, CountdownLabel, StatusLabel)
    end
    if State.AutoWash then
        WashModule.StartAutoWashLoop(State)
    end
    if State.FastPickup then
        AuctionModule.StartFastPickupLoop(State, WashModule)
    end
end

return UI
