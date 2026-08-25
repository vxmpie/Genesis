local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local UI = {}

local RARITY_COLORS = {
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(80, 220, 100),
    Rare = Color3.fromRGB(60, 150, 255),
    Epic = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 180, 40),
    Mythic = Color3.fromRGB(255, 60, 120),
    Exotic = Color3.fromRGB(0, 230, 230),
    Secret = Color3.fromRGB(255, 220, 80),
}

local RARITY_LIST = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exotic", "Secret" }

function UI.Create(Config, ResetModule, WashModule, AuctionModule, TeleportModule)
    local State = Config.State

    if CoreGui:FindFirstChild("GenesisResetTimer") then
        CoreGui.GenesisResetTimer:Destroy()
    end
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
    FloatingBtn.Size = UDim2.new(0, 48, 0, 48)
    FloatingBtn.Position = UDim2.new(1, -65, 0.5, -24)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    FloatingBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
    FloatingBtn.Text = "G"
    FloatingBtn.Font = Enum.Font.GothamBlack
    FloatingBtn.TextSize = 26
    FloatingBtn.AutoButtonColor = false
    FloatingBtn.Draggable = true
    FloatingBtn.Parent = ScreenGui

    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(1, 0)
    floatCorner.Parent = FloatingBtn

    local floatStroke = Instance.new("UIStroke")
    floatStroke.Color = Color3.fromRGB(255, 60, 60)
    floatStroke.Thickness = 2
    floatStroke.Parent = FloatingBtn

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 360, 0, 560)
    MainFrame.Position = UDim2.new(0.5, -180, 0.5, -280)
    MainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
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
    mainStroke.Color = Color3.fromRGB(38, 38, 48)
    mainStroke.Thickness = 1
    mainStroke.Parent = MainFrame

    FloatingBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 48)
    TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -50, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "GENESIS HUB"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    TitleLabel.Font = Enum.Font.GothamBlack
    TitleLabel.TextSize = 16
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -38, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 22, 25)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 13
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = TitleBar

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 6)
    cbCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    local ContentScroll = Instance.new("ScrollingFrame")
    ContentScroll.Size = UDim2.new(1, -16, 1, -58)
    ContentScroll.Position = UDim2.new(0, 8, 0, 52)
    ContentScroll.BackgroundTransparency = 1
    ContentScroll.ScrollBarThickness = 3
    ContentScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
    ContentScroll.BorderSizePixel = 0
    ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ContentScroll.Parent = MainFrame

    local cLayout = Instance.new("UIListLayout")
    cLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cLayout.Padding = UDim.new(0, 8)
    cLayout.Parent = ContentScroll

    local function createCard(titleText, order)
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, 0, 0, 0)
        Card.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        Card.AutomaticSize = Enum.AutomaticSize.Y
        Card.LayoutOrder = order
        Card.Parent = ContentScroll

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = Card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = Color3.fromRGB(35, 35, 45)
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
            Header.Size = UDim2.new(1, 0, 0, 18)
            Header.BackgroundTransparency = 1
            Header.Text = titleText:upper()
            Header.TextColor3 = Color3.fromRGB(255, 75, 75)
            Header.Font = Enum.Font.GothamBlack
            Header.TextSize = 11
            Header.TextXAlignment = Enum.TextXAlignment.Left
            Header.LayoutOrder = 0
            Header.Parent = Card
        end

        return Card
    end

    local statusCard = createCard("Guard & Movement Tracker", 1)

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, 0, 0, 20)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = State.IsActive and "ACTIVE" or "INACTIVE"
    StatusLabel.TextColor3 = State.IsActive and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(150, 150, 160)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 13
    StatusLabel.LayoutOrder = 1
    StatusLabel.Parent = statusCard

    local CountdownLabel = Instance.new("TextLabel")
    CountdownLabel.Size = UDim2.new(1, 0, 0, 36)
    CountdownLabel.BackgroundTransparency = 1
    CountdownLabel.Text = "00:00"
    CountdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    CountdownLabel.Font = Enum.Font.GothamBlack
    CountdownLabel.TextSize = 30
    CountdownLabel.LayoutOrder = 2
    CountdownLabel.Parent = statusCard

    local function createToggle(parent, labelText, initialState, onToggle, order)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 30)
        Row.BackgroundTransparency = 1
        Row.LayoutOrder = order
        Row.Parent = parent

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.7, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.Text = labelText
        Label.TextColor3 = Color3.fromRGB(225, 225, 235)
        Label.Font = Enum.Font.GothamMedium
        Label.TextSize = 13
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0, 46, 0, 22)
        Btn.Position = UDim2.new(1, -46, 0.5, -11)
        Btn.Text = ""
        Btn.AutoButtonColor = false
        Btn.Parent = Row

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(1, 0)
        bCorner.Parent = Btn

        local Circle = Instance.new("Frame")
        Circle.Size = UDim2.new(0, 16, 0, 16)
        Circle.Parent = Btn

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(1, 0)
        cCorner.Parent = Circle

        local function update(val)
            if val then
                Btn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
                Circle.Position = UDim2.new(1, -19, 0.5, -8)
                Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            else
                Btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
                Circle.Position = UDim2.new(0, 3, 0.5, -8)
                Circle.BackgroundColor3 = Color3.fromRGB(160, 160, 170)
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

    createToggle(statusCard, "Anti-Stuck Guard", State.IsActive, function()
        State.IsActive = not State.IsActive
        if State.IsActive then
            ResetModule.StartTracker(State, CountdownLabel, StatusLabel)
        else
            ResetModule.StopTracker(State, CountdownLabel, StatusLabel)
        end
        return State.IsActive
    end, 3)

    local InputRow = Instance.new("Frame")
    InputRow.Size = UDim2.new(1, 0, 0, 30)
    InputRow.BackgroundTransparency = 1
    InputRow.LayoutOrder = 4
    InputRow.Parent = statusCard

    local InpLabel = Instance.new("TextLabel")
    InpLabel.Size = UDim2.new(0.65, 0, 1, 0)
    InpLabel.BackgroundTransparency = 1
    InpLabel.Text = "Idle Threshold (Seconds)"
    InpLabel.TextColor3 = Color3.fromRGB(225, 225, 235)
    InpLabel.Font = Enum.Font.GothamMedium
    InpLabel.TextSize = 13
    InpLabel.TextXAlignment = Enum.TextXAlignment.Left
    InpLabel.Parent = InputRow

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0, 80, 0, 24)
    Box.Position = UDim2.new(1, -80, 0.5, -12)
    Box.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.Text = tostring(State.IntervalValue)
    Box.Font = Enum.Font.GothamBold
    Box.TextSize = 12
    Box.ClearTextOnFocus = false
    Box.Parent = InputRow

    local bxCorner = Instance.new("UICorner")
    bxCorner.CornerRadius = UDim.new(0, 5)
    bxCorner.Parent = Box

    local bxStroke = Instance.new("UIStroke")
    bxStroke.Color = Color3.fromRGB(45, 45, 55)
    bxStroke.Thickness = 1
    bxStroke.Parent = Box

    Box.FocusLost:Connect(function()
        local val = tonumber(Box.Text) or 15
        State.IntervalValue = val
        State.IntervalSeconds = val
        Box.Text = tostring(val)
        Config.Save()
    end)

    local washCard = createCard("Auto Wash Items (Cleaning)", 2)
    createToggle(washCard, "Auto Wash (Send & Claim)", State.AutoWash, function()
        State.AutoWash = not State.AutoWash
        if State.AutoWash then
            WashModule.StartAutoWashLoop(State)
        else
            WashModule.StopAutoWashLoop()
        end
        return State.AutoWash
    end, 1)

    local RarityGrid = Instance.new("Frame")
    RarityGrid.Size = UDim2.new(1, 0, 0, 68)
    RarityGrid.BackgroundTransparency = 1
    RarityGrid.LayoutOrder = 2
    RarityGrid.Parent = washCard

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
                rBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 42)
                rBtn.TextColor3 = col
                rbStroke.Color = col
            else
                rBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
                rBtn.TextColor3 = Color3.fromRGB(75, 75, 85)
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

    local aucCard = createCard("Fast Auction Looting", 3)
    createToggle(aucCard, "Fast Loot (Auto-Vehicle & Instant Pickup)", State.FastPickup, function()
        State.FastPickup = not State.FastPickup
        if State.FastPickup then
            AuctionModule.StartFastPickupLoop(State, WashModule)
        else
            AuctionModule.StopFastPickupLoop()
        end
        return State.FastPickup
    end, 1)

    local tpCard = createCard("Map Locations & Teleport", 4)
    local locList = TeleportModule.GetLocationList()
    local selectedLoc = State.TeleportTarget or locList[1]

    local TpSelectBtn = Instance.new("TextButton")
    TpSelectBtn.Size = UDim2.new(1, 0, 0, 32)
    TpSelectBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    TpSelectBtn.Text = "  " .. selectedLoc
    TpSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TpSelectBtn.Font = Enum.Font.GothamBold
    TpSelectBtn.TextSize = 12
    TpSelectBtn.TextXAlignment = Enum.TextXAlignment.Left
    TpSelectBtn.AutoButtonColor = false
    TpSelectBtn.LayoutOrder = 1
    TpSelectBtn.Parent = tpCard

    local tpsCorner = Instance.new("UICorner")
    tpsCorner.CornerRadius = UDim.new(0, 6)
    tpsCorner.Parent = TpSelectBtn

    local tpsStroke = Instance.new("UIStroke")
    tpsStroke.Color = Color3.fromRGB(45, 45, 55)
    tpsStroke.Thickness = 1
    tpsStroke.Parent = TpSelectBtn

    local TpListScroll = Instance.new("ScrollingFrame")
    TpListScroll.Size = UDim2.new(1, 0, 0, 140)
    TpListScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    TpListScroll.BorderSizePixel = 0
    TpListScroll.ScrollBarThickness = 3
    TpListScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
    TpListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TpListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    TpListScroll.Visible = false
    TpListScroll.LayoutOrder = 2
    TpListScroll.Parent = tpCard

    local tplsCorner = Instance.new("UICorner")
    tplsCorner.CornerRadius = UDim.new(0, 6)
    tplsCorner.Parent = TpListScroll

    local tplsLayout = Instance.new("UIListLayout")
    tplsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tplsLayout.Padding = UDim.new(0, 2)
    tplsLayout.Parent = TpListScroll

    for idx, locName in ipairs(locList) do
        local lBtn = Instance.new("TextButton")
        lBtn.Size = UDim2.new(1, 0, 0, 26)
        lBtn.BackgroundTransparency = 1
        lBtn.Text = "   " .. locName
        lBtn.TextColor3 = (locName == selectedLoc) and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(180, 180, 190)
        lBtn.Font = Enum.Font.GothamMedium
        lBtn.TextSize = 12
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
    TeleportActionBtn.Size = UDim2.new(1, 0, 0, 36)
    TeleportActionBtn.BackgroundColor3 = Color3.fromRGB(210, 45, 50)
    TeleportActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportActionBtn.Text = "TELEPORT NOW"
    TeleportActionBtn.Font = Enum.Font.GothamBold
    TeleportActionBtn.TextSize = 13
    TeleportActionBtn.AutoButtonColor = false
    TeleportActionBtn.LayoutOrder = 3
    TeleportActionBtn.Parent = tpCard

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = TeleportActionBtn

    TeleportActionBtn.MouseButton1Click:Connect(function()
        local ok = TeleportModule.TeleportTo(selectedLoc)
        TeleportActionBtn.Text = ok and "TELEPORTED!" or "LOCATION NOT FOUND"
        task.wait(1.5)
        TeleportActionBtn.Text = "TELEPORT NOW"
    end)

    local setCard = createCard("Script Control", 5)

    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Size = UDim2.new(1, 0, 0, 36)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(60, 22, 26)
    UnloadBtn.TextColor3 = Color3.fromRGB(255, 110, 110)
    UnloadBtn.Text = "UNLOAD GENESIS"
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.TextSize = 13
    UnloadBtn.AutoButtonColor = false
    UnloadBtn.LayoutOrder = 1
    UnloadBtn.Parent = setCard

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
