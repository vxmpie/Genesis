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

function UI.Create(Config, ResetModule, AuctionModule, WashModule, RepairModule, GradingModule, LocksmithModule, StockModule, RewardsModule, UtilsModule)
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
    FloatingBtn.Size = UDim2.new(0, 48, 0, 48)
    FloatingBtn.Position = UDim2.new(1, -65, 0.5, -24)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
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
    MainFrame.Size = UDim2.new(0, 720, 0, 460)
    MainFrame.Position = UDim2.new(0.5, -360, 0.5, -230)
    MainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
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
    mainStroke.Color = Color3.fromRGB(32, 32, 38)
    mainStroke.Thickness = 1
    mainStroke.Parent = MainFrame

    FloatingBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 180, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame

    local sideCorner = Instance.new("UICorner")
    sideCorner.CornerRadius = UDim.new(0, 10)
    sideCorner.Parent = Sidebar

    local sideFix = Instance.new("Frame")
    sideFix.Size = UDim2.new(0, 12, 1, 0)
    sideFix.Position = UDim2.new(1, -12, 0, 0)
    sideFix.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    sideFix.BorderSizePixel = 0
    sideFix.Parent = Sidebar

    local LogoLabel = Instance.new("TextLabel")
    LogoLabel.Size = UDim2.new(1, -20, 0, 45)
    LogoLabel.Position = UDim2.new(0, 15, 0, 8)
    LogoLabel.BackgroundTransparency = 1
    LogoLabel.Text = "GENESIS HUB"
    LogoLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    LogoLabel.Font = Enum.Font.GothamBlack
    LogoLabel.TextSize = 17
    LogoLabel.TextXAlignment = Enum.TextXAlignment.Left
    LogoLabel.Parent = Sidebar

    local NavContainer = Instance.new("Frame")
    NavContainer.Size = UDim2.new(1, -16, 1, -65)
    NavContainer.Position = UDim2.new(0, 8, 0, 55)
    NavContainer.BackgroundTransparency = 1
    NavContainer.Parent = Sidebar

    local navLayout = Instance.new("UIListLayout")
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, 5)
    navLayout.Parent = NavContainer

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, -180, 0, 48)
    TopBar.Position = UDim2.new(0, 180, 0, 0)
    TopBar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 10)
    topCorner.Parent = TopBar

    local topFix = Instance.new("Frame")
    topFix.Size = UDim2.new(0, 12, 1, 0)
    topFix.Position = UDim2.new(0, 0, 0, 0)
    topFix.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    topFix.BorderSizePixel = 0
    topFix.Parent = TopBar

    local TabTitle = Instance.new("TextLabel")
    TabTitle.Size = UDim2.new(0, 200, 1, 0)
    TabTitle.Position = UDim2.new(0, 15, 0, 0)
    TabTitle.BackgroundTransparency = 1
    TabTitle.Text = "Info"
    TabTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
    TabTitle.Font = Enum.Font.GothamBold
    TabTitle.TextSize = 16
    TabTitle.TextXAlignment = Enum.TextXAlignment.Left
    TabTitle.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -38, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(38, 25, 28)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 13
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = TopBar

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 6)
    cbCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    local PagesContainer = Instance.new("Frame")
    PagesContainer.Size = UDim2.new(1, -195, 1, -60)
    PagesContainer.Position = UDim2.new(0, 190, 0, 52)
    PagesContainer.BackgroundTransparency = 1
    PagesContainer.Parent = MainFrame

    local TabPages = {}
    local TabButtons = {}
    local CurrentTab = "Info"

    local function createPage(name)
        local Page = Instance.new("ScrollingFrame")
        Page.Name = name .. "Page"
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.ScrollBarThickness = 3
        Page.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
        Page.BorderSizePixel = 0
        Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        Page.CanvasSize = UDim2.new(0, 0, 0, 0)
        Page.Visible = false
        Page.Parent = PagesContainer

        local pLayout = Instance.new("UIListLayout")
        pLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pLayout.Padding = UDim.new(0, 8)
        pLayout.Parent = Page

        TabPages[name] = Page
        return Page
    end

    local function switchTab(name)
        CurrentTab = name
        TabTitle.Text = name
        for tName, page in pairs(TabPages) do
            page.Visible = (tName == name)
        end
        for tName, btn in pairs(TabButtons) do
            if tName == name then
                btn.BackgroundColor3 = Color3.fromRGB(35, 25, 30)
                btn.TextColor3 = Color3.fromRGB(255, 70, 70)
            else
                btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
                btn.TextColor3 = Color3.fromRGB(160, 160, 175)
            end
        end
    end

    local function createNavButton(name, icon, order)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 36)
        Btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
        Btn.Text = "  " .. icon .. "  " .. name
        Btn.TextColor3 = Color3.fromRGB(160, 160, 175)
        Btn.Font = Enum.Font.GothamBold
        Btn.TextSize = 13
        Btn.TextXAlignment = Enum.TextXAlignment.Left
        Btn.AutoButtonColor = false
        Btn.LayoutOrder = order
        Btn.Parent = NavContainer

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = Btn

        Btn.MouseButton1Click:Connect(function()
            switchTab(name)
        end)

        TabButtons[name] = Btn
        return Btn
    end

    local function createCard(parent, titleText, order)
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, -6, 0, 0)
        Card.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        Card.AutomaticSize = Enum.AutomaticSize.Y
        Card.LayoutOrder = order
        Card.Parent = parent

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = Card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = Color3.fromRGB(32, 32, 38)
        cStroke.Thickness = 1
        cStroke.Parent = Card

        local Padding = Instance.new("UIPadding")
        Padding.PaddingTop = UDim.new(0, 10)
        Padding.PaddingBottom = UDim.new(0, 10)
        Padding.PaddingLeft = UDim.new(0, 12)
        Padding.PaddingRight = UDim.new(0, 12)
        Padding.Parent = Card

        local cLayout = Instance.new("UIListLayout")
        cLayout.SortOrder = Enum.SortOrder.LayoutOrder
        cLayout.Padding = UDim.new(0, 8)
        cLayout.Parent = Card

        if titleText then
            local Header = Instance.new("TextLabel")
            Header.Size = UDim2.new(1, 0, 0, 20)
            Header.BackgroundTransparency = 1
            Header.Text = titleText:upper()
            Header.TextColor3 = Color3.fromRGB(120, 120, 140)
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
        Row.Size = UDim2.new(1, 0, 0, 32)
        Row.BackgroundTransparency = 1
        Row.LayoutOrder = order
        Row.Parent = parent

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.7, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.Text = labelText
        Label.TextColor3 = Color3.fromRGB(220, 220, 230)
        Label.Font = Enum.Font.GothamSemibold
        Label.TextSize = 13
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0, 48, 0, 22)
        Btn.Position = UDim2.new(1, -48, 0.5, -11)
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

    local function createInput(parent, labelText, initialVal, onFocusLost, order)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 32)
        Row.BackgroundTransparency = 1
        Row.LayoutOrder = order
        Row.Parent = parent

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.6, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.Text = labelText
        Label.TextColor3 = Color3.fromRGB(220, 220, 230)
        Label.Font = Enum.Font.GothamSemibold
        Label.TextSize = 13
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        local Box = Instance.new("TextBox")
        Box.Size = UDim2.new(0, 90, 0, 24)
        Box.Position = UDim2.new(1, -90, 0.5, -12)
        Box.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
        Box.TextColor3 = Color3.fromRGB(255, 255, 255)
        Box.Text = tostring(initialVal)
        Box.Font = Enum.Font.GothamBold
        Box.TextSize = 12
        Box.ClearTextOnFocus = false
        Box.Parent = Row

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 5)
        bCorner.Parent = Box

        local bStroke = Instance.new("UIStroke")
        bStroke.Color = Color3.fromRGB(45, 45, 55)
        bStroke.Thickness = 1
        bStroke.Parent = Box

        Box.FocusLost:Connect(function()
            onFocusLost(Box.Text)
            Config.Save()
        end)

        return Row
    end

    createNavButton("Info", "ℹ", 1)
    createNavButton("Farming", "🎮", 2)
    createNavButton("Management", "💼", 3)
    createNavButton("Utilities", "🔧", 4)
    createNavButton("Settings", "⚙", 5)

    local infoPage = createPage("Info")
    local accCard = createCard(infoPage, "Account & Game Info", 1)
    
    local function addInfoRow(parent, label, val)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.4, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = Color3.fromRGB(140, 140, 155)
        l.Font = Enum.Font.GothamSemibold
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = row

        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(0.6, 0, 1, 0)
        v.Position = UDim2.new(0.4, 0, 0, 0)
        v.BackgroundTransparency = 1
        v.Text = val
        v.TextColor3 = Color3.fromRGB(240, 240, 250)
        v.Font = Enum.Font.GothamBold
        v.TextSize = 12
        v.TextXAlignment = Enum.TextXAlignment.Left
        v.Parent = row
    end

    addInfoRow(accCard, "User", LocalPlayer.Name)
    addInfoRow(accCard, "Game", "Storage Hunters")
    addInfoRow(accCard, "Place ID", tostring(game.PlaceId))
    addInfoRow(accCard, "Status", "Active & Keyless")

    local featCard = createCard(infoPage, "Available Systems", 2)
    addInfoRow(featCard, "Farming", "Auto-Bid, Fast Loot, Powers, Kick NPC")
    addInfoRow(featCard, "Management", "Auto-Wash, Repair, Grade, Safes, Stock")
    addInfoRow(featCard, "Utilities", "Anti-Stuck Guard, Speeds, Drinks, Upgrades")

    local farmingPage = createPage("Farming")
    local aucCard = createCard(farmingPage, "Auction & Bid System", 1)
    
    createToggle(aucCard, "Auto Bid", State.AutoBid, function()
        State.AutoBid = not State.AutoBid
        return State.AutoBid
    end, 1)

    createToggle(aucCard, "Fast Auction Pickup (Instant Loot)", State.FastPickup, function()
        State.FastPickup = not State.FastPickup
        return State.FastPickup
    end, 2)

    createToggle(aucCard, "Auto X-Ray Powers", State.AutoXRay, function()
        State.AutoXRay = not State.AutoXRay
        return State.AutoXRay
    end, 3)

    createToggle(aucCard, "Auto Calculator Powers", State.AutoCalculator, function()
        State.AutoCalculator = not State.AutoCalculator
        return State.AutoCalculator
    end, 4)

    createToggle(aucCard, "Auto Kick Competitor NPC", State.AutoKickNPC, function()
        State.AutoKickNPC = not State.AutoKickNPC
        return State.AutoKickNPC
    end, 5)

    createInput(aucCard, "Minimum Bid ($)", State.MinimumBid, function(val)
        State.MinimumBid = tonumber(val) or 1000
    end, 6)

    createInput(aucCard, "Maximum Bid ($)", State.MaximumBid, function(val)
        State.MaximumBid = tonumber(val) or 1000000
    end, 7)

    local lfCard = createCard(farmingPage, "Lost & Found", 2)
    createToggle(lfCard, "Auto Collect Lost & Found", State.AutoLostFound, function()
        State.AutoLostFound = not State.AutoLostFound
        return State.AutoLostFound
    end, 1)

    local mgmtPage = createPage("Management")
    local washCard = createCard(mgmtPage, "Auto Wash System", 1)
    
    createToggle(washCard, "Auto Wash (Send & Claim)", State.AutoWash, function()
        State.AutoWash = not State.AutoWash
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
        rBtn.Name = rarity
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

        local color = RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)

        local function updateRBtn(enabled)
            if enabled then
                rBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 40)
                rBtn.TextColor3 = color
                rbStroke.Color = color
            else
                rBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
                rBtn.TextColor3 = Color3.fromRGB(75, 75, 85)
                rbStroke.Color = Color3.fromRGB(35, 35, 42)
            end
        end

        updateRBtn(State.WashRarities[rarity] == true)

        rBtn.MouseButton1Click:Connect(function()
            State.WashRarities[rarity] = not State.WashRarities[rarity]
            updateRBtn(State.WashRarities[rarity])
            Config.Save()
        end)
    end

    local repCard = createCard(mgmtPage, "Repair & Grading", 2)
    createToggle(repCard, "Auto Repair Items", State.AutoRepair, function()
        State.AutoRepair = not State.AutoRepair
        return State.AutoRepair
    end, 1)

    createToggle(repCard, "Auto Wrench Won Items", State.AutoWrench, function()
        State.AutoWrench = not State.AutoWrench
        return State.AutoWrench
    end, 2)

    createToggle(repCard, "Auto Grade Items (PSA)", State.AutoGrade, function()
        State.AutoGrade = not State.AutoGrade
        return State.AutoGrade
    end, 3)

    local safeCard = createCard(mgmtPage, "Locksmith & Safes", 3)
    createToggle(safeCard, "Auto Locksmith Slots", State.AutoLocksmith, function()
        State.AutoLocksmith = not State.AutoLocksmith
        return State.AutoLocksmith
    end, 1)

    createToggle(safeCard, "Auto Picklock Inventory Safes", State.AutoOpenSafes, function()
        State.AutoOpenSafes = not State.AutoOpenSafes
        return State.AutoOpenSafes
    end, 2)

    local shopCard = createCard(mgmtPage, "Shop & Stock & Sell", 4)
    createToggle(shopCard, "Auto Stock Shelves", State.AutoStock, function()
        State.AutoStock = not State.AutoStock
        return State.AutoStock
    end, 1)

    createToggle(shopCard, "Auto Sell to Pawn Shop", State.AutoSell, function()
        State.AutoSell = not State.AutoSell
        return State.AutoSell
    end, 2)

    local rewCard = createCard(mgmtPage, "Rewards & Museum", 5)
    createToggle(rewCard, "Auto Collect Museum Cash", State.AutoMuseum, function()
        State.AutoMuseum = not State.AutoMuseum
        return State.AutoMuseum
    end, 1)

    createToggle(rewCard, "Auto Claim Collections", State.AutoCollections, function()
        State.AutoCollections = not State.AutoCollections
        return State.AutoCollections
    end, 2)

    createToggle(rewCard, "Auto Claim Daily Rewards", State.AutoDailyReward, function()
        State.AutoDailyReward = not State.AutoDailyReward
        return State.AutoDailyReward
    end, 3)

    local utilsPage = createPage("Utilities")
    local guardCard = createCard(utilsPage, "Anti-Stuck & Guard", 1)

    createToggle(guardCard, "Anti-Stuck Movement Guard", State.AntiStuck, function()
        State.AntiStuck = not State.AntiStuck
        State.IsActive = State.AntiStuck
        return State.AntiStuck
    end, 1)

    createInput(guardCard, "Max Idle Threshold (Seconds)", State.IntervalValue, function(val)
        local n = tonumber(val) or 15
        State.IntervalValue = n
        State.IntervalSeconds = n
    end, 2)

    local moveCard = createCard(utilsPage, "Movement Enhancements", 2)
    createToggle(moveCard, "WalkSpeed Boost", State.WalkSpeedEnabled, function()
        State.WalkSpeedEnabled = not State.WalkSpeedEnabled
        return State.WalkSpeedEnabled
    end, 1)

    createInput(moveCard, "WalkSpeed Value", State.WalkSpeedValue, function(val)
        State.WalkSpeedValue = tonumber(val) or 16
    end, 2)

    createToggle(moveCard, "JumpPower Boost", State.JumpPowerEnabled, function()
        State.JumpPowerEnabled = not State.JumpPowerEnabled
        return State.JumpPowerEnabled
    end, 3)

    createInput(moveCard, "JumpPower Value", State.JumpPowerValue, function(val)
        State.JumpPowerValue = tonumber(val) or 50
    end, 4)

    createToggle(moveCard, "Noclip", State.Noclip, function()
        State.Noclip = not State.Noclip
        return State.Noclip
    end, 5)

    local drinkCard = createCard(utilsPage, "Energy Drinks & Upgrades", 3)
    createToggle(drinkCard, "Auto Buy Energy Drinks", State.AutoBuyDrinks, function()
        State.AutoBuyDrinks = not State.AutoBuyDrinks
        return State.AutoBuyDrinks
    end, 1)

    createToggle(drinkCard, "Auto Use Energy Drinks", State.AutoUseDrinks, function()
        State.AutoUseDrinks = not State.AutoUseDrinks
        return State.AutoUseDrinks
    end, 2)

    createToggle(drinkCard, "Auto Buy Shop Upgrades", State.AutoBuyUpgrades, function()
        State.AutoBuyUpgrades = not State.AutoBuyUpgrades
        return State.AutoBuyUpgrades
    end, 3)

    local settPage = createPage("Settings")
    local settCard = createCard(settPage, "Script Management", 1)

    local SaveBtn = Instance.new("TextButton")
    SaveBtn.Size = UDim2.new(1, 0, 0, 36)
    SaveBtn.BackgroundColor3 = Color3.fromRGB(30, 90, 45)
    SaveBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
    SaveBtn.Text = "SAVE CURRENT CONFIG"
    SaveBtn.Font = Enum.Font.GothamBold
    SaveBtn.TextSize = 13
    SaveBtn.AutoButtonColor = false
    SaveBtn.LayoutOrder = 1
    SaveBtn.Parent = settCard

    local sbCorner = Instance.new("UICorner")
    sbCorner.CornerRadius = UDim.new(0, 6)
    sbCorner.Parent = SaveBtn

    SaveBtn.MouseButton1Click:Connect(function()
        Config.Save()
        SaveBtn.Text = "CONFIG SAVED!"
        task.wait(1.5)
        SaveBtn.Text = "SAVE CURRENT CONFIG"
    end)

    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Size = UDim2.new(1, 0, 0, 36)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 28)
    UnloadBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
    UnloadBtn.Text = "UNLOAD GENESIS HUB"
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.TextSize = 13
    UnloadBtn.AutoButtonColor = false
    UnloadBtn.LayoutOrder = 2
    UnloadBtn.Parent = settCard

    local ulCorner = Instance.new("UICorner")
    ulCorner.CornerRadius = UDim.new(0, 6)
    ulCorner.Parent = UnloadBtn

    UnloadBtn.MouseButton1Click:Connect(function()
        AuctionModule.StopLoop()
        WashModule.StopAutoWashLoop()
        RepairModule.StopLoop()
        GradingModule.StopLoop()
        LocksmithModule.StopLoop()
        StockModule.StopLoop()
        RewardsModule.StopLoop()
        UtilsModule.StopLoop()
        ScreenGui:Destroy()
    end)

    switchTab("Info")

    AuctionModule.StartLoop(State)
    WashModule.StartAutoWashLoop(State)
    RepairModule.StartLoop(State)
    GradingModule.StartLoop(State)
    LocksmithModule.StartLoop(State)
    StockModule.StartLoop(State)
    RewardsModule.StartLoop(State)
    UtilsModule.StartLoop(State)
    ResetModule.StartTracker(State, nil, nil)
end

return UI
