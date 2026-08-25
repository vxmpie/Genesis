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

function UI.Create(Config, ResetModule, WashModule, AuctionModule)
    local State = Config.State

    if CoreGui:FindFirstChild("GenesisResetTimer") then
        CoreGui.GenesisResetTimer:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GenesisResetTimer"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = "FloatingBtn"
    FloatingBtn.Size = UDim2.new(0, 50, 0, 50)
    FloatingBtn.Position = UDim2.new(1, -70, 0.5, -25)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    FloatingBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
    FloatingBtn.Text = "G"
    FloatingBtn.Font = Enum.Font.GothamBlack
    FloatingBtn.TextSize = 28
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

    FloatingBtn.MouseEnter:Connect(function()
        floatStroke.Thickness = 3
        FloatingBtn.BackgroundColor3 = Color3.fromRGB(25, 20, 22)
    end)
    FloatingBtn.MouseLeave:Connect(function()
        floatStroke.Thickness = 2
        FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    end)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 350, 0, 520)
    MainFrame.Position = UDim2.new(0.5, -175, 0.5, -260)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = MainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(35, 35, 40)
    mainStroke.Thickness = 1
    mainStroke.Parent = MainFrame

    FloatingBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = TitleBar

    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0, 12)
    titleFix.Position = UDim2.new(0, 0, 1, -12)
    titleFix.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -50, 1, 0)
    TitleLabel.Position = UDim2.new(0, 15, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "GENESIS"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    TitleLabel.Font = Enum.Font.GothamBlack
    TitleLabel.TextSize = 18
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    local SubTitle = Instance.new("TextLabel")
    SubTitle.Size = UDim2.new(1, -15, 0, 16)
    SubTitle.Position = UDim2.new(0, 15, 1, -20)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = "Storage Hunter Multi-Tool"
    SubTitle.TextColor3 = Color3.fromRGB(100, 100, 115)
    SubTitle.Font = Enum.Font.GothamMedium
    SubTitle.TextSize = 11
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.Parent = TitleBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -40, 0, 10)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 38)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = TitleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1, -20, 1, -60)
    Content.Position = UDim2.new(0, 10, 0, 55)
    Content.BackgroundTransparency = 1
    Content.ScrollBarThickness = 3
    Content.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
    Content.BorderSizePixel = 0
    Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Content.CanvasSize = UDim2.new(0, 0, 0, 0)
    Content.Parent = MainFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = Content

    local CountdownFrame = Instance.new("Frame")
    CountdownFrame.Size = UDim2.new(1, 0, 0, 90)
    CountdownFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    CountdownFrame.LayoutOrder = 1
    CountdownFrame.Parent = Content

    local cdCorner = Instance.new("UICorner")
    cdCorner.CornerRadius = UDim.new(0, 10)
    cdCorner.Parent = CountdownFrame

    local cdStroke = Instance.new("UIStroke")
    cdStroke.Color = Color3.fromRGB(40, 40, 50)
    cdStroke.Thickness = 1
    cdStroke.Parent = CountdownFrame

    local CountdownLabel = Instance.new("TextLabel")
    CountdownLabel.Name = "Countdown"
    CountdownLabel.Size = UDim2.new(1, 0, 0, 50)
    CountdownLabel.Position = UDim2.new(0, 0, 0, 6)
    CountdownLabel.BackgroundTransparency = 1
    CountdownLabel.Text = "00:00"
    CountdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    CountdownLabel.Font = Enum.Font.GothamBlack
    CountdownLabel.TextSize = 40
    CountdownLabel.Parent = CountdownFrame

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "Status"
    StatusLabel.Size = UDim2.new(1, 0, 0, 20)
    StatusLabel.Position = UDim2.new(0, 0, 1, -24)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "INACTIVE"
    StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 12
    StatusLabel.Parent = CountdownFrame

    local ModeRow = Instance.new("Frame")
    ModeRow.Size = UDim2.new(1, 0, 0, 38)
    ModeRow.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    ModeRow.LayoutOrder = 2
    ModeRow.Parent = Content

    local mrCorner = Instance.new("UICorner")
    mrCorner.CornerRadius = UDim.new(0, 8)
    mrCorner.Parent = ModeRow

    local ModeLabel = Instance.new("TextLabel")
    ModeLabel.Size = UDim2.new(0, 80, 1, 0)
    ModeLabel.Position = UDim2.new(0, 12, 0, 0)
    ModeLabel.BackgroundTransparency = 1
    ModeLabel.Text = "Reset Mode"
    ModeLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    ModeLabel.Font = Enum.Font.GothamSemibold
    ModeLabel.TextSize = 13
    ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
    ModeLabel.Parent = ModeRow

    local ModeBtn = Instance.new("TextButton")
    ModeBtn.Name = "ModeToggle"
    ModeBtn.Size = UDim2.new(0, 115, 0, 26)
    ModeBtn.Position = UDim2.new(1, -127, 0.5, -13)
    ModeBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 48)
    ModeBtn.TextColor3 = Color3.fromRGB(210, 160, 255)
    ModeBtn.Text = State.Mode
    ModeBtn.Font = Enum.Font.GothamBold
    ModeBtn.TextSize = 12
    ModeBtn.AutoButtonColor = false
    ModeBtn.Parent = ModeRow

    local mbCorner = Instance.new("UICorner")
    mbCorner.CornerRadius = UDim.new(0, 6)
    mbCorner.Parent = ModeBtn

    local mbStroke = Instance.new("UIStroke")
    mbStroke.Color = Color3.fromRGB(110, 70, 170)
    mbStroke.Thickness = 1
    mbStroke.Parent = ModeBtn

    local InputRow = Instance.new("Frame")
    InputRow.Size = UDim2.new(1, 0, 0, 38)
    InputRow.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    InputRow.LayoutOrder = 3
    InputRow.Parent = Content

    local irCorner = Instance.new("UICorner")
    irCorner.CornerRadius = UDim.new(0, 8)
    irCorner.Parent = InputRow

    local InputLabel = Instance.new("TextLabel")
    InputLabel.Size = UDim2.new(0, 90, 1, 0)
    InputLabel.Position = UDim2.new(0, 12, 0, 0)
    InputLabel.BackgroundTransparency = 1
    InputLabel.Text = State.Mode == "Anti-Stuck" and "Max Idle (s)" or "Interval"
    InputLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    InputLabel.Font = Enum.Font.GothamSemibold
    InputLabel.TextSize = 13
    InputLabel.TextXAlignment = Enum.TextXAlignment.Left
    InputLabel.Parent = InputRow

    local TimeInput = Instance.new("TextBox")
    TimeInput.Name = "TimeInput"
    TimeInput.Size = UDim2.new(0, 60, 0, 26)
    TimeInput.Position = UDim2.new(0, 105, 0.5, -13)
    TimeInput.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    TimeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    TimeInput.PlaceholderText = tostring(State.IntervalValue)
    TimeInput.Text = tostring(State.IntervalValue)
    TimeInput.Font = Enum.Font.GothamBold
    TimeInput.TextSize = 13
    TimeInput.ClearTextOnFocus = false
    TimeInput.Parent = InputRow

    local tiCorner = Instance.new("UICorner")
    tiCorner.CornerRadius = UDim.new(0, 6)
    tiCorner.Parent = TimeInput

    local tiStroke = Instance.new("UIStroke")
    tiStroke.Color = Color3.fromRGB(50, 50, 60)
    tiStroke.Thickness = 1
    tiStroke.Parent = TimeInput

    local UnitBtn = Instance.new("TextButton")
    UnitBtn.Name = "UnitToggle"
    UnitBtn.Size = UDim2.new(0, 80, 0, 26)
    UnitBtn.Position = UDim2.new(1, -92, 0.5, -13)
    UnitBtn.AutoButtonColor = false
    UnitBtn.Parent = InputRow

    if State.Unit == "Seconds" then
        UnitBtn.BackgroundColor3 = Color3.fromRGB(30, 45, 55)
        UnitBtn.TextColor3 = Color3.fromRGB(100, 200, 255)
        UnitBtn.Text = "Seconds"
    else
        UnitBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 50)
        UnitBtn.TextColor3 = Color3.fromRGB(200, 160, 255)
        UnitBtn.Text = "Minutes"
    end

    UnitBtn.Font = Enum.Font.GothamBold
    UnitBtn.TextSize = 11

    local ubCorner = Instance.new("UICorner")
    ubCorner.CornerRadius = UDim.new(0, 6)
    ubCorner.Parent = UnitBtn

    local ubStroke = Instance.new("UIStroke")
    if State.Unit == "Seconds" then
        ubStroke.Color = Color3.fromRGB(60, 140, 200)
    else
        ubStroke.Color = Color3.fromRGB(120, 80, 180)
    end
    ubStroke.Thickness = 1
    ubStroke.Parent = UnitBtn

    ModeBtn.MouseButton1Click:Connect(function()
        if State.Mode == "Anti-Stuck" then
            State.Mode = "Timer"
            InputLabel.Text = "Interval"
        else
            State.Mode = "Anti-Stuck"
            InputLabel.Text = "Max Idle (s)"
        end
        ModeBtn.Text = State.Mode
        Config.Save()
        if State.IsActive then
            ResetModule.StartTracker(State, CountdownLabel, StatusLabel)
        end
    end)

    UnitBtn.MouseButton1Click:Connect(function()
        if State.Unit == "Minutes" then
            State.Unit = "Seconds"
            UnitBtn.Text = "Seconds"
            UnitBtn.TextColor3 = Color3.fromRGB(100, 200, 255)
            UnitBtn.BackgroundColor3 = Color3.fromRGB(30, 45, 55)
            ubStroke.Color = Color3.fromRGB(60, 140, 200)
        else
            State.Unit = "Minutes"
            UnitBtn.Text = "Minutes"
            UnitBtn.TextColor3 = Color3.fromRGB(200, 160, 255)
            UnitBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 50)
            ubStroke.Color = Color3.fromRGB(120, 80, 180)
        end
        if State.Unit == "Minutes" then
            State.IntervalSeconds = State.IntervalValue * 60
        else
            State.IntervalSeconds = State.IntervalValue
        end
        Config.Save()
    end)

    TimeInput.FocusLost:Connect(function()
        local rawVal = tonumber(TimeInput.Text) or State.IntervalValue
        if rawVal <= 0 then rawVal = 1 end
        State.IntervalValue = rawVal
        TimeInput.Text = tostring(rawVal)
        if State.Unit == "Minutes" then
            State.IntervalSeconds = rawVal * 60
        else
            State.IntervalSeconds = rawVal
        end
        Config.Save()
    end)

    local function createToggleRow(labelText, initialState, onToggle, order)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 40)
        Row.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
        Row.LayoutOrder = order
        Row.Parent = Content

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 8)
        rCorner.Parent = Row

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.65, 0, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = labelText
        Label.TextColor3 = Color3.fromRGB(230, 230, 235)
        Label.Font = Enum.Font.GothamBold
        Label.TextSize = 13
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0, 52, 0, 24)
        Btn.Position = UDim2.new(1, -64, 0.5, -12)
        Btn.Text = ""
        Btn.AutoButtonColor = false
        Btn.Parent = Row

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(1, 0)
        bCorner.Parent = Btn

        local Circle = Instance.new("Frame")
        Circle.Size = UDim2.new(0, 18, 0, 18)
        Circle.Parent = Btn

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(1, 0)
        cCorner.Parent = Circle

        local Text = Instance.new("TextLabel")
        Text.Size = UDim2.new(0, 26, 1, 0)
        Text.BackgroundTransparency = 1
        Text.Font = Enum.Font.GothamBold
        Text.TextSize = 9
        Text.Parent = Btn

        local function updateVisual(val)
            if val then
                Btn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
                Circle.Position = UDim2.new(1, -21, 0.5, -9)
                Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Text.Text = "ON"
                Text.Position = UDim2.new(0, 3, 0, 0)
                Text.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                Circle.Position = UDim2.new(0, 3, 0.5, -9)
                Circle.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
                Text.Text = "OFF"
                Text.Position = UDim2.new(1, -29, 0, 0)
                Text.TextColor3 = Color3.fromRGB(150, 150, 160)
            end
        end

        updateVisual(initialState)

        Btn.MouseButton1Click:Connect(function()
            local newState = onToggle()
            updateVisual(newState)
            Config.Save()
        end)

        return Row, updateVisual
    end

    createToggleRow("Auto Reset Guard", State.IsActive, function()
        State.IsActive = not State.IsActive
        if State.IsActive then
            local rawVal = tonumber(TimeInput.Text) or State.IntervalValue
            if rawVal <= 0 then rawVal = 1 end
            State.IntervalValue = rawVal
            if State.Unit == "Minutes" then
                State.IntervalSeconds = rawVal * 60
            else
                State.IntervalSeconds = rawVal
            end
            cdStroke.Color = Color3.fromRGB(40, 160, 80)
            ResetModule.StartTracker(State, CountdownLabel, StatusLabel)
        else
            cdStroke.Color = Color3.fromRGB(40, 40, 50)
            ResetModule.StopTracker(State, CountdownLabel, StatusLabel)
        end
        return State.IsActive
    end, 4)

    createToggleRow("Auto Wash Items (Send & Claim)", State.AutoWash, function()
        State.AutoWash = not State.AutoWash
        if State.AutoWash then
            WashModule.StartAutoWashLoop(State)
        else
            WashModule.StopAutoWashLoop()
        end
        return State.AutoWash
    end, 5)

    local RaritySection = Instance.new("Frame")
    RaritySection.Size = UDim2.new(1, 0, 0, 105)
    RaritySection.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    RaritySection.LayoutOrder = 6
    RaritySection.Parent = Content

    local rsCorner = Instance.new("UICorner")
    rsCorner.CornerRadius = UDim.new(0, 8)
    rsCorner.Parent = RaritySection

    local RarityTitle = Instance.new("TextLabel")
    RarityTitle.Size = UDim2.new(1, -20, 0, 20)
    RarityTitle.Position = UDim2.new(0, 10, 0, 6)
    RarityTitle.BackgroundTransparency = 1
    RarityTitle.Text = "WASH RARITY FILTER"
    RarityTitle.TextColor3 = Color3.fromRGB(150, 150, 170)
    RarityTitle.Font = Enum.Font.GothamBold
    RarityTitle.TextSize = 11
    RarityTitle.TextXAlignment = Enum.TextXAlignment.Left
    RarityTitle.Parent = RaritySection

    local RarityGrid = Instance.new("Frame")
    RarityGrid.Size = UDim2.new(1, -16, 0, 70)
    RarityGrid.Position = UDim2.new(0, 8, 0, 28)
    RarityGrid.BackgroundTransparency = 1
    RarityGrid.Parent = RaritySection

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.23, 0, 0, 30)
    gridLayout.CellPadding = UDim2.new(0.02, 0, 0, 6)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = RarityGrid

    for idx, rarity in ipairs(RARITY_LIST) do
        local rBtn = Instance.new("TextButton")
        rBtn.Name = rarity
        rBtn.Text = rarity
        rBtn.Font = Enum.Font.GothamBold
        rBtn.TextSize = 10
        rBtn.AutoButtonColor = false
        rBtn.LayoutOrder = idx
        rBtn.Parent = RarityGrid

        local rbCorner = Instance.new("UICorner")
        rbCorner.CornerRadius = UDim.new(0, 6)
        rbCorner.Parent = rBtn

        local rbStroke = Instance.new("UIStroke")
        rbStroke.Thickness = 1
        rbStroke.Parent = rBtn

        local color = RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)

        local function updateRBtn(enabled)
            if enabled then
                rBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
                rBtn.TextColor3 = color
                rbStroke.Color = color
            else
                rBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                rBtn.TextColor3 = Color3.fromRGB(80, 80, 90)
                rbStroke.Color = Color3.fromRGB(40, 40, 48)
            end
        end

        local isEnabled = State.WashRarities[rarity] == true
        updateRBtn(isEnabled)

        rBtn.MouseButton1Click:Connect(function()
            State.WashRarities[rarity] = not State.WashRarities[rarity]
            updateRBtn(State.WashRarities[rarity])
            Config.Save()
        end)
    end

    createToggleRow("Fast Auction Pickup (Instant Loot)", State.FastPickup, function()
        State.FastPickup = not State.FastPickup
        if State.FastPickup then
            AuctionModule.StartFastPickupLoop(State)
        else
            AuctionModule.StopFastPickupLoop()
        end
        return State.FastPickup
    end, 7)

    if State.IsActive then
        ResetModule.StartTracker(State, CountdownLabel, StatusLabel)
    end
    if State.AutoWash then
        WashModule.StartAutoWashLoop(State)
    end
    if State.FastPickup then
        AuctionModule.StartFastPickupLoop(State)
    end

    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Size = UDim2.new(1, 0, 0, 36)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 28)
    UnloadBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
    UnloadBtn.Text = "UNLOAD SCRIPT"
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.TextSize = 12
    UnloadBtn.AutoButtonColor = false
    UnloadBtn.LayoutOrder = 8
    UnloadBtn.Parent = Content

    local ulCorner = Instance.new("UICorner")
    ulCorner.CornerRadius = UDim.new(0, 8)
    ulCorner.Parent = UnloadBtn

    local ulStroke = Instance.new("UIStroke")
    ulStroke.Color = Color3.fromRGB(150, 40, 40)
    ulStroke.Thickness = 1
    ulStroke.Parent = UnloadBtn

    UnloadBtn.MouseEnter:Connect(function()
        UnloadBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 35)
    end)
    UnloadBtn.MouseLeave:Connect(function()
        UnloadBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 28)
    end)

    UnloadBtn.MouseButton1Click:Connect(function()
        ResetModule.StopTracker(State, CountdownLabel, StatusLabel)
        WashModule.StopAutoWashLoop()
        AuctionModule.StopFastPickupLoop()
        ScreenGui:Destroy()
    end)
end

return UI
