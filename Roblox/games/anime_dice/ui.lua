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
    ToggleOn = Color3.fromRGB(255, 60, 75),
    BtnSecondary = Color3.fromRGB(28, 28, 38)
}

local function purgeAllGenesisGuis()
    local containers = {}
    pcall(function()
        if gethui then table.insert(containers, gethui()) end
    end)
    pcall(function() table.insert(containers, CoreGui) end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(containers, pg) end
    end)

    for _, container in ipairs(containers) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                local name = child.Name
                if string.find(name, "Genesis") or name == "GenesisRedUI" or name == "GenesisCustomUI" or name == "GenesisHubGUI" then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
end

local function getGuiParent()
    local success, parent = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    if success and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function UI.Create(Config, AutoEquipModule)
    if _G.GenesisUnload then
        pcall(_G.GenesisUnload)
    end

    purgeAllGenesisGuis()

    local State = Config.GetState()
    local parent = getGuiParent()
    local connections = {}

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GenesisRedUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 9999
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = parent

    local function fullUnload()
        if Config and Config.Reset then
            pcall(function() Config.Reset() end)
        end

        State.AutoEquip = false

        if AutoEquipModule and AutoEquipModule.StopLoop then
            pcall(function() AutoEquipModule.StopLoop(State) end)
        end

        for _, conn in ipairs(connections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(connections)

        purgeAllGenesisGuis()

        _G.GenesisRunning = nil
        _G.GenesisLoaded = nil
        _G.GenesisUnload = nil
        shared.GenesisRunning = nil
        shared.GenesisLoaded = nil
        shared.GenesisUnload = nil

        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "GENESIS",
                Text = "Genesis Hub unloaded!",
                Duration = 3
            })
        end)
    end

    _G.GenesisUnload = fullUnload
    shared.GenesisUnload = fullUnload

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
    MainFrame.Size = UDim2.new(0, 560, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
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
    BrandSub.Text = "ANIME DICE"
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
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        btn.TextColor3 = THEME.TextSecondary
        btn.Text = "  " .. name
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
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

    local equipPage = createTab("equip", "Auto Equip", 1)
    local rarityPage = createTab("rarity", "Tiers / Rarities", 2)
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

            local state = (default == true)
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

        function CardObj:AddButton(text, callback, isSecondary)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = isSecondary and THEME.BtnSecondary or THEME.Primary
            btn.Font = Enum.Font.GothamBold
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 11
            btn.Parent = card

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 5)
            btnCorner.Parent = btn

            if isSecondary then
                local bStroke = Instance.new("UIStroke")
                bStroke.Color = THEME.CardBorder
                bStroke.Thickness = 1
                bStroke.Parent = btn
            end

            btn.MouseButton1Click:Connect(callback)
            return btn
        end

        function CardObj:AddSelector(label, options, current, callback)
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 28)
            row.BackgroundTransparency = 1
            row.Parent = card

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0.45, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.Text = label
            lbl.TextColor3 = THEME.TextPrimary
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = row

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.55, 0, 1, 0)
            btn.Position = UDim2.new(0.45, 0, 0, 0)
            btn.BackgroundColor3 = THEME.BtnSecondary
            btn.TextColor3 = THEME.Primary
            btn.Font = Enum.Font.GothamBold
            btn.Text = tostring(current)
            btn.TextSize = 10
            btn.Parent = row

            local bCorner = Instance.new("UICorner")
            bCorner.CornerRadius = UDim.new(0, 5)
            bCorner.Parent = btn

            local bStroke = Instance.new("UIStroke")
            bStroke.Color = THEME.CardBorder
            bStroke.Thickness = 1
            bStroke.Parent = btn

            local curIdx = 1
            for i, opt in ipairs(options) do
                if opt == current then curIdx = i break end
            end

            btn.MouseButton1Click:Connect(function()
                curIdx = curIdx + 1
                if curIdx > #options then curIdx = 1 end
                local chosen = options[curIdx]
                btn.Text = tostring(chosen)
                callback(chosen)
            end)
        end

        function CardObj:AddInfoLabel(text)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 0)
            lbl.AutomaticSize = Enum.AutomaticSize.Y
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.Text = text
            lbl.TextColor3 = THEME.TextSecondary
            lbl.TextSize = 10
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextWrapped = true
            lbl.Parent = card
            return lbl
        end

        return CardObj
    end

    -- ================= TAB 1: AUTO EQUIP =================
    local masterCard = createCard(equipPage, "Master Auto Equip Controls")
    masterCard:AddToggle("Auto Equip Loop (Active)", State.AutoEquip, function(val)
        State.AutoEquip = val
        Config.Set("AutoEquip", val)
        Config.Save()
        if val then
            AutoEquipModule.StartLoop(State)
        else
            AutoEquipModule.StopLoop(State)
        end
    end)

    masterCard:AddSelector("Equip Priority Mode", {
        "RarestFirst",
        "NativeBest"
    }, State.EquipMode or "RarestFirst", function(val)
        State.EquipMode = val
        Config.Set("EquipMode", val)
        Config.Save()
    end)

    local actionsCard = createCard(equipPage, "Instant Actions")
    local statusInfoLabel = nil

    actionsCard:AddButton("Instant Auto Equip (Scan Bag & Fill Slots 1..N)", function()
        AutoEquipModule.ProcessAutoEquip(State)
        local results = AutoEquipModule.GetLastScanResults()
        if statusInfoLabel and #results > 0 then
            local lines = { string.format("Found %d units in bag. Top placed:", #results) }
            for i = 1, math.min(6, #results) do
                local u = results[i]
                table.insert(lines, string.format("Slot %d: %s [%s] (%s)", i, u.Name, u.Rarity, u.FormattedOdds))
            end
            statusInfoLabel.Text = table.concat(lines, "\n")
        end
    end)

    actionsCard:AddButton("Scan Backpack Only (Inspect Odds & Tiers)", function()
        local units = AutoEquipModule.GetInventoryUnits()
        if #units == 0 then
            StarterGui:SetCore("SendNotification", {
                Title = "GENESIS SCAN",
                Text = "0 units detected in backpack!",
                Duration = 3
            })
            if statusInfoLabel then statusInfoLabel.Text = "No units detected in bag." end
            return
        end

        local ranks = AutoEquipModule.RARITY_RANKS or {}
        local ranked = {}
        for _, u in ipairs(units) do
            local oNum, oFmt = AutoEquipModule.CalculateUnitOdds(u)
            u.Odds = oNum
            u.FormattedOdds = oFmt
            u.Rarity = u.Rarity or (u.Meta and u.Meta.rarity) or "Common"
            u.RarityRank = ranks[u.Rarity] or 1
            table.insert(ranked, u)
        end
        table.sort(ranked, function(a, b)
            local rankA = a.RarityRank or 1
            local rankB = b.RarityRank or 1
            if rankA ~= rankB then
                return rankA > rankB
            end
            if a.Odds ~= b.Odds then
                return a.Odds > b.Odds
            end
            return (a.Level or 1) > (b.Level or 1)
        end)

        local lines = { string.format("Scanned %d total units! Top 7 Rarest:", #ranked) }
        for i = 1, math.min(7, #ranked) do
            local u = ranked[i]
            table.insert(lines, string.format("#%d %s [%s] - %s", i, u.Name, u.Rarity, u.FormattedOdds))
        end
        if statusInfoLabel then
            statusInfoLabel.Text = table.concat(lines, "\n")
        end
        StarterGui:SetCore("SendNotification", {
            Title = "GENESIS SCAN",
            Text = string.format("Found %d units. Top: %s (%s)", #ranked, ranked[1].Name, ranked[1].FormattedOdds),
            Duration = 4
        })
    end, true)

    actionsCard:AddButton("Pick All (Unequip All Slots to Bag)", function()
        if AutoEquipModule and AutoEquipModule.PickAll then
            local count = AutoEquipModule.PickAll()
            if statusInfoLabel then
                statusInfoLabel.Text = string.format("Picked up all %d units to backpack!", count)
            end
        end
    end)

    actionsCard:AddButton("Native Equip Best (Game Server Call)", function()
        AutoEquipModule.NativeEquipBest()
    end, true)

    local previewCard = createCard(equipPage, "Backpack Scan & Slot Placements")
    statusInfoLabel = previewCard:AddInfoLabel("Press 'Instant Auto Equip' or 'Scan Backpack' to preview ranked units.")

    local delayCard = createCard(equipPage, "Timing Configuration")
    local dRow = Instance.new("Frame")
    dRow.Size = UDim2.new(1, 0, 0, 28)
    dRow.BackgroundTransparency = 1
    dRow.Parent = delayCard.Card

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(0.65, 0, 1, 0)
    dLbl.BackgroundTransparency = 1
    dLbl.Font = Enum.Font.GothamMedium
    dLbl.Text = "Loop Interval (Seconds)"
    dLbl.TextColor3 = THEME.TextPrimary
    dLbl.TextSize = 11
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.Parent = dRow

    local dBox = Instance.new("TextBox")
    dBox.Size = UDim2.new(0, 75, 0, 22)
    dBox.Position = UDim2.new(1, -75, 0.5, -11)
    dBox.BackgroundColor3 = THEME.Background
    dBox.TextColor3 = THEME.TextPrimary
    dBox.Text = tostring(State.IntervalSeconds or 5)
    dBox.Font = Enum.Font.GothamBold
    dBox.TextSize = 11
    dBox.ClearTextOnFocus = false
    dBox.Parent = dRow

    local dbCorner = Instance.new("UICorner")
    dbCorner.CornerRadius = UDim.new(0, 4)
    dbCorner.Parent = dBox

    local dbStroke = Instance.new("UIStroke")
    dbStroke.Color = THEME.CardBorder
    dbStroke.Thickness = 1
    dbStroke.Parent = dBox

    dBox.FocusLost:Connect(function()
        local val = tonumber(dBox.Text) or 5
        State.IntervalSeconds = val
        dBox.Text = tostring(val)
        Config.Save()
    end)

    -- ================= TAB 2: RARITY / TIERS MATRIX =================
    local raritiesOrder = {
        "Exclusive",
        "Secret II",
        "Secret I",
        "Celestial",
        "Exotic",
        "Divine",
        "Mythical",
        "Legendary",
        "Epic",
        "Rare",
        "Uncommon",
        "Common"
    }

    local rCard = createCard(rarityPage, "Allowed Tiers to Auto Equip (Rarest to Common)")
    for _, rName in ipairs(raritiesOrder) do
        local isAllowed = true
        if State.RarityAllowed and State.RarityAllowed[rName] ~= nil then
            isAllowed = (State.RarityAllowed[rName] == true)
        end
        rCard:AddToggle(rName, isAllowed, function(val)
            if not State.RarityAllowed then State.RarityAllowed = {} end
            State.RarityAllowed[rName] = val
            Config.Save()
        end)
    end

    -- ================= TAB 3: SETTINGS =================
    local sCard = createCard(settingsPage, "Configuration & Core")
    sCard:AddButton("Save Settings to JSON", function()
        Config.Save()
        StarterGui:SetCore("SendNotification", {
            Title = "GENESIS",
            Text = "Settings Saved Successfully!",
            Duration = 3
        })
    end)
    sCard:AddButton("Reset All Settings to Default", function()
        Config.Reset()
        StarterGui:SetCore("SendNotification", {
            Title = "GENESIS",
            Text = "Settings reset to defaults!",
            Duration = 3
        })
    end)
    sCard:AddButton("Unload Genesis Hub", function()
        fullUnload()
    end)

    TabButtons["equip"].BackgroundColor3 = THEME.Primary
    TabButtons["equip"].TextColor3 = Color3.fromRGB(255, 255, 255)
    TabPages["equip"].Visible = true

    if State.AutoEquip then
        AutoEquipModule.StartLoop(State)
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
            Text = "Genesis Anime Dice Hub Loaded! Press 'G' or Shift to toggle.",
            Duration = 5
        })
    end)
end

return UI
